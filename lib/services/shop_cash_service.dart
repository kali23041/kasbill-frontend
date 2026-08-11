import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';

class CashDay {
  final String id;
  final DateTime date;
  final double openingCash;
  final bool prompted;
  final double outsTotal;
  final List<CashEntry> entries;

  const CashDay({
    required this.id,
    required this.date,
    required this.openingCash,
    required this.prompted,
    this.outsTotal = 0,
    this.entries = const [],
  });

  double get balance => openingCash - outsTotal;

  static CashDay emptyFor(String id, DateTime day) => CashDay(
        id: id,
        date: day,
        openingCash: 0,
        prompted: false,
      );

  factory CashDay.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    List<CashEntry> entries = const [],
  }) {
    final d = doc.data() ?? {};
    final outs = entries
        .where((e) => e.type == 'mod_out' || e.type == 'girvi_out')
        .fold<double>(0, (s, e) => s + e.amount.abs());
    return CashDay(
      id: doc.id,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      openingCash: (d['openingCash'] as num?)?.toDouble() ?? 0,
      prompted: d['prompted'] as bool? ?? false,
      outsTotal: outs,
      entries: entries,
    );
  }
}

class CashEntry {
  final String id;
  final String type; // opening | mod_out | girvi_out | adjust
  final double amount; // signed: + opening, store outs as positive magnitude in amount with type *_out
  final String? refType;
  final String? refId;
  final String? note;
  final DateTime? createdAt;

  const CashEntry({
    required this.id,
    required this.type,
    required this.amount,
    this.refType,
    this.refId,
    this.note,
    this.createdAt,
  });

  factory CashEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CashEntry(
      id: doc.id,
      type: (d['type'] as String?) ?? 'adjust',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      refType: d['refType'] as String?,
      refId: d['refId'] as String?,
      note: d['note'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ShopCashService {
  ShopCashService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _cashDays() =>
      _userRef()?.collection('cashDays');

  static String dayId([DateTime? at]) {
    final d = at ?? DateTime.now();
    return '${d.year}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime dayStart([DateTime? at]) {
    final d = at ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  DocumentReference<Map<String, dynamic>>? _todayRef() {
    final col = _cashDays();
    if (col == null) return null;
    return col.doc(dayId());
  }

  CollectionReference<Map<String, dynamic>>? _entries(String dayDocId) =>
      _cashDays()?.doc(dayDocId).collection('entries');

  Stream<CashDay> watchToday() {
    final ref = _todayRef();
    if (ref == null) {
      return Stream.value(CashDay.emptyFor(dayId(), dayStart()));
    }
    final id = dayId();
    // Listen to day doc; refetch entries on each day change (opening / updatedAt).
    return ref.snapshots().asyncMap((snap) async {
      if (!snap.exists) {
        return CashDay.emptyFor(id, dayStart());
      }
      try {
        final entrySnap = await ref.collection('entries').get();
        final entries = entrySnap.docs.map(CashEntry.fromDoc).toList();
        return CashDay.fromDoc(snap, entries: entries);
      } catch (_) {
        return CashDay.fromDoc(snap);
      }
    });
  }

  Future<CashDay> getToday() async {
    final ref = _todayRef();
    if (ref == null) return CashDay.emptyFor(dayId(), dayStart());
    final snap = await ref.get();
    if (!snap.exists) return CashDay.emptyFor(dayId(), dayStart());
    final entrySnap = await ref.collection('entries').get();
    final entries = entrySnap.docs.map(CashEntry.fromDoc).toList();
    return CashDay.fromDoc(snap, entries: entries);
  }

  /// Loads cash days whose `date` falls in [start, end] (inclusive calendar days).
  Future<List<CashDay>> fetchDaysInRange(DateTime start, DateTime end) async {
    final col = _cashDays();
    if (col == null) return const [];
    final startDay = dayStart(start);
    final endExclusive = dayStart(end).add(const Duration(days: 1));
    try {
      final snap = await col
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDay))
          .where('date', isLessThan: Timestamp.fromDate(endExclusive))
          .get();
      if (snap.docs.isEmpty) return const [];
      final days = await Future.wait(snap.docs.map((doc) async {
        try {
          final entrySnap = await doc.reference.collection('entries').get();
          final entries = entrySnap.docs.map(CashEntry.fromDoc).toList();
          return CashDay.fromDoc(doc, entries: entries);
        } catch (_) {
          return CashDay.fromDoc(doc);
        }
      }));
      days.sort((a, b) => a.date.compareTo(b.date));
      return days;
    } catch (_) {
      return const [];
    }
  }

  /// Skip or confirm opening cash for today. Marks prompted.
  Future<void> setOpeningCash(double amount) async {
    final ref = _todayRef();
    if (ref == null) throw Exception('Not signed in');
    final opening = amount < 0 ? 0.0 : amount;
    final start = dayStart();

    await ref.set(
      {
        'date': Timestamp.fromDate(start),
        'openingCash': opening,
        'prompted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final entries = _entries(dayId());
    if (entries == null) return;
    await entries.doc('opening').set(
      {
        'type': 'opening',
        'amount': opening,
        'refType': null,
        'refId': null,
        'note': 'Opening cash',
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> skipOpeningCash() => setOpeningCash(0);

  /// Idempotent cash out for a Mod purchase (doc id mod_{modNo}).
  Future<void> recordModCashOut({
    required String modNo,
    required double amount,
  }) async {
    await _upsertOutEntry(
      entryId: 'mod_$modNo',
      type: 'mod_out',
      amount: amount,
      refType: 'mod',
      refId: modNo,
      note: 'Mod $modNo',
    );
  }

  /// Clear mod cash out when payment mode is no longer cash.
  Future<void> clearModCashOut(String modNo) async {
    await _deleteEntry('mod_$modNo');
  }

  Future<void> recordGirviCashOut({
    required String girviNo,
    required double amount,
  }) async {
    await _upsertOutEntry(
      entryId: 'girvi_$girviNo',
      type: 'girvi_out',
      amount: amount,
      refType: 'girvi',
      refId: girviNo,
      note: 'Girvi $girviNo',
    );
  }

  Future<void> clearGirviCashOut(String girviNo) async {
    await _deleteEntry('girvi_$girviNo');
  }

  Future<void> _upsertOutEntry({
    required String entryId,
    required String type,
    required double amount,
    required String refType,
    required String refId,
    String? note,
  }) async {
    final dayRef = _todayRef();
    final entries = _entries(dayId());
    if (dayRef == null || entries == null) throw Exception('Not signed in');

    // Ensure day doc exists so streams work.
    await dayRef.set(
      {
        'date': Timestamp.fromDate(dayStart()),
        'prompted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final magnitude = amount < 0 ? 0.0 : amount;
    if (magnitude <= 0) {
      await _deleteEntry(entryId);
      return;
    }

    await entries.doc(entryId).set(
      {
        'type': type,
        'amount': magnitude,
        'refType': refType,
        'refId': refId,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _deleteEntry(String entryId) async {
    final entries = _entries(dayId());
    if (entries == null) return;
    await entries.doc(entryId).delete();
  }
}
