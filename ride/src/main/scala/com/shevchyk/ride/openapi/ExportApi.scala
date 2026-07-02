package com.shevchyk.ride.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.{CompanyId, PersonId}
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.{CompanySettingsRepository, PersonRepository}
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.{Expense, ExpenseCategory, PaymentMethod, Ride, RideStatus}
import com.shevchyk.ride.infrastructure.http.{DatevCsvSection, DatevExportResponse, DatevSummarySection}
import com.shevchyk.ride.openapi.RideSchemas.given
import com.shevchyk.ride.openapi.RideSecure.*
import com.shevchyk.ride.repository.ExpenseRepository
import sttp.model.{HeaderNames, MediaType, StatusCode}
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.{Clock, ZIO}

import java.nio.charset.{Charset, CodingErrorAction}
import java.time.format.DateTimeFormatter
import java.time.{Instant, YearMonth, ZoneOffset}

/**
 * Tapir descriptions and server logic for the DATEV export endpoints. Replaces the zio-http handlers in `ExportRoutes`,
 * keeping the exact paths, status codes, role checks, company isolation and content types. The CSV/ text endpoints
 * respond with `text/csv` plain bodies; the full export responds with the JSON envelope. The pure DATEV CSV generation
 * is copied here so the same byte-for-byte output is produced.
 */
object ExportApi:

  private val exportTag = "Export"

  type ExportEnv = RideService & ExpenseRepository & PersonRepository & JwtService & CompanySettingsRepository

  private def internalError: Err = (StatusCode.InternalServerError, ApiError("Internal server error"))

  // --- DATEV helpers (copied verbatim from ExportRoutes) ---

  /**
   * Sanitise a free-text value before it is placed into a `;`-delimited DATEV CSV field. Prevents:
   *   - CSV structure breakage from embedded `;`, quotes, CR/LF (the field is quoted and inner quotes doubled);
   *   - CSV formula injection in spreadsheet software (a leading `= + - @ TAB CR` is neutralised with a `'` prefix).
   * Applied to attacker-influenced values such as client names and expense descriptions.
   */
  private def escapeCsvField(raw: String): String =
    val deFormulated = if raw.nonEmpty && "=+-@\t\r".contains(raw.head) then s"'$raw" else raw
    if deFormulated.exists(c => c == ';' || c == '"' || c == '\n' || c == '\r') then
      "\"" + deFormulated.replace("\"", "\"\"") + "\""
    else deFormulated

  private def datevDate(instant: Instant): String =
    val ld = instant.atZone(ZoneOffset.UTC).toLocalDate
    f"${ld.getDayOfMonth}%02d${ld.getMonthValue}%02d"

  private def counterAccountForPayment(paymentMethod: Option[PaymentMethod]): String =
    paymentMethod match
      case Some(PaymentMethod.Cash)                                                          => "10000"
      // Payment is a cashless electronic/online payment, booked like Card/Bank.
      case Some(PaymentMethod.Card) | Some(PaymentMethod.Bank) | Some(PaymentMethod.Payment) => "12000"
      case Some(PaymentMethod.Invoice) | Some(PaymentMethod.Receivable)                      => "14000"
      case _                                                                                 => "10000"

  private def expenseAccount(category: ExpenseCategory): String =
    category match
      case ExpenseCategory.Fuel        => "4530"
      case ExpenseCategory.Parking     => "4580"
      case ExpenseCategory.Tolls       => "4580"
      case ExpenseCategory.Cleaning    => "4910"
      case ExpenseCategory.Maintenance => "4520"
      case ExpenseCategory.Other       => "4900"

  private val revenueCsvHeader =
    "Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen;WKZ Umsatz;Konto;Gegenkonto (ohne BU-Schluessel);BU-Schluessel;Belegdatum;Belegfeld 1;Buchungstext"

  private val expenseCsvHeader =
    "Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen;WKZ Umsatz;Konto;Gegenkonto (ohne BU-Schluessel);BU-Schluessel;Belegdatum;Belegfeld 1;Buchungstext"

  private[openapi] def generateRevenueCsv(rides: List[Ride], clientNames: Map[PersonId, String]): String =
    val rows = rides.map { ride =>
      val amount  = ride.finalPrice.orElse(ride.estimatedPrice).map(_.doubleValue).getOrElse(0.0)
      val counter = counterAccountForPayment(ride.paymentMethod)
      val date    = datevDate(ride.endTime.getOrElse(ride.requestTime))
      val rideId  = ride.id.value.toString.take(12)
      val client  = clientNames.getOrElse(ride.clientId, "Unbekannt")
      val text    = escapeCsvField(s"Fahrdienstleistung $client")
      f"$amount%.2f;S;EUR;8400;$counter;;$date;$rideId;$text"
    }
    (revenueCsvHeader +: rows).mkString("\n")

  private def generateExpensesCsv(expenses: List[Expense]): String =
    val rows = expenses.map { exp =>
      val account = expenseAccount(exp.category)
      val date    = datevDate(exp.createdAt)
      val expId   = exp.id.value.toString.take(12)
      val desc    = exp.description.getOrElse("")
      val text    = escapeCsvField(s"${exp.category} $desc")
      f"${exp.amount.doubleValue}%.2f;S;EUR;$account;70000;;$date;$expId;$text"
    }
    (expenseCsvHeader +: rows).mkString("\n")

  private def generateSummaryCsv(completedRides: List[Ride], expenses: List[Expense]): String =
    val totalRevenue = completedRides.flatMap(r => r.finalPrice.orElse(r.estimatedPrice)).map(_.doubleValue).sum
    val byCategory   = expenses.groupBy(_.category)

    val header = "Bezeichnung;Betrag;Waehrung"
    val lines  =
      List(f"Umsatzerloese;$totalRevenue%.2f;EUR") ++ List(
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

  // --- EXTF helpers ---

  /**
   * Format a monetary amount using the German decimal notation required by DATEV: comma as decimal separator, exactly
   * two decimal places, no thousands separator. Examples: 1234.5 -> "1234,50", 0.0 -> "0,00"
   */
  private[openapi] def germanAmount(d: Double): String = f"$d%.2f".replace('.', ',')

  /**
   * Build the EXTF header line (line 1 of a Buchungsstapel file).
   *
   * @param timestamp
   *   yyyyMMddHHmmssSSS — exactly 17 characters
   * @param beraternummer
   *   Steuerberater number; empty string if not configured
   * @param mandantennummer
   *   Mandant number; empty string if not configured
   * @param wjBeginn
   *   Start of fiscal year yyyyMMdd
   * @param sachkontenlaenge
   *   Account-number length (typically 4)
   * @param datumVon
   *   Period start yyyyMMdd
   * @param datumBis
   *   Period end yyyyMMdd
   * @param bezeichnung
   *   Free-text description of the batch (e.g. "Erlöse Mai 2025")
   */
  private[openapi] def extfHeaderLine(
      timestamp: String,
      beraternummer: String,
      mandantennummer: String,
      wjBeginn: String,
      sachkontenlaenge: Int,
      datumVon: String,
      datumBis: String,
      bezeichnung: String
  ): String =
    // Field layout follows DATEV Buchungsstapel Format v7 (22 fields, 0-indexed):
    // [0]EXTF [1]700 [2]21 [3]Buchungsstapel [4]7 [5]Erzeugt-am [6]Importiert(empty)
    // [7]Herkunft [8]Exportiert-von [9]Importiert-von(empty) [10]Beraternummer
    // [11]Mandantennummer [12]WJ-Beginn [13]Sachkontenlänge [14]Datum-von [15]Datum-bis
    // [16]Bezeichnung [17]Diktatkürzel [18]Buchungstyp [19]Rechnungslegungszweck(empty)
    // [20]Festschreibung=0 [21]WKZ=EUR
    s""""EXTF";700;21;"Buchungsstapel";7;$timestamp;;"";"";;$beraternummer;$mandantennummer;$wjBeginn;$sachkontenlaenge;$datumVon;$datumBis;"$bezeichnung";"";"";;0;"EUR";"""

  private val datevCsvColumnHeader =
    "Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen;WKZ Umsatz;Konto;Gegenkonto (ohne BU-Schluessel);BU-Schluessel;Belegdatum;Belegfeld 1;Buchungstext"

  /**
   * Generate revenue rows in EXTF format: amounts use German comma notation.
   */
  private def generateRevenueCsvExtf(rides: List[Ride], clientNames: Map[PersonId, String]): List[String] = rides.map {
    ride =>
      val amount  = ride.finalPrice.orElse(ride.estimatedPrice).map(_.doubleValue).getOrElse(0.0)
      val counter = counterAccountForPayment(ride.paymentMethod)
      val date    = datevDate(ride.endTime.getOrElse(ride.requestTime))
      val rideId  = ride.id.value.toString.take(12)
      val client  = clientNames.getOrElse(ride.clientId, "Unbekannt")
      val text    = escapeCsvField(s"Fahrdienstleistung $client")
      s"${germanAmount(amount)};S;EUR;8400;$counter;;$date;$rideId;$text"
  }

  /**
   * Generate expense rows in EXTF format: amounts use German comma notation.
   */
  private def generateExpensesCsvExtf(expenses: List[Expense]): List[String] = expenses.map { exp =>
    val account = expenseAccount(exp.category)
    val date    = datevDate(exp.createdAt)
    val expId   = exp.id.value.toString.take(12)
    val desc    = exp.description.getOrElse("")
    val text    = escapeCsvField(s"${exp.category} $desc")
    s"${germanAmount(exp.amount.doubleValue)};S;EUR;$account;70000;;$date;$expId;$text"
  }

  private val win1252: Charset                        = Charset.forName("windows-1252")
  private val yyyyMMddFmt: DateTimeFormatter          = DateTimeFormatter.ofPattern("yyyyMMdd")
  private val yyyyMMddHHmmssSSSFmt: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyyMMddHHmmssSSS")

  /**
   * Assemble the complete EXTF Buchungsstapel byte array. Encoding: Windows-1252 with REPLACE for unmappable
   * characters. Line separator: CRLF.
   */
  private[openapi] def buildExtf(
      rides: List[Ride],
      expenses: List[Expense],
      clientNames: Map[PersonId, String],
      month: YearMonth,
      beraternummer: String,
      mandantennummer: String,
      sachkontenlaenge: Int,
      now: Instant
  ): Array[Byte] =
    val zonedNow    = now.atZone(ZoneOffset.UTC)
    val timestamp   = yyyyMMddHHmmssSSSFmt.format(zonedNow)
    val wjBeginn    = yyyyMMddFmt.format(month.atDay(1).withDayOfYear(1))
    val datumVon    = yyyyMMddFmt.format(month.atDay(1))
    val datumBis    = yyyyMMddFmt.format(month.atEndOfMonth())
    val bezeichnung = s"Buchungsstapel ${month.getMonthValue.toString.padTo(2, ' ').reverse.mkString}/${month.getYear}"

    val header      = extfHeaderLine(
      timestamp,
      beraternummer,
      mandantennummer,
      wjBeginn,
      sachkontenlaenge,
      datumVon,
      datumBis,
      bezeichnung
    )
    val revenueRows = generateRevenueCsvExtf(rides, clientNames)
    val expenseRows = generateExpensesCsvExtf(expenses)
    val allRows     = List(header, datevCsvColumnHeader) ::: revenueRows ::: expenseRows
    val content     = allRows.mkString("\r\n")

    val encoder = win1252
      .newEncoder()
      .onMalformedInput(CodingErrorAction.REPLACE)
      .onUnmappableCharacter(CodingErrorAction.REPLACE)
    val charBuf = java.nio.CharBuffer.wrap(content)
    val byteBuf = encoder.encode(charBuf)
    val result  = new Array[Byte](byteBuf.remaining())
    byteBuf.get(result)
    result

  /**
   * Sanitise a string for safe use as a filename in a Content-Disposition header. Strips characters that are dangerous
   * in filenames (path separators, quotes, control chars).
   */
  private[openapi] def sanitizeFilename(raw: String): String = raw.replaceAll("[^A-Za-z0-9._\\-]", "_")

  private def parseMonth(monthOpt: Option[String]): YearMonth = monthOpt
    .flatMap(s => scala.util.Try(YearMonth.parse(s)).toOption)
    .getOrElse(YearMonth.now())

  private def fetchData(
      companyId: CompanyId,
      month: YearMonth
  ): ZIO[RideService & ExpenseRepository & PersonRepository, Err, (List[Ride], List[Expense], Map[PersonId, String])] =
    val startInstant = month.atDay(1).atStartOfDay().toInstant(ZoneOffset.UTC)
    val endInstant   = month.plusMonths(1).atDay(1).atStartOfDay().toInstant(ZoneOffset.UTC)

    (for
      rideService   <- ZIO.service[RideService]
      expenseRepo   <- ZIO.service[ExpenseRepository]
      personRepo    <- ZIO.service[PersonRepository]
      allRides      <- rideService.getRidesByCompany(companyId)
      completedRides = allRides.filter { ride =>
                         ride.status == RideStatus.Completed &&
                         ride.endTime.exists(t => !t.isBefore(startInstant) && t.isBefore(endInstant))
                       }
      allExpenses   <- expenseRepo.findByCompanyId(companyId)
      monthExpenses  = allExpenses.filter { exp =>
                         !exp.createdAt.isBefore(startInstant) && exp.createdAt.isBefore(endInstant)
                       }
      clientIds      = completedRides.map(_.clientId).distinct
      clients       <-
        ZIO.foreachPar(clientIds)(id => personRepo.findById(id).map(p => id -> p.map(_.name).getOrElse("Unbekannt")))
      clientMap      = clients.toMap
    yield (completedRides, monthExpenses, clientMap)).mapError(_ => internalError)

  // -- Endpoint descriptions -----------------------------------------------

  val datevExportEndpoint = secureEndpoint.get
    .in("api" / "export" / "datev")
    .in(query[Option[String]]("month"))
    .out(jsonBody[DatevExportResponse])
    .tag(exportTag)
    .summary("Full DATEV export (JSON with three CSV sections)")

  val datevRidesCsvEndpoint = secureEndpoint.get
    .in("api" / "export" / "datev" / "rides")
    .in(query[Option[String]]("month"))
    .out(stringBody.and(header(sttp.model.Header.contentType(MediaType.unsafeApply("text", "csv")))))
    .tag(exportTag)
    .summary("Rides revenue CSV (text/csv)")

  val datevExpensesCsvEndpoint = secureEndpoint.get
    .in("api" / "export" / "datev" / "expenses")
    .in(query[Option[String]]("month"))
    .out(stringBody.and(header(sttp.model.Header.contentType(MediaType.unsafeApply("text", "csv")))))
    .tag(exportTag)
    .summary("Expenses CSV (text/csv)")

  val datevExtfEndpoint = secureEndpoint.get
    .in("api" / "export" / "datev" / "extf")
    .in(query[Option[String]]("month"))
    .out(byteArrayBody)
    .out(header(sttp.model.Header.contentType(MediaType.unsafeApply("text", "csv"))))
    .out(header[String](HeaderNames.ContentDisposition))
    .tag(exportTag)
    .summary("Download DATEV EXTF Buchungsstapel file (Windows-1252, CRLF, German comma amounts)")

  val endpoints = List(datevExportEndpoint, datevRidesCsvEndpoint, datevExpensesCsvEndpoint, datevExtfEndpoint)

  // -- Server logic --------------------------------------------------------

  private val datevExportServer: ZServerEndpoint[ExportEnv, Any] = datevExportEndpoint.serverLogic { user => monthOpt =>
    for {
      _                                         <- checkRole(user, "DISPATCHER", "ADMIN")
      companyId                                 <- requireCompanyId(user.companyId)
      month                                      = parseMonth(monthOpt)
      result                                    <- fetchData(companyId, month)
      (completedRides, monthExpenses, clientMap) = result
      revenueCsv                                 = generateRevenueCsv(completedRides, clientMap)
      expensesCsv                                = generateExpensesCsv(monthExpenses)
      summaryCsv                                 = generateSummaryCsv(completedRides, monthExpenses)
      totalRevenue                               = completedRides.flatMap(r => r.finalPrice.orElse(r.estimatedPrice)).map(_.doubleValue).sum
      totalExpenses                              = monthExpenses.map(_.amount.doubleValue).sum
    } yield DatevExportResponse(
      month = month.toString,
      revenue = DatevCsvSection(csv = revenueCsv, totalRows = completedRides.size, totalAmount = totalRevenue),
      expenses = DatevCsvSection(csv = expensesCsv, totalRows = monthExpenses.size, totalAmount = totalExpenses),
      summary = DatevSummarySection(
        csv = summaryCsv,
        totalRevenue = totalRevenue,
        totalExpenses = totalExpenses,
        netIncome = totalRevenue - totalExpenses
      )
    )
  }

  private val datevRidesCsvServer: ZServerEndpoint[ExportEnv, Any] = datevRidesCsvEndpoint.serverLogic {
    user => monthOpt =>
      for {
        _                             <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId                     <- requireCompanyId(user.companyId)
        month                          = parseMonth(monthOpt)
        result                        <- fetchData(companyId, month)
        (completedRides, _, clientMap) = result
        csv                            = generateRevenueCsv(completedRides, clientMap)
      } yield csv
  }

  private val datevExpensesCsvServer: ZServerEndpoint[ExportEnv, Any] = datevExpensesCsvEndpoint.serverLogic {
    user => monthOpt =>
      for {
        _                    <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId            <- requireCompanyId(user.companyId)
        month                 = parseMonth(monthOpt)
        result               <- fetchData(companyId, month)
        (_, monthExpenses, _) = result
        csv                   = generateExpensesCsv(monthExpenses)
      } yield csv
  }

  private val datevExtfServer: ZServerEndpoint[ExportEnv, Any] = datevExtfEndpoint.serverLogic { user => monthOpt =>
    for {
      _                                         <- checkRole(user, "DISPATCHER", "ADMIN")
      companyId                                 <- requireCompanyId(user.companyId)
      month                                      = parseMonth(monthOpt)
      result                                    <- fetchData(companyId, month)
      (completedRides, monthExpenses, clientMap) = result
      settingsRepo                              <- ZIO.service[CompanySettingsRepository]
      settingsOpt                               <- settingsRepo.findByCompanyId(companyId).mapError(_ => internalError)
      settings                                   = settingsOpt.getOrElse(
                                                     com.shevchyk.core.domain.CompanySettings(companyId = companyId)
                                                   )
      beraternummer                              = settings.datevBeraternummer.getOrElse("")
      mandantennummer                            = settings.datevMandantennummer.getOrElse("")
      sachkontenlaenge                           = settings.datevSachkontenlaenge.getOrElse(4)
      now                                       <- Clock.instant
      bytes                                      = buildExtf(
                                                     completedRides,
                                                     monthExpenses,
                                                     clientMap,
                                                     month,
                                                     beraternummer,
                                                     mandantennummer,
                                                     sachkontenlaenge,
                                                     now
                                                   )
      rawFilename                                = s"EXTF_Buchungsstapel_${companyId.value}_${month}"
      filename                                   = sanitizeFilename(rawFilename) + ".csv"
      disposition                                = s"""attachment; filename="$filename""""
    } yield (bytes, disposition)
  }

  val serverEndpoints: List[ZServerEndpoint[ExportEnv, Any]] = List(
    datevExportServer,
    datevRidesCsvServer,
    datevExpensesCsvServer,
    datevExtfServer
  )
