import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'shop_mod_service.dart';

enum ModPrintFormat { thermal80, a4 }

class ModPdfService {
  static final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs ',
    decimalDigits: 0,
  );

  static String formatLabel(ModPrintFormat format) {
    switch (format) {
      case ModPrintFormat.thermal80:
        return 'Thermal 80mm';
      case ModPrintFormat.a4:
        return 'A4 Receipt';
    }
  }

  static PdfPageFormat _pageFormat(ModPrintFormat format) {
    switch (format) {
      case ModPrintFormat.thermal80:
        return const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 6 * PdfPageFormat.mm,
        );
      case ModPrintFormat.a4:
        return PdfPageFormat.a4;
    }
  }

  static Future<Uint8List> buildPdf(ShopMod mod, ModPrintFormat format) async {
    final doc = pw.Document();
    final pageFormat = _pageFormat(format);
    final dateStr = DateFormat('d MMM yyyy').format(mod.paidAt);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          if (format == ModPrintFormat.thermal80) {
            return _thermal(mod, dateStr);
          }
          return _a4(mod, dateStr);
        },
      ),
    );
    return doc.save();
  }

  static Future<void> printMod(ShopMod mod, ModPrintFormat format) async {
    final bytes = await buildPdf(mod, format);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: '${mod.modNo}_${format.name}',
    );
  }

  static Future<void> shareMod(ShopMod mod, ModPrintFormat format) async {
    final bytes = await buildPdf(mod, format);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${mod.modNo}_${format.name}.pdf',
    );
  }

  static pw.Widget _thermal(ShopMod m, String dateStr) {
    const fs = 9.0;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          m.shopSnapshot.shopName ?? 'Ratnex Jewellers',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: fs + 3, fontWeight: pw.FontWeight.bold),
        ),
        if (m.shopSnapshot.address != null)
          pw.Text(
            m.shopSnapshot.address!,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: fs - 1),
          ),
        if (m.shopSnapshot.phone != null)
          pw.Text(
            'Ph: ${m.shopSnapshot.phone}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: fs - 1),
          ),
        pw.SizedBox(height: 6),
        pw.Text(
          'MOD / ORNAMENT PURCHASE',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: fs + 1, fontWeight: pw.FontWeight.bold),
        ),
        pw.Divider(),
        pw.Text('No: ${m.modNo}', style: const pw.TextStyle(fontSize: fs)),
        pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: fs - 1)),
        pw.Text(
          'Customer: ${m.customer.name}',
          style: const pw.TextStyle(fontSize: fs),
        ),
        if (m.customer.phone != null)
          pw.Text(
            'Ph: ${m.customer.phone}',
            style: const pw.TextStyle(fontSize: fs - 1),
          ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.BarcodeWidget(
            barcode: Barcode.qrCode(),
            data: m.modNo,
            width: 56,
            height: 56,
            drawText: false,
          ),
        ),
        pw.Text(
          m.modNo,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: fs - 1),
        ),
        pw.Divider(),
        for (final item in m.items) ...[
          pw.Text(
            item.name,
            style: pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${item.netWeight}g @ ${_currency.format(item.ratePerGram.round())}/g'
            '${item.metalLabel != null ? ' · ${item.metalLabel}' : ''}',
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
        _row('Appraisal', _currency.format(m.totals.appraisalValue.round()), fs),
        if (m.totals.makingDeduction > 0)
          _row(
            'Making (${m.deductionPercent}%)',
            '- ${_currency.format(m.totals.makingDeduction.round())}',
            fs,
          ),
        if (m.totals.stoneDeduction > 0)
          _row(
            'Stone ded.',
            '- ${_currency.format(m.totals.stoneDeduction.round())}',
            fs,
          ),
        if (m.totals.otherDeduction > 0)
          _row(
            'Other ded.',
            '- ${_currency.format(m.totals.otherDeduction.round())}',
            fs,
          ),
        _row(
          'PAID TO CUSTOMER',
          _currency.format(m.totals.purchaseAmount.round()),
          fs + 1,
          bold: true,
        ),
        _row('Payment', m.paymentModeLabel, fs),
        if (m.paymentRef != null && m.paymentRef!.isNotEmpty)
          _row('Ref', m.paymentRef!, fs),
        pw.SizedBox(height: 8),
        pw.Text(
          'Thank you',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: fs),
        ),
      ],
    );
  }

  static pw.Widget _a4(ShopMod m, String dateStr) {
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
                    m.shopSnapshot.shopName ?? 'Ratnex Jewellers',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (m.shopSnapshot.address != null)
                    pw.Text(m.shopSnapshot.address!),
                  if (m.shopSnapshot.phone != null)
                    pw.Text('Phone: ${m.shopSnapshot.phone}'),
                  if (m.shopSnapshot.gstNumber != null)
                    pw.Text('GSTIN: ${m.shopSnapshot.gstNumber}'),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'MOD PURCHASE',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(m.modNo),
                pw.Text('Date: $dateStr'),
                pw.Text(m.statusLabel),
                pw.SizedBox(height: 8),
                pw.BarcodeWidget(
                  barcode: Barcode.qrCode(),
                  data: m.modNo,
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
                'Seller / Customer',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(m.customer.name),
              if (m.customer.phone != null) pw.Text(m.customer.phone!),
              if (m.customer.address != null) pw.Text(m.customer.address!),
              if (m.idProofType != null)
                pw.Text(
                  'ID: ${m.idProofType}'
                  '${m.idProofNumber != null ? ' · ${m.idProofNumber}' : ''}',
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: const ['Item', 'Metal', 'Net g', 'Rate', 'Appraisal'],
          data: [
            for (final i in m.items)
              [
                i.name,
                i.metalLabel ?? '—',
                i.netWeight.toStringAsFixed(3),
                _currency.format(i.ratePerGram.round()),
                _currency.format(i.appraisalValue.round()),
              ],
          ],
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 260,
            child: pw.Column(
              children: [
                _row(
                  'Appraisal',
                  _currency.format(m.totals.appraisalValue.round()),
                  11,
                ),
                if (m.totals.makingDeduction > 0)
                  _row(
                    'Making (${m.deductionPercent}%)',
                    '- ${_currency.format(m.totals.makingDeduction.round())}',
                    11,
                  ),
                if (m.totals.stoneDeduction > 0)
                  _row(
                    'Stone deduction',
                    '- ${_currency.format(m.totals.stoneDeduction.round())}',
                    11,
                  ),
                if (m.totals.otherDeduction > 0)
                  _row(
                    'Other deduction',
                    '- ${_currency.format(m.totals.otherDeduction.round())}',
                    11,
                  ),
                pw.Divider(),
                _row(
                  'Paid to customer',
                  _currency.format(m.totals.purchaseAmount.round()),
                  12,
                  bold: true,
                ),
                _row('Payment', m.paymentModeLabel, 11),
                if (m.paymentRef != null && m.paymentRef!.isNotEmpty)
                  _row('Reference', m.paymentRef!, 11),
              ],
            ),
          ),
        ),
        pw.Spacer(),
        pw.Text(
          'Direct purchase of ornaments — no interest. Amount paid in full.',
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
