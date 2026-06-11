package com.shevchyk.billing.application

import com.shevchyk.billing.domain.Invoice
import zio.*

// Abstraction over "has this invoice been paid?". Today it's a mock that always
// reports unpaid; later a real implementation will query the banking API by the
// invoice's reference/payment purpose and confirm matching incoming transfers.
trait PaymentChecker:
  def isPaid(invoice: Invoice): Task[Boolean]

object PaymentChecker:

  // Mock: never reports a payment. The manual `markPaid` endpoint stays the way
  // payments are recorded until the banking integration replaces this layer.
  val mockLayer: ZLayer[Any, Nothing, PaymentChecker] = ZLayer.succeed(
    new PaymentChecker:
      override def isPaid(invoice: Invoice): Task[Boolean] = ZIO.succeed(false)
  )
