package com.shevchyk.ride.openapi

import com.shevchyk.auth.service.JwtService
import com.shevchyk.core.domain.PersonId
import com.shevchyk.core.openapi.ApiError
import com.shevchyk.ride.domain.*
import com.shevchyk.ride.openapi.RideSchemas.given
import com.shevchyk.ride.openapi.RideSecure.*
import com.shevchyk.ride.repository.ExpenseRepository
import sttp.model.StatusCode
import sttp.tapir.json.zio.*
import sttp.tapir.ztapir.*
import zio.ZIO

/**
 * Tapir descriptions and server logic for the expense endpoints. Replaces the zio-http handlers in `ExpenseRoutes`,
 * keeping the exact paths, status codes, role checks and company isolation. Note the original maps unexpected
 * `RuntimeException`s (e.g. "Expense not found", "Access denied") to a 500 — that behaviour is preserved here.
 */
object ExpenseApi:

  private val expenseTag = "Expenses"

  type ExpenseEnv = ExpenseRepository & JwtService

  private def internalError: Err = (StatusCode.InternalServerError, ApiError("Internal server error"))

  // -- Endpoint descriptions -----------------------------------------------

  val createExpenseEndpoint = secureEndpoint.post
    .in("api" / "expenses")
    .in(jsonBody[CreateExpenseRequest])
    .out(statusCode(StatusCode.Created).and(jsonBody[Expense]))
    .tag(expenseTag)
    .summary("Create an expense")

  val listExpensesEndpoint = secureEndpoint.get
    .in("api" / "expenses")
    .out(jsonBody[List[Expense]])
    .tag(expenseTag)
    .summary("List expenses for the driver or company")

  val deleteExpenseEndpoint = secureEndpoint.delete
    .in("api" / "expenses" / path[String]("id"))
    .out(statusCode(StatusCode.NoContent))
    .tag(expenseTag)
    .summary("Delete an expense")

  val endpoints = List(createExpenseEndpoint, listExpensesEndpoint, deleteExpenseEndpoint)

  // -- Server logic --------------------------------------------------------

  private val createExpenseServer: ZServerEndpoint[ExpenseEnv, Any] = createExpenseEndpoint.serverLogic { user => req =>
    for {
      _         <- checkRole(user, "DRIVER", "DISPATCHER", "ADMIN")
      _         <- ZIO
                     .fail((StatusCode.BadRequest, ApiError("Expense amount must be greater than zero")))
                     .when(req.amount <= 0)
      repo      <- ZIO.service[ExpenseRepository]
      rideIdOpt <- ZIO.foreach(req.rideId)(parseRideId)
      companyId <- requireCompanyId(user.companyId)
      expense    = Expense(
                     id = ExpenseId.generate(),
                     rideId = rideIdOpt,
                     driverId = PersonId(user.userId),
                     companyId = companyId,
                     category = ExpenseCategory.valueOf(req.category),
                     amount = BigDecimal(req.amount),
                     description = req.description
                   )
      created   <- repo.create(expense).mapError(_ => internalError)
    } yield created
  }

  private val listExpensesServer: ZServerEndpoint[ExpenseEnv, Any] = listExpensesEndpoint.serverLogic { user => _ =>
    for {
      _        <- checkRole(user, "DRIVER", "DISPATCHER", "ADMIN")
      repo     <- ZIO.service[ExpenseRepository]
      expenses <-
        user.role match {
          case "DISPATCHER" =>
            requireCompanyId(user.companyId).flatMap(cid => repo.findByCompanyId(cid).mapError(_ => internalError))
          case _            => repo.findByDriverId(PersonId(user.userId)).mapError(_ => internalError)
        }
    } yield expenses
  }

  private val deleteExpenseServer: ZServerEndpoint[ExpenseEnv, Any] = deleteExpenseEndpoint.serverLogic { user => id =>
    for {
      _          <- checkRole(user, "DRIVER", "DISPATCHER", "ADMIN")
      repo       <- ZIO.service[ExpenseRepository]
      expenseId  <- parseUuid(id).map(ExpenseId(_))
      expenseOpt <- repo.findById(expenseId).mapError(_ => internalError)
      expense    <- ZIO.fromOption(expenseOpt).orElseFail(internalError)
      userCid    <- requireCompanyId(user.companyId)
      _          <- ZIO.fail(internalError).when(expense.companyId.value != userCid.value)
      _          <- ZIO.fail(internalError).when(user.role == "DRIVER" && expense.driverId.value != user.userId)
      deleteId   <- parseUuid(id).map(ExpenseId(_))
      deleted    <- repo.delete(deleteId).mapError(_ => internalError)
      _          <- ZIO.fail((StatusCode.NotFound, ApiError("Not found"))).when(!deleted)
    } yield ()
  }

  val serverEndpoints: List[ZServerEndpoint[ExpenseEnv, Any]] = List(
    createExpenseServer,
    listExpensesServer,
    deleteExpenseServer
  )
