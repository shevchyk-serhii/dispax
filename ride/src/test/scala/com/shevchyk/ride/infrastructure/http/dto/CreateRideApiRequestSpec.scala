package com.shevchyk.ride.infrastructure.http.dto

import com.shevchyk.core.domain.*
import com.shevchyk.ride.domain.*
import zio.test.*
import zio.*
import java.time.Instant
import java.util.UUID

object CreateRideApiRequestSpec extends ZIOSpecDefault {

  private val companyId      = CompanyId(UUID.randomUUID())
  private val validClientId  = UUID.randomUUID().toString
  private val futureDateTime = Instant.now().plusSeconds(3600).toString

  private def makeRequest(paymentMethod: Option[String]) = CreateRideApiRequest(
    clientId = validClientId,
    creatorId = validClientId,
    pickupDateTime = Some(futureDateTime),
    from = LocationDto(address = "Marienplatz 1, Munich"),
    to = LocationDto(address = "Airport MUC"),
    clientName = "Test Client",
    paymentMethod = paymentMethod
  )

  def spec =
    suite("CreateRideApiRequest.toDomain")(
      // paymentMethod = parsedPaymentMethod — a mutation to None survives if the wire field is None,
      // so this test supplies a concrete wire value and asserts it is parsed and carried through.
      test("parses the paymentMethod wire value into the domain enum") {
        CreateRideApiRequest
          .toDomain(makeRequest(paymentMethod = Some("Invoice")), companyId)
          .map(domain => assertTrue(domain.paymentMethod.contains(PaymentMethod.Invoice)))
      },
      test("parses the new Payment wire value") {
        CreateRideApiRequest
          .toDomain(makeRequest(paymentMethod = Some("Payment")), companyId)
          .map(domain => assertTrue(domain.paymentMethod.contains(PaymentMethod.Payment)))
      },
      test("leaves paymentMethod None when the field is absent") {
        CreateRideApiRequest
          .toDomain(makeRequest(paymentMethod = None), companyId)
          .map(domain => assertTrue(domain.paymentMethod.isEmpty))
      },
      test("leaves paymentMethod None for an unknown wire value") {
        CreateRideApiRequest
          .toDomain(makeRequest(paymentMethod = Some("Bitcoin")), companyId)
          .map(domain => assertTrue(domain.paymentMethod.isEmpty))
      },
      // An airport transfer can be created without a flight number — specifics are still built,
      // with the flight left None (no live gate/terminal/entry-time until the number is added).
      test("builds airport specifics with no flight when isAirportTransfer is set but no flight given") {
        CreateRideApiRequest
          .toDomain(makeRequest(paymentMethod = None).copy(isAirportTransfer = true), companyId)
          .map(domain =>
            assertTrue(
              domain.specifics match
                case Some(RideSpecifics.AirportTransfer(_, None, _)) => true
                case _                                               => false
            )
          )
      },
      test("builds airport specifics carrying the flight number when one is given") {
        CreateRideApiRequest
          .toDomain(
            makeRequest(paymentMethod = None).copy(isAirportTransfer = true, flightNumber = Some("LH123")),
            companyId
          )
          .map(domain =>
            assertTrue(
              domain.specifics match
                case Some(RideSpecifics.AirportTransfer(_, Some("LH123"), _)) => true
                case _                                                        => false
            )
          )
      }
    )
}
