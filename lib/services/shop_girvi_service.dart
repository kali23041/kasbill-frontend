import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';
import 'shop_bills_service.dart';

String generateGirviNo([DateTime? at]) {
  final now = at ?? DateTime.now();
  final stamp =
      '${now.year.toString().substring(2)}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
  final rand = Random().nextInt(90) + 10;
  return 'GRV$stamp$rand';
}

double appraisalFor({
  required double netWeight,
  required double ratePerGram,
}) =>
    netWeight * ratePerGram;

/// Simple monthly interest; months = days/30 for prorated accrual.
double interestFor({
  required double loanAmount,
  required double ratePercentPerMonth,
  required double months,
}) {
  if (loanAmount <= 0 || ratePercentPerMonth <= 0 || months <= 0) return 0;
  return loanAmount * (ratePercentPerMonth / 100) * months;
}

double monthsBetween(DateTime from, DateTime to) {
  final days = to.difference(from).inDays;
  if (days <= 0) return 0;
  return days / 30.0;
}

class GirviItem {
  final String name;
  final String? metalLabel;
  final int? karat;
  final double grossWeight;
  final double netWeight;
  final double ratePerGram;
  final double appraisalValue;
  final String? imageBase64;
  final String? imageMime;
  final String? notes;

  const GirviItem({
    required this.name,
    this.metalLabel,
    this.karat,
    required this.grossWeight,
    required this.netWeight,
    required this.ratePerGram,
    required this.appraisalValue,
    this.imageBase64,
    this.imageMime,
    this.notes,
  });

  factory GirviItem.compute({
    required String name,
    String? metalLabel,
    int? karat,
    required double grossWeight,
    required double netWeight,
    required double ratePerGram,
    String? imageBase64,
    String? imageMime,
    String? notes,
  }) {
    return GirviItem(
      name: name.trim(),
      metalLabel: metalLabel,
      karat: karat,
      grossWeight: grossWeight,
      netWeight: netWeight,
      ratePerGram: ratePerGram,
      appraisalValue: appraisalFor(
        netWeight: netWeight,
        ratePerGram: ratePerGram,
      ),
      imageBase64: imageBase64,
      imageMime: imageMime,
      notes: notes,
    );
  }

  factory GirviItem.fromMap(Map<String, dynamic> m) {
    return GirviItem(
      name: (m['name'] as String?) ?? '',
      metalLabel: m['metalLabel'] as String?,
      karat: (m['karat'] as num?)?.toInt(),
      grossWeight: (m['grossWeight'] as num?)?.toDouble() ?? 0,
      netWeight: (m['netWeight'] as num?)?.toDouble() ?? 0,
      ratePerGram: (m['ratePerGram'] as num?)?.toDouble() ?? 0,
      appraisalValue: (m['appraisalValue'] as num?)?.toDouble() ?? 0,
      imageBase64: m['imageBase64'] as String?,
      imageMime: m['imageMime'] as String?,
      notes: m['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'metalLabel': metalLabel,
        'karat': karat,
        'grossWeight': grossWeight,
        'netWeight': netWeight,
        'ratePerGram': ratePerGram,
        'appraisalValue': appraisalValue,
        'imageBase64': imageBase64,
        'imageMime': imageMime,
        'notes': notes,
      };
}

class GirviPayment {
  final double amount;
  final DateTime? paidAt;
  final String? note;

  const GirviPayment({
    required this.amount,
    this.paidAt,
    this.note,
  });

  factory GirviPayment.fromMap(Map<String, dynamic> m) {
    return GirviPayment(
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      paidAt: (m['paidAt'] as Timestamp?)?.toDate(),
      note: m['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'paidAt': paidAt != null
            ? Timestamp.fromDate(paidAt!)
            : FieldValue.serverTimestamp(),
        'note': note,
      };
}

class GirviTotals {
  final double appraisalValue;
  final double loanAmount;
  final double interestTillDue;
  final double amountDue;
  final double paidAmount;
  final double balance;

  const GirviTotals({
    required this.appraisalValue,
    required this.loanAmount,
    required this.interestTillDue,
    required this.amountDue,
    required this.paidAmount,
    required this.balance,
  });

  factory GirviTotals.compute({
    required List<GirviItem> items,
    required double loanAmount,
    required double interestRatePercent,
    required int tenureMonths,
    double paidAmount = 0,
  }) {
    final appraisal = items.fold<double>(0, (s, i) => s + i.appraisalValue);
    final interest = interestFor(
      loanAmount: loanAmount,
      ratePercentPerMonth: interestRatePercent,
      months: tenureMonths.toDouble(),
    );
    final due = loanAmount + interest;
    final paid = paidAmount.clamp(0, double.infinity).toDouble();
    return GirviTotals(
      appraisalValue: appraisal,
      loanAmount: loanAmount,
      interestTillDue: interest,
      amountDue: due,
      paidAmount: paid,
      balance: (due - paid).clamp(0, double.infinity).toDouble(),
    );
  }

  factory GirviTotals.fromMap(Map<String, dynamic>? m) {
    m ??= {};
    return GirviTotals(
      appraisalValue: (m['appraisalValue'] as num?)?.toDouble() ?? 0,
      loanAmount: (m['loanAmount'] as num?)?.toDouble() ?? 0,
      interestTillDue: (m['interestTillDue'] as num?)?.toDouble() ?? 0,
      amountDue: (m['amountDue'] as num?)?.toDouble() ?? 0,
      paidAmount: (m['paidAmount'] as num?)?.toDouble() ?? 0,
      balance: (m['balance'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'appraisalValue': appraisalValue,
        'loanAmount': loanAmount,
        'interestTillDue': interestTillDue,
        'amountDue': amountDue,
        'paidAmount': paidAmount,
        'balance': balance,
      };
}

class ShopGirvi {
  final String girviNo;
  final BillCustomer customer;
  final List<GirviItem> items;
  final double loanAmount;
  final double interestRatePercent;
  final int tenureMonths;
  final DateTime startedAt;
  final DateTime dueDate;
  final String status; // active | closed | overdue
  final GirviTotals totals;
  final List<GirviPayment> payments;
  final String disbursementMode; // cash | upi | bank | other

  /// KYC on the borrower. Pawn lending is regulated, so the shop should be
  /// able to show who it lent against. Null on loans written before this.
  final String? idProofType; // aadhaar | pan | voter | driving | passport
  final String? idProofNumber;
  final String? notes;
  final BillShopSnapshot shopSnapshot;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasKyc =>
      (idProofType?.trim().isNotEmpty ?? false) &&
      (idProofNumber?.trim().isNotEmpty ?? false);

  const ShopGirvi({
    required this.girviNo,
    required this.customer,
    required this.items,
    required this.loanAmount,
    required this.interestRatePercent,
    required this.tenureMonths,
    required this.startedAt,
    required this.dueDate,
    required this.status,
    required this.totals,
    this.payments = const [],
    this.disbursementMode = 'cash',
    this.idProofType,
    this.idProofNumber,
    this.notes,
    required this.shopSnapshot,
    this.createdAt,
    this.updatedAt,
  });

  String get disbursementModeLabel {
    switch (disbursementMode) {
      case 'upi':
        return 'UPI';
      case 'bank':
        return 'Bank';
      case 'other':
        return 'Other';
      default:
        return 'Cash';
    }
  }

  String get statusLabel {
    switch (effectiveStatus) {
      case 'closed':
        return 'Closed';
      case 'overdue':
        return 'Overdue';
      default:
        return 'Active';
    }
  }

  /// Live status: closed stays closed; else overdue if past due.
  String get effectiveStatus {
    if (status == 'closed') return 'closed';
    final today = DateTime.now();
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final nowDay = DateTime(today.year, today.month, today.day);
    if (nowDay.isAfter(dueDay)) return 'overdue';
    return 'active';
  }

  double get interestSoFar => interestFor(
        loanAmount: loanAmount,
        ratePercentPerMonth: interestRatePercent,
        months: monthsBetween(startedAt, DateTime.now()),
      );

  double get amountDueSoFar => loanAmount + interestSoFar;

  factory ShopGirvi.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ShopGirvi(
      girviNo: (d['girviNo'] as String?) ?? doc.id,
      customer: BillCustomer.fromMap(d['customer'] as Map<String, dynamic>?),
      items: ((d['items'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => GirviItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      loanAmount: (d['loanAmount'] as num?)?.toDouble() ?? 0,
      interestRatePercent: (d['interestRatePercent'] as num?)?.toDouble() ?? 0,
      tenureMonths: (d['tenureMonths'] as num?)?.toInt() ?? 1,
      startedAt: (d['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (d['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: (d['status'] as String?) ?? 'active',
      totals: GirviTotals.fromMap(d['totals'] as Map<String, dynamic>?),
      payments: ((d['payments'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => GirviPayment.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      disbursementMode: (d['disbursementMode'] as String?) ?? 'cash',
      idProofType: d['idProofType'] as String?,
      idProofNumber: d['idProofNumber'] as String?,
      notes: d['notes'] as String?,
      shopSnapshot:
          BillShopSnapshot.fromMap(d['shopSnapshot'] as Map<String, dynamic>?),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    final map = <String, dynamic>{
      'girviNo': girviNo,
      'customer': customer.toMap(),
      'items': items.map((e) => e.toMap()).toList(),
      'loanAmount': loanAmount,
      'interestRatePercent': interestRatePercent,
      'tenureMonths': tenureMonths,
      'startedAt': Timestamp.fromDate(startedAt),
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status,
      'totals': totals.toMap(),
      'payments': payments.map((e) => e.toMap()).toList(),
      'disbursementMode': disbursementMode,
      'idProofType': idProofType,
      'idProofNumber': idProofNumber?.trim(),
      'notes': notes,
      'shopSnapshot': shopSnapshot.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (includeCreatedAt) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }
}

class ShopGirviService {
  ShopGirviService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _girvi() =>
      _userRef()?.collection('girvi');

  Stream<List<ShopGirvi>> watchGirvi() {
    final col = _girvi();
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(ShopGirvi.fromDoc).toList();
      list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return list;
    });
  }

  Future<ShopGirvi?> getGirvi(String girviNo) async {
    final col = _girvi();
    if (col == null) return null;
    final snap = await col.doc(girviNo).get();
    if (!snap.exists) return null;
    return ShopGirvi.fromDoc(snap);
  }

  Future<String> _uniqueGirviNo() async {
    final col = _girvi();
    if (col == null) throw Exception('Not signed in');
    for (var i = 0; i < 5; i++) {
      final no = generateGirviNo();
      final existing = await col.doc(no).get();
      if (!existing.exists) return no;
    }
    return generateGirviNo();
  }

  Future<ShopGirvi> createGirvi(ShopGirvi draft) async {
    final col = _girvi();
    if (col == null) throw Exception('Not signed in');
    final no =
        draft.girviNo.isNotEmpty ? draft.girviNo : await _uniqueGirviNo();
    final girvi = ShopGirvi(
      girviNo: no,
      customer: draft.customer,
      items: draft.items,
      loanAmount: draft.loanAmount,
      interestRatePercent: draft.interestRatePercent,
      tenureMonths: draft.tenureMonths,
      startedAt: draft.startedAt,
      dueDate: draft.dueDate,
      status: draft.status,
      totals: draft.totals,
      payments: draft.payments,
      disbursementMode: draft.disbursementMode,
      idProofType: draft.idProofType,
      idProofNumber: draft.idProofNumber,
      notes: draft.notes,
      shopSnapshot: draft.shopSnapshot,
    );
    await col.doc(no).set(girvi.toMap(includeCreatedAt: true));
    return girvi;
  }

  Future<void> updateGirvi(ShopGirvi girvi) async {
    final col = _girvi();
    if (col == null) throw Exception('Not signed in');
    await col.doc(girvi.girviNo).set(girvi.toMap(), SetOptions(merge: true));
  }

  Future<void> markClosed(String girviNo) async {
    final col = _girvi();
    if (col == null) throw Exception('Not signed in');
    await col.doc(girviNo).set(
      {
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> addPayment(String girviNo, GirviPayment payment) async {
    final existing = await getGirvi(girviNo);
    if (existing == null) throw Exception('Girvi not found');
    final payments = [...existing.payments, payment];
    final paid = payments.fold<double>(0, (s, p) => s + p.amount);
    final totals = GirviTotals.compute(
      items: existing.items,
      loanAmount: existing.loanAmount,
      interestRatePercent: existing.interestRatePercent,
      tenureMonths: existing.tenureMonths,
      paidAmount: paid,
    );
    final closed = totals.balance <= 0.5;
    await updateGirvi(
      ShopGirvi(
        girviNo: existing.girviNo,
        customer: existing.customer,
        items: existing.items,
        loanAmount: existing.loanAmount,
        interestRatePercent: existing.interestRatePercent,
        tenureMonths: existing.tenureMonths,
        startedAt: existing.startedAt,
        dueDate: existing.dueDate,
        status: closed ? 'closed' : existing.status,
        totals: totals,
        payments: payments,
        disbursementMode: existing.disbursementMode,
        idProofType: existing.idProofType,
        idProofNumber: existing.idProofNumber,
        notes: existing.notes,
        shopSnapshot: existing.shopSnapshot,
        createdAt: existing.createdAt,
      ),
    );
  }
}
