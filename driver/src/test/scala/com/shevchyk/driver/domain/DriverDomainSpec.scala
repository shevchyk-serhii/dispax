package com.shevchyk.driver.domain

import zio.test.*

object DriverDomainSpec extends ZIOSpecDefault {

  def spec =
    suite("DriverDomain")(
      suite("DriverStatus")(
        test("has three values") {
          assertTrue(
            DriverStatus.values.length == 3 &&
              DriverStatus.values.contains(DriverStatus.Available) &&
              DriverStatus.values.contains(DriverStatus.Busy) &&
              DriverStatus.values.contains(DriverStatus.Offline)
          )
        }
      ),
      suite("DriverLocation")(
        test("creates with all fields") {
          val loc = DriverLocation(
            driverId = com.shevchyk.core.domain.PersonId(java.util.UUID.randomUUID()),
            latitude = 48.1351,
            longitude = 11.5820
          )
          assertTrue(
            loc.latitude == 48.1351 &&
              loc.longitude == 11.5820
          )
        },
        test("distanceMeters calculates correct distance between Munich and Airport") {
          // Munich center to Munich Airport ~30km
          val distance = DriverLocation.distanceMeters(48.1351, 11.5820, 48.3537, 11.7750)
          assertTrue(distance > 25000 && distance < 35000)
        },
        test("distanceMeters returns 0 for same point") {
          val distance = DriverLocation.distanceMeters(48.1351, 11.5820, 48.1351, 11.5820)
          assertTrue(distance == 0)
        },
        test("distanceMeters is symmetric") {
          val d1 = DriverLocation.distanceMeters(48.1351, 11.5820, 48.3537, 11.7750)
          val d2 = DriverLocation.distanceMeters(48.3537, 11.7750, 48.1351, 11.5820)
          assertTrue(d1 == d2)
        },
        test("distanceMeters handles antipodal points") {
          // Approximately half the earth's circumference
          val distance = DriverLocation.distanceMeters(0.0, 0.0, 0.0, 180.0)
          assertTrue(distance > 20000000 && distance < 20100000)
        },
        test("distanceMeters handles short distances accurately") {
          // ~100m between two nearby points
          val distance = DriverLocation.distanceMeters(48.1351, 11.5820, 48.1360, 11.5820)
          assertTrue(distance > 90 && distance < 110)
        }
      )
    )
}
