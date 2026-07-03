package com.shevchyk.ride.infrastructure.http

import zio.json.*

/**
 * JSON response models for the DATEV export endpoints (`ExportApi`). Amounts are `Double` at this JSON boundary only —
 * aggregation happens in `BigDecimal` inside `ExportApi`.
 */

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
