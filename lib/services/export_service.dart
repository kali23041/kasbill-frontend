import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/ratnex_format.dart';
import 'shop_bills_service.dart';
import 'shop_customers_service.dart';
import 'shop_girvi_service.dart';
import 'shop_karigar_service.dart';
import 'shop_ledger_service.dart';
import 'shop_mod_service.dart';
import 'shop_stock_service.dart';

class ExportResult {
  final String path;
  final String filename;
  final int rowCount;

  const ExportResult({
    required this.path,
    required this.filename,
    required this.rowCount,
  });
}

/// CSV and GST exports. Shop owners do not trust cloud-only — being able to
/// hand their CA a file is often what closes the sale.
class ExportService {
  ExportService._();

  static final _fileStamp = DateFormat('yyyyMMdd_HHmm');

  static Future<ExportResult> _write(
    String baseName,
    List<List<dynamic>> rows,
  ) async {
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final filename = '${baseName}_${_fileStamp.format(DateTime.now())}.csv';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csv);
    return ExportResult(
      path: file.path,
      filename: filename,
      // Header row is not data.
      rowCount: rows.isEmpty ? 0 : rows.length - 1,
    );
  }

  static Future<void> share(ExportResult result, {String? subject}) async {
    await Share.shareXFiles(
      [XFile(result.path, mimeType: 'text/csv')],
      subject: subject ?? result.filename,
    );
  }

  static String _d(DateTime? d) =>
      d == null ? '' : DateFormat('dd-MM-yyyy').format(d);

  static String _dt(DateTime? d) =>
      d == null ? '' : DateFormat('dd-MM-yyyy HH:mm').format(d);

  // ---- Bills ---------------------------------------------------------------

  static Future<ExportResult> bills(List<ShopBill> bills) async {
    final rows = <List<dynamic>>[
      [
        'Bill No', 'Date', 'Customer', 'Phone', 'GSTIN', 'Items',
        'Gross Wt (g)', 'Net Wt (g)', 'Taxable', 'GST', 'Grand Total',
        'Paid', 'Balance', 'Status', 'Payment Mode', 'Notes',
      ],
    ];
    for (final b in bills) {
      final grossWt = b.items.fold<double>(
        0,
        (s, i) => s + i.grossWeight * i.qty,
      );
      final netWt = b.items.fold<double>(0, (s, i) => s + i.netWeight * i.qty);
      rows.add([
        b.billNo,
        _d(b.billedAt),
        b.customer.name,
        b.customer.phone ?? '',
        b.customer.gstin ?? '',
        b.items.length,
        grossWt.toStringAsFixed(3),
        netWt.toStringAsFixed(3),
        b.totals.taxable.toStringAsFixed(2),
        b.totals.gst.toStringAsFixed(2),
        b.totals.grandTotal.toStringAsFixed(2),
        b.totals.paidAmount.toStringAsFixed(2),
        b.totals.balance.toStringAsFixed(2),
        b.statusLabel,
        b.paymentMode ?? '',
        b.notes ?? '',
      ]);
    }
    return _write('ratnex_bills', rows);
  }

  /// One row per line item — what a CA actually wants for reconciliation.
  static Future<ExportResult> billItems(List<ShopBill> bills) async {
    final rows = <List<dynamic>>[
      [
        'Bill No', 'Date', 'Customer', 'Item', 'Category', 'Metal', 'Karat',
        'HSN', 'Qty', 'Gross Wt', 'Net Wt', 'Rate/g', 'Making', 'Making Type',
        'Wastage %', 'Stone', 'Other', 'Taxable', 'GST %', 'GST Amt', 'Total',
      ],
    ];
    for (final b in bills) {
      for (final i in b.items) {
        rows.add([
          b.billNo,
          _d(b.billedAt),
          b.customer.name,
          i.name,
          i.category ?? '',
          i.metalLabel ?? '',
          i.karat ?? '',
          RatnexHsn.forMetalType(i.metalLabel, categoryName: i.category),
          i.qty,
          i.grossWeight.toStringAsFixed(3),
          i.netWeight.toStringAsFixed(3),
          i.ratePerGram.toStringAsFixed(2),
          i.makingCharge.toStringAsFixed(2),
          i.makingType,
          i.wastagePercent.toStringAsFixed(2),
          i.stoneCharge.toStringAsFixed(2),
          i.otherCharge.toStringAsFixed(2),
          i.taxableAmount.toStringAsFixed(2),
          i.gstPercent?.toStringAsFixed(2) ?? '0',
          i.gstAmount.toStringAsFixed(2),
          i.lineTotal.toStringAsFixed(2),
        ]);
      }
    }
    return _write('ratnex_bill_items', rows);
  }

  // ---- GST -----------------------------------------------------------------

  /// GSTR-1 B2B section: invoices raised to customers who gave a GSTIN.
  static Future<ExportResult> gstr1B2B(
    List<ShopBill> bills, {
    required String stateCode,
  }) async {
    final rows = <List<dynamic>>[
      [
        'GSTIN/UIN of Recipient', 'Receiver Name', 'Invoice Number',
        'Invoice date', 'Invoice Value', 'Place Of Supply', 'Reverse Charge',
        'Applicable % of Tax Rate', 'Invoice Type', 'E-Commerce GSTIN',
        'Rate', 'Taxable Value', 'Cess Amount',
      ],
    ];
    for (final b in bills) {
      final gstin = b.customer.gstin?.trim() ?? '';
      if (gstin.isEmpty) continue;
      if (b.paymentStatus == 'cancelled') continue;
      // GSTR-1 wants one row per tax rate on the invoice.
      final byRate = <double, double>{};
      for (final i in b.items) {
        final rate = i.applyGst ? (i.gstPercent ?? 0) : 0;
        byRate[rate.toDouble()] =
            (byRate[rate.toDouble()] ?? 0) + i.taxableAmount;
      }
      byRate.forEach((rate, taxable) {
        rows.add([
          gstin,
          b.customer.name,
          b.billNo,
          _d(b.billedAt),
          b.totals.grandTotal.toStringAsFixed(2),
          stateCode,
          'N',
          '',
          'Regular B2B',
          '',
          rate.toStringAsFixed(2),
          taxable.toStringAsFixed(2),
          '',
        ]);
      });
    }
    return _write('gstr1_b2b', rows);
  }

  /// GSTR-1 B2CS: everything else, summarised by rate.
  static Future<ExportResult> gstr1B2CS(
    List<ShopBill> bills, {
    required String stateCode,
  }) async {
    final byRate = <double, double>{};
    for (final b in bills) {
      if ((b.customer.gstin?.trim() ?? '').isNotEmpty) continue;
      if (b.paymentStatus == 'cancelled') continue;
      for (final i in b.items) {
        final rate = (i.applyGst ? (i.gstPercent ?? 0) : 0).toDouble();
        byRate[rate] = (byRate[rate] ?? 0) + i.taxableAmount;
      }
    }
    final rows = <List<dynamic>>[
      [
        'Type', 'Place Of Supply', 'Applicable % of Tax Rate', 'Rate',
        'Taxable Value', 'Cess Amount', 'E-Commerce GSTIN',
      ],
    ];
    byRate.forEach((rate, taxable) {
      rows.add([
        'OE',
        stateCode,
        '',
        rate.toStringAsFixed(2),
        taxable.toStringAsFixed(2),
        '',
        '',
      ]);
    });
    return _write('gstr1_b2cs', rows);
  }

  /// HSN-wise summary — a mandatory table in GSTR-1.
  static Future<ExportResult> hsnSummary(List<ShopBill> bills) async {
    final agg = <String, _HsnRow>{};
    for (final b in bills) {
      if (b.paymentStatus == 'cancelled') continue;
      for (final i in b.items) {
        final hsn =
            RatnexHsn.forMetalType(i.metalLabel, categoryName: i.category);
        final row = agg.putIfAbsent(hsn, () => _HsnRow(hsn));
        row.quantity += i.qty;
        row.weight += i.netWeight * i.qty;
        row.taxable += i.taxableAmount;
        row.tax += i.gstAmount;
      }
    }
    final rows = <List<dynamic>>[
      [
        'HSN', 'Description', 'UQC', 'Total Quantity', 'Total Weight (g)',
        'Total Value', 'Taxable Value', 'Integrated Tax', 'Central Tax',
        'State/UT Tax', 'Cess',
      ],
    ];
    for (final r in agg.values) {
      rows.add([
        r.hsn,
        _hsnDescription(r.hsn),
        'GMS',
        r.quantity,
        r.weight.toStringAsFixed(3),
        (r.taxable + r.tax).toStringAsFixed(2),
        r.taxable.toStringAsFixed(2),
        '0.00',
        (r.tax / 2).toStringAsFixed(2),
        (r.tax / 2).toStringAsFixed(2),
        '0.00',
      ]);
    }
    return _write('gstr1_hsn', rows);
  }

  static String _hsnDescription(String hsn) {
    switch (hsn) {
      case RatnexHsn.looseStone:
        return 'Precious/semi-precious stones';
      case RatnexHsn.bullionGold:
        return 'Gold, unwrought or semi-manufactured';
      case RatnexHsn.bullionSilver:
        return 'Silver, unwrought or semi-manufactured';
      case RatnexHsn.coin:
        return 'Coin';
      default:
        return 'Articles of jewellery of precious metal';
    }
  }

  // ---- Stock, customers, udhaar, karigar -----------------------------------

  static Future<ExportResult> stock(List<StockItem> items) async {
    final rows = <List<dynamic>>[
      [
        'Item', 'SKU', 'HUID', 'Barcode', 'Category', 'Metal', 'Karat',
        'Gross Wt', 'Net Wt', 'Stone Wt', 'Wastage %', 'Making Type', 'Making',
        'Stone Chg', 'Other Chg', 'Qty', 'Unit', 'Rate/g', 'Unit Value',
        'Line Value', 'Status', 'Added On', 'Updated On',
      ],
    ];
    for (final s in items) {
      rows.add([
        s.name,
        s.sku ?? '',
        s.huid ?? '',
        s.barcode ?? '',
        s.categoryName,
        s.metalLabel,
        s.karat ?? '',
        s.grossWeight.toStringAsFixed(3),
        s.netWeight.toStringAsFixed(3),
        s.stoneWeight.toStringAsFixed(3),
        s.wastagePercent.toStringAsFixed(2),
        s.makingChargeType,
        s.makingCharge.toStringAsFixed(2),
        s.stoneCharge.toStringAsFixed(2),
        s.otherCharge.toStringAsFixed(2),
        s.quantity,
        s.unit,
        s.shopRatePerGram.toStringAsFixed(2),
        s.addedUnitValue.toStringAsFixed(2),
        s.addedLineValue.toStringAsFixed(2),
        s.statusLabel,
        _d(s.createdAt),
        _d(s.updatedAt),
      ]);
    }
    return _write('ratnex_stock', rows);
  }

  static Future<ExportResult> customers(
    List<ShopCustomer> customers, {
    Map<String, UdhaarAccount> udhaarByPhone = const {},
  }) async {
    final rows = <List<dynamic>>[
      [
        'Name', 'Phone', 'Address', 'GSTIN', 'Bills', 'Outstanding',
        'First Seen', 'Last Updated',
      ],
    ];
    for (final c in customers) {
      rows.add([
        c.name,
        c.phone,
        c.address ?? '',
        c.gstin ?? '',
        c.billCount,
        (udhaarByPhone[c.phoneId]?.outstanding ?? 0).toStringAsFixed(2),
        _d(c.createdAt),
        _d(c.updatedAt),
      ]);
    }
    return _write('ratnex_customers', rows);
  }

  static Future<ExportResult> udhaar(List<UdhaarAccount> accounts) async {
    final rows = <List<dynamic>>[
      [
        'Name', 'Phone', 'Outstanding', 'Total Given', 'Total Collected',
        'Written Off', 'Oldest Due', 'Days Overdue', 'Last Activity',
      ],
    ];
    for (final a in accounts) {
      rows.add([
        a.name,
        a.phone,
        a.outstanding.toStringAsFixed(2),
        a.totalCredit.toStringAsFixed(2),
        a.totalPaid.toStringAsFixed(2),
        a.writtenOff.toStringAsFixed(2),
        _d(a.oldestDueAt),
        a.daysOverdue,
        _dt(a.lastActivityAt),
      ]);
    }
    return _write('ratnex_udhaar', rows);
  }

  static Future<ExportResult> girvi(List<ShopGirvi> loans) async {
    final rows = <List<dynamic>>[
      [
        'Girvi No', 'Customer', 'Phone', 'Started', 'Due', 'Items',
        'Appraisal', 'Loan', 'Interest %', 'Tenure (m)', 'Interest',
        'Amount Due', 'Paid', 'Balance', 'Status',
      ],
    ];
    for (final g in loans) {
      rows.add([
        g.girviNo,
        g.customer.name,
        g.customer.phone ?? '',
        _d(g.startedAt),
        _d(g.dueDate),
        g.items.length,
        g.totals.appraisalValue.toStringAsFixed(2),
        g.loanAmount.toStringAsFixed(2),
        g.interestRatePercent.toStringAsFixed(2),
        g.tenureMonths,
        g.totals.interestTillDue.toStringAsFixed(2),
        g.totals.amountDue.toStringAsFixed(2),
        g.totals.paidAmount.toStringAsFixed(2),
        g.totals.balance.toStringAsFixed(2),
        g.status,
      ]);
    }
    return _write('ratnex_girvi', rows);
  }

  static Future<ExportResult> mod(List<ShopMod> purchases) async {
    final rows = <List<dynamic>>[
      [
        'MOD No', 'Customer', 'Phone', 'Date', 'Items', 'Gross Wt', 'Net Wt',
        'Appraisal', 'Deduction %', 'Paid Out', 'Mode', 'ID Proof', 'Status',
      ],
    ];
    for (final m in purchases) {
      final gross = m.items.fold<double>(0, (s, i) => s + i.grossWeight);
      final net = m.items.fold<double>(0, (s, i) => s + i.netWeight);
      rows.add([
        m.modNo,
        m.customer.name,
        m.customer.phone ?? '',
        _d(m.paidAt),
        m.items.length,
        gross.toStringAsFixed(3),
        net.toStringAsFixed(3),
        m.totals.appraisalValue.toStringAsFixed(2),
        m.deductionPercent.toStringAsFixed(2),
        m.totals.purchaseAmount.toStringAsFixed(2),
        m.paymentMode,
        m.idProofType == null
            ? ''
            : '${m.idProofType} ${RatnexFormat.maskId(m.idProofNumber)}',
        m.status,
      ]);
    }
    return _write('ratnex_mod', rows);
  }

  static Future<ExportResult> karigars(List<Karigar> list) async {
    final rows = <List<dynamic>>[
      [
        'Name', 'Phone', 'Specialty', 'Issued (g)', 'Received (g)',
        'With Karigar (g)', 'Wastage %', 'Allowed %', 'Labour Due',
        'Labour Paid', 'Balance', 'Status',
      ],
    ];
    for (final k in list) {
      rows.add([
        k.name,
        k.phone ?? '',
        k.specialty ?? '',
        k.issuedWeight.toStringAsFixed(3),
        k.receivedWeight.toStringAsFixed(3),
        k.outstandingWeight.toStringAsFixed(3),
        k.wastagePercent.toStringAsFixed(2),
        k.allowedWastagePercent.toStringAsFixed(2),
        k.labourDue.toStringAsFixed(2),
        k.labourPaid.toStringAsFixed(2),
        k.labourBalance.toStringAsFixed(2),
        k.status,
      ]);
    }
    return _write('ratnex_karigars', rows);
  }
}

class _HsnRow {
  _HsnRow(this.hsn);

  final String hsn;
  int quantity = 0;
  double weight = 0;
  double taxable = 0;
  double tax = 0;
}
