import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';

String generateSchemeId() {
  final now = DateTime.now();
  final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}';
  final rand = Random().nextInt(9000) + 1000;
  return 'SCH$stamp$rand';
}

String generateMemberNo(String schemeId, int sequence) =>
    '$schemeId-${sequence.toString().padLeft(3, '0')}';

/// How the shop rewards a member who completes the plan.
class SchemeBonusType {
  /// Shop pays the final installment (the classic 11+1).
  static const freeInstallment = 'freeInstallment';

  /// A percentage of everything collected.
  static const percent = 'percent';

  /// A flat rupee amount.
  static const flat = 'flat';

  /// No bonus — the member simply accumulates grams.
  static const none = 'none';

  static const all = [freeInstallment, percent, flat, none];

  static String label(String type) {
    switch (type) {
      case percent:
        return 'Percent of collection';
      case flat:
        return 'Flat amount';
      case none:
        return 'No bonus';
      default:
        return 'Free installment (11+1)';
    }
  }
}

/// What the member is actually saving toward.
class SchemeAccrual {
  /// Every installment buys grams at that day's rate — protects the customer
  /// from price rises and is the most common jewellery scheme.
  static const grams = 'grams';

  /// Plain rupee savings, redeemed at maturity against any purchase.
  static const rupees = 'rupees';

  static const all = [grams, rupees];

  static String label(String v) =>
      v == grams ? 'Accumulate grams' : 'Accumulate rupees';
}

class SavingsScheme {
  final String id;
  final String name;
  final double monthlyAmount;
  final int durationMonths;
  final String accrual; // grams | rupees
  final String metalType; // gold | silver
  final int? karat;
  final String bonusType;
  final double bonusValue;
  final bool allowCustomAmount;
  final String status; // active | closed
  final String? terms;
  final String? notes;
  final int memberCount;
  final double collected;
  final DateTime? startedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SavingsScheme({
    required this.id,
    required this.name,
    required this.monthlyAmount,
    required this.durationMonths,
    this.accrual = SchemeAccrual.grams,
    this.metalType = 'gold',
    this.karat,
    this.bonusType = SchemeBonusType.freeInstallment,
    this.bonusValue = 1,
    this.allowCustomAmount = false,
    this.status = 'active',
    this.terms,
    this.notes,
    this.memberCount = 0,
    this.collected = 0,
    this.startedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'active';

  /// "11 + 1" style label for the card.
  String get planLabel {
    if (bonusType == SchemeBonusType.freeInstallment) {
      return '$durationMonths + ${bonusValue.toInt()}';
    }
    return '$durationMonths months';
  }

  double get totalPayable => monthlyAmount * durationMonths;

  /// Rupee value of the bonus for a member who paid everything.
  double bonusAmountFor(double paidTotal, int paidCount) {
    switch (bonusType) {
      case SchemeBonusType.freeInstallment:
        return monthlyAmount * bonusValue;
      case SchemeBonusType.percent:
        return paidTotal * (bonusValue / 100);
      case SchemeBonusType.flat:
        return bonusValue;
      default:
        return 0;
    }
  }

  factory SavingsScheme.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SavingsScheme(
      id: doc.id,
      name: (d['name'] as String?)?.trim() ?? '',
      monthlyAmount: (d['monthlyAmount'] as num?)?.toDouble() ?? 0,
      durationMonths: (d['durationMonths'] as num?)?.toInt() ?? 11,
      accrual: (d['accrual'] as String?) ?? SchemeAccrual.grams,
      metalType: (d['metalType'] as String?) ?? 'gold',
      karat: (d['karat'] as num?)?.toInt(),
      bonusType: (d['bonusType'] as String?) ?? SchemeBonusType.freeInstallment,
      bonusValue: (d['bonusValue'] as num?)?.toDouble() ?? 1,
      allowCustomAmount: d['allowCustomAmount'] as bool? ?? false,
      status: (d['status'] as String?) ?? 'active',
      terms: d['terms'] as String?,
      notes: d['notes'] as String?,
      memberCount: (d['memberCount'] as num?)?.toInt() ?? 0,
      collected: (d['collected'] as num?)?.toDouble() ?? 0,
      startedAt: (d['startedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    final map = <String, dynamic>{
      'name': name.trim(),
      'monthlyAmount': monthlyAmount,
      'durationMonths': durationMonths,
      'accrual': accrual,
      'metalType': metalType,
      'karat': karat,
      'bonusType': bonusType,
      'bonusValue': bonusValue,
      'allowCustomAmount': allowCustomAmount,
      'status': status,
      'terms': terms?.trim(),
      'notes': notes?.trim(),
      'startedAt': startedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(startedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (includeCreatedAt) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['memberCount'] = 0;
      map['collected'] = 0;
    }
    return map;
  }
}

class SchemeMember {
  final String id;
  final String memberNo;
  final String name;
  final String phone;
  final String? address;
  final String? nomineeName;
  final String status; // active | matured | redeemed | cancelled
  final int paidCount;
  final double paidAmount;
  final double gramsAccrued;
  final DateTime? joinedAt;
  final DateTime? maturesAt;
  final DateTime? lastPaidAt;
  final DateTime? nextDueAt;
  final String? redeemedBillNo;
  final DateTime? redeemedAt;
  final String? notes;

  const SchemeMember({
    required this.id,
    required this.memberNo,
    required this.name,
    required this.phone,
    this.address,
    this.nomineeName,
    this.status = 'active',
    this.paidCount = 0,
    this.paidAmount = 0,
    this.gramsAccrued = 0,
    this.joinedAt,
    this.maturesAt,
    this.lastPaidAt,
    this.nextDueAt,
    this.redeemedBillNo,
    this.redeemedAt,
    this.notes,
  });

  bool get isActive => status == 'active';

  bool get isDue {
    final d = nextDueAt;
    if (d == null || !isActive) return false;
    return DateTime.now().isAfter(d);
  }

  int get daysOverdue {
    final d = nextDueAt;
    if (d == null || !isDue) return 0;
    return DateTime.now().difference(d).inDays;
  }

  factory SchemeMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SchemeMember(
      id: doc.id,
      memberNo: (d['memberNo'] as String?) ?? doc.id,
      name: (d['name'] as String?)?.trim() ?? '',
      phone: (d['phone'] as String?)?.trim() ?? '',
      address: d['address'] as String?,
      nomineeName: d['nomineeName'] as String?,
      status: (d['status'] as String?) ?? 'active',
      paidCount: (d['paidCount'] as num?)?.toInt() ?? 0,
      paidAmount: (d['paidAmount'] as num?)?.toDouble() ?? 0,
      gramsAccrued: (d['gramsAccrued'] as num?)?.toDouble() ?? 0,
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate(),
      maturesAt: (d['maturesAt'] as Timestamp?)?.toDate(),
      lastPaidAt: (d['lastPaidAt'] as Timestamp?)?.toDate(),
      nextDueAt: (d['nextDueAt'] as Timestamp?)?.toDate(),
      redeemedBillNo: d['redeemedBillNo'] as String?,
      redeemedAt: (d['redeemedAt'] as Timestamp?)?.toDate(),
      notes: d['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    final map = <String, dynamic>{
      'memberNo': memberNo,
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address?.trim(),
      'nomineeName': nomineeName?.trim(),
      'status': status,
      'notes': notes?.trim(),
      'maturesAt': maturesAt == null ? null : Timestamp.fromDate(maturesAt!),
      'nextDueAt': nextDueAt == null ? null : Timestamp.fromDate(nextDueAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (includeCreatedAt) {
      map['joinedAt'] = joinedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(joinedAt!);
      map['createdAt'] = FieldValue.serverTimestamp();
      map['paidCount'] = 0;
      map['paidAmount'] = 0;
      map['gramsAccrued'] = 0;
    }
    return map;
  }
}

class SchemeInstallment {
  final String id;
  final int monthIndex;
  final double amount;
  final String mode;
  final double? ratePerGram;
  final double grams;
  final String? receiptNo;
  final String? note;
  final DateTime? paidAt;

  const SchemeInstallment({
    required this.id,
    required this.monthIndex,
    required this.amount,
    this.mode = 'cash',
    this.ratePerGram,
    this.grams = 0,
    this.receiptNo,
    this.note,
    this.paidAt,
  });

  factory SchemeInstallment.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return SchemeInstallment(
      id: doc.id,
      monthIndex: (d['monthIndex'] as num?)?.toInt() ?? 0,
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      mode: (d['mode'] as String?) ?? 'cash',
      ratePerGram: (d['ratePerGram'] as num?)?.toDouble(),
      grams: (d['grams'] as num?)?.toDouble() ?? 0,
      receiptNo: d['receiptNo'] as String?,
      note: d['note'] as String?,
      paidAt: (d['paidAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'monthIndex': monthIndex,
        'amount': amount,
        'mode': mode,
        'ratePerGram': ratePerGram,
        'grams': grams,
        'receiptNo': receiptNo,
        'note': note?.trim(),
        'paidAt':
            paidAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(paidAt!),
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// Monthly gold savings schemes (the paper "chit" every jeweller runs).
///
/// Layout:
///   users/{email}/schemes/{schemeId}
///   users/{email}/schemes/{schemeId}/members/{memberId}
///   users/{email}/schemes/{schemeId}/members/{memberId}/installments/{id}
class ShopSchemesService {
  ShopSchemesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _schemes() =>
      _userRef()?.collection('schemes');

  CollectionReference<Map<String, dynamic>>? membersRef(String schemeId) =>
      _schemes()?.doc(schemeId).collection('members');

  CollectionReference<Map<String, dynamic>>? installmentsRef(
    String schemeId,
    String memberId,
  ) =>
      membersRef(schemeId)?.doc(memberId).collection('installments');

  Stream<List<SavingsScheme>> watchSchemes() {
    final col = _schemes();
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(SavingsScheme.fromDoc).toList();
      list.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        final at = a.createdAt ?? DateTime(2000);
        final bt = b.createdAt ?? DateTime(2000);
        return bt.compareTo(at);
      });
      return list;
    });
  }

  Stream<SavingsScheme?> watchScheme(String schemeId) {
    final col = _schemes();
    if (col == null) return Stream.value(null);
    return col.doc(schemeId).snapshots().map(
          (s) => s.exists ? SavingsScheme.fromDoc(s) : null,
        );
  }

  Future<SavingsScheme> createScheme(SavingsScheme draft) async {
    final col = _schemes();
    if (col == null) throw Exception('Not signed in');
    final id = draft.id.isNotEmpty ? draft.id : generateSchemeId();
    await col.doc(id).set(draft.toMap(includeCreatedAt: true));
    return SavingsScheme(
      id: id,
      name: draft.name,
      monthlyAmount: draft.monthlyAmount,
      durationMonths: draft.durationMonths,
      accrual: draft.accrual,
      metalType: draft.metalType,
      karat: draft.karat,
      bonusType: draft.bonusType,
      bonusValue: draft.bonusValue,
      allowCustomAmount: draft.allowCustomAmount,
      status: draft.status,
      terms: draft.terms,
      notes: draft.notes,
      startedAt: draft.startedAt ?? DateTime.now(),
    );
  }

  Future<void> updateScheme(SavingsScheme scheme) async {
    final col = _schemes();
    if (col == null) throw Exception('Not signed in');
    await col.doc(scheme.id).set(scheme.toMap(), SetOptions(merge: true));
  }

  Future<void> closeScheme(String schemeId) async {
    final col = _schemes();
    if (col == null) throw Exception('Not signed in');
    await col.doc(schemeId).set({
      'status': 'closed',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteScheme(String schemeId) async {
    final col = _schemes();
    final members = membersRef(schemeId);
    if (col == null || members == null) throw Exception('Not signed in');
    // Firestore does not cascade — clear members (and their installments)
    // before removing the parent so no orphans are left behind.
    final memberSnap = await members.get();
    for (final m in memberSnap.docs) {
      final inst = await m.reference.collection('installments').get();
      for (final i in inst.docs) {
        await i.reference.delete();
      }
      await m.reference.delete();
    }
    await col.doc(schemeId).delete();
  }

  Stream<List<SchemeMember>> watchMembers(String schemeId) {
    final col = membersRef(schemeId);
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(SchemeMember.fromDoc).toList();
      list.sort((a, b) {
        if (a.isDue != b.isDue) return a.isDue ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    });
  }

  Stream<List<SchemeInstallment>> watchInstallments(
    String schemeId,
    String memberId,
  ) {
    final col = installmentsRef(schemeId, memberId);
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(SchemeInstallment.fromDoc).toList();
      list.sort((a, b) => a.monthIndex.compareTo(b.monthIndex));
      return list;
    });
  }

  Future<SchemeMember> enrollMember({
    required SavingsScheme scheme,
    required String name,
    required String phone,
    String? address,
    String? nomineeName,
    String? notes,
    DateTime? joinedAt,
  }) async {
    final col = membersRef(scheme.id);
    final schemes = _schemes();
    if (col == null || schemes == null) throw Exception('Not signed in');

    final joined = joinedAt ?? DateTime.now();
    final matures = DateTime(
      joined.year,
      joined.month + scheme.durationMonths,
      joined.day,
    );
    final nextDue = DateTime(joined.year, joined.month + 1, joined.day);

    final memberRef = col.doc();
    final sequence = (await col.count().get()).count ?? 0;
    final member = SchemeMember(
      id: memberRef.id,
      memberNo: generateMemberNo(scheme.id, sequence + 1),
      name: name,
      phone: phone,
      address: address,
      nomineeName: nomineeName,
      notes: notes,
      joinedAt: joined,
      maturesAt: matures,
      nextDueAt: nextDue,
    );

    final batch = _firestore.batch();
    batch.set(memberRef, member.toMap(includeCreatedAt: true));
    batch.set(
      schemes.doc(scheme.id),
      {
        'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    return member;
  }

  Future<void> updateMember(String schemeId, SchemeMember member) async {
    final col = membersRef(schemeId);
    if (col == null) throw Exception('Not signed in');
    await col.doc(member.id).set(member.toMap(), SetOptions(merge: true));
  }

  /// Records one installment and rolls the member + scheme totals forward.
  Future<void> payInstallment({
    required SavingsScheme scheme,
    required SchemeMember member,
    required double amount,
    required String mode,
    double? ratePerGram,
    String? receiptNo,
    String? note,
    DateTime? paidAt,
  }) async {
    final memberCol = membersRef(scheme.id);
    final schemeCol = _schemes();
    if (memberCol == null || schemeCol == null) {
      throw Exception('Not signed in');
    }

    final memberRef = memberCol.doc(member.id);
    final installRef = memberRef.collection('installments').doc();
    final when = paidAt ?? DateTime.now();
    final grams = (scheme.accrual == SchemeAccrual.grams &&
            ratePerGram != null &&
            ratePerGram > 0)
        ? amount / ratePerGram
        : 0.0;

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(memberRef);
      final d = snap.data() ?? <String, dynamic>{};
      final paidCount = (d['paidCount'] as num?)?.toInt() ?? 0;
      final paidAmount = (d['paidAmount'] as num?)?.toDouble() ?? 0;
      final gramsAccrued = (d['gramsAccrued'] as num?)?.toDouble() ?? 0;

      final nextCount = paidCount + 1;
      final completed = nextCount >= scheme.durationMonths;
      final nextDue = completed
          ? null
          : DateTime(when.year, when.month + 1, when.day);

      txn.set(installRef, {
        ...SchemeInstallment(
          id: installRef.id,
          monthIndex: nextCount,
          amount: amount,
          mode: mode,
          ratePerGram: ratePerGram,
          grams: grams,
          receiptNo: receiptNo,
          note: note,
          paidAt: when,
        ).toMap(),
      });

      txn.set(
        memberRef,
        {
          'paidCount': nextCount,
          'paidAmount': paidAmount + amount,
          'gramsAccrued': gramsAccrued + grams,
          'lastPaidAt': Timestamp.fromDate(when),
          'nextDueAt': nextDue == null ? null : Timestamp.fromDate(nextDue),
          'status': completed ? 'matured' : 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      txn.set(
        schemeCol.doc(scheme.id),
        {
          'collected': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Marks a matured member as redeemed against a bill.
  Future<void> redeemMember({
    required String schemeId,
    required SchemeMember member,
    required String billNo,
  }) async {
    final col = membersRef(schemeId);
    if (col == null) throw Exception('Not signed in');
    await col.doc(member.id).set({
      'status': 'redeemed',
      'redeemedBillNo': billNo,
      'redeemedAt': FieldValue.serverTimestamp(),
      'nextDueAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeMember(String schemeId, String memberId) async {
    final col = membersRef(schemeId);
    final schemes = _schemes();
    if (col == null || schemes == null) throw Exception('Not signed in');
    final inst = await col.doc(memberId).collection('installments').get();
    for (final i in inst.docs) {
      await i.reference.delete();
    }
    await col.doc(memberId).delete();
    await schemes.doc(schemeId).set({
      'memberCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Total value owed to a member at maturity: what they paid plus the bonus.
  static double maturityValue(SavingsScheme scheme, SchemeMember member) {
    final bonus = scheme.bonusAmountFor(member.paidAmount, member.paidCount);
    return member.paidAmount + bonus;
  }
}
