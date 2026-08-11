import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';
import 'shop_rates_service.dart';

/// Generates a unique Code128-friendly stock barcode, e.g. RNX2508041945123487
String generateStockBarcode() {
  final now = DateTime.now();
  final stamp =
      '${now.year.toString().substring(2)}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
  final rand = Random().nextInt(9000) + 1000;
  return 'RNX$stamp$rand';
}

class StockItem {
  final String id;
  final String name;
  final String? sku;
  final String? huid;
  final String? barcode;
  final String categoryId;
  final String categoryName;
  final String metalId;
  final String metalLabel;
  final String metalType;
  final int? karat;
  final double shopRatePerGram;
  final double? liveRatePerGram;
  final double grossWeight;
  final double netWeight;
  final double stoneWeight;
  final double wastagePercent;
  final String makingChargeType; // per_gram | flat | percent
  final double makingCharge;
  final double stoneCharge;
  final double otherCharge;
  final int quantity;
  final String? size;
  final String unit;
  final String status; // in_stock | low | sold
  final String? imageBase64;
  final String? imageMime;
  final String? notes;
  final double? calculatedPrice;
  final bool applyGst;
  final double? gstPercent;
  final double? gstAmount;
  final double? priceWithGst;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StockItem({
    required this.id,
    required this.name,
    this.sku,
    this.huid,
    this.barcode,
    required this.categoryId,
    required this.categoryName,
    required this.metalId,
    required this.metalLabel,
    required this.metalType,
    this.karat,
    required this.shopRatePerGram,
    this.liveRatePerGram,
    required this.grossWeight,
    required this.netWeight,
    required this.stoneWeight,
    required this.wastagePercent,
    required this.makingChargeType,
    required this.makingCharge,
    required this.stoneCharge,
    required this.otherCharge,
    required this.quantity,
    this.size,
    this.unit = 'pcs',
    required this.status,
    this.imageBase64,
    this.imageMime,
    this.notes,
    this.calculatedPrice,
    this.applyGst = false,
    this.gstPercent,
    this.gstAmount,
    this.priceWithGst,
    this.createdAt,
    this.updatedAt,
  });

  bool get isLow => status == 'low' || quantity <= 2;

  String get statusLabel {
    switch (status) {
      case 'sold':
        return 'Sold';
      case 'low':
        return 'Low';
      default:
        return isLow ? 'Low' : 'In stock';
    }
  }

  double get estimatedValue {
    return calculateStockPrice(
      netWeight: netWeight,
      shopRatePerGram: shopRatePerGram,
      wastagePercent: wastagePercent,
      makingChargeType: makingChargeType,
      makingCharge: makingCharge,
      stoneCharge: stoneCharge,
      otherCharge: otherCharge,
    ).total;
  }

  double get displayPrice {
    if (applyGst && priceWithGst != null) return priceWithGst!;
    return calculatedPrice ?? estimatedValue;
  }

  /// Unit price at rates frozen when the item was saved.
  double get addedUnitValue => displayPrice;

  /// Line value at add (unit × qty).
  double get addedLineValue => addedUnitValue * quantity;

  double todayUnitValue(double currentShopRatePerGram) {
    final base = calculateStockPrice(
      netWeight: netWeight,
      shopRatePerGram: currentShopRatePerGram,
      wastagePercent: wastagePercent,
      makingChargeType: makingChargeType,
      makingCharge: makingCharge,
      stoneCharge: stoneCharge,
      otherCharge: otherCharge,
    ).total;
    if (!applyGst) return base;
    final pct = gstPercent ?? 0;
    return base * (1 + pct / 100);
  }

  double todayLineValue(double currentShopRatePerGram) =>
      todayUnitValue(currentShopRatePerGram) * quantity;

  factory StockItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return StockItem(
      id: doc.id,
      name: (d['name'] as String?)?.trim() ?? '',
      sku: d['sku'] as String?,
      huid: d['huid'] as String?,
      barcode: d['barcode'] as String?,
      categoryId: (d['categoryId'] as String?) ?? '',
      categoryName: (d['categoryName'] as String?) ?? '',
      metalId: (d['metalId'] as String?) ?? '',
      metalLabel: (d['metalLabel'] as String?) ?? '',
      metalType: (d['metalType'] as String?) ?? '',
      karat: (d['karat'] as num?)?.toInt(),
      shopRatePerGram: (d['shopRatePerGram'] as num?)?.toDouble() ?? 0,
      liveRatePerGram: (d['liveRatePerGram'] as num?)?.toDouble(),
      grossWeight: (d['grossWeight'] as num?)?.toDouble() ?? 0,
      netWeight: (d['netWeight'] as num?)?.toDouble() ?? 0,
      stoneWeight: (d['stoneWeight'] as num?)?.toDouble() ?? 0,
      wastagePercent: (d['wastagePercent'] as num?)?.toDouble() ?? 0,
      makingChargeType: (d['makingChargeType'] as String?) ?? 'flat',
      makingCharge: (d['makingCharge'] as num?)?.toDouble() ?? 0,
      stoneCharge: (d['stoneCharge'] as num?)?.toDouble() ?? 0,
      otherCharge: (d['otherCharge'] as num?)?.toDouble() ?? 0,
      quantity: (d['quantity'] as num?)?.toInt() ?? 0,
      size: d['size'] as String?,
      unit: (d['unit'] as String?) ?? 'pcs',
      status: (d['status'] as String?) ?? 'in_stock',
      imageBase64: d['imageBase64'] as String?,
      imageMime: d['imageMime'] as String?,
      notes: d['notes'] as String?,
      calculatedPrice: (d['calculatedPrice'] as num?)?.toDouble(),
      applyGst: d['applyGst'] as bool? ?? false,
      gstPercent: (d['gstPercent'] as num?)?.toDouble(),
      gstAmount: (d['gstAmount'] as num?)?.toDouble(),
      priceWithGst: (d['priceWithGst'] as num?)?.toDouble(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    final base = calculatedPrice ?? estimatedValue;
    final pct = gstPercent ?? 0;
    final gst = applyGst ? base * (pct / 100) : 0.0;
    final withGst = applyGst ? base + gst : base;

    final map = <String, dynamic>{
      'name': name.trim(),
      'sku': sku?.trim(),
      'huid': huid?.trim(),
      'barcode': barcode?.trim(),
      'categoryId': categoryId,
      'categoryName': categoryName,
      'metalId': metalId,
      'metalLabel': metalLabel,
      'metalType': metalType,
      'karat': karat,
      'shopRatePerGram': shopRatePerGram,
      'liveRatePerGram': liveRatePerGram,
      'grossWeight': grossWeight,
      'netWeight': netWeight,
      'stoneWeight': stoneWeight,
      'wastagePercent': wastagePercent,
      'makingChargeType': makingChargeType,
      'makingCharge': makingCharge,
      'stoneCharge': stoneCharge,
      'otherCharge': otherCharge,
      'quantity': quantity,
      'size': size?.trim(),
      'unit': unit,
      'status': status,
      'imageBase64': imageBase64,
      'imageMime': imageMime,
      'notes': notes?.trim(),
      'calculatedPrice': base,
      'applyGst': applyGst,
      'gstPercent': applyGst ? pct : null,
      'gstAmount': applyGst ? (gstAmount ?? gst) : null,
      'priceWithGst': applyGst ? (priceWithGst ?? withGst) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (includeCreatedAt) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }
}

/// Mark-to-market vs value-at-add for a stock line.
class StockValuation {
  final double addedUnit;
  final double todayUnit;
  final double addedLine;
  final double todayLine;
  final double changePct;

  const StockValuation({
    required this.addedUnit,
    required this.todayUnit,
    required this.addedLine,
    required this.todayLine,
    required this.changePct,
  });

  factory StockValuation.forItem(
    StockItem item,
    Map<String, ShopMetalRate> metalsById,
  ) {
    final metal = metalsById[item.metalId];
    final rate = metal?.shopRatePerGram ?? item.shopRatePerGram;
    final addedUnit = item.addedUnitValue;
    final todayUnit = item.todayUnitValue(rate);
    final addedLine = addedUnit * item.quantity;
    final todayLine = todayUnit * item.quantity;
    final changePct =
        addedUnit > 0 ? ((todayUnit - addedUnit) / addedUnit) * 100 : 0.0;
    return StockValuation(
      addedUnit: addedUnit,
      todayUnit: todayUnit,
      addedLine: addedLine,
      todayLine: todayLine,
      changePct: changePct,
    );
  }

  static StockValuation portfolio(
    List<StockItem> items,
    Map<String, ShopMetalRate> metalsById,
  ) {
    var added = 0.0;
    var today = 0.0;
    for (final item in items) {
      if (item.status == 'sold') continue;
      final v = StockValuation.forItem(item, metalsById);
      added += v.addedLine;
      today += v.todayLine;
    }
    final pct = added > 0 ? ((today - added) / added) * 100 : 0.0;
    return StockValuation(
      addedUnit: added,
      todayUnit: today,
      addedLine: added,
      todayLine: today,
      changePct: pct,
    );
  }
}

class StockPriceBreakdown {
  final double metalValue;
  final double wastage;
  final double making;
  final double stoneCharge;
  final double otherCharge;

  const StockPriceBreakdown({
    required this.metalValue,
    required this.wastage,
    required this.making,
    required this.stoneCharge,
    required this.otherCharge,
  });

  double get total =>
      metalValue + wastage + making + stoneCharge + otherCharge;
}

StockPriceBreakdown calculateStockPrice({
  required double netWeight,
  required double shopRatePerGram,
  required double wastagePercent,
  required String makingChargeType,
  required double makingCharge,
  required double stoneCharge,
  required double otherCharge,
}) {
  final metalValue = netWeight * shopRatePerGram;
  double making = makingCharge;
  if (makingChargeType == 'per_gram') {
    making = makingCharge * netWeight;
  } else if (makingChargeType == 'percent') {
    making = metalValue * (makingCharge / 100);
  }
  final wastage = metalValue * (wastagePercent / 100);
  return StockPriceBreakdown(
    metalValue: metalValue,
    wastage: wastage,
    making: making,
    stoneCharge: stoneCharge,
    otherCharge: otherCharge,
  );
}

class ShopStockService {
  ShopStockService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const lowStockThreshold = 2;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _stock() =>
      _userRef()?.collection('stock');

  Stream<List<StockItem>> watchStock() {
    final col = _stock();
    if (col == null) return Stream.value(const []);
    return col.orderBy('updatedAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(StockItem.fromDoc).toList(),
        );
  }

  Future<void> saveItem(StockItem item, {String? id}) async {
    final col = _stock();
    if (col == null) throw Exception('Not signed in');

    final isNew = id == null || id.isEmpty;
    final data = item.toMap(includeCreatedAt: isNew);

    if (isNew) {
      await col.add(data);
    } else {
      await col.doc(id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> deleteItem(String id) async {
    final col = _stock();
    if (col == null) throw Exception('Not signed in');
    await col.doc(id).delete();
  }
}
