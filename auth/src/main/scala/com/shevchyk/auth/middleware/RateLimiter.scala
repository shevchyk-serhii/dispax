package com.shevchyk.auth.middleware

import zio.*
import java.time.Instant

trait RateLimiter:
  /**
   * Check the bucket AND consume one slot when under the limit. True = allowed.
   */
  def checkRate(key: String): UIO[Boolean]

  /**
   * Peek whether the bucket is at its limit WITHOUT consuming a slot. Used where the consumption is conditional on a
   * later outcome (e.g. the per-email login bucket counts only FAILED attempts — counting every attempt would let an
   * attacker lock a victim out of their own account by merely sending requests with the victim's email).
   */
  def isLimited(key: String): UIO[Boolean]

  /**
   * Unconditionally consume one slot (no limit check). The deferred half of [[isLimited]]: call it once the outcome
   * that should count (e.g. a failed login) is known.
   */
  def record(key: String): UIO[Unit]

class InMemoryRateLimiter(
    state: Ref[Map[String, List[Instant]]],
    maxRequests: Int,
    windowSeconds: Long
) extends RateLimiter:

  override def checkRate(key: String): UIO[Boolean] =
    val now    = Instant.now()
    val cutoff = now.minusSeconds(windowSeconds)
    state.modify { map =>
      // Sweep keys whose whole window has expired before touching the requested key. Without this
      // every key ever seen (e.g. every source IP) kept a permanent entry in the map, growing the
      // process memory without bound. Sweeping on access keeps the map bounded by the number of
      // keys active within one window; login traffic is low, so the O(keys) sweep is cheap.
      val pruned     = map.filter { case (_, stamps) => stamps.exists(_.isAfter(cutoff)) }
      val timestamps = pruned.getOrElse(key, Nil).filter(_.isAfter(cutoff))
      if timestamps.length >= maxRequests then (false, pruned.updated(key, timestamps))
      else (true, pruned.updated(key, timestamps :+ now))
    }

  override def isLimited(key: String): UIO[Boolean] =
    val cutoff = Instant.now().minusSeconds(windowSeconds)
    // Read-only: prune the window but do NOT append a timestamp — peeking must not consume.
    state.modify { map =>
      val pruned     = map.filter { case (_, stamps) => stamps.exists(_.isAfter(cutoff)) }
      val timestamps = pruned.getOrElse(key, Nil).filter(_.isAfter(cutoff))
      (timestamps.length >= maxRequests, pruned)
    }

  override def record(key: String): UIO[Unit] =
    val now    = Instant.now()
    val cutoff = now.minusSeconds(windowSeconds)
    state.update { map =>
      val pruned     = map.filter { case (_, stamps) => stamps.exists(_.isAfter(cutoff)) }
      val timestamps = pruned.getOrElse(key, Nil).filter(_.isAfter(cutoff))
      pruned.updated(key, timestamps :+ now)
    }

  // Test-only observability: the keys currently tracked, used to assert eviction of expired buckets.
  private[middleware] def trackedKeys: UIO[Set[String]] = state.get.map(_.keySet)

object RateLimiter:

  def make(maxRequests: Int = 10, windowSeconds: Long = 60): UIO[InMemoryRateLimiter] = Ref
    .make(Map.empty[String, List[Instant]])
    .map(ref => InMemoryRateLimiter(ref, maxRequests, windowSeconds))

  val layer: ZLayer[Any, Nothing, RateLimiter] = ZLayer.fromZIO(make())
