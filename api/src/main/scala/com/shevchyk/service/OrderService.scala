package com.shevchyk.service

import com.shevchyk.domain.{Order, Person, Location}
import zio.*

trait OrderService:
  def getAllOrders: Task[List[Order]]
  def getOrderById(id: Long): Task[Option[Order]]
  def createOrder(order: Order): Task[Order]

class OrderServiceImpl extends OrderService:

  private val orders = Ref.make(List.empty[Order])

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
