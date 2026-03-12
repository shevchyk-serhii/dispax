package com.shevchyk.ride.infrastructure.http

import com.shevchyk.auth.middleware.{AuthMiddleware, UuidParser}
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.ride.domain.RideStatus
import com.shevchyk.ride.repository.{ExpenseRepository, RideRatingRepository}
import com.shevchyk.repository.PersonRepository
import zio.*
import zio.http.*
import zio.json.*

import java.time.{Instant, LocalDate, ZoneId, ZoneOffset}

case class PayrollSummary(
    driverId: String,
    from: String,
    to: String,
    totalRides: Int,
    totalEarnings: Double,
    totalExpenses: Double,
    commission: Double,
    netPay: Double
) derives JsonCodec

case class PeakHourEntry(
    hour: Int,
    dayOfWeek: Int,
    count: Int
) derives JsonCodec

case class ClientValueEntry(
    clientId: String,
    clientName: String,
    totalRides: Int,
    totalRevenue: Double,
    avgRidePrice: Double,
    firstRideDate: String,
    lastRideDate: String,
    cancelledRides: Int
) derives JsonCodec

case class DriverPerformanceEntry(
    driverId: String,
    driverName: String,
    totalRides: Int,
    completedRides: Int,
    cancelledRides: Int,
    completionRate: Double,
    totalEarnings: Double,
    avgEarningsPerRide: Double,
    avgRating: Option[Double] = None
) derives JsonCodec

case class DriverRatingEntry(
    driverId: String,
    driverName: String,
    avgRating: Double,
    totalRatings: Int
) derives JsonCodec

object StatsRoutes:

  private val COMMISSION_RATE = 0.15

  private def handleError(ex: Throwable): UIO[Response] =
    val msg = Option(ex.getMessage).getOrElse(ex.toString)
    ZIO
      .logError(s"Stats error: $msg")
      .as(Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}""")))

  val authenticatedRoutes
      : Routes[RideService & ExpenseRepository & PersonRepository & RideRatingRepository & JwtService, Response] =
    Routes(
      Method.GET / "api" / "stats" / "payroll" -> handler { (request: Request) =>
        (for {
          user      <- AuthMiddleware.authenticateRequest(request)
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
          driverId  <- ZIO
                         .fromOption(request.url.queryParams.queryParam("driverId"))
                         .orElseFail(new RuntimeException("driverId query parameter is required"))
          fromStr   <- ZIO
                         .fromOption(request.url.queryParams.queryParam("from"))
                         .orElseFail(new RuntimeException("from query parameter is required"))
          toStr     <- ZIO
                         .fromOption(request.url.queryParams.queryParam("to"))
                         .orElseFail(new RuntimeException("to query parameter is required"))
          fromDate   = LocalDate.parse(fromStr)
          toDate     = LocalDate.parse(toStr)
          fromInst   = fromDate.atStartOfDay().toInstant(ZoneOffset.UTC)
          toInst     = toDate.plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC)
          driverPid <- UuidParser.parsePersonId(driverId)

          rideService    <- ZIO.service[RideService]
          allDriverRides <- rideService.getDriverRides(driverPid)
          completedRides  = allDriverRides.filter { ride =>
                              ride.status == RideStatus.Completed &&
                              ride.endTime.exists(t => !t.isBefore(fromInst) && t.isBefore(toInst))
                            }
          totalEarnings   = completedRides.flatMap(r => r.finalPrice.orElse(r.estimatedPrice)).map(_.doubleValue).sum

          expenseRepo  <- ZIO.service[ExpenseRepository]
          expenses     <- expenseRepo.findByDriverId(driverPid)
          filteredExp   = expenses.filter { exp =>
                            !exp.createdAt.isBefore(fromInst) && exp.createdAt.isBefore(toInst)
                          }
          totalExpenses = filteredExp.map(_.amount.doubleValue).sum
          commission    = totalEarnings * COMMISSION_RATE
          netPay        = totalEarnings - commission - totalExpenses

          summary = PayrollSummary(
                      driverId = driverId,
                      from = fromStr,
                      to = toStr,
                      totalRides = completedRides.size,
                      totalEarnings = totalEarnings,
                      totalExpenses = totalExpenses,
                      commission = commission,
                      netPay = netPay
                    )
        } yield Response.json(summary.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // Feature 1: Cancellation stats
      Method.GET / "api" / "stats" / "cancellations" -> handler { (request: Request) =>
        (for {
          user      <- AuthMiddleware.authenticateRequest(request)
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
          companyId <- UuidParser.requireCompanyId(user.companyId)
          service   <- ZIO.service[RideService]
          stats     <- service.getCancellationStats(companyId)
          entries    = stats.map { case (reason, count) => s"""{"reason":"$reason","count":$count}""" }
          json       = entries.mkString("[", ",", "]")
        } yield Response.json(json)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // Feature 5: Peak hours analysis
      Method.GET / "api" / "stats" / "peak-hours" -> handler { (request: Request) =>
        (for {
          user      <- AuthMiddleware.authenticateRequest(request)
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
          companyId <- UuidParser.requireCompanyId(user.companyId)
          days       = request.url.queryParams.queryParam("days").flatMap(_.toIntOption).getOrElse(30)
          service   <- ZIO.service[RideService]
          allRides  <- service.getRidesByCompany(companyId)
          cutoff     = Instant.now().minusSeconds(days.toLong * 86400)
          filtered   = allRides.filter(r => r.requestTime.isAfter(cutoff))
          grouped    = filtered.groupBy { ride =>
                         val zdt = ride.scheduledTime.getOrElse(ride.requestTime).atZone(ZoneId.systemDefault())
                         (zdt.getHour, zdt.getDayOfWeek.getValue % 7) // 0=Sunday style
                       }
          entries    = grouped
                         .map { case ((hour, dow), rides) => PeakHourEntry(hour, dow, rides.size) }
                         .toList
                         .sortBy(e => (e.dayOfWeek, e.hour))
        } yield Response.json(entries.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // Feature 6: Client lifetime value
      Method.GET / "api" / "stats" / "client-value" -> handler { (request: Request) =>
        (for {
          user       <- AuthMiddleware.authenticateRequest(request)
          _          <- AuthMiddleware.checkRole(user, "DISPATCHER")
          companyId  <- UuidParser.requireCompanyId(user.companyId)
          service    <- ZIO.service[RideService]
          personRepo <- ZIO.service[PersonRepository]
          allRides   <- service.getRidesByCompany(companyId)
          clients    <- personRepo.findByRole(PersonRole.Client)
          clientMap   = clients.map(c => c.id -> c.name).toMap
          byClient    = allRides.groupBy(_.clientId)
          entries     =
            byClient.map { case (clientId, rides) =>
              val completedRides = rides.filter(_.status == RideStatus.Completed)
              val totalRevenue   =
                completedRides.flatMap(r => r.finalPrice.orElse(r.estimatedPrice)).map(_.doubleValue).sum
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
        } yield Response.json(entries.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // Feature 7: Driver performance scorecard
      Method.GET / "api" / "stats" / "driver-performance" -> handler { (request: Request) =>
        (for {
          user       <- AuthMiddleware.authenticateRequest(request)
          _          <- AuthMiddleware.checkRole(user, "DISPATCHER")
          companyId  <- UuidParser.requireCompanyId(user.companyId)
          service    <- ZIO.service[RideService]
          personRepo <- ZIO.service[PersonRepository]
          ratingRepo <- ZIO.service[RideRatingRepository]
          allRides   <- service.getRidesByCompany(companyId)
          drivers    <- personRepo.findByRole(PersonRole.Driver)
          entries    <-
            ZIO.foreach(drivers.filter(_.companyId.contains(companyId))) { driver =>
              val driverRides    = allRides.filter(_.driverId.contains(driver.id))
              val completedRides = driverRides.filter(_.status == RideStatus.Completed)
              val cancelledRides = driverRides.count(_.status == RideStatus.Cancelled)
              val totalEarnings  =
                completedRides.flatMap(r => r.finalPrice.orElse(r.estimatedPrice)).map(_.doubleValue).sum
              val completionRate = if driverRides.nonEmpty then completedRides.size.toDouble / driverRides.size else 0.0
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
        } yield Response.json(entries.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // Feature 8: Driver ratings stats
      Method.GET / "api" / "stats" / "driver-ratings" -> handler { (request: Request) =>
        (for {
          user       <- AuthMiddleware.authenticateRequest(request)
          _          <- AuthMiddleware.checkRole(user, "DISPATCHER")
          companyId  <- UuidParser.requireCompanyId(user.companyId)
          personRepo <- ZIO.service[PersonRepository]
          ratingRepo <- ZIO.service[RideRatingRepository]
          drivers    <- personRepo.findByRole(PersonRole.Driver)
          entries    <-
            ZIO.foreach(drivers.filter(_.companyId.contains(companyId))) { driver =>
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
          filtered    = entries.flatten
        } yield Response.json(filtered.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      }
    )
