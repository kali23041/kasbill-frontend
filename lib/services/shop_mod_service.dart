import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';
import 'shop_bills_service.dart';

String generateModNo([DateTime? at]) {
  final now = at ?? DateTime.now();
  final stamp =
      '${now.year.toString().substring(2)}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
  final rand = Random().nextInt(90) + 10;
  return 'MOD$stamp$rand';
}

double modAppraisalFor({
  required double netWeight,
  required double ratePerGram,
}) =>
    netWeight * ratePerGram;

class ModItem {
  final String name;
  final String? metalLabel;
  final int? karat;
  final double? purity;
  final double grossWeight;
  final double stoneWeight;
  final double netWeight;
  final double ratePerGram;
  final double appraisalValue;
  final String? imageBase64;
  final String? imageMime;
  final String? notes;

  const ModItem({
    required this.name,
    this.metalLabel,
    this.karat,
    this.purity,
    required this.grossWeight,
    this.stoneWeight = 0,
    required this.netWeight,
    required this.ratePerGram,
    required this.appraisalValue,
    this.imageBase64,
    this.imageMime,
    this.notes,
  });

  factory ModItem.compute({
    required String name,
    String? metalLabel,
    int? karat,
    double? purity,
    required double grossWeight,
    double stoneWeight = 0,
    double? netWeight,
    required double ratePerGram,
    String? imageBase64,
    String? imageMime,
    String? notes,
  }) {
    final stone = stoneWeight < 0 ? 0.0 : stoneWeight;
    final net = netWeight ?? (grossWeight - stone).clamp(0, double.infinity);
    return ModItem(
      name: name.trim(),
      metalLabel: metalLabel,
      karat: karat,
      purity: purity,
      grossWeight: grossWeight,
      stoneWeight: stone,
      netWeight: net,
      ratePerGram: ratePerGram,
      appraisalValue: modAppraisalFor(
        netWeight: net,
        ratePerGram: ratePerGram,
      ),
      imageBase64: imageBase64,
      imageMime: imageMime,
      notes: notes,
    );
  }

  factory ModItem.fromMap(Map<String, dynamic> m) {
    return ModItem(
      name: (m['name'] as String?) ?? '',
      metalLabel: m['metalLabel'] as String?,
      karat: (m['karat'] as num?)?.toInt(),
      purity: (m['purity'] as num?)?.toDouble(),
      grossWeight: (m['grossWeight'] as num?)?.toDouble() ?? 0,
      stoneWeight: (m['stoneWeight'] as num?)?.toDouble() ?? 0,
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
        'purity': purity,
        'grossWeight': grossWeight,
        'stoneWeight': stoneWeight,
        'netWeight': netWeight,
        'ratePerGram': ratePerGram,
        'appraisalValue': appraisalValue,
        'imageBase64': imageBase64,
        'imageMime': imageMime,
        'notes': notes,
      };
}

class ModTotals {
  final double appraisalValue;
  final double stoneDeduction;
  final double makingDeduction;
  final double otherDeduction;
  final double purchaseAmount;

  const ModTotals({
    required this.appraisalValue,
    this.stoneDeduction = 0,
    this.makingDeduction = 0,
    this.otherDeduction = 0,
    required this.purchaseAmount,
  });

  factory ModTotals.compute({
    required List<ModItem> items,
    double deductionPercent = 0,
    double stoneDeduction = 0,
    double otherDeduction = 0,
    double? purchaseOverride,
  }) {
    final appraisal = items.fold<double>(0, (s, i) => s + i.appraisalValue);
    final making = appraisal * (deductionPercent.clamp(0, 100) / 100);
    final stone = stoneDeduction.clamp(0, double.infinity).toDouble();
    final other = otherDeduction.clamp(0, double.infinity).toDouble();
    final computed =
        (appraisal - making - stone - other).clamp(0, double.infinity).toDouble();
    return ModTotals(
      appraisalValue: appraisal,
      stoneDeduction: stone,
      makingDeduction: making,
      otherDeduction: other,
      purchaseAmount: purchaseOverride ?? computed,
    );
  }

  factory ModTotals.fromMap(Map<String, dynamic>? m) {
    m ??= {};
    return ModTotals(
      appraisalValue: (m['appraisalValue'] as num?)?.toDouble() ?? 0,
      stoneDeduction: (m['stoneDeduction'] as num?)?.toDouble() ?? 0,
      makingDeduction: (m['makingDeduction'] as num?)?.toDouble() ?? 0,
      otherDeduction: (m['otherDeduction'] as num?)?.toDouble() ?? 0,
      purchaseAmount: (m['purchaseAmount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'appraisalValue': appraisalValue,
        'stoneDeduction': stoneDeduction,
        'makingDeduction': makingDeduction,
        'otherDeduction': otherDeduction,
        'purchaseAmount': purchaseAmount,
      };
}

class ShopMod {
  final String modNo;
  final BillCustomer customer;
  final List<ModItem> items;
  final ModTotals totals;
  final double deductionPercent;
  final String paymentMode; // cash | upi | bank | card | other
  final String? paymentRef;
  final DateTime paidAt;
  final String status; // completed | cancelled
  final String? idProofType;
  final String? idProofNumber;
  final String? notes;
  final BillShopSnapshot shopSnapshot;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ShopMod({
    required this.modNo,
    required this.customer,
    required this.items,
    required this.totals,
    this.deductionPercent = 0,
    required this.paymentMode,
    this.paymentRef,
    required this.paidAt,
    required this.status,
    this.idProofType,
    this.idProofNumber,
    this.notes,
    required this.shopSnapshot,
    this.createdAt,
    this.updatedAt,
  });

  String get statusLabel => status == 'cancelled' ? 'Cancelled' : 'Completed';

  String get paymentModeLabel {
    switch (paymentMode) {
      case 'upi':
        return 'UPI';
      case 'bank':
        return 'Bank transfer';
      case 'card':
        return 'Card';
      case 'other':
        return 'Other';
      default:
        return 'Cash';
    }
  }

  factory ShopMod.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ShopMod(
      modNo: (d['modNo'] as String?) ?? doc.id,
      customer: BillCustomer.fromMap(d['customer'] as Map<String, dynamic>?),
      items: ((d['items'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => ModItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      totals: ModTotals.fromMap(d['totals'] as Map<String, dynamic>?),
      deductionPercent: (d['deductionPercent'] as num?)?.toDouble() ?? 0,
      paymentMode: (d['paymentMode'] as String?) ?? 'cash',
      paymentRef: d['paymentRef'] as String?,
      paidAt: (d['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: (d['status'] as String?) ?? 'completed',
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
      'modNo': modNo,
      'customer': customer.toMap(),
      'items': items.map((e) => e.toMap()).toList(),
      'totals': totals.toMap(),
      'deductionPercent': deductionPercent,
      'paymentMode': paymentMode,
      'paymentRef': paymentRef,
      'paidAt': Timestamp.fromDate(paidAt),
      'status': status,
      'idProofType': idProofType,
      'idProofNumber': idProofNumber,
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

class ShopModService {
  ShopModService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _mod() =>
      _userRef()?.collection('mod');

  Stream<List<ShopMod>> watchMod() {
    final col = _mod();
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(ShopMod.fromDoc).toList();
      list.sort((a, b) => b.paidAt.compareTo(a.paidAt));
      return list;
    });
  }

  Future<ShopMod?> getMod(String modNo) async {
    final col = _mod();
    if (col == null) return null;
    final snap = await col.doc(modNo).get();
    if (!snap.exists) return null;
    return ShopMod.fromDoc(snap);
  }

  Future<String> _uniqueModNo() async {
    final col = _mod();
    if (col == null) throw Exception('Not signed in');
    for (var i = 0; i < 5; i++) {
      final no = generateModNo();
      final existing = await col.doc(no).get();
      if (!existing.exists) return no;
    }
    return generateModNo();
  }

  Future<ShopMod> createMod(ShopMod draft) async {
    final col = _mod();
    if (col == null) throw Exception('Not signed in');
    final no = draft.modNo.isNotEmpty ? draft.modNo : await _uniqueModNo();
    final mod = ShopMod(
      modNo: no,
      customer: draft.customer,
      items: draft.items,
      totals: draft.totals,
      deductionPercent: draft.deductionPercent,
      paymentMode: draft.paymentMode,
      paymentRef: draft.paymentRef,
      paidAt: draft.paidAt,
      status: draft.status,
      idProofType: draft.idProofType,
      idProofNumber: draft.idProofNumber,
      notes: draft.notes,
      shopSnapshot: draft.shopSnapshot,
    );
    await col.doc(no).set(mod.toMap(includeCreatedAt: true));
    return mod;
  }

  Future<void> updateMod(ShopMod mod) async {
    final col = _mod();
    if (col == null) throw Exception('Not signed in');
    await col.doc(mod.modNo).set(mod.toMap(), SetOptions(merge: true));
  }

  Future<void> markCancelled(String modNo) async {
    final col = _mod();
    if (col == null) throw Exception('Not signed in');
    await col.doc(modNo).set(
      {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
