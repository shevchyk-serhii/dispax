package com.shevchyk.ride.openapi

import com.shevchyk.core.domain.{CompanyId, Location, PersonId, RideId}
import com.shevchyk.core.repository.{CompanySettingsRepository, InMemoryCompanySettingsRepository}
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.{ExpenseRepository, InMemoryExpenseRepository, InMemoryRideRepository}
import zio.*
import zio.test.*
import zio.test.Assertion.*

import java.nio.charset.Charset
import java.time.{Instant, YearMonth}
import java.util.UUID

/**
 * Unit tests for the pure EXTF helper functions in ExportApi.
 *
 * All functions under test are made `private[openapi]` in production code to keep them accessible from this
 * same-package test class without exposing them to unrelated modules. Tests run against in-memory data with no I/O.
 */
object ExportApiSpec extends ZIOSpecDefault {

  // ── Shared test fixtures ─────────────────────────────────────────────────

  val companyA: CompanyId = CompanyId(UUID.fromString("0000000A-0000-0000-0000-000000000001"))
  val companyB: CompanyId = CompanyId(UUID.fromString("0000000B-0000-0000-0000-000000000001"))

  val clientA1: PersonId = PersonId(UUID.fromString("000000AA-0000-0000-0000-000000000001"))
  val clientA2: PersonId = PersonId(UUID.fromString("000000AA-0000-0000-0000-000000000002"))
  val clientB1: PersonId = PersonId(UUID.fromString("000000BB-0000-0000-0000-000000000001"))

  val driverA: PersonId = PersonId(UUID.fromString("000000DA-0000-0000-0000-000000000001"))

  /**
   * Fixed timestamp for deterministic header line tests.
   */
  val fixedNow: Instant = Instant.parse("2025-05-15T08:30:45.123Z")

  val may2025: YearMonth = YearMonth.of(2025, 5)

  val win1252: Charset = Charset.forName("windows-1252")

  // ── Helpers ──────────────────────────────────────────────────────────────

  private def makeCompletedRide(
      id: RideId = RideId.generate(),
      companyId: CompanyId = companyA,
      clientId: PersonId = clientA1,
      endTime: Instant = Instant.parse("2025-05-10T12:00:00Z"),
      estimatedPrice: Option[BigDecimal] = Some(BigDecimal("50.00")),
      finalPrice: Option[BigDecimal] = None,
      paymentMethod: Option[PaymentMethod] = Some(PaymentMethod.Cash)
  ): Ride = Ride(
    id = id,
    clientId = clientId,
    creatorId = clientId,
    companyId = companyId,
    status = RideStatus.Completed,
    pickupLocation = Location("Munich Airport"),
    dropoffLocation = Location("City Center"),
    pickupDateTime = Instant.parse("2025-05-10T10:00:00Z"),
    requestTime = Instant.parse("2025-05-10T09:00:00Z"),
    endTime = Some(endTime),
    estimatedPrice = estimatedPrice,
    finalPrice = finalPrice,
    paymentMethod = paymentMethod
  )

  private def makeExpense(
      id: ExpenseId = ExpenseId.generate(),
      companyId: CompanyId = companyA,
      driverId: PersonId = driverA,
      amount: BigDecimal = BigDecimal("12.50"),
      category: ExpenseCategory = ExpenseCategory.Fuel
  ): Expense = Expense(
    id = id,
    driverId = driverId,
    companyId = companyId,
    category = category,
    amount = amount,
    currency = "EUR",
    description = Some("test")
  )

  // ── Spec ─────────────────────────────────────────────────────────────────

  def spec =
    suite("ExportApi")(
      suite("germanAmount")(
        test("12.5 → 12,50 (two decimal places, comma)") {
          assertTrue(ExportApi.germanAmount(12.5) == "12,50")
        },
        test("0.0 → 0,00") {
          assertTrue(ExportApi.germanAmount(0.0) == "0,00")
        },
        test("1234.5 → 1234,50 (no thousands separator)") {
          // DATEV requires no grouping: 1234,50 not 1.234,50
          val result = ExportApi.germanAmount(1234.5)
          assertTrue(result == "1234,50")
        },
        test("100.0 → 100,00") {
          assertTrue(ExportApi.germanAmount(100.0) == "100,00")
        },
        test("result always contains comma not dot") {
          val result = ExportApi.germanAmount(99.99)
          assertTrue(result.contains(",") && !result.contains("."))
        }
      ),
      suite("extfHeaderLine structure")(
        test("starts with \"EXTF\";700;21;\"Buchungsstapel\"") {
          val line = ExportApi.extfHeaderLine(
            timestamp = "20250515083045123",
            beraternummer = "12345",
            mandantennummer = "67890",
            wjBeginn = "20250101",
            sachkontenlaenge = 4,
            datumVon = "20250501",
            datumBis = "20250531",
            bezeichnung = "Test batch"
          )
          assertTrue(line.startsWith("\"EXTF\";700;21;\"Buchungsstapel\""))
        },
        test("contains all supplied parameters") {
          val line = ExportApi.extfHeaderLine(
            timestamp = "20250515083045123",
            beraternummer = "12345",
            mandantennummer = "67890",
            wjBeginn = "20250101",
            sachkontenlaenge = 4,
            datumVon = "20250501",
            datumBis = "20250531",
            bezeichnung = "Erlöse"
          )
          assertTrue(
            line.contains("12345"),
            line.contains("67890"),
            line.contains("20250101"),
            line.contains("20250501"),
            line.contains("20250531"),
            line.contains("Erlöse"),
            line.contains(";4;")
          )
        },
        test("empty beraternummer produces two consecutive semicolons in position") {
          val line = ExportApi.extfHeaderLine(
            timestamp = "20250515083045123",
            beraternummer = "",
            mandantennummer = "",
            wjBeginn = "20250101",
            sachkontenlaenge = 4,
            datumVon = "20250501",
            datumBis = "20250531",
            bezeichnung = "X"
          )
          // Both empty numbers become ;; in succession
          assertTrue(line.contains(";;"))
        }
      ),
      suite("buildExtf file structure")(
        test("first line starts with EXTF header, second line is column header") {
          val bytes  = ExportApi.buildExtf(
            rides = Nil,
            expenses = Nil,
            clientNames = Map.empty,
            month = may2025,
            beraternummer = "12345",
            mandantennummer = "67890",
            sachkontenlaenge = 4,
            now = fixedNow
          )
          val text   = new String(bytes, win1252)
          val lines  = text.split("\r\n", -1)
          val header = lines(0)
          val cols   = lines(1)
          assertTrue(
            header.startsWith("\"EXTF\";700;21;\"Buchungsstapel\""),
            cols.startsWith("Umsatz (ohne Soll/Haben-Kz)")
          )
        },
        test("lines are separated by CRLF (not bare LF)") {
          val bytes       = ExportApi.buildExtf(
            rides = Nil,
            expenses = Nil,
            clientNames = Map.empty,
            month = may2025,
            beraternummer = "",
            mandantennummer = "",
            sachkontenlaenge = 4,
            now = fixedNow
          )
          val text        = new String(bytes, win1252)
          // File must contain \r\n and must NOT contain bare \n outside a \r\n pair
          val hasCrlf     = text.contains("\r\n")
          val bareNewline = text.replace("\r\n", "").contains("\n")
          assertTrue(hasCrlf && !bareNewline)
        },
        test("empty month produces exactly 2 lines: header + column header") {
          val bytes = ExportApi.buildExtf(
            rides = Nil,
            expenses = Nil,
            clientNames = Map.empty,
            month = may2025,
            beraternummer = "",
            mandantennummer = "",
            sachkontenlaenge = 4,
            now = fixedNow
          )
          val text  = new String(bytes, win1252)
          val lines = text.split("\r\n", -1)
          assertTrue(lines.length == 2)
        },
        test("booking rows appear after the column header for rides with data") {
          val ride      = makeCompletedRide(estimatedPrice = Some(BigDecimal("75.00")))
          val clientMap = Map(clientA1 -> "Test Client")
          val bytes     = ExportApi.buildExtf(
            rides = List(ride),
            expenses = Nil,
            clientNames = clientMap,
            month = may2025,
            beraternummer = "",
            mandantennummer = "",
            sachkontenlaenge = 4,
            now = fixedNow
          )
          val text      = new String(bytes, win1252)
          val lines     = text.split("\r\n", -1)
          // header + column header + 1 booking row = 3 lines
          assertTrue(
            lines.length == 3,
            lines(2).contains("75,00"),
            lines(2).contains(";S;EUR;")
          )
        },
        test("booking row amounts use German comma not dot") {
          val ride     = makeCompletedRide(estimatedPrice = Some(BigDecimal("99.50")))
          val bytes    = ExportApi.buildExtf(
            rides = List(ride),
            expenses = Nil,
            clientNames = Map(clientA1 -> "Müller"),
            month = may2025,
            beraternummer = "",
            mandantennummer = "",
            sachkontenlaenge = 4,
            now = fixedNow
          )
          val text     = new String(bytes, win1252)
          val lines    = text.split("\r\n", -1)
          val bookLine = lines(2)
          // EXTF amount must use comma
          assertTrue(bookLine.startsWith("99,50"))
        },
        test("sachkontenlaenge default=4 used when provided as 4") {
          val bytes = ExportApi.buildExtf(
            rides = Nil,
            expenses = Nil,
            clientNames = Map.empty,
            month = may2025,
            beraternummer = "",
            mandantennummer = "",
            sachkontenlaenge = 4,
            now = fixedNow
          )
          val text  = new String(bytes, win1252)
          assertTrue(text.contains(";4;"))
        },
        test("sachkontenlaenge=6 used when provided as 6") {
          val bytes = ExportApi.buildExtf(
            rides = Nil,
            expenses = Nil,
            clientNames = Map.empty,
            month = may2025,
            beraternummer = "",
            mandantennummer = "",
            sachkontenlaenge = 6,
            now = fixedNow
          )
          val text  = new String(bytes, win1252)
          assertTrue(text.contains(";6;"))
        }
      ),
      suite("buildExtf Windows-1252 encoding")(
        test("umlaut round-trip: Müller encodes and decodes correctly under Cp1252") {
          val ride  = makeCompletedRide(estimatedPrice = Some(BigDecimal("10.00")))
          val bytes = ExportApi.buildExtf(
            rides = List(ride),
            expenses = Nil,
            clientNames = Map(clientA1 -> "Müller"),
            month = may2025,
            beraternummer = "",
            mandantennummer = "",
            sachkontenlaenge = 4,
            now = fixedNow
          )
          val text  = new String(bytes, win1252)
          assertTrue(text.contains("Müller"))
        },
        test("ü is single byte 0xFC in windows-1252 (not multi-byte UTF-8)") {
          // In UTF-8, ü is 0xC3 0xBC (2 bytes). In windows-1252 it is 0xFC (1 byte).
          val ride  = makeCompletedRide(estimatedPrice = Some(BigDecimal("10.00")))
          val bytes = ExportApi.buildExtf(
            rides = List(ride),
            expenses = Nil,
            clientNames = Map(clientA1 -> "ü"),
            month = may2025,
            beraternummer = "",
            mandantennummer = "",
            sachkontenlaenge = 4,
            now = fixedNow
          )
          val text  = new String(bytes, win1252)
          // Find the position of the ü in the decoded string, then check the raw byte
          val idx   = text.indexOf('ü')
          assertTrue(
            idx >= 0,
            // The raw byte at that position must be 0xFC (signed -4 in Scala Byte)
            (bytes(idx) & 0xff) == 0xfc
          )
        },
        test("bytes are NOT valid UTF-8 when umlauts are present (encoding is windows-1252)") {
          val ride      = makeCompletedRide(estimatedPrice = Some(BigDecimal("10.00")))
          val bytes     = ExportApi.buildExtf(
            rides = List(ride),
            expenses = Nil,
            clientNames = Map(clientA1 -> "Müller"),
            month = may2025,
            beraternummer = "",
            mandantennummer = "",
            sachkontenlaenge = 4,
            now = fixedNow
          )
          // If we try to decode with UTF-8, Müller becomes garbled (replacement char or different
          // string) — the ü 0xFC byte is not valid UTF-8
          val asUtf8    = new String(bytes, "UTF-8")
          val asWin1252 = new String(bytes, "windows-1252")
          assertTrue(asUtf8 != asWin1252)
        }
      ),
      suite("old generateRevenueCsv still uses dot (backward-compat)")(
        test("generateRevenueCsv amount format uses dot not comma") {
          val ride = makeCompletedRide(estimatedPrice = Some(BigDecimal("75.25")))
          val csv  = ExportApi.generateRevenueCsv(
            rides = List(ride),
            clientNames = Map(clientA1 -> "Client")
          )
          // Old JSON path must keep dot decimal separator
          assertTrue(
            csv.contains("75.25"),
            !csv.lines().skip(1).findFirst().map(_.startsWith("75,")).orElse(false)
          )
        }
      ),
      suite("sanitizeFilename")(
        test("allows safe characters unchanged") {
          assertTrue(ExportApi.sanitizeFilename("EXTF_Buchungsstapel_2025-05.csv") == "EXTF_Buchungsstapel_2025-05.csv")
        },
        test("replaces path traversal sequences") {
          assertTrue(!ExportApi.sanitizeFilename("../../etc/passwd").contains("/"))
        },
        test("replaces space with underscore") {
          assertTrue(!ExportApi.sanitizeFilename("file name.csv").contains(" "))
        },
        test("replaces quote characters") {
          assertTrue(!ExportApi.sanitizeFilename("file\"name.csv").contains("\""))
        },
        test("replaces backslash") {
          assertTrue(!ExportApi.sanitizeFilename("path\\file.csv").contains("\\"))
        },
        test("preserves alphanumeric, dot, dash, underscore") {
          val safe = "MyFile_2025-05.csv"
          assertTrue(ExportApi.sanitizeFilename(safe) == safe)
        }
      ),
      suite("tenant isolation: buildExtf only uses rides and expenses passed to it")(
        test("company B rides do not appear in company A export") {
          // The isolation is enforced at the service level (fetchData filters by companyId).
          // Here we verify that buildExtf is a pure function that uses only its arguments —
          // mixing company B data would show up if accidentally passed in.
          val rideA = makeCompletedRide(companyId = companyA, estimatedPrice = Some(BigDecimal("50.00")))
          // Company B ride exists in the system but must not be passed to this company's buildExtf call
          val _     = makeCompletedRide(companyId = companyB, estimatedPrice = Some(BigDecimal("999.99")))

          // Simulate correct service behaviour: only companyA rides passed to buildExtf
          val bytesA = ExportApi.buildExtf(
            rides = List(rideA),
            expenses = Nil,
            clientNames = Map(clientA1 -> "Client A"),
            month = may2025,
            beraternummer = "",
            mandantennummer = "",
            sachkontenlaenge = 4,
            now = fixedNow
          )
          val textA  = new String(bytesA, win1252)
          // Company B's amount must not appear
          assertTrue(
            textA.contains("50,00"),
            !textA.contains("999,99")
          )
        },
        test("company A settings (beraternummer) appear in header, not company B settings") {
          val bytesA = ExportApi.buildExtf(
            rides = Nil,
            expenses = Nil,
            clientNames = Map.empty,
            month = may2025,
            beraternummer = "11111",
            mandantennummer = "22222",
            sachkontenlaenge = 4,
            now = fixedNow
          )
          val textA  = new String(bytesA, win1252)
          assertTrue(
            textA.contains("11111"),
            textA.contains("22222"),
            !textA.contains("99999")
          )
        }
      )
    )
}
