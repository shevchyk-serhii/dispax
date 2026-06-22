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
        },
        // -----------------------------------------------------------------------
        // MUTATION KILL: haversine cos factor and Earth radius
        // -----------------------------------------------------------------------
        // Two points at Munich latitude (48.137°N) with exactly 1 degree of longitude
        // separation and zero latitude difference.
        //
        // Correct result:
        //   dist = 6 371 000 * c  where  a = cos²(48.137°) * sin²(0.5°)
        //   ≈ 74 205 m   (int-truncated from .toInt in distanceMeters)
        //
        // Mutations targeted (must both FAIL these assertions):
        //   • cos(lat1)*cos(lat2) dropped (L27) → a = sin²(0.5°) alone, same as equator
        //     → dist ≈ 111 194 m  — fails upper bound 74 300
        //   • Earth radius 6 371 000 → 6 385 000 (L22) → 0.22 % inflation
        //     → dist ≈ 74 368 m  — fails upper bound 74 300
        //
        // Companion assertion: at equator the SAME 1-degree longitude arc is ~111 194 m,
        // confirming the cos factor is the only reason Munich gives a shorter result.
        test(
          "distanceMeters: 1-degree longitude diff at Munich lat pins the cos factor and Earth radius"
        ) {
          // 48.137°N, 0.000°E  →  48.137°N, 1.000°E
          val distanceMunich  = DriverLocation.distanceMeters(48.137, 0.0, 48.137, 1.0)
          // 0.000°N, 0.000°E  →  0.000°N, 1.000°E
          val distanceEquator = DriverLocation.distanceMeters(0.0, 0.0, 0.0, 1.0)

          assertTrue(
            // Correct haversine gives ~74 205 m; window [74 000, 74 300] kills both mutations.
            distanceMunich > 74000 && distanceMunich < 74300,
            // At equator cos(0)*cos(0)=1 so the full 1-deg arc ~111 194 m — proves cos matters.
            distanceEquator > 110000 && distanceEquator < 112000,
            // Munich must be strictly less than the equatorial arc (cos factor compresses it).
            distanceMunich < distanceEquator
          )
        }
      )
    )
}
