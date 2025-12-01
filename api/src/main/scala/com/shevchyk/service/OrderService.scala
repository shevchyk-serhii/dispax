package com.shevchyk.service

import com.shevchyk.domain.{Order, Person, Location}
import zio.*

trait OrderService:
  def getAllOrders: Task[List[Order]]
  def getOrderById(id: Long): Task[Option[Order]]
  def createOrder(order: Order): Task[Order]

class OrderServiceImpl extends OrderService:

  private val orders = Ref.make(List(
    Order(
      id = 1, 
      customer = Person(1, "John Doe", 30),
      pickup = Location(37.7749, -122.4194, Some("San Francisco")),
      destination = Location(37.7849, -122.4094, Some("Downtown SF"))
    ),
    Order(
      id = 2,
      customer = Person(2, "Jane Smith", 25), 
      pickup = Location(34.0522, -118.2437, Some("Los Angeles")),
      destination = Location(34.0622, -118.2337, Some("Hollywood"))
    )
  ))

  override def getAllOrders: Task[List[Order]] =
    for
      orderRef <- orders
      orders   <- orderRef.get
    yield orders

  override def getOrderById(id: Long): Task[Option[Order]] =
    for
      orderRef <- orders
      orders   <- orderRef.get
    yield orders.find(_.id == id)

  override def createOrder(order: Order): Task[Order] =
    for
      orderRef <- orders
      _        <- orderRef.update(order :: _)
    yield order

object OrderService:
  val live: ULayer[OrderService] = ZLayer.succeed(OrderServiceImpl())