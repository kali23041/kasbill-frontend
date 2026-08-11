import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'shop_girvi_service.dart';

enum GirviPrintFormat { thermal80, a4 }

class GirviPdfService {
  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs ',
    decimalDigits: 0,
  );

  static String formatLabel(GirviPrintFormat format) {
    switch (format) {
      case GirviPrintFormat.thermal80:
        return 'Thermal 80mm';
      case GirviPrintFormat.a4:
        return 'A4 Receipt';
    }
  }

  static PdfPageFormat _pageFormat(GirviPrintFormat format) {
    switch (format) {
      case GirviPrintFormat.thermal80:
        return const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 6 * PdfPageFormat.mm,
        );
      case GirviPrintFormat.a4:
        return PdfPageFormat.a4;
    }
  }

  static Future<Uint8List> buildPdf(
    ShopGirvi girvi,
    GirviPrintFormat format,
  ) async {
    final doc = pw.Document();
    final pageFormat = _pageFormat(format);
    final dateStr = DateFormat('d MMM yyyy').format(girvi.startedAt);
    final dueStr = DateFormat('d MMM yyyy').format(girvi.dueDate);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          if (format == GirviPrintFormat.thermal80) {
            return _thermal(girvi, dateStr, dueStr);
          }
          return _a4(girvi, dateStr, dueStr);
        },
      ),
    );
    return doc.save();
  }

  static Future<void> printGirvi(ShopGirvi girvi, GirviPrintFormat format) async {
    final bytes = await buildPdf(girvi, format);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: '${girvi.girviNo}_${format.name}',
    );
  }

  static Future<void> shareGirvi(ShopGirvi girvi, GirviPrintFormat format) async {
    final bytes = await buildPdf(girvi, format);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${girvi.girviNo}_${format.name}.pdf',
    );
  }

  static pw.Widget _thermal(ShopGirvi g, String dateStr, String dueStr) {
    const fs = 9.0;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          g.shopSnapshot.shopName ?? 'Ratnex Jewellers',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: fs + 3, fontWeight: pw.FontWeight.bold),
        ),
        if (g.shopSnapshot.address != null)
          pw.Text(
            g.shopSnapshot.address!,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: fs - 1),
          ),
        if (g.shopSnapshot.phone != null)
          pw.Text(
            'Ph: ${g.shopSnapshot.phone}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: fs - 1),
          ),
        pw.SizedBox(height: 6),
        pw.Text(
          'GIRVI / GOLD LOAN',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: fs + 1, fontWeight: pw.FontWeight.bold),
        ),
        pw.Divider(),
        pw.Text('No: ${g.girviNo}', style: const pw.TextStyle(fontSize: fs)),
        pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: fs - 1)),
        pw.Text('Due: $dueStr', style: const pw.TextStyle(fontSize: fs - 1)),
        pw.Text(
          'Customer: ${g.customer.name}',
          style: const pw.TextStyle(fontSize: fs),
        ),
        if (g.customer.phone != null)
          pw.Text('Ph: ${g.customer.phone}', style: const pw.TextStyle(fontSize: fs - 1)),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.BarcodeWidget(
            barcode: Barcode.qrCode(),
            data: g.girviNo,
            width: 56,
            height: 56,
            drawText: false,
          ),
        ),
        pw.Text(
          g.girviNo,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: fs - 1),
        ),
        pw.Divider(),
        for (final item in g.items) ...[
          pw.Text(
            item.name,
            style: pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${item.netWeight}g @ ${_currency.format(item.ratePerGram.round())}/g',
            style: const pw.TextStyle(fontSize: fs - 1),
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              _currency.format(item.appraisalValue.round()),
              style: const pw.TextStyle(fontSize: fs),
            ),
          ),
          pw.SizedBox(height: 3),
        ],
        pw.Divider(),
        _row('Appraisal', _currency.format(g.totals.appraisalValue.round()), fs),
        _row('Loan given', _currency.format(g.loanAmount.round()), fs),
        _row('Interest', '${g.interestRatePercent}% / mo × ${g.tenureMonths} mo', fs),
        _row(
          'Interest amt',
          _currency.format(g.totals.interestTillDue.round()),
          fs,
        ),
        _row(
          'AMOUNT DUE',
          _currency.format(g.totals.amountDue.round()),
          fs + 1,
          bold: true,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Thank you',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: fs),
        ),
      ],
    );
  }

  static pw.Widget _a4(ShopGirvi g, String dateStr, String dueStr) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    g.shopSnapshot.shopName ?? 'Ratnex Jewellers',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (g.shopSnapshot.address != null)
                    pw.Text(g.shopSnapshot.address!),
                  if (g.shopSnapshot.phone != null)
                    pw.Text('Phone: ${g.shopSnapshot.phone}'),
                  if (g.shopSnapshot.gstNumber != null)
                    pw.Text('GSTIN: ${g.shopSnapshot.gstNumber}'),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'GIRVI RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(g.girviNo),
                pw.Text('Start: $dateStr'),
                pw.Text('Due: $dueStr'),
                pw.SizedBox(height: 8),
                pw.BarcodeWidget(
                  barcode: Barcode.qrCode(),
                  data: g.girviNo,
                  width: 72,
                  height: 72,
                  drawText: false,
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Customer',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(g.customer.name),
              if (g.customer.phone != null) pw.Text(g.customer.phone!),
              if (g.customer.address != null) pw.Text(g.customer.address!),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: const ['Item', 'Metal', 'Net g', 'Rate', 'Appraisal'],
          data: [
            for (final i in g.items)
              [
                i.name,
                i.metalLabel ?? '—',
                i.netWeight.toStringAsFixed(3),
                _currency.format(i.ratePerGram.round()),
                _currency.format(i.appraisalValue.round()),
              ],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 240,
            child: pw.Column(
              children: [
                _row('Appraisal', _currency.format(g.totals.appraisalValue.round()), 11),
                _row('Loan given', _currency.format(g.loanAmount.round()), 11),
                _row(
                  'Interest (${g.interestRatePercent}% × ${g.tenureMonths} mo)',
                  _currency.format(g.totals.interestTillDue.round()),
                  11,
                ),
                pw.Divider(),
                _row(
                  'Amount due',
                  _currency.format(g.totals.amountDue.round()),
                  12,
                  bold: true,
                ),
              ],
            ),
          ),
        ),
        pw.Spacer(),
        pw.Text(
          'Pledge redeemable on or before due date against full settlement.',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  static pw.Widget _row(
    String label,
    String value,
    double fontSize, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
