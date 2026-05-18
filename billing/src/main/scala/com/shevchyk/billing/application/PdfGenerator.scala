package com.shevchyk.billing.application

import com.lowagie.text.{List => _, Chunk => PdfChunk, *}
import com.lowagie.text.pdf.*
import com.lowagie.text.pdf.draw.LineSeparator
import com.shevchyk.billing.domain.{Invoice, InvoiceItem}
import com.shevchyk.core.domain.ClientCompany
import zio.*

import java.awt.Color
import java.io.{ByteArrayOutputStream, File, FileOutputStream}
import java.time.format.DateTimeFormatter

object PdfGenerator:

  private val dateFormatter = DateTimeFormatter.ofPattern("dd.MM.yyyy")

  private val colorPrimary = new Color(41, 98, 255)
  private val colorLight   = new Color(240, 245, 255)
  private val colorGrey    = new Color(100, 100, 100)
  private val colorBorder  = new Color(220, 220, 220)

  private val fontTitle     = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 20f, colorPrimary)
  private val fontHeading   = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11f, Color.BLACK)
  private val fontNormal    = FontFactory.getFont(FontFactory.HELVETICA, 10f, Color.BLACK)
  private val fontSmall     = FontFactory.getFont(FontFactory.HELVETICA, 8f, colorGrey)
  private val fontTableHead = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 9f, Color.WHITE)
  private val fontTableCell = FontFactory.getFont(FontFactory.HELVETICA, 9f, Color.BLACK)
  private val fontTotal     = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11f, colorPrimary)

  def generateBytes(invoice: Invoice, clientCompany: ClientCompany, companyName: String): Task[Array[Byte]] = ZIO
    .attempt {
      val out    = new ByteArrayOutputStream()
      val doc    = new Document(PageSize.A4, 50, 50, 60, 50)
      val writer = PdfWriter.getInstance(doc, out)
      doc.open()

      addHeader(doc, invoice, companyName)
      doc.add(PdfChunk.NEWLINE)
      addAddresses(doc, invoice, clientCompany, companyName)
      doc.add(PdfChunk.NEWLINE)
      addPeriodInfo(doc, invoice)
      doc.add(PdfChunk.NEWLINE)
      addItemsTable(doc, invoice.items)
      doc.add(PdfChunk.NEWLINE)
      addTotals(doc, invoice)
      invoice.notes.foreach { n =>
        doc.add(PdfChunk.NEWLINE)
        addNotes(doc, n)
      }
      addFooter(doc, invoice)

      doc.close()
      out.toByteArray
    }

  def generateToFile(invoice: Invoice, clientCompany: ClientCompany, companyName: String, path: String): Task[String] =
    generateBytes(invoice, clientCompany, companyName).flatMap { bytes =>
      ZIO.attempt {
        val file = new File(path)
        file.getParentFile.mkdirs()
        val fos  = new FileOutputStream(file)
        fos.write(bytes)
        fos.close()
        path
      }
    }

  private def addHeader(doc: Document, invoice: Invoice, companyName: String): Unit =
    val table = new PdfPTable(2)
    table.setWidthPercentage(100)
    table.setWidths(Array(3f, 2f))

    val titleCell = new PdfPCell(new Phrase(companyName, fontTitle))
    titleCell.setBorder(Rectangle.NO_BORDER)
    titleCell.setPaddingBottom(4)
    table.addCell(titleCell)

    val invCell = new PdfPCell()
    invCell.setBorder(Rectangle.NO_BORDER)
    invCell.setHorizontalAlignment(Element.ALIGN_RIGHT)
    invCell.addElement(new Phrase("RECHNUNG", fontHeading))
    invCell.addElement(new Phrase(invoice.number, fontTitle))
    table.addCell(invCell)

    doc.add(table)

    // separator line
    val line = new LineSeparator(1f, 100f, colorPrimary, Element.ALIGN_CENTER, 0f)
    doc.add(line)

  private def addAddresses(doc: Document, invoice: Invoice, clientCompany: ClientCompany, companyName: String): Unit =
    val table = new PdfPTable(2)
    table.setWidthPercentage(100)
    table.setWidths(Array(1f, 1f))

    val fromCell = new PdfPCell()
    fromCell.setBorder(Rectangle.NO_BORDER)
    fromCell.addElement(new Phrase("VON", fontSmall))
    fromCell.addElement(new Phrase(companyName, fontHeading))
    table.addCell(fromCell)

    val toCell = new PdfPCell()
    toCell.setBorder(Rectangle.NO_BORDER)
    toCell.addElement(new Phrase("AN", fontSmall))
    toCell.addElement(new Phrase(clientCompany.name, fontHeading))
    clientCompany.address.foreach(a => toCell.addElement(new Phrase(a, fontNormal)))
    clientCompany.email.foreach(e => toCell.addElement(new Phrase(e, fontNormal)))
    table.addCell(toCell)

    doc.add(table)

  private def addPeriodInfo(doc: Document, invoice: Invoice): Unit =
    val table = new PdfPTable(3)
    table.setWidthPercentage(60)
    table.setHorizontalAlignment(Element.ALIGN_LEFT)

    def infoCell(label: String, value: String): Unit =
      val lc = new PdfPCell(new Phrase(label, fontSmall))
      lc.setBackgroundColor(colorLight)
      lc.setBorderColor(colorBorder)
      lc.setPadding(6)
      table.addCell(lc)
      val vc = new PdfPCell(new Phrase(value, fontNormal))
      vc.setBorderColor(colorBorder)
      vc.setPadding(6)
      vc.setColspan(2)
      table.addCell(vc)

    infoCell("Rechnungsnr.", invoice.number)
    infoCell("Zeitraum", s"${invoice.periodFrom.format(dateFormatter)} – ${invoice.periodTo.format(dateFormatter)}")
    invoice.dueDate.foreach(d => infoCell("Fällig am", d.format(dateFormatter)))

    doc.add(table)

  private def addItemsTable(doc: Document, items: scala.collection.immutable.List[InvoiceItem]): Unit =
    val table = new PdfPTable(5)
    table.setWidthPercentage(100)
    table.setWidths(Array(1.5f, 5f, 1f, 2f, 2f))

    def headerCell(text: String, align: Int = Element.ALIGN_LEFT): PdfPCell =
      val c = new PdfPCell(new Phrase(text, fontTableHead))
      c.setBackgroundColor(colorPrimary)
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
      val bg = if i % 2 == 0 then Color.WHITE else new Color(248, 248, 252)

      def dataCell(text: String, align: Int = Element.ALIGN_LEFT): PdfPCell =
        val c = new PdfPCell(new Phrase(text, fontTableCell))
        c.setBackgroundColor(bg)
        c.setBorderColor(colorBorder)
        c.setBorderWidth(0.5f)
        c.setPadding(7)
        c.setHorizontalAlignment(align)
        c

      val date = item.createdAt.atOffset(java.time.ZoneOffset.UTC).toLocalDate.format(dateFormatter)
      table.addCell(dataCell(date))
      table.addCell(dataCell(item.description))
      table.addCell(dataCell(item.quantity.setScale(0, BigDecimal.RoundingMode.HALF_UP).toString, Element.ALIGN_CENTER))
      table.addCell(dataCell(formatMoney(item.unitPrice), Element.ALIGN_RIGHT))
      table.addCell(dataCell(formatMoney(item.total), Element.ALIGN_RIGHT))
    }

    doc.add(table)

  private def addTotals(doc: Document, invoice: Invoice): Unit =
    val table = new PdfPTable(2)
    table.setWidthPercentage(40)
    table.setHorizontalAlignment(Element.ALIGN_RIGHT)

    def totalRow(label: String, value: String, bold: Boolean = false): Unit =
      val f  = if bold then fontTotal else fontNormal
      val lc = new PdfPCell(new Phrase(label, f))
      lc.setBorderColor(colorBorder)
      lc.setPadding(6)
      if bold then lc.setBackgroundColor(colorLight)
      table.addCell(lc)
      val vc = new PdfPCell(new Phrase(value, f))
      vc.setBorderColor(colorBorder)
      vc.setPadding(6)
      vc.setHorizontalAlignment(Element.ALIGN_RIGHT)
      if bold then vc.setBackgroundColor(colorLight)
      table.addCell(vc)

    totalRow("Zwischensumme", formatMoney(invoice.subtotalAmount))
    if invoice.taxRate > 0 then totalRow(s"MwSt. ${invoice.taxRate}%", formatMoney(invoice.taxAmount))
    totalRow(s"GESAMTBETRAG (${invoice.currency})", formatMoney(invoice.totalAmount), bold = true)

    doc.add(table)

  private def addNotes(doc: Document, notes: String): Unit =
    doc.add(new Phrase("Anmerkungen", fontHeading))
    doc.add(PdfChunk.NEWLINE)
    doc.add(new Phrase(notes, fontNormal))

  private def addFooter(doc: Document, invoice: Invoice): Unit =
    doc.add(PdfChunk.NEWLINE)
    doc.add(new LineSeparator(0.5f, 100f, colorBorder, Element.ALIGN_CENTER, 0f))
    doc.add(new Phrase(s"Generiert am ${java.time.LocalDate.now().format(dateFormatter)}", fontSmall))

  private def formatMoney(amount: BigDecimal): String = f"${amount.setScale(2, BigDecimal.RoundingMode.HALF_UP)}%.2f €"
