package com.shevchyk.billing.application

import com.lowagie.text.{List => _, Chunk => PdfChunk, *}
import com.lowagie.text.pdf.*
import com.lowagie.text.pdf.draw.LineSeparator
import com.shevchyk.billing.domain.{CompanyBillingProfile, Invoice, InvoiceItem}
import com.shevchyk.core.domain.ClientCompany
import zio.*

import java.awt.Color
import java.io.{ByteArrayOutputStream, File, FileOutputStream}
import java.time.format.DateTimeFormatter
import java.time.{ZoneId, format => _}

object PdfGenerator:

  // iText's `Document.add` / `PdfPTable.addCell` return a value we intentionally ignore.
  extension [A](a: A) private def discard: Unit = ()

  // Documents are issued in Munich; format all stored UTC instants in the local zone
  // so dates/times near midnight do not shift to the previous/next calendar day.
  private val BerlinZone = ZoneId.of("Europe/Berlin")

  private val dateFormatter     = DateTimeFormatter.ofPattern("dd.MM.yyyy")
  private val dateTimeFormatter = DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm")
  private val monthFormatter    = DateTimeFormatter.ofPattern("MMMM yyyy", java.util.Locale.GERMAN)

  // Monochrome (black & white) palette, matching the plain reference Rechnung.
  private val colorPrimary = Color.BLACK
  private val colorLight   = new Color(245, 245, 245)
  private val colorGrey    = new Color(100, 100, 100)
  private val colorBorder  = new Color(200, 200, 200)
  private val colorTableHd = new Color(60, 60, 60)

  private val fontTitle     = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 20f, colorPrimary)
  private val fontHeading   = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11f, Color.BLACK)
  private val fontSubHead   = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 12f, Color.BLACK)
  private val fontNormal    = FontFactory.getFont(FontFactory.HELVETICA, 10f, Color.BLACK)
  private val fontSmall     = FontFactory.getFont(FontFactory.HELVETICA, 8f, colorGrey)
  private val fontFooter    = FontFactory.getFont(FontFactory.HELVETICA, 8f, Color.BLACK)
  private val fontFooterB   = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 8f, Color.BLACK)
  private val fontTableHead = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 9f, Color.WHITE)
  private val fontTableCell = FontFactory.getFont(FontFactory.HELVETICA, 9f, Color.BLACK)
  private val fontTotal     = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11f, colorPrimary)

  // Backward-compatible entry point: build a minimal profile from a plain company name.
  def generateBytes(invoice: Invoice, clientCompany: ClientCompany, companyName: String): Task[Array[Byte]] =
    generateBytes(invoice, clientCompany, profileFromName(invoice, companyName))

  def generateToFile(invoice: Invoice, clientCompany: ClientCompany, companyName: String, path: String): Task[String] =
    generateToFile(invoice, clientCompany, profileFromName(invoice, companyName), path)

  private def profileFromName(invoice: Invoice, companyName: String): CompanyBillingProfile = CompanyBillingProfile(
    companyId = invoice.taxiCompanyId,
    legalName = Some(companyName)
  )

  def generateBytes(invoice: Invoice, clientCompany: ClientCompany, profile: CompanyBillingProfile): Task[Array[Byte]] =
    ZIO.attempt {
      val out = new ByteArrayOutputStream()
      val doc = new Document(PageSize.A4, 50, 50, 60, 50)
      PdfWriter.getInstance(doc, out)
      doc.open()

      addIssuerHeader(doc, invoice, profile)
      doc.add(PdfChunk.NEWLINE)
      addTitle(doc)
      addRecipient(doc, invoice, clientCompany)
      doc.add(PdfChunk.NEWLINE)
      addCostHeading(doc, invoice, profile)
      doc.add(PdfChunk.NEWLINE)
      addTotals(doc, invoice)
      doc.add(PdfChunk.NEWLINE)
      addPaymentTerms(doc, profile)
      addSignature(doc, profile)
      invoice.notes.foreach { n =>
        doc.add(PdfChunk.NEWLINE)
        addNotes(doc, n)
      }
      if invoice.items.nonEmpty then
        doc.add(PdfChunk.NEWLINE)
        addItemsTable(doc, invoice.items)
      addFooter(doc, profile)

      doc.close()
      out.toByteArray
    }

  def generateToFile(
      invoice: Invoice,
      clientCompany: ClientCompany,
      profile: CompanyBillingProfile,
      path: String
  ): Task[String] = generateBytes(invoice, clientCompany, profile).flatMap { bytes =>
    ZIO.attempt {
      val file = new File(path)
      file.getParentFile.mkdirs()
      val fos  = new FileOutputStream(file)
      fos.write(bytes)
      fos.close()
      path
    }
  }

  // Single-ride German taxi receipt ("Quittung / Rechnung"). A clean digital
  // document, not a replica of the paper form. The price is treated as gross
  // (Brutto, incl. MwSt); Netto and MwSt are derived from it. Ride type and
  // payment method are static in v1 ("Stadtfahrt" / "Bar").
  def generateReceiptBytes(
      receiptNumber: String,
      pickupAddress: String,
      dropoffAddress: String,
      pickupDatetime: java.time.Instant,
      grossPrice: BigDecimal,
      taxRatePct: BigDecimal,
      issuer: CompanyBillingProfile,
      recipient: ClientCompany
  ): Task[Array[Byte]] = ZIO.attempt {
    val out = new ByteArrayOutputStream()
    val doc = new Document(PageSize.A4, 50, 50, 60, 50)
    PdfWriter.getInstance(doc, out)
    doc.open()

    addReceiptIssuerHeader(doc, pickupDatetime, issuer)
    doc.add(PdfChunk.NEWLINE)
    addReceiptTitle(doc)
    addReceiptRecipient(doc, receiptNumber, recipient)
    doc.add(PdfChunk.NEWLINE)
    addReceiptRideDetails(doc, pickupAddress, dropoffAddress, pickupDatetime)
    doc.add(PdfChunk.NEWLINE)
    addReceiptAmounts(doc, grossPrice, taxRatePct)
    addReceiptSignature(doc)
    addFooter(doc, issuer)

    doc.close()
    out.toByteArray
  }

  def generateReceiptToFile(
      receiptNumber: String,
      pickupAddress: String,
      dropoffAddress: String,
      pickupDatetime: java.time.Instant,
      grossPrice: BigDecimal,
      taxRatePct: BigDecimal,
      issuer: CompanyBillingProfile,
      recipient: ClientCompany,
      path: String
  ): Task[String] = generateReceiptBytes(
    receiptNumber,
    pickupAddress,
    dropoffAddress,
    pickupDatetime,
    grossPrice,
    taxRatePct,
    issuer,
    recipient
  )
    .flatMap { bytes =>
      ZIO.attempt {
        val file = new File(path)
        file.getParentFile.mkdirs()
        val fos  = new FileOutputStream(file)
        fos.write(bytes)
        fos.close()
        path
      }
    }

  private def addReceiptIssuerHeader(
      doc: Document,
      pickupDatetime: java.time.Instant,
      profile: CompanyBillingProfile
  ): Unit =
    val table = new PdfPTable(2)
    table.setWidthPercentage(100)
    table.setWidths(Array(3f, 2f))

    val issuer = new PdfPCell()
    issuer.setBorder(Rectangle.NO_BORDER)
    profile.businessType.foreach(bt => issuer.addElement(new Phrase(bt, fontNormal)))
    profile.legalName.foreach(ln => issuer.addElement(new Phrase(ln, fontHeading)))
    profile.addressLine1.foreach(a => issuer.addElement(new Phrase(a, fontNormal)))
    profile.addressLine2.foreach(a => issuer.addElement(new Phrase(a, fontNormal)))
    table.addCell(issuer)

    val date     = pickupDatetime.atZone(BerlinZone).toLocalDate
    val dateCell = new PdfPCell(new Phrase(date.format(dateFormatter), fontNormal))
    dateCell.setBorder(Rectangle.NO_BORDER)
    dateCell.setHorizontalAlignment(Element.ALIGN_RIGHT)
    table.addCell(dateCell)

    doc.add(table).discard

  private def addReceiptTitle(doc: Document): Unit =
    val title = new Paragraph("Quittung / Rechnung", fontTitle)
    title.setAlignment(Element.ALIGN_RIGHT)
    doc.add(title).discard
    doc.add(new LineSeparator(1f, 100f, colorPrimary, Element.ALIGN_CENTER, 0f)).discard

  private def addReceiptRecipient(doc: Document, receiptNumber: String, recipient: ClientCompany): Unit =
    val table = new PdfPTable(2)
    table.setWidthPercentage(100)
    table.setWidths(Array(3f, 2f))

    val toCell = new PdfPCell()
    toCell.setBorder(Rectangle.NO_BORDER)
    toCell.addElement(new Phrase("Name, Anschrift des Rechnungsempfängers", fontSmall))
    toCell.addElement(new Phrase(recipient.name, fontHeading))
    recipient.address.foreach(a => toCell.addElement(new Phrase(a, fontNormal)))
    table.addCell(toCell)

    val nrCell = new PdfPCell()
    nrCell.setBorder(Rectangle.NO_BORDER)
    nrCell.setHorizontalAlignment(Element.ALIGN_RIGHT)
    nrCell.addElement(new Phrase("Belegnr.:", fontSmall))
    nrCell.addElement(new Phrase(receiptNumber, fontHeading))
    table.addCell(nrCell)

    doc.add(table).discard

  private def addReceiptRideDetails(
      doc: Document,
      pickupAddress: String,
      dropoffAddress: String,
      pickupDatetime: java.time.Instant
  ): Unit =
    val table = new PdfPTable(2)
    table.setWidthPercentage(100)
    table.setWidths(Array(1.5f, 4f))

    def row(label: String, value: String): Unit =
      val lc = new PdfPCell(new Phrase(label, fontNormal))
      lc.setBorder(Rectangle.NO_BORDER)
      lc.setPaddingTop(4)
      table.addCell(lc)
      val vc = new PdfPCell(new Phrase(value, fontNormal))
      vc.setBorder(Rectangle.NO_BORDER)
      vc.setPaddingTop(4)
      table.addCell(vc).discard

    row("Fahrtart:", "Stadtfahrt")
    row("Fahrt von:", pickupAddress)
    row("nach:", dropoffAddress)
    row("Datum/Uhrzeit:", pickupDatetime.atZone(BerlinZone).toLocalDateTime.format(dateTimeFormatter))
    row("Zahlungsart:", "Bar")

    doc.add(table).discard

  // Brutto (gross) in → Netto and MwSt derived. Same HALF_UP rounding as the invoice path.
  private def addReceiptAmounts(doc: Document, grossPrice: BigDecimal, taxRatePct: BigDecimal): Unit =
    val gross = grossPrice.setScale(2, BigDecimal.RoundingMode.HALF_UP)
    val net   = (gross / (1 + taxRatePct / 100)).setScale(2, BigDecimal.RoundingMode.HALF_UP)
    val tax   = (gross - net).setScale(2, BigDecimal.RoundingMode.HALF_UP)

    val table = new PdfPTable(2)
    table.setWidthPercentage(100)

    def totalRow(label: String, value: String, bold: Boolean = false): Unit =
      val f  = if bold then fontTotal else fontNormal
      val lc = new PdfPCell(new Phrase(label, f))
      lc.setBorder(Rectangle.NO_BORDER)
      lc.setPaddingTop(6)
      table.addCell(lc)
      val vc = new PdfPCell(new Phrase(value, f))
      vc.setBorder(Rectangle.NO_BORDER)
      vc.setPaddingTop(6)
      vc.setHorizontalAlignment(Element.ALIGN_RIGHT)
      table.addCell(vc).discard

    totalRow("Netto-Fahrpreis", formatMoney(net))
    if taxRatePct > 0 then totalRow(s"MwSt. $taxRatePct%", formatMoney(tax))
    totalRow("= Brutto-Fahrpreis", formatMoney(gross), bold = true)

    doc.add(table).discard

  private def addReceiptSignature(doc: Document): Unit =
    val line = new Paragraph("____________________________", fontNormal)
    line.setSpacingBefore(28f)
    doc.add(line)
    doc.add(new Paragraph("Datum, Unterschrift des Fahrers", fontSmall)).discard

  // Issuer block (top-left) + invoice date (top-right), mirroring the sample Rechnung.
  private def addIssuerHeader(doc: Document, invoice: Invoice, profile: CompanyBillingProfile): Unit =
    val table = new PdfPTable(2)
    table.setWidthPercentage(100)
    table.setWidths(Array(3f, 2f))

    val issuer = new PdfPCell()
    issuer.setBorder(Rectangle.NO_BORDER)
    profile.businessType.foreach(bt => issuer.addElement(new Phrase(bt, fontNormal)))
    profile.legalName.foreach(ln => issuer.addElement(new Phrase(ln, fontHeading)))
    profile.addressLine1.foreach(a => issuer.addElement(new Phrase(a, fontNormal)))
    profile.addressLine2.foreach(a => issuer.addElement(new Phrase(a, fontNormal)))
    table.addCell(issuer)

    val invoiceDate = invoice.sentAt.getOrElse(invoice.createdAt).atZone(BerlinZone).toLocalDate
    val dateCell    = new PdfPCell(new Phrase(invoiceDate.format(dateFormatter), fontNormal))
    dateCell.setBorder(Rectangle.NO_BORDER)
    dateCell.setHorizontalAlignment(Element.ALIGN_RIGHT)
    table.addCell(dateCell)

    doc.add(table).discard

  private def addTitle(doc: Document): Unit =
    val title = new Paragraph("Rechnung", fontTitle)
    title.setAlignment(Element.ALIGN_RIGHT)
    doc.add(title)
    doc.add(new LineSeparator(1f, 100f, colorPrimary, Element.ALIGN_CENTER, 0f)).discard

  // Recipient (client company) on the left, invoice number on the right.
  private def addRecipient(doc: Document, invoice: Invoice, clientCompany: ClientCompany): Unit =
    val table = new PdfPTable(2)
    table.setWidthPercentage(100)
    table.setWidths(Array(3f, 2f))

    val toCell = new PdfPCell()
    toCell.setBorder(Rectangle.NO_BORDER)
    toCell.addElement(new Phrase(clientCompany.name, fontHeading))
    clientCompany.address.foreach(a => toCell.addElement(new Phrase(a, fontNormal)))
    table.addCell(toCell)

    val nrCell = new PdfPCell()
    nrCell.setBorder(Rectangle.NO_BORDER)
    nrCell.setHorizontalAlignment(Element.ALIGN_RIGHT)
    nrCell.addElement(new Phrase("Rechnungs- Nr.:", fontSmall))
    nrCell.addElement(new Phrase(invoice.number, fontHeading))
    table.addCell(nrCell)

    doc.add(table).discard

  private def addCostHeading(doc: Document, invoice: Invoice, profile: CompanyBillingProfile): Unit =
    val heading = new Paragraph("Kostenrechnung", fontSubHead)
    heading.setAlignment(Element.ALIGN_CENTER)
    doc.add(heading)
    doc.add(PdfChunk.NEWLINE)
    profile.invoiceIntro.foreach(intro => doc.add(new Phrase(intro, fontNormal)))
    doc.add(PdfChunk.NEWLINE)
    val period  = invoice.periodFrom.format(monthFormatter)
    doc.add(new Phrase(s"Auftragsfahrten v. $period", fontNormal)).discard

  private def addTotals(doc: Document, invoice: Invoice): Unit =
    val table = new PdfPTable(2)
    table.setWidthPercentage(100)

    def totalRow(label: String, value: String, bold: Boolean = false): Unit =
      val f  = if bold then fontTotal else fontNormal
      val lc = new PdfPCell(new Phrase(label, f))
      lc.setBorder(Rectangle.NO_BORDER)
      lc.setPaddingTop(6)
      table.addCell(lc)
      val vc = new PdfPCell(new Phrase(value, f))
      vc.setBorder(Rectangle.NO_BORDER)
      vc.setPaddingTop(6)
      vc.setHorizontalAlignment(Element.ALIGN_RIGHT)
      table.addCell(vc).discard

    totalRow("Nettozwischensumme", formatMoney(invoice.subtotalAmount))
    if invoice.taxRate > 0 then totalRow(s"MwSt. ${invoice.taxRate}%", formatMoney(invoice.taxAmount))
    totalRow(s"= Rechnungsbetrag (${invoice.currency})", formatMoney(invoice.totalAmount), bold = true)

    doc.add(table).discard

  private def addPaymentTerms(doc: Document, profile: CompanyBillingProfile): Unit =
    val p1 = new Paragraph("Bitte überweisen Sie den ausgewiesenen Betrag.", fontNormal)
    p1.setSpacingBefore(16f)
    doc.add(p1)
    doc.add(new Paragraph(s"Zahlbar innerhalb von ${profile.paymentTermsDays} Tagen.", fontSmall)).discard

  private def addSignature(doc: Document, profile: CompanyBillingProfile): Unit =
    val greet = new Paragraph("Mit freundlichen Grüßen", fontNormal)
    greet.setSpacingBefore(16f)
    doc.add(greet)
    profile.legalName.foreach { ln =>
      val sig = new Paragraph(ln, fontNormal)
      sig.setSpacingBefore(8f)
      doc.add(sig)
    }

  private def addItemsTable(doc: Document, items: scala.collection.immutable.List[InvoiceItem]): Unit =
    val table = new PdfPTable(5)
    table.setWidthPercentage(100)
    table.setWidths(Array(1.5f, 5f, 1f, 2f, 2f))

    def headerCell(text: String, align: Int = Element.ALIGN_LEFT): PdfPCell =
      val c = new PdfPCell(new Phrase(text, fontTableHead))
      c.setBackgroundColor(colorTableHd)
      c.setBorder(Rectangle.NO_BORDER)
      c.setPadding(8)
      c.setHorizontalAlignment(align)
      c

    table.addCell(headerCell("Datum"))
    table.addCell(headerCell("Beschreibung"))
    table.addCell(headerCell("Menge", Element.ALIGN_CENTER))
    table.addCell(headerCell("Einzelpreis", Element.ALIGN_RIGHT))
    table.addCell(headerCell("Gesamt", Element.ALIGN_RIGHT))

    items.zipWithIndex.foreach { case (item, i) =>
      val bg = if i % 2 == 0 then Color.WHITE else colorLight

      def dataCell(text: String, align: Int = Element.ALIGN_LEFT): PdfPCell =
        val c = new PdfPCell(new Phrase(text, fontTableCell))
        c.setBackgroundColor(bg)
        c.setBorderColor(colorBorder)
        c.setBorderWidth(0.5f)
        c.setPadding(7)
        c.setHorizontalAlignment(align)
        c

      val date = item.createdAt.atZone(BerlinZone).toLocalDate.format(dateFormatter)
      table.addCell(dataCell(date))
      table.addCell(dataCell(item.description))
      table.addCell(dataCell(item.quantity.setScale(0, BigDecimal.RoundingMode.HALF_UP).toString, Element.ALIGN_CENTER))
      table.addCell(dataCell(formatMoney(item.unitPrice), Element.ALIGN_RIGHT))
      table.addCell(dataCell(formatMoney(item.total), Element.ALIGN_RIGHT))
    }

    doc.add(table).discard

  private def addNotes(doc: Document, notes: String): Unit =
    val head = new Paragraph("Anmerkungen", fontHeading)
    head.setSpacingBefore(16f)
    doc.add(head)
    doc.add(new Paragraph(notes, fontNormal)).discard

  // Footer: contact + tax IDs (left column) and bank details (right column), as in the sample.
  private def addFooter(doc: Document, profile: CompanyBillingProfile): Unit =
    doc.add(PdfChunk.NEWLINE)
    doc.add(new LineSeparator(0.5f, 100f, colorBorder, Element.ALIGN_CENTER, 0f))

    val table = new PdfPTable(2)
    table.setWidthPercentage(100)
    table.setWidths(Array(1f, 1f))

    def kv(cell: PdfPCell, label: String, value: Option[String]): Unit = value.foreach { v =>
      val p = new Paragraph()
      p.add(new PdfChunk(s"$label: ", fontFooter))
      p.add(new PdfChunk(v, fontFooterB))
      cell.addElement(p)
    }

    val left = new PdfPCell()
    left.setBorder(Rectangle.NO_BORDER)
    kv(left, "Telefon", profile.phone)
    kv(left, "E-Mail", profile.email)
    kv(left, "St-Nr.", profile.taxNumber)
    kv(left, "IdNr.", profile.vatId)
    table.addCell(left)

    val right = new PdfPCell()
    right.setBorder(Rectangle.NO_BORDER)
    profile.legalName.foreach(ln => right.addElement(new Phrase(ln, fontFooterB)))
    kv(right, "Bank", profile.bankName)
    kv(right, "Konto-Nr.", profile.bankAccountNo)
    kv(right, "BLZ", profile.bankCode)
    kv(right, "IBAN", profile.iban)
    kv(right, "BIC", profile.bic)
    table.addCell(right)

    doc.add(table).discard

  // German number format: comma decimal separator, e.g. "171,50 €".
  private def formatMoney(amount: BigDecimal): String =
    val nf = java.text.NumberFormat.getNumberInstance(java.util.Locale.GERMAN)
    nf.setMinimumFractionDigits(2)
    nf.setMaximumFractionDigits(2)
    s"${nf.format(amount.setScale(2, BigDecimal.RoundingMode.HALF_UP))} €"
