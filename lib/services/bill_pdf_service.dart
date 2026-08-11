import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'shop_bills_service.dart';

enum BillPrintFormat { thermal58, thermal80, a4 }

class BillPdfService {
  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs ',
    decimalDigits: 0,
  );

  static PdfPageFormat _pageFormat(BillPrintFormat format) {
    switch (format) {
      case BillPrintFormat.thermal58:
        return const PdfPageFormat(
          58 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        );
      case BillPrintFormat.thermal80:
        return const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 6 * PdfPageFormat.mm,
        );
      case BillPrintFormat.a4:
        return PdfPageFormat.a4;
    }
  }

  static String formatLabel(BillPrintFormat format) {
    switch (format) {
      case BillPrintFormat.thermal58:
        return 'Thermal 58mm';
      case BillPrintFormat.thermal80:
        return 'Thermal 80mm';
      case BillPrintFormat.a4:
        return 'A4 Invoice';
    }
  }

  static Future<Uint8List> buildPdf(
    ShopBill bill,
    BillPrintFormat format,
  ) async {
    final doc = pw.Document();
    final pageFormat = _pageFormat(format);
    final isThermal = format != BillPrintFormat.a4;
    final date = bill.billedAt ?? bill.createdAt ?? DateTime.now();
    final dateStr = DateFormat('d MMM yyyy, h:mm a').format(date);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          if (isThermal) {
            return _thermalBody(bill, dateStr, format == BillPrintFormat.thermal58);
          }
          return _a4Body(bill, dateStr);
        },
      ),
    );

    return doc.save();
  }

  static Future<void> printBill(ShopBill bill, BillPrintFormat format) async {
    final bytes = await buildPdf(bill, format);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: '${bill.billNo}_${format.name}',
    );
  }

  static Future<void> shareBill(ShopBill bill, BillPrintFormat format) async {
    final bytes = await buildPdf(bill, format);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${bill.billNo}_${format.name}.pdf',
    );
  }

  static pw.Widget _thermalBody(ShopBill bill, String dateStr, bool narrow) {
    final fontSize = narrow ? 8.0 : 9.0;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          bill.shopSnapshot.shopName ?? 'Ratnex Jewellers',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: fontSize + 3, fontWeight: pw.FontWeight.bold),
        ),
        if (bill.shopSnapshot.tagline != null)
          pw.Text(
            bill.shopSnapshot.tagline!,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: fontSize),
          ),
        if (bill.shopSnapshot.address != null)
          pw.Text(
            bill.shopSnapshot.address!,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: fontSize - 1),
          ),
        if (bill.shopSnapshot.phone != null)
          pw.Text(
            'Ph: ${bill.shopSnapshot.phone}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: fontSize - 1),
          ),
        if (bill.shopSnapshot.gstNumber != null)
          pw.Text(
            'GSTIN: ${bill.shopSnapshot.gstNumber}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: fontSize - 1),
          ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.6),
        pw.Text('Bill: ${bill.billNo}', style: pw.TextStyle(fontSize: fontSize)),
        pw.Text(dateStr, style: pw.TextStyle(fontSize: fontSize - 1)),
        pw.Text(
          'Customer: ${bill.customer.name}',
          style: pw.TextStyle(fontSize: fontSize),
        ),
        if (bill.customer.phone != null)
          pw.Text(
            'Ph: ${bill.customer.phone}',
            style: pw.TextStyle(fontSize: fontSize - 1),
          ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.BarcodeWidget(
            barcode: Barcode.qrCode(),
            data: bill.billNo,
            width: narrow ? 48 : 56,
            height: narrow ? 48 : 56,
            drawText: false,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          bill.billNo,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: fontSize - 1),
        ),
        pw.Divider(thickness: 0.6),
        for (final item in bill.items) ...[
          pw.Text(
            item.name,
            style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${item.netWeight}g x ${_currency.format(item.ratePerGram.round())}',
            style: pw.TextStyle(fontSize: fontSize - 1),
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              _currency.format(item.lineTotal.round()),
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
          if (item.barcode != null && item.barcode!.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: Barcode.code128(),
                data: item.barcode!,
                width: narrow ? 110 : 140,
                height: narrow ? 28 : 34,
                drawText: false,
              ),
            ),
            pw.Text(
              item.barcode!,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: fontSize - 2),
            ),
          ],
          pw.SizedBox(height: 4),
        ],
        pw.Divider(thickness: 0.6),
        _row('Taxable', _currency.format(bill.totals.taxable.round()), fontSize),
        _row('GST', _currency.format(bill.totals.gst.round()), fontSize),
        _row(
          'TOTAL',
          _currency.format(bill.totals.grandTotal.round()),
          fontSize + 1,
          bold: true,
        ),
        _row('Paid', _currency.format(bill.totals.paidAmount.round()), fontSize),
        _row('Balance', _currency.format(bill.totals.balance.round()), fontSize),
        pw.SizedBox(height: 4),
        pw.Text(
          'Status: ${bill.statusLabel}${bill.paymentMode != null ? ' · ${bill.paymentMode}' : ''}',
          style: pw.TextStyle(fontSize: fontSize - 1),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Thank you',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: fontSize),
        ),
      ],
    );
  }

  static pw.Widget _a4Body(ShopBill bill, String dateStr) {
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
                    bill.shopSnapshot.shopName ?? 'Ratnex Jewellers',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (bill.shopSnapshot.tagline != null)
                    pw.Text(bill.shopSnapshot.tagline!),
                  if (bill.shopSnapshot.address != null)
                    pw.Text(bill.shopSnapshot.address!),
                  if (bill.shopSnapshot.phone != null)
                    pw.Text('Phone: ${bill.shopSnapshot.phone}'),
                  if (bill.shopSnapshot.gstNumber != null)
                    pw.Text('GSTIN: ${bill.shopSnapshot.gstNumber}'),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'TAX INVOICE',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Bill No: ${bill.billNo}'),
                pw.Text(dateStr),
                pw.Text('Status: ${bill.statusLabel}'),
                pw.SizedBox(height: 8),
                pw.BarcodeWidget(
                  barcode: Barcode.qrCode(),
                  data: bill.billNo,
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
                'Bill To',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(bill.customer.name),
              if (bill.customer.phone != null) pw.Text(bill.customer.phone!),
              if (bill.customer.address != null) pw.Text(bill.customer.address!),
              if (bill.customer.gstin != null)
                pw.Text('GSTIN: ${bill.customer.gstin}'),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: const ['Item', 'Net g', 'Rate', 'Qty', 'GST', 'Amount'],
          data: [
            for (final i in bill.items)
              [
                i.name,
                i.netWeight.toStringAsFixed(3),
                _currency.format(i.ratePerGram.round()),
                '${i.qty}',
                _currency.format(i.gstAmount.round()),
                _currency.format(i.lineTotal.round()),
              ],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.center,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 12),
        for (final item in bill.items)
          if (item.barcode != null && item.barcode!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      item.name,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: item.barcode!,
                    width: 140,
                    height: 32,
                    drawText: false,
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    item.barcode!,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 220,
            child: pw.Column(
              children: [
                _row('Taxable', _currency.format(bill.totals.taxable.round()), 11),
                _row('GST', _currency.format(bill.totals.gst.round()), 11),
                pw.Divider(),
                _row(
                  'Grand Total',
                  _currency.format(bill.totals.grandTotal.round()),
                  12,
                  bold: true,
                ),
                _row('Paid', _currency.format(bill.totals.paidAmount.round()), 11),
                _row(
                  'Balance',
                  _currency.format(bill.totals.balance.round()),
                  11,
                  bold: true,
                ),
              ],
            ),
          ),
        ),
        if (bill.paymentMode != null) ...[
          pw.SizedBox(height: 8),
          pw.Text('Payment mode: ${bill.paymentMode}'),
        ],
        if (bill.notes != null && bill.notes!.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Notes: ${bill.notes}'),
        ],
        pw.Spacer(),
        pw.Text(
          'Thank you for your business.',
          textAlign: pw.TextAlign.center,
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
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
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
