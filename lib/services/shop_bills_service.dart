import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';
import 'shop_profile_service.dart';
import 'shop_stock_service.dart';

String generateBillNo([DateTime? at]) {
  final now = at ?? DateTime.now();
  final stamp =
      '${now.year.toString().substring(2)}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
  final rand = Random().nextInt(90) + 10;
  return 'RNX$stamp$rand';
}

class BillCustomer {
  final String name;
  final String? phone;
  final String? address;
  final String? gstin;

  const BillCustomer({
    required this.name,
    this.phone,
    this.address,
    this.gstin,
  });

  factory BillCustomer.fromMap(Map<String, dynamic>? m) {
    m ??= {};
    return BillCustomer(
      name: (m['name'] as String?)?.trim() ?? '',
      phone: m['phone'] as String?,
      address: m['address'] as String?,
      gstin: m['gstin'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'phone': phone?.trim(),
        'address': address?.trim(),
        'gstin': gstin?.trim(),
      };
}

class BillLineItem {
  final String? stockId;
  final String name;
  final String? category;
  final String? metalLabel;
  final int? karat;
  final String? barcode;
  final double grossWeight;
  final double netWeight;
  final double ratePerGram;
  final double makingCharge;
  final String makingType;
  final double wastagePercent;
  final double stoneCharge;
  final double otherCharge;
  final int qty;
  final double taxableAmount;
  final bool applyGst;
  final double? gstPercent;
  final double gstAmount;
  final double lineTotal;

  const BillLineItem({
    this.stockId,
    required this.name,
    this.category,
    this.metalLabel,
    this.karat,
    this.barcode,
    required this.grossWeight,
    required this.netWeight,
    required this.ratePerGram,
    required this.makingCharge,
    this.makingType = 'flat',
    required this.wastagePercent,
    required this.stoneCharge,
    required this.otherCharge,
    this.qty = 1,
    required this.taxableAmount,
    this.applyGst = false,
    this.gstPercent,
    required this.gstAmount,
    required this.lineTotal,
  });

  factory BillLineItem.compute({
    String? stockId,
    required String name,
    String? category,
    String? metalLabel,
    int? karat,
    String? barcode,
    required double grossWeight,
    required double netWeight,
    required double ratePerGram,
    required double makingCharge,
    String makingType = 'flat',
    required double wastagePercent,
    required double stoneCharge,
    required double otherCharge,
    int qty = 1,
    bool applyGst = false,
    double gstPercent = 0,
  }) {
    final breakdown = calculateStockPrice(
      netWeight: netWeight,
      shopRatePerGram: ratePerGram,
      wastagePercent: wastagePercent,
      makingChargeType: makingType,
      makingCharge: makingCharge,
      stoneCharge: stoneCharge,
      otherCharge: otherCharge,
    );
    final taxable = breakdown.total * qty;
    final gst = applyGst ? taxable * (gstPercent / 100) : 0.0;
    return BillLineItem(
      stockId: stockId,
      name: name,
      category: category,
      metalLabel: metalLabel,
      karat: karat,
      barcode: barcode?.trim().isEmpty == true ? null : barcode?.trim(),
      grossWeight: grossWeight,
      netWeight: netWeight,
      ratePerGram: ratePerGram,
      makingCharge: makingCharge,
      makingType: makingType,
      wastagePercent: wastagePercent,
      stoneCharge: stoneCharge,
      otherCharge: otherCharge,
      qty: qty,
      taxableAmount: taxable,
      applyGst: applyGst,
      gstPercent: applyGst ? gstPercent : null,
      gstAmount: gst,
      lineTotal: taxable + gst,
    );
  }

  factory BillLineItem.fromMap(Map<String, dynamic> m) {
    return BillLineItem(
      stockId: m['stockId'] as String?,
      name: (m['name'] as String?) ?? '',
      category: m['category'] as String?,
      metalLabel: m['metalLabel'] as String?,
      karat: (m['karat'] as num?)?.toInt(),
      barcode: m['barcode'] as String?,
      grossWeight: (m['grossWeight'] as num?)?.toDouble() ?? 0,
      netWeight: (m['netWeight'] as num?)?.toDouble() ?? 0,
      ratePerGram: (m['ratePerGram'] as num?)?.toDouble() ?? 0,
      makingCharge: (m['makingCharge'] as num?)?.toDouble() ?? 0,
      makingType: (m['makingType'] as String?) ?? 'flat',
      wastagePercent: (m['wastagePercent'] as num?)?.toDouble() ?? 0,
      stoneCharge: (m['stoneCharge'] as num?)?.toDouble() ?? 0,
      otherCharge: (m['otherCharge'] as num?)?.toDouble() ?? 0,
      qty: (m['qty'] as num?)?.toInt() ?? 1,
      taxableAmount: (m['taxableAmount'] as num?)?.toDouble() ?? 0,
      applyGst: m['applyGst'] as bool? ?? false,
      gstPercent: (m['gstPercent'] as num?)?.toDouble(),
      gstAmount: (m['gstAmount'] as num?)?.toDouble() ?? 0,
      lineTotal: (m['lineTotal'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'stockId': stockId,
        'name': name,
        'category': category,
        'metalLabel': metalLabel,
        'karat': karat,
        'barcode': barcode,
        'grossWeight': grossWeight,
        'netWeight': netWeight,
        'ratePerGram': ratePerGram,
        'makingCharge': makingCharge,
        'makingType': makingType,
        'wastagePercent': wastagePercent,
        'stoneCharge': stoneCharge,
        'otherCharge': otherCharge,
        'qty': qty,
        'taxableAmount': taxableAmount,
        'applyGst': applyGst,
        'gstPercent': gstPercent,
        'gstAmount': gstAmount,
        'lineTotal': lineTotal,
      };
}

class BillPayment {
  final double amount;
  final String mode;
  final DateTime? paidAt;
  final String? note;

  const BillPayment({
    required this.amount,
    required this.mode,
    this.paidAt,
    this.note,
  });

  factory BillPayment.fromMap(Map<String, dynamic> m) {
    return BillPayment(
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      mode: (m['mode'] as String?) ?? 'cash',
      paidAt: (m['paidAt'] as Timestamp?)?.toDate(),
      note: m['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'mode': mode,
        'paidAt': paidAt != null
            ? Timestamp.fromDate(paidAt!)
            : FieldValue.serverTimestamp(),
        'note': note,
      };
}

class BillTotals {
  final double taxable;
  final double gst;
  final double grandTotal;
  final double paidAmount;
  final double balance;

  const BillTotals({
    required this.taxable,
    required this.gst,
    required this.grandTotal,
    required this.paidAmount,
    required this.balance,
  });

  factory BillTotals.fromItems({
    required List<BillLineItem> items,
    required double paidAmount,
  }) {
    final taxable = items.fold<double>(0, (s, i) => s + i.taxableAmount);
    final gst = items.fold<double>(0, (s, i) => s + i.gstAmount);
    final grand = taxable + gst;
    final paid = paidAmount.clamp(0, double.infinity).toDouble();
    return BillTotals(
      taxable: taxable,
      gst: gst,
      grandTotal: grand,
      paidAmount: paid,
      balance: (grand - paid).clamp(0, double.infinity).toDouble(),
    );
  }

  factory BillTotals.fromMap(Map<String, dynamic>? m) {
    m ??= {};
    return BillTotals(
      taxable: (m['taxable'] as num?)?.toDouble() ?? 0,
      gst: (m['gst'] as num?)?.toDouble() ?? 0,
      grandTotal: (m['grandTotal'] as num?)?.toDouble() ?? 0,
      paidAmount: (m['paidAmount'] as num?)?.toDouble() ?? 0,
      balance: (m['balance'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'taxable': taxable,
        'gst': gst,
        'grandTotal': grandTotal,
        'paidAmount': paidAmount,
        'balance': balance,
      };
}

class BillShopSnapshot {
  final String? shopName;
  final String? phone;
  final String? address;
  final String? gstNumber;
  final String? tagline;

  const BillShopSnapshot({
    this.shopName,
    this.phone,
    this.address,
    this.gstNumber,
    this.tagline,
  });

  factory BillShopSnapshot.fromProfile(ShopProfile p, {String? gstNumber}) {
    final parts = [
      p.addressLine1,
      p.addressLine2,
      p.city,
      p.state,
      p.pincode,
    ].where((e) => e != null && e.trim().isNotEmpty).map((e) => e!.trim());
    return BillShopSnapshot(
      shopName: p.shopName,
      phone: p.phone ?? p.whatsapp,
      address: parts.isEmpty ? null : parts.join(', '),
      gstNumber: gstNumber,
      tagline: p.tagline,
    );
  }

  factory BillShopSnapshot.fromMap(Map<String, dynamic>? m) {
    m ??= {};
    return BillShopSnapshot(
      shopName: m['shopName'] as String?,
      phone: m['phone'] as String?,
      address: m['address'] as String?,
      gstNumber: m['gstNumber'] as String?,
      tagline: m['tagline'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'shopName': shopName,
        'phone': phone,
        'address': address,
        'gstNumber': gstNumber,
        'tagline': tagline,
      };
}

class ShopBill {
  final String billNo;
  final BillCustomer customer;
  final List<BillLineItem> items;
  final BillTotals totals;
  final String paymentStatus; // unpaid | partial | paid | cancelled
  final String? paymentMode; // cash | online | upi | card | mixed
  final List<BillPayment> payments;
  final String? notes;
  final BillShopSnapshot shopSnapshot;
  final DateTime? billedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ShopBill({
    required this.billNo,
    required this.customer,
    required this.items,
    required this.totals,
    required this.paymentStatus,
    this.paymentMode,
    this.payments = const [],
    this.notes,
    required this.shopSnapshot,
    this.billedAt,
    this.createdAt,
    this.updatedAt,
  });

  String get statusLabel {
    switch (paymentStatus) {
      case 'paid':
        return 'Paid';
      case 'partial':
        return 'Partial';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unpaid';
    }
  }

  static String statusFromPaid({
    required double grandTotal,
    required double paidAmount,
    String? forced,
  }) {
    if (forced == 'cancelled') return 'cancelled';
    if (paidAmount <= 0) return 'unpaid';
    if (paidAmount + 0.5 >= grandTotal) return 'paid';
    return 'partial';
  }

  factory ShopBill.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final itemsRaw = (d['items'] as List?) ?? const [];
    final paymentsRaw = (d['payments'] as List?) ?? const [];
    return ShopBill(
      billNo: (d['billNo'] as String?) ?? doc.id,
      customer: BillCustomer.fromMap(d['customer'] as Map<String, dynamic>?),
      items: itemsRaw
          .whereType<Map>()
          .map((e) => BillLineItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      totals: BillTotals.fromMap(d['totals'] as Map<String, dynamic>?),
      paymentStatus: (d['paymentStatus'] as String?) ?? 'unpaid',
      paymentMode: d['paymentMode'] as String?,
      payments: paymentsRaw
          .whereType<Map>()
          .map((e) => BillPayment.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      notes: d['notes'] as String?,
      shopSnapshot:
          BillShopSnapshot.fromMap(d['shopSnapshot'] as Map<String, dynamic>?),
      billedAt: (d['billedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    final map = <String, dynamic>{
      'billNo': billNo,
      'customer': customer.toMap(),
      'items': items.map((e) => e.toMap()).toList(),
      'totals': totals.toMap(),
      'paymentStatus': paymentStatus,
      'paymentMode': paymentMode,
      'payments': payments.map((e) => e.toMap()).toList(),
      'notes': notes?.trim(),
      'shopSnapshot': shopSnapshot.toMap(),
      'billedAt': billedAt != null
          ? Timestamp.fromDate(billedAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (includeCreatedAt) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }
}

class ShopBillsService {
  ShopBillsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _bills() =>
      _userRef()?.collection('bills');

  Stream<List<ShopBill>> watchBills() {
    final col = _bills();
    if (col == null) return Stream.value(const []);
    return col.orderBy('billedAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(ShopBill.fromDoc).toList(),
        );
  }

  Future<ShopBill?> getBill(String billNo) async {
    final col = _bills();
    if (col == null) return null;
    final snap = await col.doc(billNo).get();
    if (!snap.exists) return null;
    return ShopBill.fromDoc(snap);
  }

  Future<String> _uniqueBillNo() async {
    final col = _bills();
    if (col == null) throw Exception('Not signed in');
    for (var i = 0; i < 5; i++) {
      final no = generateBillNo();
      final existing = await col.doc(no).get();
      if (!existing.exists) return no;
    }
    return generateBillNo();
  }

  Future<ShopBill> createBill(ShopBill draft) async {
    final col = _bills();
    if (col == null) throw Exception('Not signed in');
    final billNo =
        draft.billNo.isNotEmpty ? draft.billNo : await _uniqueBillNo();
    final bill = ShopBill(
      billNo: billNo,
      customer: draft.customer,
      items: draft.items,
      totals: draft.totals,
      paymentStatus: draft.paymentStatus,
      paymentMode: draft.paymentMode,
      payments: draft.payments,
      notes: draft.notes,
      shopSnapshot: draft.shopSnapshot,
      billedAt: draft.billedAt ?? DateTime.now(),
    );
    await col.doc(billNo).set(bill.toMap(includeCreatedAt: true));
    return bill;
  }

  Future<void> updateBill(ShopBill bill) async {
    final col = _bills();
    if (col == null) throw Exception('Not signed in');
    await col.doc(bill.billNo).set(bill.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteBill(String billNo) async {
    final col = _bills();
    if (col == null) throw Exception('Not signed in');
    await col.doc(billNo).delete();
  }
}
