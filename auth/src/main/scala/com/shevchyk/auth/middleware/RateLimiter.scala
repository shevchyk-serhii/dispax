package com.shevchyk.auth.middleware

import zio.*
import java.time.Instant

trait RateLimiter:
  def checkRate(key: String): UIO[Boolean]

class InMemoryRateLimiter(
    state: Ref[Map[String, List[Instant]]],
    maxRequests: Int,
    windowSeconds: Long
) extends RateLimiter:

  override def checkRate(key: String): UIO[Boolean] =
    val now    = Instant.now()
    val cutoff = now.minusSeconds(windowSeconds)
    state.modify { map =>
      val timestamps = map.getOrElse(key, Nil).filter(_.isAfter(cutoff))
      if timestamps.length >= maxRequests then (false, map.updated(key, timestamps))
      else (true, map.updated(key, timestamps :+ now))
    }

object RateLimiter:

  def make(maxRequests: Int = 10, windowSeconds: Long = 60): UIO[RateLimiter] = Ref
    .make(Map.empty[String, List[Instant]])
    .map(ref => InMemoryRateLimiter(ref, maxRequests, windowSeconds))

  val layer: ZLayer[Any, Nothing, RateLimiter] = ZLayer.fromZIO(make())
