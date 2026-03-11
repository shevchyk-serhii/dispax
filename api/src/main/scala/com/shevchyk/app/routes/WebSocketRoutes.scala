package com.shevchyk.app.routes

import com.shevchyk.core.application.EventHub
import com.shevchyk.auth.service.JwtService
import zio.*
import zio.http.*
import zio.http.ChannelEvent.*
import zio.json.*

object WebSocketRoutes:

  val wsRoutes: Routes[EventHub & JwtService, Nothing] = Routes(
    Method.GET / "api" / "ws" -> handler { (req: Request) =>
      val tokenFromHeader = req.header(Header.Authorization).collect { case Header.Authorization.Bearer(token) =>
        token.value.asString
      }
      val tokenFromQuery  = req.url.queryParams.queryParam("token")
      val tokenOpt        = tokenFromHeader.orElse(tokenFromQuery)

      tokenOpt match
        case None        =>
          ZIO.succeed(
            Response(
              Status.Unauthorized,
              body = Body.fromString("Missing Authorization header or token query parameter")
            )
          )
        case Some(token) =>
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
    }
  )
