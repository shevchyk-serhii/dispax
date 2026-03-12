package com.shevchyk.ride.infrastructure.http

import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.{Expense, ExpenseCategory, RideStatus, Ride}
import com.shevchyk.ride.repository.ExpenseRepository
import com.shevchyk.repository.PersonRepository
import zio.*
import zio.http.*
import zio.json.*

import java.time.{Instant, LocalDate, YearMonth, ZoneOffset}

// --- JSON response models ---

case class DatevCsvSection(
    csv: String,
    totalRows: Int,
    totalAmount: Double
) derives JsonCodec

case class DatevSummarySection(
    csv: String,
    totalRevenue: Double,
    totalExpenses: Double,
    netIncome: Double
) derives JsonCodec

case class DatevExportResponse(
    month: String,
    revenue: DatevCsvSection,
    expenses: DatevCsvSection,
    summary: DatevSummarySection
) derives JsonCodec

object ExportRoutes:

  private def handleError(ex: Throwable): UIO[Response] =
    val msg = Option(ex.getMessage).getOrElse(ex.toString)
    ZIO
      .logError(s"Export error: $msg")
      .as(Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}""")))

  /**
   * Parse month query param (YYYY-MM) or default to current month
   */
  private def parseMonth(request: Request): YearMonth = request.url.queryParams
    .queryParam("month")
    .flatMap(s => scala.util.Try(YearMonth.parse(s)).toOption)
    .getOrElse(YearMonth.now())

  /**
   * DATEV date format: DDMM (4 digits, no year)
   */
  private def datevDate(instant: Instant): String =
    val ld = instant.atZone(ZoneOffset.UTC).toLocalDate
    f"${ld.getDayOfMonth}%02d${ld.getMonthValue}%02d"

  /**
   * Determine DATEV counter account based on payment method
   */
  private def counterAccountForPayment(paymentMethod: Option[String]): String =
    paymentMethod.map(_.toLowerCase) match
      case Some("cash")                         => "10000"
      case Some("card") | Some("bank")          => "12000"
      case Some("invoice") | Some("receivable") => "14000"
      case _                                    => "10000" // default to cash

  /**
   * DATEV expense account by category
   */
  private def expenseAccount(category: ExpenseCategory): String =
    category match
      case ExpenseCategory.Fuel        => "4530"
      case ExpenseCategory.Parking     => "4580"
      case ExpenseCategory.Tolls       => "4580"
      case ExpenseCategory.Cleaning    => "4910"
      case ExpenseCategory.Maintenance => "4520"
      case ExpenseCategory.Other       => "4900"

  // --- CSV generation ---

  private val revenueCsvHeader =
    "Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen;WKZ Umsatz;Konto;Gegenkonto (ohne BU-Schluessel);BU-Schluessel;Belegdatum;Belegfeld 1;Buchungstext"

  private val expenseCsvHeader =
    "Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen;WKZ Umsatz;Konto;Gegenkonto (ohne BU-Schluessel);BU-Schluessel;Belegdatum;Belegfeld 1;Buchungstext"

  private def generateRevenueCsv(rides: List[Ride], clientNames: Map[PersonId, String]): String =
    val rows = rides.map { ride =>
      val amount  = ride.finalPrice.orElse(ride.estimatedPrice).map(_.doubleValue).getOrElse(0.0)
      val counter = counterAccountForPayment(ride.paymentMethod)
      val date    = datevDate(ride.endTime.getOrElse(ride.requestTime))
      val rideId  = ride.id.value.toString.take(12)
      val client  = clientNames.getOrElse(ride.clientId, "Unbekannt")
      f"$amount%.2f;S;EUR;8400;$counter;;$date;$rideId;Fahrdienstleistung $client"
    }
    (revenueCsvHeader +: rows).mkString("\n")

  private def generateExpensesCsv(expenses: List[Expense]): String =
    val rows = expenses.map { exp =>
      val account = expenseAccount(exp.category)
      val date    = datevDate(exp.createdAt)
      val expId   = exp.id.value.toString.take(12)
      val desc    = exp.description.getOrElse("")
      f"${exp.amount.doubleValue}%.2f;S;EUR;$account;70000;;$date;$expId;${exp.category} $desc"
    }
    (expenseCsvHeader +: rows).mkString("\n")

  private def generateSummaryCsv(
      completedRides: List[Ride],
      expenses: List[Expense]
  ): String =
    val totalRevenue = completedRides.flatMap(r => r.finalPrice.orElse(r.estimatedPrice)).map(_.doubleValue).sum
    val byCategory   = expenses.groupBy(_.category)

    val header = "Bezeichnung;Betrag;Waehrung"
    val lines  =
      List(
        f"Umsatzerloese;$totalRevenue%.2f;EUR"
      ) ++ List(
        ExpenseCategory.Fuel        -> "Kraftstoff",
        ExpenseCategory.Parking     -> "Parkgebuehren",
        ExpenseCategory.Tolls       -> "Mautgebuehren",
        ExpenseCategory.Cleaning    -> "Reinigung",
        ExpenseCategory.Maintenance -> "Wartung",
        ExpenseCategory.Other       -> "Sonstiges"
      ).map { case (cat, label) =>
        val amount = byCategory.getOrElse(cat, Nil).map(_.amount.doubleValue).sum
        f"$label;$amount%.2f;EUR"
      } ++ {
        val totalExp = expenses.map(_.amount.doubleValue).sum
        val net      = totalRevenue - totalExp
        List(f"Ergebnis;$net%.2f;EUR")
      }

    (header +: lines).mkString("\n")

  // --- Shared data fetching ---

  private def fetchData(
      companyId: CompanyId,
      month: YearMonth
  ): ZIO[RideService & ExpenseRepository & PersonRepository, Throwable, (List[Ride], List[Expense], Map[PersonId, String])] =
    val startInstant = month.atDay(1).atStartOfDay().toInstant(ZoneOffset.UTC)
    val endInstant   = month.plusMonths(1).atDay(1).atStartOfDay().toInstant(ZoneOffset.UTC)

    for
      rideService <- ZIO.service[RideService]
      expenseRepo <- ZIO.service[ExpenseRepository]
      personRepo  <- ZIO.service[PersonRepository]

      allRides      <- rideService.getRidesByCompany(companyId).mapError(e => new RuntimeException(e.toString))
      completedRides = allRides.filter { ride =>
                         ride.status == RideStatus.Completed &&
                         ride.endTime.exists(t => !t.isBefore(startInstant) && t.isBefore(endInstant))
                       }

      allExpenses  <- expenseRepo.findByCompanyId(companyId)
      monthExpenses = allExpenses.filter { exp =>
                        !exp.createdAt.isBefore(startInstant) && exp.createdAt.isBefore(endInstant)
                      }

      clientIds = completedRides.map(_.clientId).distinct
      clients  <-
        ZIO.foreach(clientIds)(id => personRepo.findById(id).map(p => id -> p.map(_.name).getOrElse("Unbekannt")))
      clientMap = clients.toMap
    yield (completedRides, monthExpenses, clientMap)

  // --- Route definitions ---

  val authenticatedRoutes: Routes[RideService & ExpenseRepository & PersonRepository & JwtService, Response] = Routes(
    // Full DATEV export as JSON with three CSV sections
    Method.GET / "api" / "export" / "datev" -> handler { (request: Request) =>
      (for
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        month      = parseMonth(request)

        result                                    <- fetchData(companyId, month)
        (completedRides, monthExpenses, clientMap) = result

        revenueCsv  = generateRevenueCsv(completedRides, clientMap)
        expensesCsv = generateExpensesCsv(monthExpenses)
        summaryCsv  = generateSummaryCsv(completedRides, monthExpenses)

        totalRevenue  = completedRides.flatMap(r => r.finalPrice.orElse(r.estimatedPrice)).map(_.doubleValue).sum
        totalExpenses = monthExpenses.map(_.amount.doubleValue).sum

        response = DatevExportResponse(
                     month = month.toString,
                     revenue = DatevCsvSection(
                       csv = revenueCsv,
                       totalRows = completedRides.size,
                       totalAmount = totalRevenue
                     ),
                     expenses = DatevCsvSection(
                       csv = expensesCsv,
                       totalRows = monthExpenses.size,
                       totalAmount = totalExpenses
                     ),
                     summary = DatevSummarySection(
                       csv = summaryCsv,
                       totalRevenue = totalRevenue,
                       totalExpenses = totalExpenses,
                       netIncome = totalRevenue - totalExpenses
                     )
                   )
      yield Response.json(response.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // Rides CSV only (plain text/csv)
    Method.GET / "api" / "export" / "datev" / "rides" -> handler { (request: Request) =>
      (for
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        month      = parseMonth(request)

        result                        <- fetchData(companyId, month)
        (completedRides, _, clientMap) = result

        csv = generateRevenueCsv(completedRides, clientMap)
      yield Response(
        Status.Ok,
        Headers(Header.ContentType(MediaType.text.csv)),
        Body.fromString(csv)
      )).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    },

    // Expenses CSV only (plain text/csv)
    Method.GET / "api" / "export" / "datev" / "expenses" -> handler { (request: Request) =>
      (for
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
        companyId <- UuidParser.requireCompanyId(user.companyId)
        month      = parseMonth(request)

        result               <- fetchData(companyId, month)
        (_, monthExpenses, _) = result

        csv = generateExpensesCsv(monthExpenses)
      yield Response(
        Status.Ok,
        Headers(Header.ContentType(MediaType.text.csv)),
        Body.fromString(csv)
      )).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleError(ex)
      }
    }
  )
