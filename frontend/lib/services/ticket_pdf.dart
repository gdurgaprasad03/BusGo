import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/booking.dart';
import '../models/payment_method.dart';
import '../utils/formatters.dart';

/// Builds the e-ticket as a real PDF and lets the user save or share it.
class TicketPdf {
  TicketPdf._();

  static String fileName(Booking b) => 'BusGo-ticket-${b.bookingReference}.pdf';

  /// Opens the system share / save sheet for the PDF.
  static Future<void> share(Booking booking) async {
    await Printing.sharePdf(bytes: await build(booking), filename: fileName(booking));
  }

  static Future<Uint8List> build(Booking b) async {
    final doc = pw.Document(title: 'BusGo e-ticket ${b.bookingReference}', author: 'BusGo (demo)');
    const blue = PdfColor.fromInt(0xFF1A5FE0);
    const grey = PdfColor.fromInt(0xFF5B6575);
    const lightGrey = PdfColor.fromInt(0xFFE3E8F1);

    pw.Widget label(String text) => pw.Text(text, style: const pw.TextStyle(fontSize: 8.5, color: grey));
    pw.Widget value(String text, {bool bold = false, double size = 11}) => pw.Text(text,
        style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal));
    pw.Widget row(String l, String v, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(l, style: const pw.TextStyle(fontSize: 10, color: grey)),
            value(v, bold: bold),
          ]),
        );

    final status = b.isCancelled ? 'CANCELLED' : (b.upcoming ? 'CONFIRMED' : 'COMPLETED');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: lightGrey), borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: const pw.BoxDecoration(
                color: blue,
                borderRadius: pw.BorderRadius.only(topLeft: pw.Radius.circular(10), topRight: pw.Radius.circular(10)),
              ),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('BusGo', style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.Text('BUS E-TICKET (DEMO)', style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('BOOKING ID / PNR', style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
                  pw.Text(b.bookingReference,
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
                  pw.Text(status, style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ]),
              ]),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(16),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                value(b.operatorName, bold: true, size: 15),
                pw.Text(b.busType.label, style: const pw.TextStyle(fontSize: 10, color: grey)),
                pw.SizedBox(height: 14),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    value(b.source, bold: true, size: 17),
                    pw.Text(Fmt.time(b.departureTime), style: pw.TextStyle(color: blue, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    label(Fmt.dmy(b.departureTime)),
                  ]),
                  pw.Text('${Fmt.duration(b.arrivalTime.difference(b.departureTime).inMinutes)}  >>>',
                      style: const pw.TextStyle(fontSize: 10, color: grey)),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    value(b.destination, bold: true, size: 17),
                    pw.Text(Fmt.time(b.arrivalTime), style: pw.TextStyle(color: blue, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    label(Fmt.dmy(b.arrivalTime)),
                  ]),
                ]),
                pw.SizedBox(height: 12),
                pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    label('BOARDING POINT'),
                    value(b.boardingPoint, bold: true),
                  ])),
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    label('DROPPING POINT'),
                    value(b.droppingPoint, bold: true),
                  ])),
                ]),
                pw.Divider(color: lightGrey, height: 28),
                pw.Row(children: [
                  pw.Expanded(flex: 5, child: label('PASSENGER')),
                  pw.Expanded(flex: 3, child: label('AGE / SEX')),
                  pw.Expanded(flex: 2, child: pw.Align(alignment: pw.Alignment.centerRight, child: label('SEAT'))),
                ]),
                pw.SizedBox(height: 4),
                for (final p in b.passengers)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Row(children: [
                      pw.Expanded(flex: 5, child: value(p.name, bold: true)),
                      pw.Expanded(flex: 3, child: value('${p.age} / ${p.gender[0]}')),
                      pw.Expanded(flex: 2, child: pw.Align(alignment: pw.Alignment.centerRight, child: value(p.seatNumber, bold: true))),
                    ]),
                  ),
                pw.Divider(color: lightGrey, height: 28),
                row('Payment mode', PaymentMethod.labelFor(b.paymentMethod)),
                row('Booked on', Fmt.dateTime(b.bookedAt)),
                row('Contact', '${b.contactPhone}  ${b.contactEmail}'),
                row('Total fare', Fmt.money(b.totalAmount), bold: true),
                if (b.isCancelled) row('Demo refund', Fmt.money(b.refundAmount ?? 0), bold: true),
                pw.SizedBox(height: 18),
                pw.Center(
                  child: pw.Column(children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: b.bookingReference,
                      width: 90,
                      height: 90,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Scan to verify: ${b.bookingReference}', style: const pw.TextStyle(fontSize: 8.5, color: grey)),
                  ]),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'Carry a valid photo ID. Reach the boarding point at least 15 minutes before departure.',
                  style: const pw.TextStyle(fontSize: 9, color: grey),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFFFF4E0), borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Text('DEMO TICKET - sample data, simulated payment. Not valid for travel.',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
    return doc.save();
  }
}
