package com.shevchyk.ride.infrastructure.http

import com.shevchyk.auth.middleware.AuthMiddleware
import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.*
import com.shevchyk.auth.middleware.UuidParser
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.repository.ExpenseRepository
import zio.*
import zio.http.*
import zio.json.*

object ExpenseRoutes:

  private def handleExpenseError(ex: Throwable): UIO[Response] =
    val msg = Option(ex.getMessage).getOrElse(ex.toString)
    ZIO
      .logError(s"Expense error: $msg")
      .as(Response(Status.InternalServerError, body = Body.fromString(s"""{"error":"Internal server error"}""")))

  val authenticatedRoutes: Routes[ExpenseRepository & JwtService, Response] = Routes(
    // POST /api/expenses — create expense (driver or dispatcher)
    Method.POST / "api" / "expenses"                  -> handler { (request: Request) =>
      (for {
        user      <- AuthMiddleware.authenticateRequest(request)
        _         <- AuthMiddleware.checkRole(user, "DRIVER", "DISPATCHER")
        bodyStr   <- request.body.asString
        req       <- ZIO
                       .fromEither(bodyStr.fromJson[CreateExpenseRequest])
                       .mapError(err => new RuntimeException(s"Invalid JSON: $err"))
        repo      <- ZIO.service[ExpenseRepository]
        rideIdOpt <- ZIO.foreach(req.rideId)(UuidParser.parseRideId)
        companyId <- UuidParser.requireCompanyId(user.companyId)
        expense    = Expense(
                       id = ExpenseId.generate(),
                       rideId = rideIdOpt,
                       driverId = PersonId(user.userId),
                       companyId = companyId,
                       category = ExpenseCategory.valueOf(req.category),
                       amount = BigDecimal(req.amount),
                       description = req.description
                     )
        created   <- repo.create(expense)
      } yield Response(Status.Created, body = Body.fromString(created.toJson))).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleExpenseError(ex)
      }
    },
    // GET /api/expenses — list expenses for driver or company
    Method.GET / "api" / "expenses"                   -> handler { (request: Request) =>
      (for {
        user     <- AuthMiddleware.authenticateRequest(request)
        _        <- AuthMiddleware.checkRole(user, "DRIVER", "DISPATCHER")
        repo     <- ZIO.service[ExpenseRepository]
        expenses <-
          user.role match {
            case "DISPATCHER" => UuidParser.requireCompanyId(user.companyId).flatMap(repo.findByCompanyId)
            case _            => repo.findByDriverId(PersonId(user.userId))
          }
      } yield Response.json(expenses.toJson)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleExpenseError(ex)
      }
    },
    // DELETE /api/expenses/{id} — delete expense (owner or dispatcher in same company)
    Method.DELETE / "api" / "expenses" / string("id") -> handler { (id: String, request: Request) =>
      (for {
        user       <- AuthMiddleware.authenticateRequest(request)
        _          <- AuthMiddleware.checkRole(user, "DRIVER", "DISPATCHER")
        repo       <- ZIO.service[ExpenseRepository]
        expenseId  <- UuidParser.parse(id).map(ExpenseId(_))
        expenseOpt <- repo.findById(expenseId)
        expense    <- ZIO.fromOption(expenseOpt).orElseFail(new RuntimeException("Expense not found"))
        userCid    <- UuidParser.requireCompanyId(user.companyId)
        _          <-
          ZIO.when(expense.companyId.value != userCid.value)(
            ZIO.fail(new RuntimeException("Access denied"))
          )
        _          <-
          ZIO.when(user.role == "DRIVER" && expense.driverId.value != user.userId)(
            ZIO.fail(new RuntimeException("Access denied"))
          )
        deleteId   <- UuidParser.parse(id).map(ExpenseId(_))
        deleted    <- repo.delete(deleteId)
      } yield if deleted then Response(Status.NoContent) else Response.status(Status.NotFound)).catchAll {
        case response: Response => ZIO.succeed(response)
        case ex: Throwable      => handleExpenseError(ex)
      }
    }
  )
