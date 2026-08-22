import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';

class ShopMetalRate {
  final String id;
  final String metalType;
  final String? customName;
  final int? karat;
  final double shopRatePerGram;
  final double? liveRatePerGram;
  final DateTime? updatedAt;

  const ShopMetalRate({
    required this.id,
    required this.metalType,
    this.customName,
    required this.karat,
    required this.shopRatePerGram,
    this.liveRatePerGram,
    this.updatedAt,
  });

  /// Back-compat alias.
  double? get onlineRatePerGram => liveRatePerGram;

  String get label {
    if (metalType == 'custom') {
      final name = customName?.trim();
      return (name != null && name.isNotEmpty) ? name : 'Custom metal';
    }
    if (metalType == 'gold' && karat != null) return 'Gold ${karat}K';
    if (metalType == 'silver') {
      if (karat == null) return 'Silver';
      return switch (karat) {
        999 => 'Silver 999 · Fine',
        970 => 'Silver 970',
        925 => 'Silver 925 · Sterling',
        900 => 'Silver 900',
        800 => 'Silver 800',
        _ => 'Silver $karat',
      };
    }
    if (metalType == 'platinum') return 'Platinum';
    return metalType;
  }

  factory ShopMetalRate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final live = (d['liveRatePerGram'] as num?)?.toDouble() ??
        (d['onlineRatePerGram'] as num?)?.toDouble();
    return ShopMetalRate(
      id: doc.id,
      metalType: (d['metalType'] as String?) ?? 'gold',
      customName: d['customName'] as String?,
      karat: (d['karat'] as num?)?.toInt(),
      shopRatePerGram: (d['shopRatePerGram'] as num?)?.toDouble() ?? 0,
      liveRatePerGram: live,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class MetalRatePoint {
  final String id;
  final DateTime date;
  final double shopRatePerGram;
  final double? liveRatePerGram;

  const MetalRatePoint({
    required this.id,
    required this.date,
    required this.shopRatePerGram,
    this.liveRatePerGram,
  });

  factory MetalRatePoint.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return MetalRatePoint(
      id: doc.id,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      shopRatePerGram: (d['shopRatePerGram'] as num?)?.toDouble() ?? 0,
      liveRatePerGram: (d['liveRatePerGram'] as num?)?.toDouble(),
    );
  }
}

class ShopDiamondRate {
  final String id;
  final String diamondType;
  final double carat;
  final double shopRatePerCarat;
  final DateTime? updatedAt;

  const ShopDiamondRate({
    required this.id,
    required this.diamondType,
    required this.carat,
    required this.shopRatePerCarat,
    this.updatedAt,
  });

  String get typeLabel {
    switch (diamondType) {
      case 'natural':
        return 'Natural';
      case 'labgrown':
        return 'Lab-grown';
      case 'solitaire':
        return 'Solitaire';
      case 'loose':
        return 'Loose';
      default:
        return diamondType;
    }
  }

  factory ShopDiamondRate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ShopDiamondRate(
      id: doc.id,
      diamondType: (d['diamondType'] as String?) ?? 'natural',
      carat: (d['carat'] as num?)?.toDouble() ?? 0,
      shopRatePerCarat: (d['shopRatePerCarat'] as num?)?.toDouble() ?? 0,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ShopRatesService {
  ShopRatesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _metals() =>
      _userRef()?.collection('metals');

  CollectionReference<Map<String, dynamic>>? _diamonds() =>
      _userRef()?.collection('diamonds');

  CollectionReference<Map<String, dynamic>>? _history(String metalId) =>
      _metals()?.doc(metalId).collection('history');

  static String historyDocId([DateTime? at]) {
    final d = at ?? DateTime.now();
    return '${d.year}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Stream<List<ShopMetalRate>> watchMetals() {
    final col = _metals();
    if (col == null) return Stream.value(const []);
    return col.orderBy('updatedAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(ShopMetalRate.fromDoc).toList(),
        );
  }

  Future<ShopMetalRate?> getMetal(String id) async {
    final col = _metals();
    if (col == null) return null;
    final snap = await col.doc(id).get();
    if (!snap.exists) return null;
    return ShopMetalRate.fromDoc(snap);
  }

  /// Movement in a metal's shop rate since the previous recorded day.
  ///
  /// Shops think in rupees per gram, not percentages, so this returns the
  /// rupee change alongside the percentage.
  Future<({double change, double percent, DateTime? since})?> rateDelta(
    String metalId,
    double currentRate,
  ) async {
    final col = _history(metalId);
    if (col == null) return null;
    try {
      final snap =
          await col.orderBy('date', descending: true).limit(5).get();
      final points = snap.docs.map(MetalRatePoint.fromDoc).toList();
      final today = DateTime.now();
      // Skip any snapshot written today — we want the previous close.
      for (final p in points) {
        final sameDay = p.date.year == today.year &&
            p.date.month == today.month &&
            p.date.day == today.day;
        if (sameDay) continue;
        if (p.shopRatePerGram <= 0) continue;
        final change = currentRate - p.shopRatePerGram;
        return (
          change: change,
          percent: (change / p.shopRatePerGram) * 100,
          since: p.date,
        );
      }
    } catch (_) {
      // History is a nice-to-have; never surface an error for it.
    }
    return null;
  }

  /// Last ~90 days of shop-rate snapshots, ascending by date.
  Stream<List<MetalRatePoint>> watchHistory(String metalId) {
    final col = _history(metalId);
    if (col == null) return Stream.value(const []);
    return col.orderBy('date', descending: true).limit(90).snapshots().map(
      (snap) {
        final list = snap.docs.map(MetalRatePoint.fromDoc).toList();
        return list.reversed.toList();
      },
    );
  }

  Future<void> _writeHistoryPoint({
    required String metalId,
    required double shopRatePerGram,
    double? liveRatePerGram,
    DateTime? at,
  }) async {
    final col = _history(metalId);
    if (col == null) return;
    final when = at ?? DateTime.now();
    final day = DateTime(when.year, when.month, when.day);
    final id = historyDocId(day);
    await col.doc(id).set(
      {
        'date': Timestamp.fromDate(day),
        'shopRatePerGram': shopRatePerGram,
        'liveRatePerGram': liveRatePerGram,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Writes today's snapshot if missing or shop rate changed vs last point.
  Future<void> recordSnapshotIfChanged(ShopMetalRate metal) async {
    final col = _history(metal.id);
    if (col == null) return;
    final id = historyDocId();
    final existing = await col.doc(id).get();
    if (existing.exists) {
      final prev = (existing.data()?['shopRatePerGram'] as num?)?.toDouble();
      if (prev != null && (prev - metal.shopRatePerGram).abs() < 0.01) {
        return;
      }
    }
    await _writeHistoryPoint(
      metalId: metal.id,
      shopRatePerGram: metal.shopRatePerGram,
      liveRatePerGram: metal.liveRatePerGram,
    );
  }

  Future<void> recordSnapshotsForMetals(List<ShopMetalRate> metals) async {
    for (final m in metals) {
      try {
        await recordSnapshotIfChanged(m);
      } catch (_) {}
    }
  }

  Stream<List<ShopDiamondRate>> watchDiamonds() {
    final col = _diamonds();
    if (col == null) return Stream.value(const []);
    return col.orderBy('updatedAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(ShopDiamondRate.fromDoc).toList(),
        );
  }

  /// Saves under `users/{email}/metals/{id}` with both live + shop rates.
  Future<String> saveMetal({
    String? id,
    required String metalType,
    String? customName,
    int? karat,
    required double shopRatePerGram,
    double? liveRatePerGram,
  }) async {
    final col = _metals();
    if (col == null) throw Exception('Not signed in');

    final data = <String, dynamic>{
      'metalType': metalType,
      'customName': metalType == 'custom' ? (customName?.trim() ?? '') : null,
      'karat': karat,
      'shopRatePerGram': shopRatePerGram,
      'liveRatePerGram': liveRatePerGram,
      // Keep alias for older readers.
      'onlineRatePerGram': liveRatePerGram,
      'unit': 'g',
      'hasLiveRate': liveRatePerGram != null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final String metalId;
    if (id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await col.add(data);
      metalId = ref.id;
    } else {
      metalId = id;
      await col.doc(id).set(data, SetOptions(merge: true));
    }

    await _writeHistoryPoint(
      metalId: metalId,
      shopRatePerGram: shopRatePerGram,
      liveRatePerGram: liveRatePerGram,
    );
    return metalId;
  }

  Future<void> deleteMetal(String id) async {
    final col = _metals();
    if (col == null) throw Exception('Not signed in');
    await col.doc(id).delete();
  }

  Future<void> saveDiamond({
    String? id,
    required String diamondType,
    required double carat,
    required double shopRatePerCarat,
  }) async {
    final col = _diamonds();
    if (col == null) throw Exception('Not signed in');

    final data = <String, dynamic>{
      'diamondType': diamondType,
      'carat': carat,
      'shopRatePerCarat': shopRatePerCarat,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (id == null) {
      await col.add(data);
    } else {
      await col.doc(id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> deleteDiamond(String id) async {
    final col = _diamonds();
    if (col == null) throw Exception('Not signed in');
    await col.doc(id).delete();
  }
}
