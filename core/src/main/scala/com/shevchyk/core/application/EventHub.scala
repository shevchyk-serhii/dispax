package com.shevchyk.core.application

import com.shevchyk.core.domain.WebSocketEvent
import zio.*

trait EventHub:
  def publish(event: WebSocketEvent): UIO[Boolean]
  def subscribe: ZIO[Scope, Nothing, Dequeue[WebSocketEvent]]

class EventHubImpl(hub: Hub[WebSocketEvent]) extends EventHub:

  override def publish(event: WebSocketEvent): UIO[Boolean] = hub.publish(event)

  override def subscribe: ZIO[Scope, Nothing, Dequeue[WebSocketEvent]] = hub.subscribe

object EventHub:

  val layer: ZLayer[Any, Nothing, EventHub] = ZLayer.scoped {
    for {
      hub <- Hub.bounded[WebSocketEvent](256)
    } yield EventHubImpl(hub)
  }
