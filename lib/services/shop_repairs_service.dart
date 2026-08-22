import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';

/// Short, countable token the customer can quote at the counter, e.g. J2508147.
String generateJobNo({DateTime? at}) {
  final now = at ?? DateTime.now();
  final stamp = '${now.year.toString().substring(2)}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
  final rand = Random().nextInt(900) + 100;
  return 'J$stamp$rand';
}

class RepairStatus {
  static const received = 'received';
  static const inProgress = 'inProgress';
  static const ready = 'ready';
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';

  static const open = [received, inProgress, ready];
  static const all = [received, inProgress, ready, delivered, cancelled];

  static String label(String s) {
    switch (s) {
      case inProgress:
        return 'In progress';
      case ready:
        return 'Ready';
      case delivered:
        return 'Delivered';
      case cancelled:
        return 'Cancelled';
      default:
        return 'Received';
    }
  }
}

class RepairJobType {
  static const repair = 'repair';
  static const order = 'order';
  static const polish = 'polish';
  static const resize = 'resize';
  static const rhodium = 'rhodium';
  static const engraving = 'engraving';

  static const all = [repair, order, polish, resize, rhodium, engraving];

  static String label(String t) {
    switch (t) {
      case order:
        return 'Custom order';
      case polish:
        return 'Polish';
      case resize:
        return 'Resize';
      case rhodium:
        return 'Rhodium plating';
      case engraving:
        return 'Engraving';
      default:
        return 'Repair';
    }
  }
}

class RepairItem {
  final String name;
  final String? metalLabel;
  final int? karat;
  final double grossWeight;
  final int quantity;
  final String? condition;
  final String? imageBase64;
  final String? imageMime;
  final String? notes;

  const RepairItem({
    required this.name,
    this.metalLabel,
    this.karat,
    this.grossWeight = 0,
    this.quantity = 1,
    this.condition,
    this.imageBase64,
    this.imageMime,
    this.notes,
  });

  factory RepairItem.fromMap(Map<String, dynamic> m) => RepairItem(
        name: (m['name'] as String?)?.trim() ?? '',
        metalLabel: m['metalLabel'] as String?,
        karat: (m['karat'] as num?)?.toInt(),
        grossWeight: (m['grossWeight'] as num?)?.toDouble() ?? 0,
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        condition: m['condition'] as String?,
        imageBase64: m['imageBase64'] as String?,
        imageMime: m['imageMime'] as String?,
        notes: m['notes'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'metalLabel': metalLabel,
        'karat': karat,
        'grossWeight': grossWeight,
        'quantity': quantity,
        'condition': condition?.trim(),
        'imageBase64': imageBase64,
        'imageMime': imageMime,
        'notes': notes?.trim(),
      };
}

class RepairUpdate {
  final String id;
  final String status;
  final String? note;
  final DateTime? at;
  final String? by;

  const RepairUpdate({
    required this.id,
    required this.status,
    this.note,
    this.at,
    this.by,
  });

  factory RepairUpdate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return RepairUpdate(
      id: doc.id,
      status: (d['status'] as String?) ?? RepairStatus.received,
      note: d['note'] as String?,
      at: (d['at'] as Timestamp?)?.toDate(),
      by: d['by'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'status': status,
        'note': note?.trim(),
        'at': at == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(at!),
        'by': by,
      };
}

class RepairJob {
  final String jobNo;
  final String type;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final List<RepairItem> items;
  final String? description;
  final String status;
  final double estimate;
  final double advance;
  final double finalAmount;
  final String? karigarId;
  final String? karigarName;
  final DateTime? receivedAt;
  final DateTime? promisedAt;
  final DateTime? deliveredAt;
  final String? billNo;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RepairJob({
    required this.jobNo,
    this.type = RepairJobType.repair,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.items = const [],
    this.description,
    this.status = RepairStatus.received,
    this.estimate = 0,
    this.advance = 0,
    this.finalAmount = 0,
    this.karigarId,
    this.karigarName,
    this.receivedAt,
    this.promisedAt,
    this.deliveredAt,
    this.billNo,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  bool get isOpen => RepairStatus.open.contains(status);

  double get chargeable => finalAmount > 0 ? finalAmount : estimate;

  double get balance =>
      (chargeable - advance).clamp(0, double.infinity).toDouble();

  double get totalWeight =>
      items.fold<double>(0, (s, i) => s + i.grossWeight * i.quantity);

  bool get isLate {
    final p = promisedAt;
    if (p == null || !isOpen) return false;
    return DateTime.now().isAfter(p);
  }

  int get daysLate {
    final p = promisedAt;
    if (p == null || !isLate) return 0;
    return DateTime.now().difference(p).inDays;
  }

  factory RepairJob.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final itemsRaw = (d['items'] as List?) ?? const [];
    return RepairJob(
      jobNo: (d['jobNo'] as String?) ?? doc.id,
      type: (d['type'] as String?) ?? RepairJobType.repair,
      customerName: (d['customerName'] as String?)?.trim() ?? '',
      customerPhone: d['customerPhone'] as String?,
      customerAddress: d['customerAddress'] as String?,
      items: itemsRaw
          .whereType<Map>()
          .map((e) => RepairItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      description: d['description'] as String?,
      status: (d['status'] as String?) ?? RepairStatus.received,
      estimate: (d['estimate'] as num?)?.toDouble() ?? 0,
      advance: (d['advance'] as num?)?.toDouble() ?? 0,
      finalAmount: (d['finalAmount'] as num?)?.toDouble() ?? 0,
      karigarId: d['karigarId'] as String?,
      karigarName: d['karigarName'] as String?,
      receivedAt: (d['receivedAt'] as Timestamp?)?.toDate(),
      promisedAt: (d['promisedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (d['deliveredAt'] as Timestamp?)?.toDate(),
      billNo: d['billNo'] as String?,
      notes: d['notes'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    final map = <String, dynamic>{
      'jobNo': jobNo,
      'type': type,
      'customerName': customerName.trim(),
      'customerPhone': customerPhone?.trim(),
      'customerAddress': customerAddress?.trim(),
      'items': items.map((e) => e.toMap()).toList(),
      'description': description?.trim(),
      'status': status,
      'estimate': estimate,
      'advance': advance,
      'finalAmount': finalAmount,
      'balance': balance,
      'karigarId': karigarId,
      'karigarName': karigarName,
      'receivedAt': receivedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(receivedAt!),
      'promisedAt':
          promisedAt == null ? null : Timestamp.fromDate(promisedAt!),
      'deliveredAt':
          deliveredAt == null ? null : Timestamp.fromDate(deliveredAt!),
      'billNo': billNo,
      'notes': notes?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (includeCreatedAt) map['createdAt'] = FieldValue.serverTimestamp();
    return map;
  }

  RepairJob copyWith({
    String? type,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    List<RepairItem>? items,
    String? description,
    String? status,
    double? estimate,
    double? advance,
    double? finalAmount,
    String? karigarId,
    String? karigarName,
    DateTime? receivedAt,
    DateTime? promisedAt,
    DateTime? deliveredAt,
    String? billNo,
    String? notes,
  }) {
    return RepairJob(
      jobNo: jobNo,
      type: type ?? this.type,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      items: items ?? this.items,
      description: description ?? this.description,
      status: status ?? this.status,
      estimate: estimate ?? this.estimate,
      advance: advance ?? this.advance,
      finalAmount: finalAmount ?? this.finalAmount,
      karigarId: karigarId ?? this.karigarId,
      karigarName: karigarName ?? this.karigarName,
      receivedAt: receivedAt ?? this.receivedAt,
      promisedAt: promisedAt ?? this.promisedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      billNo: billNo ?? this.billNo,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}

/// Repair and custom-order job cards.
///
/// Layout:
///   users/{email}/repairs/{jobNo}
///   users/{email}/repairs/{jobNo}/updates/{updateId}   status history
class ShopRepairsService {
  ShopRepairsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _repairs() =>
      _userRef()?.collection('repairs');

  CollectionReference<Map<String, dynamic>>? updatesRef(String jobNo) =>
      _repairs()?.doc(jobNo).collection('updates');

  Stream<List<RepairJob>> watchJobs() {
    final col = _repairs();
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(RepairJob.fromDoc).toList();
      list.sort((a, b) {
        if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
        if (a.isLate != b.isLate) return a.isLate ? -1 : 1;
        final ap = a.promisedAt ?? a.receivedAt ?? DateTime(2000);
        final bp = b.promisedAt ?? b.receivedAt ?? DateTime(2000);
        return a.isOpen ? ap.compareTo(bp) : bp.compareTo(ap);
      });
      return list;
    });
  }

  Stream<RepairJob?> watchJob(String jobNo) {
    final col = _repairs();
    if (col == null) return Stream.value(null);
    return col.doc(jobNo).snapshots().map(
          (s) => s.exists ? RepairJob.fromDoc(s) : null,
        );
  }

  Future<RepairJob?> getJob(String jobNo) async {
    final col = _repairs();
    if (col == null) return null;
    final snap = await col.doc(jobNo).get();
    if (!snap.exists) return null;
    return RepairJob.fromDoc(snap);
  }

  Stream<List<RepairUpdate>> watchUpdates(String jobNo) {
    final col = updatesRef(jobNo);
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(RepairUpdate.fromDoc).toList();
      list.sort((a, b) {
        final at = a.at ?? DateTime(2000);
        final bt = b.at ?? DateTime(2000);
        return bt.compareTo(at);
      });
      return list;
    });
  }

  Future<String> _uniqueJobNo() async {
    final col = _repairs();
    if (col == null) throw Exception('Not signed in');
    for (var i = 0; i < 5; i++) {
      final no = generateJobNo();
      final existing = await col.doc(no).get();
      if (!existing.exists) return no;
    }
    return generateJobNo();
  }

  Future<RepairJob> createJob(RepairJob draft) async {
    final col = _repairs();
    if (col == null) throw Exception('Not signed in');
    final jobNo = draft.jobNo.isNotEmpty ? draft.jobNo : await _uniqueJobNo();
    final job = draft.copyWith(receivedAt: draft.receivedAt ?? DateTime.now());
    final saved = RepairJob(
      jobNo: jobNo,
      type: job.type,
      customerName: job.customerName,
      customerPhone: job.customerPhone,
      customerAddress: job.customerAddress,
      items: job.items,
      description: job.description,
      status: job.status,
      estimate: job.estimate,
      advance: job.advance,
      finalAmount: job.finalAmount,
      karigarId: job.karigarId,
      karigarName: job.karigarName,
      receivedAt: job.receivedAt,
      promisedAt: job.promisedAt,
      notes: job.notes,
    );
    final batch = _firestore.batch();
    batch.set(col.doc(jobNo), saved.toMap(includeCreatedAt: true));
    batch.set(
      col.doc(jobNo).collection('updates').doc(),
      RepairUpdate(
        id: '',
        status: saved.status,
        note: 'Job card created',
        by: _auth.currentUser?.email,
      ).toMap(),
    );
    await batch.commit();
    return saved;
  }

  Future<void> updateJob(RepairJob job) async {
    final col = _repairs();
    if (col == null) throw Exception('Not signed in');
    await col.doc(job.jobNo).set(job.toMap(), SetOptions(merge: true));
  }

  /// Moves a job to a new status and appends to its history subcollection.
  Future<void> setStatus(
    String jobNo,
    String status, {
    String? note,
    double? finalAmount,
    String? billNo,
  }) async {
    final col = _repairs();
    if (col == null) throw Exception('Not signed in');
    final batch = _firestore.batch();
    batch.set(
      col.doc(jobNo),
      {
        'status': status,
        if (finalAmount != null) 'finalAmount': finalAmount,
        if (billNo != null) 'billNo': billNo,
        if (status == RepairStatus.delivered)
          'deliveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      col.doc(jobNo).collection('updates').doc(),
      RepairUpdate(
        id: '',
        status: status,
        note: note,
        by: _auth.currentUser?.email,
      ).toMap(),
    );
    await batch.commit();
  }

  Future<void> deleteJob(String jobNo) async {
    final col = _repairs();
    if (col == null) throw Exception('Not signed in');
    final updates = await col.doc(jobNo).collection('updates').get();
    for (final u in updates.docs) {
      await u.reference.delete();
    }
    await col.doc(jobNo).delete();
  }

  static int openCount(List<RepairJob> jobs) =>
      jobs.where((j) => j.isOpen).length;

  static int lateCount(List<RepairJob> jobs) =>
      jobs.where((j) => j.isLate).length;

  static double advanceHeld(List<RepairJob> jobs) =>
      jobs.where((j) => j.isOpen).fold<double>(0, (s, j) => s + j.advance);
}
