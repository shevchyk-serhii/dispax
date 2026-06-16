package com.shevchyk.ride.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.PersonRole
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.core.repository.PersonRepository
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.RideStatus
import com.shevchyk.ride.infrastructure.http.{
  CancellationStatsEntry,
  ClientValueEntry,
  DriverPerformanceEntry,
  DriverRatingEntry,
  PayrollSummary,
  PeakHourEntry
}
import com.shevchyk.ride.openapi.RideSchemas.given
import com.shevchyk.ride.openapi.RideSecure.*
import com.shevchyk.ride.repository.{ExpenseRepository, RideRatingRepository}
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

import java.time.{Instant, LocalDate, ZoneId, ZoneOffset}

/**
 * Tapir descriptions and server logic for the analytics endpoints. Replaces the zio-http handlers in `StatsRoutes`,
 * keeping the exact paths, status codes, role checks and company isolation. Missing required query params and parse
 * failures map to a 500, matching the original `RouteErrorHandler` behaviour.
 */
object StatsApi:

  private val statsTag = "Stats"

  private val COMMISSION_RATE = 0.15

  type StatsEnv = RideService & ExpenseRepository & PersonRepository & RideRatingRepository & JwtService

  private def internalError: Err = (StatusCode.InternalServerError, ApiError("Internal server error"))

  // -- Endpoint descriptions -----------------------------------------------

  val payrollEndpoint = secureEndpoint.get
    .in("api" / "stats" / "payroll")
    .in(query[Option[String]]("driverId"))
    .in(query[Option[String]]("from"))
    .in(query[Option[String]]("to"))
    .out(jsonBody[PayrollSummary])
    .tag(statsTag)
    .summary("Driver payroll summary")

  val cancellationsEndpoint = secureEndpoint.get
    .in("api" / "stats" / "cancellations")
    .out(jsonBody[List[CancellationStatsEntry]])
    .tag(statsTag)
    .summary("Cancellation statistics")

  val peakHoursEndpoint = secureEndpoint.get
    .in("api" / "stats" / "peak-hours")
    .in(query[Option[Int]]("days"))
    .out(jsonBody[List[PeakHourEntry]])
    .tag(statsTag)
    .summary("Peak hours analysis")

  val clientValueEndpoint = secureEndpoint.get
    .in("api" / "stats" / "client-value")
    .out(jsonBody[List[ClientValueEntry]])
    .tag(statsTag)
    .summary("Client lifetime value")

  val driverPerformanceEndpoint = secureEndpoint.get
    .in("api" / "stats" / "driver-performance")
    .out(jsonBody[List[DriverPerformanceEntry]])
    .tag(statsTag)
    .summary("Driver performance scorecard")

  val driverRatingsEndpoint = secureEndpoint.get
    .in("api" / "stats" / "driver-ratings")
    .out(jsonBody[List[DriverRatingEntry]])
    .tag(statsTag)
    .summary("Driver ratings statistics")

  val endpoints = List(
    payrollEndpoint,
    cancellationsEndpoint,
    peakHoursEndpoint,
    clientValueEndpoint,
    driverPerformanceEndpoint,
    driverRatingsEndpoint
  )

  // -- Server logic --------------------------------------------------------

  private val payrollServer: ZServerEndpoint[StatsEnv, Any] = payrollEndpoint.serverLogic {
    user => (driverIdOpt, fromOpt, toOpt) =>
      for {
        _                 <- checkRole(user, "DISPATCHER", "ADMIN")
        driverId          <- ZIO.fromOption(driverIdOpt).orElseFail(internalError)
        fromStr           <- ZIO.fromOption(fromOpt).orElseFail(internalError)
        toStr             <- ZIO.fromOption(toOpt).orElseFail(internalError)
        parsed            <- ZIO
                               .attempt {
                                 val fromDate = LocalDate.parse(fromStr)
                                 val toDate   = LocalDate.parse(toStr)
                                 (
                                   fromDate.atStartOfDay().toInstant(ZoneOffset.UTC),
                                   toDate.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC)
                                 )
                               }
                               .mapError(_ => internalError)
        (fromInst, toInst) = parsed
        driverPid         <- parsePersonId(driverId)
        rideService       <- ZIO.service[RideService]
        allDriverRides    <- rideService.getDriverRides(driverPid).mapError(_ => internalError)
        completedRides     = allDriverRides.filter { ride =>
                               ride.status == RideStatus.Completed &&
                               ride.endTime.exists(t => !t.isBefore(fromInst) && t.isBefore(toInst))
                             }
        totalEarnings      = completedRides.flatMap(r => r.finalPrice.orElse(r.estimatedPrice)).map(_.doubleValue).sum
        expenseRepo       <- ZIO.service[ExpenseRepository]
        expenses          <- expenseRepo.findByDriverId(driverPid).mapError(_ => internalError)
        filteredExp        = expenses.filter(exp => !exp.createdAt.isBefore(fromInst) && exp.createdAt.isBefore(toInst))
        totalExpenses      = filteredExp.map(_.amount.doubleValue).sum
        commission         = totalEarnings * COMMISSION_RATE
        netPay             = totalEarnings - commission - totalExpenses
      } yield PayrollSummary(
        driverId = driverId,
        from = fromStr,
        to = toStr,
        totalRides = completedRides.size,
        totalEarnings = totalEarnings,
        totalExpenses = totalExpenses,
        commission = commission,
        netPay = netPay
      )
  }

  private val cancellationsServer: ZServerEndpoint[StatsEnv, Any] = cancellationsEndpoint.serverLogic { user => _ =>
    for {
      _         <- checkRole(user, "DISPATCHER", "ADMIN")
      companyId <- requireCompanyId(user.companyId)
      service   <- ZIO.service[RideService]
      stats     <- service.getCancellationStats(companyId).mapError(_ => internalError)
    } yield stats.map { case (reason, count) => CancellationStatsEntry(reason, count) }.toList
  }

  private val peakHoursServer: ZServerEndpoint[StatsEnv, Any] = peakHoursEndpoint.serverLogic { user => daysOpt =>
    for {
      _         <- checkRole(user, "DISPATCHER", "ADMIN")
      companyId <- requireCompanyId(user.companyId)
      days       = daysOpt.getOrElse(30)
      service   <- ZIO.service[RideService]
      allRides  <- service.getRidesByCompany(companyId).mapError(_ => internalError)
      cutoff     = Instant.now().minusSeconds(days.toLong * 86400)
      filtered   = allRides.filter(r => r.requestTime.isAfter(cutoff))
      grouped    = filtered.groupBy { ride =>
                     val zdt = ride.scheduledTime.getOrElse(ride.requestTime).atZone(ZoneId.systemDefault())
                     (zdt.getHour, zdt.getDayOfWeek.getValue % 7)
                   }
    } yield grouped
      .map { case ((hour, dow), rides) => PeakHourEntry(hour, dow, rides.size) }
      .toList
      .sortBy(e => (e.dayOfWeek, e.hour))
  }

  private val clientValueServer: ZServerEndpoint[StatsEnv, Any] = clientValueEndpoint.serverLogic { user => _ =>
    for {
      _          <- checkRole(user, "DISPATCHER", "ADMIN")
      companyId  <- requireCompanyId(user.companyId)
      service    <- ZIO.service[RideService]
      personRepo <- ZIO.service[PersonRepository]
      allRides   <- service.getRidesByCompany(companyId).mapError(_ => internalError)
      clients    <- personRepo.findByRoleAndCompany(PersonRole.Client, companyId).mapError(_ => internalError)
      clientMap   = clients.map(c => c.id -> c.name).toMap
      byClient    = allRides.groupBy(_.clientId)
    } yield byClient.map { case (clientId, rides) =>
      val completedRides = rides.filter(_.status == RideStatus.Completed)
      val totalRevenue   = completedRides.flatMap(r => r.finalPrice.orElse(r.estimatedPrice)).map(_.doubleValue).sum
      val avgPrice       = if completedRides.nonEmpty then totalRevenue / completedRides.size else 0.0
      val sortedByTime   = rides.sortBy(_.requestTime)
      ClientValueEntry(
        clientId = clientId.value.toString,
        clientName = clientMap.getOrElse(clientId, "Unknown"),
        totalRides = rides.size,
        totalRevenue = totalRevenue,
        avgRidePrice = avgPrice,
        firstRideDate = sortedByTime.headOption.map(_.requestTime.toString).getOrElse(""),
        lastRideDate = sortedByTime.lastOption.map(_.requestTime.toString).getOrElse(""),
        cancelledRides = rides.count(_.status == RideStatus.Cancelled)
      )
    }.toList
  }

  private val driverPerformanceServer: ZServerEndpoint[StatsEnv, Any] = driverPerformanceEndpoint.serverLogic {
    user => _ =>
      for {
        _          <- checkRole(user, "DISPATCHER", "ADMIN")
        companyId  <- requireCompanyId(user.companyId)
        service    <- ZIO.service[RideService]
        personRepo <- ZIO.service[PersonRepository]
        ratingRepo <- ZIO.service[RideRatingRepository]
        allRides   <- service.getRidesByCompany(companyId).mapError(_ => internalError)
        drivers    <- personRepo.findByRoleAndCompany(PersonRole.Driver, companyId).mapError(_ => internalError)
        entries    <- ZIO
                        .foreach(drivers) { driver =>
                          val driverRides    = allRides.filter(_.driverId.contains(driver.id))
                          val completedRides = driverRides.filter(_.status == RideStatus.Completed)
                          val cancelledRides = driverRides.count(_.status == RideStatus.Cancelled)
                          val totalEarnings  =
                            completedRides.flatMap(r => r.finalPrice.orElse(r.estimatedPrice)).map(_.doubleValue).sum
                          val completionRate =
                            if driverRides.nonEmpty then completedRides.size.toDouble / driverRides.size else 0.0
                          val avgEarnings    = if completedRides.nonEmpty then totalEarnings / completedRides.size else 0.0
                          ratingRepo.getDriverAvgRating(driver.id).map { avgRating =>
                            DriverPerformanceEntry(
                              driverId = driver.id.value.toString,
                              driverName = driver.name,
                              totalRides = driverRides.size,
                              completedRides = completedRides.size,
                              cancelledRides = cancelledRides,
                              completionRate = completionRate,
                              totalEarnings = totalEarnings,
                              avgEarningsPerRide = avgEarnings,
                              avgRating = avgRating
                            )
                          }
                        }
                        .mapError(_ => internalError)
      } yield entries
  }

  private val driverRatingsServer: ZServerEndpoint[StatsEnv, Any] = driverRatingsEndpoint.serverLogic { user => _ =>
    for {
      _          <- checkRole(user, "DISPATCHER", "ADMIN")
      companyId  <- requireCompanyId(user.companyId)
      personRepo <- ZIO.service[PersonRepository]
      ratingRepo <- ZIO.service[RideRatingRepository]
      drivers    <- personRepo.findByRoleAndCompany(PersonRole.Driver, companyId).mapError(_ => internalError)
      entries    <- ZIO
                      .foreach(drivers) { driver =>
                        for {
                          ratings <- ratingRepo.findByDriverId(driver.id)
                          avgOpt  <- ratingRepo.getDriverAvgRating(driver.id)
                        } yield avgOpt.map { avg =>
                          DriverRatingEntry(
                            driverId = driver.id.value.toString,
                            driverName = driver.name,
                            avgRating = avg,
                            totalRatings = ratings.size
                          )
                        }
                      }
                      .mapError(_ => internalError)
    } yield entries.flatten
  }

  val serverEndpoints: List[ZServerEndpoint[StatsEnv, Any]] = List(
    payrollServer,
    cancellationsServer,
    peakHoursServer,
    clientValueServer,
    driverPerformanceServer,
    driverRatingsServer
  )
