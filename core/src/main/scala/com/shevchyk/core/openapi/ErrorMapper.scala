package com.shevchyk.core.openapi

import sttp.model.StatusCode

/**
 * Maps a domain error to the HTTP `(StatusCode, ApiError)` pair returned by a Tapir endpoint.
 *
 * Each module owns the mapping for its own error type by providing a `given ErrorMapper[E]` next to the error
 * definition. The `*Api` endpoint files then call [[ErrorMapper.toResponse]] instead of repeating a near-identical
 * `toError` pattern-match in every file.
 *
 * Domain errors in this codebase extend `Throwable` (they flow through the `Task`/`Throwable` repository channels), so
 * the endpoints receive a `Throwable`. [[ErrorMapper.fromThrowable]] bridges that: it applies the typeclass when the
 * throwable is of the expected type and otherwise falls back to a generic 500, matching the previous hand-written `case
 * _ => InternalServerError` branches.
 */
trait ErrorMapper[E]:
  def toResponse(error: E): (StatusCode, ApiError)

object ErrorMapper:

  def apply[E](using mapper: ErrorMapper[E]): ErrorMapper[E] = mapper

  /**
   * Convenience constructor from a plain function.
   */
  def instance[E](f: E => (StatusCode, ApiError)): ErrorMapper[E] = (error: E) => f(error)

  /**
   * Generic fallback used for unexpected throwables (DB drivers, runtime defects, etc.).
   */
  val internalServerError: (StatusCode, ApiError) = (StatusCode.InternalServerError, ApiError("Internal server error"))

  extension [E](error: E)(using mapper: ErrorMapper[E])
    def toResponse: (StatusCode, ApiError) = mapper.toResponse(error)

  /**
   * Maps a `Throwable` from a domain `Task` channel to an HTTP response. If it is an `E`, the module's mapper is used;
   * anything else collapses to a generic 500 (the same behaviour as the previous `case _ =>` branches).
   */
  def fromThrowable[E](
      ex: Throwable
  )(using mapper: ErrorMapper[E], ct: scala.reflect.ClassTag[E]): (StatusCode, ApiError) =
    ex match
      case ct(e) => mapper.toResponse(e)
      case _     => internalServerError
