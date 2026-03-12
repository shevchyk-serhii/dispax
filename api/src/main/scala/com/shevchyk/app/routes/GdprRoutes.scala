package com.shevchyk.app.routes

import com.shevchyk.auth.middleware.AuthMiddleware
import com.shevchyk.auth.service.JwtService
import com.shevchyk.auth.repository.UserRepository
import com.shevchyk.core.domain.*
import com.shevchyk.core.repository.GdprRepository
import com.shevchyk.ride.repository.{RideRepository, ExpenseRepository}
import com.shevchyk.repository.PersonRepository
import zio.*
import zio.http.*
import zio.json.*

import java.time.Instant
import java.util.UUID

object GdprRoutes:

  private def handleError(ex: Throwable): UIO[Response] =
    val msg = Option(ex.getMessage).getOrElse(ex.toString)
    ZIO
      .logError(s"GDPR error: $msg")
      .as(Response(Status.InternalServerError, body = Body.fromString("""{"error":"Internal server error"}""")))

  val authenticatedRoutes
      : Routes[GdprRepository & PersonRepository & UserRepository & RideRepository & ExpenseRepository & JwtService, Response] =
    Routes(
      // GET /api/gdpr/consents — get user's consents
      Method.GET / "api" / "gdpr" / "consents" -> handler { (request: Request) =>
        (for {
          user     <- AuthMiddleware.authenticateRequest(request)
          repo     <- ZIO.service[GdprRepository]
          consents <- repo.findConsentsByUserId(PersonId(user.userId))
        } yield Response.json(consents.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // PUT /api/gdpr/consents — update consent
      Method.PUT / "api" / "gdpr" / "consents" -> handler { (request: Request) =>
        (for {
          user    <- AuthMiddleware.authenticateRequest(request)
          bodyStr <- request.body.asString
          req     <- ZIO
                       .fromEither(bodyStr.fromJson[UpdateConsentRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
          repo    <- ZIO.service[GdprRepository]
          cType   <- ZIO.attempt(ConsentType.valueOf(req.consentType))
          result  <-
            if req.granted then
              repo
                .createConsent(
                  GdprConsent(
                    id = GdprConsentId.generate(),
                    userId = PersonId(user.userId),
                    consentType = cType,
                    grantedAt = Instant.now()
                  )
                )
                .map(c => Response.json(c.toJson))
            else
              repo
                .revokeConsent(PersonId(user.userId), cType)
                .map(ok => if ok then Response.json("""{"success":true}""") else Response.status(Status.NotFound))
        } yield result).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // GET /api/gdpr/export — export all user data
      Method.GET / "api" / "gdpr" / "export" -> handler { (request: Request) =>
        (for {
          user       <- AuthMiddleware.authenticateRequest(request)
          personRepo <- ZIO.service[PersonRepository]
          userRepo   <- ZIO.service[UserRepository]
          rideRepo   <- ZIO.service[RideRepository]
          expRepo    <- ZIO.service[ExpenseRepository]
          gdprRepo   <- ZIO.service[GdprRepository]

          personOpt   <- personRepo.findById(PersonId(user.userId))
          userOpt     <- userRepo.findById(user.userId)
          clientRides <- rideRepo.findByClientId(PersonId(user.userId))
          driverRides <- rideRepo.findByDriverId(PersonId(user.userId))
          userRides    = (clientRides ++ driverRides).distinctBy(_.id)
          expenses    <- expRepo.findByDriverId(PersonId(user.userId))
          consents    <- gdprRepo.findConsentsByUserId(PersonId(user.userId))

          userData = Map(
                       "id"    -> user.userId.toString,
                       "email" -> user.email,
                       "role"  -> user.role,
                       "name"  -> personOpt.map(_.name).getOrElse(""),
                       "phone" -> personOpt.flatMap(_.phone).getOrElse("")
                     )

          rideData = userRides.map(r =>
                       Map(
                         "id"     -> r.id.value.toString,
                         "from"   -> r.pickupLocation.address,
                         "to"     -> r.dropoffLocation.address,
                         "status" -> r.status.toString,
                         "date"   -> r.scheduledTime.map(_.toString).getOrElse(r.requestTime.toString),
                         "price"  -> r.finalPrice.orElse(r.estimatedPrice).map(_.toString).getOrElse("")
                       )
                     )

          expenseData = expenses.map(e =>
                          Map(
                            "id"          -> e.id.value.toString,
                            "category"    -> e.category.toString,
                            "amount"      -> e.amount.toString,
                            "description" -> e.description.getOrElse("")
                          )
                        )

          dataExport = GdprDataExport(
                         user = userData,
                         rides = rideData,
                         expenses = expenseData,
                         consents = consents,
                         exportedAt = Instant.now()
                       )
        } yield Response.json(dataExport.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // POST /api/gdpr/deletion-request — request data deletion
      Method.POST / "api" / "gdpr" / "deletion-request" -> handler { (request: Request) =>
        (for {
          user    <- AuthMiddleware.authenticateRequest(request)
          repo    <- ZIO.service[GdprRepository]
          req      = GdprRequest(
                       id = GdprRequestId.generate(),
                       userId = PersonId(user.userId),
                       requestType = GdprRequestType.DELETION,
                       requestedAt = Instant.now()
                     )
          created <- repo.createRequest(req)
        } yield Response(Status.Created, body = Body.fromString(created.toJson))).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      },

      // GET /api/gdpr/requests — get user's GDPR requests
      Method.GET / "api" / "gdpr" / "requests" -> handler { (request: Request) =>
        (for {
          user     <- AuthMiddleware.authenticateRequest(request)
          repo     <- ZIO.service[GdprRepository]
          requests <- repo.findRequestsByUserId(PersonId(user.userId))
        } yield Response.json(requests.toJson)).catchAll {
          case response: Response => ZIO.succeed(response)
          case ex: Throwable      => handleError(ex)
        }
      }
    )
