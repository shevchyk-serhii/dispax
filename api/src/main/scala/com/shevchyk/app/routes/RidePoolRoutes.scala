package com.shevchyk.app.routes

import com.shevchyk.auth.middleware.AuthMiddleware
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.auth.middleware.UuidParser
import com.shevchyk.core.repository.RidePoolRepository
import com.shevchyk.core.application.{AuditService, EventHub}
import com.shevchyk.ride.application.service.RideService
import com.shevchyk.core.infrastructure.http.RouteErrorHandler
import zio.*
import zio.http.*
import zio.json.*

import java.time.Instant

object RidePoolRoutes:

  private def handleError(ex: Throwable): UIO[Response] = RouteErrorHandler.handleError("RidePool")(ex)

  val authenticatedRoutes: Routes[RidePoolRepository & RideService & AuditService & EventHub & JwtService, Response] =
    Routes(
      // POST /api/pools — create a ride pool
      Method.POST / "api" / "pools" -> handler { (request: Request) =>
        (for {
          user      <- AuthMiddleware.authenticateRequest(request)
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
          bodyStr   <- request.body.asString
          req       <- ZIO
                         .fromEither(bodyStr.fromJson[CreatePoolRequest])
                         .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          repo      <- ZIO.service[RidePoolRepository]
          companyId <- UuidParser.requireCompanyId(user.companyId)
          pool       = RidePool(
                         id = RidePoolId.generate(),
                         companyId = companyId,
                         name = req.name,
                         maxPassengers = req.maxPassengers.getOrElse(4),
                         routeDirection = req.routeDirection,
                         scheduledTime = req.scheduledTime.flatMap(s => scala.util.Try(Instant.parse(s)).toOption),
                         createdBy = PersonId(user.userId)
                       )
          created   <- repo.create(pool)
          // Add initial rides if provided
          service   <- ZIO.service[RideService]
          _         <-
            ZIO.foreach(req.rideIds.zipWithIndex) { case (rideIdStr, idx) =>
              for {
                parsedRideId <- UuidParser.parseRideId(rideIdStr)
                ride         <- service.getRideById(parsedRideId)
                member        = RidePoolMember(
                                  id = RidePoolMemberId.generate(),
                                  poolId = created.id,
                                  rideId = ride.id,
                                  clientId = ride.clientId,
                                  pickupOrder = idx
                                )
                _            <- repo.addMember(member)
              } yield ()
            }
          updated   <-
            if req.rideIds.nonEmpty then repo.update(created.copy(currentPassengers = req.rideIds.size))
            else ZIO.succeed(created)
          audit     <- ZIO.service[AuditService]
          _         <-
            audit
              .log(
                AuditLogEntry(
                  id = AuditLogId.generate(),
                  companyId = pool.companyId,
                  actorId = PersonId(user.userId),
                  action = AuditAction.UserUpdated,
                  entityType = "ride_pool",
                  entityId = pool.id.value,
                  newValue = Some(s"created pool with ${req.rideIds.size} rides")
                )
              )
              .ignore
        } yield Response(Status.Created, body = Body.fromString(updated.toJson))).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // GET /api/pools — list pools for company
      Method.GET / "api" / "pools" -> handler { (request: Request) =>
        (for {
          user      <- AuthMiddleware.authenticateRequest(request)
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
          repo      <- ZIO.service[RidePoolRepository]
          companyId <- UuidParser.requireCompanyId(user.companyId)
          pools     <- repo.findByCompanyId(companyId)
        } yield Response.json(pools.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // GET /api/pools/open — list open pools
      Method.GET / "api" / "pools" / "open" -> handler { (request: Request) =>
        (for {
          user      <- AuthMiddleware.authenticateRequest(request)
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER")
          repo      <- ZIO.service[RidePoolRepository]
          companyId <- UuidParser.requireCompanyId(user.companyId)
          pools     <- repo.findOpenPools(companyId)
        } yield Response.json(pools.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // GET /api/pools/{id} — get pool details with members
      Method.GET / "api" / "pools" / string("id") -> handler { (id: String, request: Request) =>
        (for {
          user    <- AuthMiddleware.authenticateRequest(request)
          _       <- AuthMiddleware.checkRole(user, "DISPATCHER", "DRIVER")
          repo    <- ZIO.service[RidePoolRepository]
          poolId  <- UuidParser.parse(id).map(RidePoolId(_))
          poolOpt <- repo.findById(poolId)
          pool    <- ZIO.fromOption(poolOpt).orElseFail(new RuntimeException("Pool not found"))
          members <- repo.findMembersByPoolId(pool.id)
          response =
            s"""{
          "pool": ${pool.toJson},
          "members": ${members.toJson}
        }"""
        } yield Response.json(response)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // POST /api/pools/{id}/rides — add ride to pool
      Method.POST / "api" / "pools" / string("id") / "rides" -> handler { (id: String, request: Request) =>
        (for {
          user         <- AuthMiddleware.authenticateRequest(request)
          _            <- AuthMiddleware.checkRole(user, "DISPATCHER")
          bodyStr      <- request.body.asString
          req          <- ZIO
                            .fromEither(bodyStr.fromJson[AddToPoolRequest])
                            .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          repo         <- ZIO.service[RidePoolRepository]
          poolId       <- UuidParser.parse(id).map(RidePoolId(_))
          poolOpt      <- repo.findById(poolId)
          pool         <- ZIO.fromOption(poolOpt).orElseFail(new RuntimeException("Pool not found"))
          _            <- ZIO.fail(new RuntimeException("Pool is full or not open")).when(!pool.canAddPassenger)
          service      <- ZIO.service[RideService]
          parsedRideId <- UuidParser.parseRideId(req.rideId)
          ride         <- service.getRideById(parsedRideId)
          members      <- repo.findMembersByPoolId(pool.id)
          member        = RidePoolMember(
                            id = RidePoolMemberId.generate(),
                            poolId = pool.id,
                            rideId = ride.id,
                            clientId = ride.clientId,
                            pickupOrder = members.size
                          )
          _            <- repo.addMember(member)
          newCount      = pool.currentPassengers + 1
          newStatus     = if newCount >= pool.maxPassengers then PoolStatus.Full else PoolStatus.Open
          updated      <- repo.update(pool.copy(currentPassengers = newCount, status = newStatus))
          hub          <- ZIO.service[EventHub]
          _            <-
            hub
              .publish(
                WebSocketEvent.RideStatusChanged(
                  rideId = ride.id.value,
                  newStatus = "PooledRide",
                  driverId = pool.driverId.map(_.value),
                  companyId = pool.companyId.value
                )
              )
              .ignore
        } yield Response(Status.Created, body = Body.fromString(member.toJson))).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // DELETE /api/pools/{id}/rides/{rideId} — remove ride from pool
      Method.DELETE / "api" / "pools" / string("id") / "rides" / string("rideId") -> handler {
        (id: String, rideId: String, request: Request) =>
          (for {
            user         <- AuthMiddleware.authenticateRequest(request)
            _            <- AuthMiddleware.checkRole(user, "DISPATCHER")
            repo         <- ZIO.service[RidePoolRepository]
            poolId       <- UuidParser.parse(id).map(RidePoolId(_))
            poolOpt      <- repo.findById(poolId)
            pool         <- ZIO.fromOption(poolOpt).orElseFail(new RuntimeException("Pool not found"))
            parsedRideId <- UuidParser.parseRideId(rideId)
            removed      <- repo.removeMember(pool.id, parsedRideId)
            _            <- ZIO.fail(new RuntimeException("Ride not in pool")).when(!removed)
            updated      <- repo.update(
                              pool.copy(
                                currentPassengers = Math.max(0, pool.currentPassengers - 1),
                                status = if pool.status == PoolStatus.Full then PoolStatus.Open else pool.status
                              )
                            )
          } yield Response.status(Status.NoContent)).catchAll {
            case response: Response => ZIO.succeed(response)
            case ex: Throwable      => handleError(ex)
          }
      },

      // PUT /api/pools/{id}/assign — assign driver to pool
      Method.PUT / "api" / "pools" / string("id") / "assign" -> handler { (id: String, request: Request) =>
        (for {
          user        <- AuthMiddleware.authenticateRequest(request)
          _           <- AuthMiddleware.checkRole(user, "DISPATCHER")
          bodyStr     <- request.body.asString
          driverReq   <- ZIO
                           .fromEither(bodyStr.fromJson[Map[String, String]])
                           .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          driverIdStr <- ZIO
                           .fromOption(driverReq.get("driverId"))
                           .orElseFail(
                             Response(Status.BadRequest, body = Body.fromString("""{"error":"driverId required"}"""))
                           )
          driverPid   <- UuidParser.parsePersonId(driverIdStr)
          repo        <- ZIO.service[RidePoolRepository]
          poolId      <- UuidParser.parse(id).map(RidePoolId(_))
          poolOpt     <- repo.findById(poolId)
          pool        <- ZIO.fromOption(poolOpt).orElseFail(new RuntimeException("Pool not found"))
          // Assign driver to all rides in pool
          members     <- repo.findMembersByPoolId(pool.id)
          service     <- ZIO.service[RideService]
          _           <-
            ZIO.foreach(members) { m =>
              service.assignDriver(m.rideId, driverPid).catchAll(_ => ZIO.unit)
            }
          updated     <- repo.update(pool.copy(driverId = Some(driverPid)))
        } yield Response.json(updated.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // PUT /api/pools/{id}/status — update pool status
      Method.PUT / "api" / "pools" / string("id") / "status" -> handler { (id: String, request: Request) =>
        (for {
          user      <- AuthMiddleware.authenticateRequest(request)
          _         <- AuthMiddleware.checkRole(user, "DISPATCHER", "DRIVER")
          bodyStr   <- request.body.asString
          statusReq <- ZIO
                         .fromEither(bodyStr.fromJson[Map[String, String]])
                         .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          newStatus <- ZIO
                         .fromOption(statusReq.get("status"))
                         .orElseFail(
                           Response(Status.BadRequest, body = Body.fromString("""{"error":"status required"}"""))
                         )
          repo      <- ZIO.service[RidePoolRepository]
          poolId    <- UuidParser.parse(id).map(RidePoolId(_))
          poolOpt   <- repo.findById(poolId)
          pool      <- ZIO.fromOption(poolOpt).orElseFail(new RuntimeException("Pool not found"))
          poolStatus = PoolStatus.valueOf(newStatus)
          updated   <- repo.update(pool.copy(status = poolStatus))
        } yield Response.json(updated.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // GET /api/pools/ride/{rideId} — find pool for a ride
      Method.GET / "api" / "pools" / "ride" / string("rideId") -> handler { (rideId: String, request: Request) =>
        (for {
          user         <- AuthMiddleware.authenticateRequest(request)
          repo         <- ZIO.service[RidePoolRepository]
          parsedRideId <- UuidParser.parseRideId(rideId)
          poolOpt      <- repo.findPoolByRideId(parsedRideId)
        } yield poolOpt match {
          case Some(pool) => Response.json(pool.toJson)
          case None       => Response.status(Status.NotFound)
        }).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      }
    )
