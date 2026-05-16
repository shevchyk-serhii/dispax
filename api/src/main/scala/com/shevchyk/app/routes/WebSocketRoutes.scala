package com.shevchyk.app.routes

import com.shevchyk.core.application.EventHub
import com.shevchyk.auth.service.JwtService
import zio.*
import zio.http.*
import zio.http.ChannelEvent.*
import zio.json.*

import java.util.UUID

object WebSocketRoutes:

  // Short-lived connection tickets: ticket -> (JWT payload claims needed, expiry)
  private case class WsTicket(token: String, createdAt: Long)

  private val tickets: Ref.Synchronized[Map[String, WsTicket]] = Unsafe.unsafe { implicit unsafe =>
    Runtime.default.unsafe.run(Ref.Synchronized.make(Map.empty[String, WsTicket])).getOrThrowFiberFailure()
  }

  private val TICKET_TTL_SECONDS = 30L

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

  val wsRoutes: Routes[EventHub & JwtService, Nothing] =
    ticketRoute ++ Routes(
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
                                  if event.companyId == payload.companyId.getOrElse(event.companyId) then
                                    channel.send(ChannelEvent.Read(WebSocketFrame.text(event.toJson))).ignore
                                  else ZIO.unit
                                }
                                .forever
                                .fork

                            val receiveMessages = channel.receiveAll {
                              case Read(WebSocketFrame.Close(_, _)) => ZIO.unit
                              case _                                => ZIO.unit
                            }

                            for {
                              fiber <- sendEvents
                              _     <- receiveMessages
                              _     <- fiber.interrupt
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
