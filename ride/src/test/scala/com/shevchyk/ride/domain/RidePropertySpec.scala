package com.shevchyk.ride.domain

import com.shevchyk.core.domain.*
import zio.json.*
import zio.test.*
import java.time.Instant

/**
 * Property-based tests using ZIO Test generators. These complement the example-based RideDomainSpec by checking
 * invariants across many randomly generated values rather than a handful of hand-picked cases.
 *
 * Two kinds of properties are covered:
 *   - JSON round-trips for the flat-string ID encodings (a value encoded then decoded must equal the original).
 *   - State-machine invariants of the ride lifecycle predicates (the predicates must be mutually consistent for every
 *     reachable status).
 */
object RidePropertySpec extends ZIOSpecDefault {

  // Generators ---------------------------------------------------------------

  private val genRideId: Gen[Any, RideId]       = Gen.uuid.map(RideId(_))
  private val genPersonId: Gen[Any, PersonId]   = Gen.uuid.map(PersonId(_))
  private val genCompanyId: Gen[Any, CompanyId] = Gen.uuid.map(CompanyId(_))

  private val genStatus: Gen[Any, RideStatus] = Gen.fromIterable(RideStatus.values)

  /**
   * A ride with a generated status; a driver is attached whenever the status logically requires one.
   */
  private val genRide: Gen[Any, Ride] =
    for
      id        <- genRideId
      clientId  <- genPersonId
      companyId <- genCompanyId
      status    <- genStatus
      hasDriver <- Gen.boolean
      driverId  <- genPersonId
    yield Ride(
      id = id,
      clientId = clientId,
      creatorId = clientId,
      companyId = companyId,
      driverId = Option.when(hasDriver || status != RideStatus.Requested)(driverId),
      status = status,
      pickupLocation = Location("Start"),
      dropoffLocation = Location("End"),
      pickupDateTime = Instant.now().plusSeconds(3600)
    )

  def spec =
    suite("RideDomain properties")(
      suite("ID JSON round-trip")(
        test("RideId encodes to a flat string and decodes back unchanged") {
          check(genRideId) { id =>
            val json    = id.toJson
            val decoded = json.fromJson[RideId]
            assertTrue(
              !json.contains("\"value\""), // flat string, not an object wrapper
              decoded == Right(id)
            )
          }
        },
        test("PersonId round-trips through JSON") {
          check(genPersonId)(id => assertTrue(id.toJson.fromJson[PersonId] == Right(id)))
        },
        test("CompanyId round-trips through JSON") {
          check(genCompanyId)(id => assertTrue(id.toJson.fromJson[CompanyId] == Right(id)))
        }
      ),
      suite("status-machine invariants")(
        test("a ride is never both assignable and already in a terminal state") {
          check(genRide) { ride =>
            val terminal = ride.status == RideStatus.Completed || ride.status == RideStatus.Cancelled
            assertTrue(!(ride.canBeAssigned && terminal))
          }
        },
        test("only Requested rides can be assigned") {
          check(genRide)(ride => assertTrue(ride.canBeAssigned == (ride.status == RideStatus.Requested)))
        },
        test("starting requires a confirmed ride with a driver") {
          check(genRide) { ride =>
            // canBeStarted now requires Confirmed status (driver must confirm before starting)
            assertTrue(
              ride.canBeStarted == (ride.status == RideStatus.Confirmed && ride.driverId.isDefined)
            )
          }
        },
        test("terminal rides allow no further transitions") {
          check(genRide.filter(r => r.status == RideStatus.Completed || r.status == RideStatus.Cancelled)) { ride =>
            assertTrue(
              !ride.canBeAssigned,
              !ride.canBeReassigned,
              !ride.canBeStarted,
              !ride.canBeCompleted,
              !ride.canBeCancelled,
              !ride.canBeEdited
            )
          }
        },
        test("a ride can be cancelled exactly when it is not in a terminal state") {
          check(genRide) { ride =>
            val terminal = ride.status == RideStatus.Completed || ride.status == RideStatus.Cancelled
            assertTrue(ride.canBeCancelled == !terminal)
          }
        }
      )
    )
}
