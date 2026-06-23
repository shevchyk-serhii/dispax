package com.shevchyk.ride.openapi

import zio.test.*
import zio.test.Assertion.*

/**
 * Unit tests for the pagination clamping helpers used by `listRides`.
 *
 * Without clamping, negative / oversized `offset` and `limit` values would flow straight into the SQL LIMIT/OFFSET
 * clauses. These tests pin the safe bounds: limit ∈ [1, 200], offset ≥ 0.
 */
object RidePagingSpec extends ZIOSpecDefault {

  import RideApi.Paging

  def spec: Spec[Any, Nothing] =
    suite("RideApi.Paging")(
      test("clampLimit floors a negative limit to the minimum (1)") {
        assert(Paging.clampLimit(-1))(equalTo(1))
      },
      test("clampLimit floors zero to the minimum (1)") {
        assert(Paging.clampLimit(0))(equalTo(1))
      },
      test("clampLimit caps an oversized limit to the maximum (200)") {
        assert(Paging.clampLimit(99999))(equalTo(200))
      },
      test("clampLimit leaves an in-range limit untouched") {
        assert(Paging.clampLimit(50))(equalTo(50))
      },
      test("clampOffset floors a negative offset to 0") {
        assert(Paging.clampOffset(-10))(equalTo(0))
      },
      test("clampOffset leaves a non-negative offset untouched") {
        assert(Paging.clampOffset(120))(equalTo(120))
      }
    )
}
