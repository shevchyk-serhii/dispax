package com.shevchyk.app.routes

import com.shevchyk.service.{UserService, OrderService}
import zio.*
import zio.http.*
import zio.json.*

object UserRoutes {
  
  val routes = Routes(
    Method.GET / "api" / "users" ->
      handler {
        (for
          userService <- ZIO.service[UserService]
          users       <- userService.getAllUsers
        yield Response.json(users.toJson))
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      },
    Method.GET / "api" / "users" / long("id") ->
      handler { (id: Long, req: Request) =>
        (for
          userService <- ZIO.service[UserService]
          user        <- userService.getUserById(id)
        yield user match
          case Some(u) => Response.json(u.toJson)
          case None    => Response.status(Status.NotFound)
        )
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      },
    Method.GET / "api" / "orders" ->
      handler {
        (for
          orderService <- ZIO.service[OrderService]
          orders       <- orderService.getAllOrders
        yield Response.json(orders.toJson))
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      },
    Method.GET / "api" / "orders" / long("id") ->
      handler { (id: Long, req: Request) =>
        (for
          orderService <- ZIO.service[OrderService]
          order        <- orderService.getOrderById(id)
        yield order match
          case Some(o) => Response.json(o.toJson)
          case None    => Response.status(Status.NotFound)
        )
          .catchAll(_ => ZIO.succeed(Response.internalServerError))
      }
  )
}