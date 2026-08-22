import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';
import 'shop_customers_service.dart';

String generateLedgerEntryId() {
  final now = DateTime.now();
  final stamp = now.microsecondsSinceEpoch.toRadixString(36).toUpperCase();
  final rand = Random().nextInt(900) + 100;
  return 'L$stamp$rand';
}

/// What moved the balance.
class LedgerEntryType {
  static const credit = 'credit'; // shop gave goods / customer owes more
  static const payment = 'payment'; // customer paid
  static const adjustment = 'adjustment'; // discount, correction (signed)
  static const writeOff = 'writeOff'; // bad debt written off

  static const all = [credit, payment, adjustment, writeOff];

  static String label(String type) {
    switch (type) {
      case payment:
        return 'Payment received';
      case adjustment:
        return 'Adjustment';
      case writeOff:
        return 'Written off';
      default:
        return 'Udhaar given';
    }
  }
}

/// Where the entry came from, so the timeline can deep-link back.
class LedgerSource {
  static const bill = 'bill';
  static const girvi = 'girvi';
  static const mod = 'mod';
  static const repair = 'repair';
  static const scheme = 'scheme';
  static const manual = 'manual';
}

class LedgerEntry {
  final String id;
  final String type;
  final double amount;
  final String source;
  final String? sourceId;
  final String? note;
  final String? mode; // cash | upi | card | bank | cheque
  final DateTime? dueAt;
  final DateTime? entryAt;
  final DateTime? createdAt;
  final String? recordedBy;

  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    this.source = LedgerSource.manual,
    this.sourceId,
    this.note,
    this.mode,
    this.dueAt,
    this.entryAt,
    this.createdAt,
    this.recordedBy,
  });

  /// Signed effect on the outstanding balance.
  double get delta {
    switch (type) {
      case LedgerEntryType.credit:
        return amount;
      case LedgerEntryType.payment:
      case LedgerEntryType.writeOff:
        return -amount;
      case LedgerEntryType.adjustment:
        return amount; // caller passes a signed amount
      default:
        return 0;
    }
  }

  bool get isOverdue {
    if (type != LedgerEntryType.credit) return false;
    final d = dueAt;
    if (d == null) return false;
    return DateTime.now().isAfter(d);
  }

  factory LedgerEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return LedgerEntry(
      id: doc.id,
      type: (d['type'] as String?) ?? LedgerEntryType.credit,
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      source: (d['source'] as String?) ?? LedgerSource.manual,
      sourceId: d['sourceId'] as String?,
      note: d['note'] as String?,
      mode: d['mode'] as String?,
      dueAt: (d['dueAt'] as Timestamp?)?.toDate(),
      entryAt: (d['entryAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      recordedBy: d['recordedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'amount': amount,
        'source': source,
        'sourceId': sourceId,
        'note': note?.trim(),
        'mode': mode,
        'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt!),
        'entryAt': entryAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(entryAt!),
        'createdAt': FieldValue.serverTimestamp(),
        'recordedBy': recordedBy,
      };
}

/// Rollup document at `users/{email}/udhaar/{phoneId}`.
class UdhaarAccount {
  final String phoneId;
  final String name;
  final String phone;
  final double outstanding;
  final double totalCredit;
  final double totalPaid;
  final double writtenOff;
  final DateTime? oldestDueAt;
  final DateTime? lastActivityAt;
  final int entryCount;

  const UdhaarAccount({
    required this.phoneId,
    required this.name,
    required this.phone,
    this.outstanding = 0,
    this.totalCredit = 0,
    this.totalPaid = 0,
    this.writtenOff = 0,
    this.oldestDueAt,
    this.lastActivityAt,
    this.entryCount = 0,
  });

  bool get isSettled => outstanding <= 0.5;

  bool get isOverdue {
    final d = oldestDueAt;
    if (d == null || isSettled) return false;
    return DateTime.now().isAfter(d);
  }

  int get daysOverdue {
    final d = oldestDueAt;
    if (d == null || !isOverdue) return 0;
    return DateTime.now().difference(d).inDays;
  }

  factory UdhaarAccount.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return UdhaarAccount(
      phoneId: doc.id,
      name: (d['name'] as String?)?.trim() ?? '',
      phone: (d['phone'] as String?)?.trim() ?? doc.id,
      outstanding: (d['outstanding'] as num?)?.toDouble() ?? 0,
      totalCredit: (d['totalCredit'] as num?)?.toDouble() ?? 0,
      totalPaid: (d['totalPaid'] as num?)?.toDouble() ?? 0,
      writtenOff: (d['writtenOff'] as num?)?.toDouble() ?? 0,
      oldestDueAt: (d['oldestDueAt'] as Timestamp?)?.toDate(),
      lastActivityAt: (d['lastActivityAt'] as Timestamp?)?.toDate(),
      entryCount: (d['entryCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Customer credit book (udhaar / khata).
///
/// Layout — everything in subcollections, production documents untouched:
///   users/{email}/udhaar/{phoneId}                 rollup
///   users/{email}/udhaar/{phoneId}/entries/{id}    individual movements
class ShopLedgerService {
  ShopLedgerService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _udhaar() =>
      _userRef()?.collection('udhaar');

  CollectionReference<Map<String, dynamic>>? entriesRef(String phoneId) =>
      _udhaar()?.doc(phoneId).collection('entries');

  Stream<List<UdhaarAccount>> watchAccounts({bool onlyOutstanding = false}) {
    final col = _udhaar();
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      var list = snap.docs.map(UdhaarAccount.fromDoc).toList();
      if (onlyOutstanding) {
        list = list.where((a) => !a.isSettled).toList();
      }
      list.sort((a, b) {
        // Overdue first, then largest outstanding, then most recent.
        if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
        final byAmount = b.outstanding.compareTo(a.outstanding);
        if (byAmount != 0) return byAmount;
        final at = a.lastActivityAt ?? DateTime(2000);
        final bt = b.lastActivityAt ?? DateTime(2000);
        return bt.compareTo(at);
      });
      return list;
    });
  }

  Stream<UdhaarAccount?> watchAccount(String phoneId) {
    final col = _udhaar();
    if (col == null) return Stream.value(null);
    return col.doc(phoneId).snapshots().map(
          (s) => s.exists ? UdhaarAccount.fromDoc(s) : null,
        );
  }

  Future<UdhaarAccount?> getAccount(String phoneId) async {
    final col = _udhaar();
    if (col == null) return null;
    final snap = await col.doc(phoneId).get();
    if (!snap.exists) return null;
    return UdhaarAccount.fromDoc(snap);
  }

  Stream<List<LedgerEntry>> watchEntries(String phoneId) {
    final col = entriesRef(phoneId);
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(LedgerEntry.fromDoc).toList();
      list.sort((a, b) {
        final at = a.entryAt ?? a.createdAt ?? DateTime(2000);
        final bt = b.entryAt ?? b.createdAt ?? DateTime(2000);
        return bt.compareTo(at);
      });
      return list;
    });
  }

  /// Adds a movement and rolls the summary forward atomically.
  Future<void> addEntry({
    required String customerName,
    required String phone,
    required LedgerEntry entry,
  }) async {
    final col = _udhaar();
    final phoneId = customerPhoneDocId(phone);
    if (col == null) throw Exception('Not signed in');
    if (phoneId == null) {
      throw Exception('A valid phone number is needed to keep a khata');
    }

    final accountRef = col.doc(phoneId);
    final entryRef = accountRef.collection('entries').doc(generateLedgerEntryId());
    final recordedBy = _auth.currentUser?.email;

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(accountRef);
      final data = snap.data() ?? <String, dynamic>{};

      final outstanding = (data['outstanding'] as num?)?.toDouble() ?? 0;
      final totalCredit = (data['totalCredit'] as num?)?.toDouble() ?? 0;
      final totalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0;
      final writtenOff = (data['writtenOff'] as num?)?.toDouble() ?? 0;
      final entryCount = (data['entryCount'] as num?)?.toInt() ?? 0;
      final oldestDue = (data['oldestDueAt'] as Timestamp?)?.toDate();

      final nextOutstanding = outstanding + entry.delta;

      DateTime? nextOldestDue = oldestDue;
      if (entry.type == LedgerEntryType.credit && entry.dueAt != null) {
        if (nextOldestDue == null || entry.dueAt!.isBefore(nextOldestDue)) {
          nextOldestDue = entry.dueAt;
        }
      }
      // Fully settled clears the ageing clock.
      if (nextOutstanding <= 0.5) nextOldestDue = null;

      txn.set(
        accountRef,
        {
          'name': customerName.trim(),
          'phone': phone.trim(),
          'outstanding': nextOutstanding,
          'totalCredit': entry.type == LedgerEntryType.credit
              ? totalCredit + entry.amount
              : totalCredit,
          'totalPaid': entry.type == LedgerEntryType.payment
              ? totalPaid + entry.amount
              : totalPaid,
          'writtenOff': entry.type == LedgerEntryType.writeOff
              ? writtenOff + entry.amount
              : writtenOff,
          'entryCount': entryCount + 1,
          'oldestDueAt':
              nextOldestDue == null ? null : Timestamp.fromDate(nextOldestDue),
          'lastActivityAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      txn.set(entryRef, {
        ...entry.toMap(),
        'recordedBy': entry.recordedBy ?? recordedBy,
      });
    });
  }

  /// Convenience: books the unpaid balance of a bill as udhaar.
  Future<void> recordBillBalance({
    required String customerName,
    required String? phone,
    required String billNo,
    required double balance,
    required int dueInDays,
    DateTime? billedAt,
  }) async {
    if (balance <= 0.5) return;
    if (customerPhoneDocId(phone) == null) return;
    final base = billedAt ?? DateTime.now();
    await addEntry(
      customerName: customerName,
      phone: phone!,
      entry: LedgerEntry(
        id: '',
        type: LedgerEntryType.credit,
        amount: balance,
        source: LedgerSource.bill,
        sourceId: billNo,
        note: 'Balance on bill $billNo',
        dueAt: base.add(Duration(days: dueInDays)),
        entryAt: base,
      ),
    );
  }

  Future<void> recordPayment({
    required String customerName,
    required String phone,
    required double amount,
    required String mode,
    String? note,
    String? againstBillNo,
    DateTime? paidAt,
  }) async {
    await addEntry(
      customerName: customerName,
      phone: phone,
      entry: LedgerEntry(
        id: '',
        type: LedgerEntryType.payment,
        amount: amount,
        source: againstBillNo == null ? LedgerSource.manual : LedgerSource.bill,
        sourceId: againstBillNo,
        mode: mode,
        note: note,
        entryAt: paidAt,
      ),
    );
  }

  /// Removes an entry and reverses its effect on the summary.
  Future<void> deleteEntry(String phoneId, LedgerEntry entry) async {
    final col = _udhaar();
    if (col == null) throw Exception('Not signed in');
    final accountRef = col.doc(phoneId);
    final entryRef = accountRef.collection('entries').doc(entry.id);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(accountRef);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};
      final outstanding = (data['outstanding'] as num?)?.toDouble() ?? 0;
      final totalCredit = (data['totalCredit'] as num?)?.toDouble() ?? 0;
      final totalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0;
      final writtenOff = (data['writtenOff'] as num?)?.toDouble() ?? 0;
      final entryCount = (data['entryCount'] as num?)?.toInt() ?? 0;

      txn.set(
        accountRef,
        {
          'outstanding': outstanding - entry.delta,
          'totalCredit': entry.type == LedgerEntryType.credit
              ? (totalCredit - entry.amount).clamp(0, double.infinity)
              : totalCredit,
          'totalPaid': entry.type == LedgerEntryType.payment
              ? (totalPaid - entry.amount).clamp(0, double.infinity)
              : totalPaid,
          'writtenOff': entry.type == LedgerEntryType.writeOff
              ? (writtenOff - entry.amount).clamp(0, double.infinity)
              : writtenOff,
          'entryCount': (entryCount - 1).clamp(0, 1 << 30),
          'lastActivityAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      txn.delete(entryRef);
    });
  }

  /// Recomputes a summary from its entries — a repair hatch if a write was
  /// ever lost mid-transaction.
  Future<void> rebuildAccount(String phoneId) async {
    final col = _udhaar();
    final entries = entriesRef(phoneId);
    if (col == null || entries == null) throw Exception('Not signed in');
    final snap = await entries.get();
    final list = snap.docs.map(LedgerEntry.fromDoc).toList();

    var outstanding = 0.0;
    var credit = 0.0;
    var paid = 0.0;
    var written = 0.0;
    DateTime? oldestDue;
    for (final e in list) {
      outstanding += e.delta;
      if (e.type == LedgerEntryType.credit) {
        credit += e.amount;
        if (e.dueAt != null &&
            (oldestDue == null || e.dueAt!.isBefore(oldestDue))) {
          oldestDue = e.dueAt;
        }
      } else if (e.type == LedgerEntryType.payment) {
        paid += e.amount;
      } else if (e.type == LedgerEntryType.writeOff) {
        written += e.amount;
      }
    }
    if (outstanding <= 0.5) oldestDue = null;

    await col.doc(phoneId).set({
      'outstanding': outstanding,
      'totalCredit': credit,
      'totalPaid': paid,
      'writtenOff': written,
      'entryCount': list.length,
      'oldestDueAt': oldestDue == null ? null : Timestamp.fromDate(oldestDue),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static double totalOutstanding(List<UdhaarAccount> accounts) =>
      accounts.fold<double>(0, (s, a) => s + max(0, a.outstanding));

  static double totalOverdue(List<UdhaarAccount> accounts) => accounts
      .where((a) => a.isOverdue)
      .fold<double>(0, (s, a) => s + max(0, a.outstanding));

  /// Buckets outstanding money by age for the collections report.
  static Map<String, double> ageingBuckets(List<UdhaarAccount> accounts) {
    final out = <String, double>{
      'Not due': 0,
      '0-30d': 0,
      '31-60d': 0,
      '61-90d': 0,
      '90d+': 0,
    };
    for (final a in accounts) {
      if (a.isSettled) continue;
      if (!a.isOverdue) {
        out['Not due'] = out['Not due']! + a.outstanding;
        continue;
      }
      final d = a.daysOverdue;
      final key = d <= 30
          ? '0-30d'
          : d <= 60
              ? '31-60d'
              : d <= 90
                  ? '61-90d'
                  : '90d+';
      out[key] = out[key]! + a.outstanding;
    }
    return out;
  }
}
