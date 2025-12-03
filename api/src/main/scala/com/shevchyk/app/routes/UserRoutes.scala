package com.shevchyk.app.routes

import com.shevchyk.service.{UserService, OrderService}
import RouteHelpers.*
import zio.*
import zio.http.*
import zio.json.*

object UserRoutes {

  val routes = Routes(
    Method.GET / "api" / "users"               ->
      safeEndpoint {
        for
          userService <- ZIO.service[UserService]
          users       <- userService.getAllUsers
        yield jsonResponse(users)
      },
    Method.GET / "api" / "users" / long("id")  ->
      endpointWithParams { (id: Long, req: Request) =>
        for
          userService <- ZIO.service[UserService]
          user        <- userService.getUserById(id)
        yield handleOptionalResult(user)
      },
    Method.GET / "api" / "orders"              ->
      safeEndpoint {
        for
          orderService <- ZIO.service[OrderService]
          orders       <- orderService.getAllOrders
        yield jsonResponse(orders)
      },
    Method.GET / "api" / "orders" / long("id") ->
      endpointWithParams { (id: Long, req: Request) =>
        for
          orderService <- ZIO.service[OrderService]
          order        <- orderService.getOrderById(id)
        yield handleOptionalResult(order)
      }
  )
}
