import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';

class KarigarEntryType {
  /// Metal handed to the goldsmith.
  static const issue = 'issue';

  /// Finished goods / scrap coming back.
  static const receive = 'receive';

  /// Labour paid out — does not move metal.
  static const payment = 'payment';

  static const all = [issue, receive, payment];

  static String label(String t) {
    switch (t) {
      case receive:
        return 'Received back';
      case payment:
        return 'Labour paid';
      default:
        return 'Issued';
    }
  }
}

class Karigar {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? specialty;
  final String labourType; // per_gram | per_piece | percent
  final double labourRate;
  final double allowedWastagePercent;

  /// Rollups maintained by the service.
  final double issuedWeight;
  final double receivedWeight;
  final double outstandingWeight;
  final double wastageWeight;
  final double labourDue;
  final double labourPaid;
  final int entryCount;
  final String status; // active | inactive
  final DateTime? lastActivityAt;
  final DateTime? createdAt;

  const Karigar({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.specialty,
    this.labourType = 'per_gram',
    this.labourRate = 0,
    this.allowedWastagePercent = 0,
    this.issuedWeight = 0,
    this.receivedWeight = 0,
    this.outstandingWeight = 0,
    this.wastageWeight = 0,
    this.labourDue = 0,
    this.labourPaid = 0,
    this.entryCount = 0,
    this.status = 'active',
    this.lastActivityAt,
    this.createdAt,
  });

  bool get isActive => status == 'active';

  double get labourBalance =>
      (labourDue - labourPaid).clamp(0, double.infinity).toDouble();

  /// Wastage as a share of everything issued — the number that tells a shop
  /// whether a karigar is losing them money.
  double get wastagePercent =>
      issuedWeight <= 0 ? 0 : (wastageWeight / issuedWeight) * 100;

  bool get wastageOverLimit =>
      allowedWastagePercent > 0 && wastagePercent > allowedWastagePercent;

  factory Karigar.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Karigar(
      id: doc.id,
      name: (d['name'] as String?)?.trim() ?? '',
      phone: d['phone'] as String?,
      address: d['address'] as String?,
      specialty: d['specialty'] as String?,
      labourType: (d['labourType'] as String?) ?? 'per_gram',
      labourRate: (d['labourRate'] as num?)?.toDouble() ?? 0,
      allowedWastagePercent:
          (d['allowedWastagePercent'] as num?)?.toDouble() ?? 0,
      issuedWeight: (d['issuedWeight'] as num?)?.toDouble() ?? 0,
      receivedWeight: (d['receivedWeight'] as num?)?.toDouble() ?? 0,
      outstandingWeight: (d['outstandingWeight'] as num?)?.toDouble() ?? 0,
      wastageWeight: (d['wastageWeight'] as num?)?.toDouble() ?? 0,
      labourDue: (d['labourDue'] as num?)?.toDouble() ?? 0,
      labourPaid: (d['labourPaid'] as num?)?.toDouble() ?? 0,
      entryCount: (d['entryCount'] as num?)?.toInt() ?? 0,
      status: (d['status'] as String?) ?? 'active',
      lastActivityAt: (d['lastActivityAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    final map = <String, dynamic>{
      'name': name.trim(),
      'phone': phone?.trim(),
      'address': address?.trim(),
      'specialty': specialty?.trim(),
      'labourType': labourType,
      'labourRate': labourRate,
      'allowedWastagePercent': allowedWastagePercent,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (includeCreatedAt) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['issuedWeight'] = 0;
      map['receivedWeight'] = 0;
      map['outstandingWeight'] = 0;
      map['wastageWeight'] = 0;
      map['labourDue'] = 0;
      map['labourPaid'] = 0;
      map['entryCount'] = 0;
    }
    return map;
  }
}

class KarigarEntry {
  final String id;
  final String type;
  final String? metalLabel;
  final int? karat;
  final double grossWeight;
  final double netWeight;
  final double purity;
  final int pieces;
  final String? itemName;
  final double labourAmount;
  final double paidAmount;
  final String? paymentMode;
  final String? jobNo;
  final String? note;
  final String? imageBase64;
  final String? imageMime;
  final DateTime? entryAt;
  final DateTime? createdAt;

  const KarigarEntry({
    required this.id,
    required this.type,
    this.metalLabel,
    this.karat,
    this.grossWeight = 0,
    this.netWeight = 0,
    this.purity = 0,
    this.pieces = 0,
    this.itemName,
    this.labourAmount = 0,
    this.paidAmount = 0,
    this.paymentMode,
    this.jobNo,
    this.note,
    this.imageBase64,
    this.imageMime,
    this.entryAt,
    this.createdAt,
  });

  /// Weight actually counted against the karigar's balance.
  double get effectiveWeight => netWeight > 0 ? netWeight : grossWeight;

  factory KarigarEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return KarigarEntry(
      id: doc.id,
      type: (d['type'] as String?) ?? KarigarEntryType.issue,
      metalLabel: d['metalLabel'] as String?,
      karat: (d['karat'] as num?)?.toInt(),
      grossWeight: (d['grossWeight'] as num?)?.toDouble() ?? 0,
      netWeight: (d['netWeight'] as num?)?.toDouble() ?? 0,
      purity: (d['purity'] as num?)?.toDouble() ?? 0,
      pieces: (d['pieces'] as num?)?.toInt() ?? 0,
      itemName: d['itemName'] as String?,
      labourAmount: (d['labourAmount'] as num?)?.toDouble() ?? 0,
      paidAmount: (d['paidAmount'] as num?)?.toDouble() ?? 0,
      paymentMode: d['paymentMode'] as String?,
      jobNo: d['jobNo'] as String?,
      note: d['note'] as String?,
      imageBase64: d['imageBase64'] as String?,
      imageMime: d['imageMime'] as String?,
      entryAt: (d['entryAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'metalLabel': metalLabel,
        'karat': karat,
        'grossWeight': grossWeight,
        'netWeight': netWeight,
        'purity': purity,
        'pieces': pieces,
        'itemName': itemName?.trim(),
        'labourAmount': labourAmount,
        'paidAmount': paidAmount,
        'paymentMode': paymentMode,
        'jobNo': jobNo,
        'note': note?.trim(),
        'imageBase64': imageBase64,
        'imageMime': imageMime,
        'entryAt': entryAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(entryAt!),
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// Metal issued to and received back from goldsmiths — where a shop quietly
/// loses grams if nobody is counting.
///
/// Layout:
///   users/{email}/karigars/{karigarId}
///   users/{email}/karigars/{karigarId}/issues/{entryId}
class ShopKarigarService {
  ShopKarigarService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _karigars() =>
      _userRef()?.collection('karigars');

  CollectionReference<Map<String, dynamic>>? entriesRef(String karigarId) =>
      _karigars()?.doc(karigarId).collection('issues');

  Stream<List<Karigar>> watchKarigars() {
    final col = _karigars();
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(Karigar.fromDoc).toList();
      list.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        final byWeight = b.outstandingWeight.compareTo(a.outstandingWeight);
        if (byWeight != 0) return byWeight;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    });
  }

  Stream<Karigar?> watchKarigar(String id) {
    final col = _karigars();
    if (col == null) return Stream.value(null);
    return col.doc(id).snapshots().map(
          (s) => s.exists ? Karigar.fromDoc(s) : null,
        );
  }

  Stream<List<KarigarEntry>> watchEntries(String karigarId) {
    final col = entriesRef(karigarId);
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(KarigarEntry.fromDoc).toList();
      list.sort((a, b) {
        final at = a.entryAt ?? a.createdAt ?? DateTime(2000);
        final bt = b.entryAt ?? b.createdAt ?? DateTime(2000);
        return bt.compareTo(at);
      });
      return list;
    });
  }

  Future<Karigar> createKarigar(Karigar draft) async {
    final col = _karigars();
    if (col == null) throw Exception('Not signed in');
    final ref = draft.id.isEmpty ? col.doc() : col.doc(draft.id);
    await ref.set(draft.toMap(includeCreatedAt: true));
    return Karigar(
      id: ref.id,
      name: draft.name,
      phone: draft.phone,
      address: draft.address,
      specialty: draft.specialty,
      labourType: draft.labourType,
      labourRate: draft.labourRate,
      allowedWastagePercent: draft.allowedWastagePercent,
    );
  }

  Future<void> updateKarigar(Karigar karigar) async {
    final col = _karigars();
    if (col == null) throw Exception('Not signed in');
    await col.doc(karigar.id).set(karigar.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteKarigar(String id) async {
    final col = _karigars();
    if (col == null) throw Exception('Not signed in');
    final entries = await col.doc(id).collection('issues').get();
    for (final e in entries.docs) {
      await e.reference.delete();
    }
    await col.doc(id).delete();
  }

  /// Books an issue / receive / payment and rolls the karigar totals forward.
  ///
  /// On a `receive`, anything not returned counts as wastage — that is the
  /// number the shop actually cares about.
  Future<void> addEntry(String karigarId, KarigarEntry entry) async {
    final col = _karigars();
    if (col == null) throw Exception('Not signed in');
    final karigarRef = col.doc(karigarId);
    final entryRef = karigarRef.collection('issues').doc();

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(karigarRef);
      final d = snap.data() ?? <String, dynamic>{};
      final issued = (d['issuedWeight'] as num?)?.toDouble() ?? 0;
      final received = (d['receivedWeight'] as num?)?.toDouble() ?? 0;
      final wastage = (d['wastageWeight'] as num?)?.toDouble() ?? 0;
      final labourDue = (d['labourDue'] as num?)?.toDouble() ?? 0;
      final labourPaid = (d['labourPaid'] as num?)?.toDouble() ?? 0;
      final count = (d['entryCount'] as num?)?.toInt() ?? 0;

      var nextIssued = issued;
      var nextReceived = received;
      var nextWastage = wastage;
      var nextDue = labourDue;
      var nextPaid = labourPaid;

      switch (entry.type) {
        case KarigarEntryType.issue:
          nextIssued += entry.effectiveWeight;
        case KarigarEntryType.receive:
          nextReceived += entry.effectiveWeight;
          nextDue += entry.labourAmount;
        case KarigarEntryType.payment:
          nextPaid += entry.paidAmount;
      }

      // Wastage is whatever has been issued but never came back.
      nextWastage = (nextIssued - nextReceived).clamp(0, double.infinity).toDouble();

      txn.set(
        karigarRef,
        {
          'issuedWeight': nextIssued,
          'receivedWeight': nextReceived,
          'outstandingWeight': nextWastage,
          'wastageWeight': nextWastage,
          'labourDue': nextDue,
          'labourPaid': nextPaid,
          'entryCount': count + 1,
          'lastActivityAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      txn.set(entryRef, entry.toMap());
    });
  }

  Future<void> deleteEntry(String karigarId, String entryId) async {
    final col = entriesRef(karigarId);
    if (col == null) throw Exception('Not signed in');
    await col.doc(entryId).delete();
    await rebuild(karigarId);
  }

  /// Recomputes rollups from the entry subcollection.
  Future<void> rebuild(String karigarId) async {
    final col = _karigars();
    final entries = entriesRef(karigarId);
    if (col == null || entries == null) throw Exception('Not signed in');
    final snap = await entries.get();
    final list = snap.docs.map(KarigarEntry.fromDoc).toList();

    var issued = 0.0;
    var received = 0.0;
    var due = 0.0;
    var paid = 0.0;
    for (final e in list) {
      switch (e.type) {
        case KarigarEntryType.issue:
          issued += e.effectiveWeight;
        case KarigarEntryType.receive:
          received += e.effectiveWeight;
          due += e.labourAmount;
        case KarigarEntryType.payment:
          paid += e.paidAmount;
      }
    }
    final outstanding = (issued - received).clamp(0, double.infinity).toDouble();

    await col.doc(karigarId).set({
      'issuedWeight': issued,
      'receivedWeight': received,
      'outstandingWeight': outstanding,
      'wastageWeight': outstanding,
      'labourDue': due,
      'labourPaid': paid,
      'entryCount': list.length,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static double totalWithKarigars(List<Karigar> list) =>
      list.fold<double>(0, (s, k) => s + k.outstandingWeight);

  static double totalLabourDue(List<Karigar> list) =>
      list.fold<double>(0, (s, k) => s + k.labourBalance);
}
