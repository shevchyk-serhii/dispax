package com.shevchyk.app.routes

import com.shevchyk.core.application.EventHub
import com.shevchyk.core.domain.{PersonRole, WebSocketEvent}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.ride.application.service.RideShareTokenService
import zio.*
import zio.http.*
import zio.http.ChannelEvent.*
import zio.json.*

import java.util.UUID

object WebSocketRoutes:

  // -- Guest tracking socket helpers ---------------------------------------

  /**
   * The per-event ride id, used to scope a guest socket to exactly one ride. `LocationUpdated` already carries an
   * `Option[UUID]`; the other guest-relevant events carry a required `rideId`.
   */
  private[app] def eventRideId(event: WebSocketEvent): Option[UUID] =
    event match
      case e: WebSocketEvent.LocationUpdated          => e.rideId
      case e: WebSocketEvent.RideStatusChanged        => Some(e.rideId)
      case e: WebSocketEvent.DriverApproaching        => Some(e.rideId)
      case e: WebSocketEvent.AirportCheckpointReached => Some(e.rideId)
      case _                                          => None

  /**
   * Build the reduced, PII-free JSON a guest socket forwards. Mirrors ZIO-JSON's sealed-trait wrapper (`{"TypeName":
   * {payload}}`) so the Flutter `WebSocketEvent.fromJson` parses it unchanged, but strips every field a guest must not
   * see: driver/client ids, companyId, the driver's userId on a location update. Returns None for any event that is not
   * on the guest allowlist (it must not be forwarded at all).
   */
  private[app] def guestPayload(event: WebSocketEvent): Option[String] =
    event match
      // Only the driver's live position — never the client's.
      case e: WebSocketEvent.LocationUpdated if e.locationType == "driver" =>
        Some(
          s"""{"LocationUpdated":{"rideId":${e.rideId
              .map(id => s"\"$id\"")
              .getOrElse("null")},"latitude":${e.latitude},"longitude":${e.longitude},"locationType":"driver"}}"""
        )
      case e: WebSocketEvent.RideStatusChanged                             =>
        Some(s"""{"RideStatusChanged":{"rideId":"${e.rideId}","newStatus":"${e.newStatus}"}}""")
      case e: WebSocketEvent.DriverApproaching                             =>
        Some(
          s"""{"DriverApproaching":{"rideId":"${e.rideId}","distanceMeters":${e.distanceMeters},"threshold":"${e.threshold}"}}"""
        )
      case e: WebSocketEvent.AirportCheckpointReached                      =>
        Some(
          s"""{"AirportCheckpointReached":{"rideId":"${e.rideId}","checkpointType":"${e.checkpointType}","checkpointName":${e.checkpointName.toJson}}}"""
        )
      case _                                                               => None

  // Short-lived connection tickets: ticket -> (JWT payload claims needed, expiry)
  private case class WsTicket(token: String, createdAt: Long)

  private val tickets: Ref.Synchronized[Map[String, WsTicket]] = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe.run(Ref.Synchronized.make(Map.empty[String, WsTicket])).getOrThrowFiberFailure()
  }

  private val TICKET_TTL_SECONDS = 30L

  /**
   * Tenant filter for the authenticated event socket — fail-closed. A subscriber whose JWT carries a companyId receives
   * exactly that company's events. A token WITHOUT a companyId receives events only when it belongs to a SuperAdmin
   * (platform-wide monitoring); any other companyId-less token receives nothing. The previous
   * `payload.companyId.getOrElse(event.companyId)` made a missing companyId match EVERY event — a fail-open stream of
   * all tenants' data to any historically companyId-less account.
   */
  private[app] def shouldDeliverToAuthenticated(
      eventCompanyId: UUID,
      subscriberCompanyId: Option[UUID],
      subscriberRoles: Set[PersonRole]
  ): Boolean =
    subscriberCompanyId match
      case Some(cid) => cid == eventCompanyId
      case None      => subscriberRoles.contains(PersonRole.SuperAdmin)

  // Server-side heartbeat: without traffic the connection goes idle and Netty's
  // default read timeout (~60s) tears it down, causing clients to flap-reconnect.
  // A periodic Ping keeps the socket live; it must be shorter than the read timeout.
  // Package-private so the heartbeat behaviour can be unit-tested with TestClock.
  private[app] val HEARTBEAT_INTERVAL: Duration = 30.seconds

  // Periodically emit a Ping frame via `send` to keep the connection non-idle.
  // Extracted so it can be unit-tested independently of zio-http's WebSocketChannel.
  // The first ping fires immediately, then once per interval; failures to send are
  // ignored (the channel will surface a real close through receiveAll).
  private[app] def heartbeatLoop[R](send: WebSocketFrame => ZIO[R, Throwable, Unit]): ZIO[R, Nothing, Long] = send(
    WebSocketFrame.ping
  ).ignore
    .repeat(Schedule.spaced(HEARTBEAT_INTERVAL))

  // POST /api/ws/ticket — exchange a JWT for a short-lived WebSocket ticket
  private val ticketRoute: Routes[JwtService, Nothing] = Routes(
    Method.POST / "api" / "ws" / "ticket" -> handler { (req: Request) =>
      val tokenFromHeader = req.header(Header.Authorization).collect { case Header.Authorization.Bearer(token) =>
        token.value.asString
      }

      tokenFromHeader match
        case None        =>
          ZIO.succeed(
            Response(Status.Unauthorized, body = Body.fromString("""{"error":"Missing Authorization header"}"""))
          )
        case Some(token) =>
          ZIO.serviceWithZIO[JwtService] { jwtService =>
            jwtService
              .validateToken(token)
              .foldZIO(
                _ =>
                  ZIO.succeed(Response(Status.Unauthorized, body = Body.fromString("""{"error":"Invalid token"}"""))),
                _ =>
                  val ticketId = UUID.randomUUID().toString
                  val wsTicket = WsTicket(token = token, createdAt = java.lang.System.currentTimeMillis() / 1000)
                  tickets
                    .update(_.updated(ticketId, wsTicket))
                    .as(
                      Response.json(s"""{"ticket":"$ticketId","expiresIn":$TICKET_TTL_SECONDS}""")
                    )
              )
          }
    }
  )

  private def cleanExpiredTickets: UIO[Unit] =
    val now = java.lang.System.currentTimeMillis() / 1000
    tickets.update(_.filter { case (_, t) => (now - t.createdAt) < TICKET_TTL_SECONDS })

  // GET /api/ws/track?token=<shareToken> — public guest tracking socket.
  // No JWT: a high-entropy share token (validated against the ride's tracking window) authorizes a read-only stream
  // for exactly ONE ride. The stream filters by rideId (NOT companyId — filtering by company would leak the whole
  // company's event stream to a guest) and forwards only the PII-free guest payloads from `guestPayload`.
  private val guestTrackRoute: Routes[EventHub & RideShareTokenService, Nothing] = Routes(
    Method.GET / "api" / "ws" / "track" -> handler { (req: Request) =>
      req.url.queryParams.queryParam("token") match
        case None        => ZIO.succeed(Response(Status.BadRequest, body = Body.fromString("Missing token query parameter")))
        case Some(token) =>
          ZIO.serviceWithZIO[RideShareTokenService] { shareTokenService =>
            shareTokenService
              .resolve(token)
              .foldZIO(
                _ => ZIO.succeed(Response(Status.NotFound, body = Body.fromString("Invalid or expired tracking link"))),
                resolved =>
                  val rideId = resolved.rideId.value
                  ZIO.serviceWithZIO[EventHub] { eventHub =>
                    val socketApp = Handler.webSocket { channel =>
                      ZIO.scoped {
                        eventHub.subscribe.flatMap { dequeue =>
                          val sendEvents =
                            dequeue.take
                              .flatMap { event =>
                                if eventRideId(event).contains(rideId) then
                                  guestPayload(event) match
                                    case Some(json) => channel.send(ChannelEvent.Read(WebSocketFrame.text(json))).ignore
                                    case None       => ZIO.unit
                                else ZIO.unit
                              }
                              .forever
                              .fork

                          val heartbeat = heartbeatLoop(frame => channel.send(ChannelEvent.Read(frame))).fork

                          val receiveMessages = channel.receiveAll {
                            case Read(WebSocketFrame.Close(_, _)) => ZIO.unit
                            case Read(WebSocketFrame.Ping)        =>
                              channel.send(ChannelEvent.Read(WebSocketFrame.pong)).ignore
                            case _                                => ZIO.unit
                          }

                          for {
                            sender <- sendEvents
                            pinger <- heartbeat
                            _      <- receiveMessages
                            _      <- sender.interrupt
                            _      <- pinger.interrupt
                          } yield ()
                        }
                      }
                    }
                    socketApp.toResponse
                  }
              )
          }
    }
  )

  val wsRoutes: Routes[EventHub & JwtService & RideShareTokenService, Nothing] =
    ticketRoute ++ guestTrackRoute ++ Routes(
      Method.GET / "api" / "ws" -> handler { (req: Request) =>
        // Accept auth via header (preferred) or via short-lived ticket query param
        val tokenFromHeader = req.header(Header.Authorization).collect { case Header.Authorization.Bearer(token) =>
          token.value.asString
        }
        val ticketParam     = req.url.queryParams.queryParam("ticket")
        val tokenParam      = req.url.queryParams.queryParam("token")

        // Resolve the JWT token: header → ticket → token query param
        val resolveToken: ZIO[Any, Option[Nothing], String] =
          tokenFromHeader match
            case Some(token) => ZIO.succeed(token)
            case None        =>
              ticketParam match
                case Some(ticketId) =>
                  for {
                    _         <- cleanExpiredTickets
                    ticketMap <- tickets.get
                    wsTicket  <- ZIO.fromOption(ticketMap.get(ticketId))
                    // Consume the ticket (one-time use)
                    _         <- tickets.update(_ - ticketId)
                  } yield wsTicket.token
                case None           =>
                  tokenParam match
                    case Some(token) => ZIO.succeed(token)
                    case None        => ZIO.fail(None)

        resolveToken.foldZIO(
          _ =>
            ZIO.succeed(
              Response(
                Status.Unauthorized,
                body = Body.fromString("Missing Authorization header or ticket query parameter")
              )
            ),
          token =>
            ZIO.serviceWithZIO[JwtService] { jwtService =>
              jwtService
                .validateToken(token)
                .foldZIO(
                  _ => ZIO.succeed(Response(Status.Unauthorized, body = Body.fromString("Invalid token"))),
                  payload =>
                    ZIO.serviceWithZIO[EventHub] { eventHub =>
                      val socketApp = Handler.webSocket { channel =>
                        ZIO.scoped {
                          eventHub.subscribe.flatMap { dequeue =>
                            val sendEvents =
                              dequeue.take
                                .flatMap { event =>
                                  if shouldDeliverToAuthenticated(
                                        event.companyId,
                                        payload.companyId,
                                        payload.roles.getOrElse(Nil).toSet + payload.role
                                      )
                                  then channel.send(ChannelEvent.Read(WebSocketFrame.text(event.toJson))).ignore
                                  else ZIO.unit
                                }
                                .forever
                                .fork

                            // Keep the socket non-idle so Netty's read timeout never fires.
                            val heartbeat = heartbeatLoop(frame => channel.send(ChannelEvent.Read(frame))).fork

                            val receiveMessages = channel.receiveAll {
                              case Read(WebSocketFrame.Close(_, _)) => ZIO.unit
                              // Reply to a client Ping with a Pong (RFC 6455); ignore the Pong it sends back.
                              case Read(WebSocketFrame.Ping)        =>
                                channel.send(ChannelEvent.Read(WebSocketFrame.pong)).ignore
                              case _                                => ZIO.unit
                            }

                            for {
                              sender <- sendEvents
                              pinger <- heartbeat
                              _      <- receiveMessages
                              _      <- sender.interrupt
                              _      <- pinger.interrupt
                            } yield ()
                          }
                        }
                      }

                      socketApp.toResponse
                    }
                )
            }
        )
      }
    )
