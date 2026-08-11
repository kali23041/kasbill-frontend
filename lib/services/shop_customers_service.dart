import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';

/// Digits-only phone used as Firestore doc id under users/{email}/customers.
String? customerPhoneDocId(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 6) return null;
  return digits;
}

class ShopCustomer {
  final String phoneId;
  final String name;
  final String phone;
  final String? address;
  final String? gstin;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int billCount;

  const ShopCustomer({
    required this.phoneId,
    required this.name,
    required this.phone,
    this.address,
    this.gstin,
    this.createdAt,
    this.updatedAt,
    this.billCount = 0,
  });

  factory ShopCustomer.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return ShopCustomer(
      phoneId: doc.id,
      name: (d['name'] as String?)?.trim() ?? '',
      phone: (d['phone'] as String?)?.trim() ?? doc.id,
      address: d['address'] as String?,
      gstin: d['gstin'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      billCount: (d['billCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    final map = <String, dynamic>{
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address?.trim(),
      'gstin': gstin?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (includeCreatedAt) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['billCount'] = billCount;
    }
    return map;
  }
}

class ShopCustomersService {
  ShopCustomersService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _customers() =>
      _userRef()?.collection('customers');

  Stream<List<ShopCustomer>> watchCustomers() {
    final col = _customers();
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(ShopCustomer.fromDoc).toList();
      list.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return list;
    });
  }

  /// Creates or updates customer by phone doc id. No-op if phone invalid.
  /// Set [bumpBillCount] true when a new bill is created for this customer.
  Future<void> upsertFromBill({
    required String name,
    required String? phone,
    String? address,
    String? gstin,
    bool bumpBillCount = true,
  }) async {
    final col = _customers();
    final phoneId = customerPhoneDocId(phone);
    if (col == null || phoneId == null || name.trim().isEmpty) return;

    final ref = col.doc(phoneId);
    final existing = await ref.get();
    final data = <String, dynamic>{
      'name': name.trim(),
      'phone': phone!.trim(),
      'address': address?.trim().isEmpty == true ? null : address?.trim(),
      'gstin': gstin?.trim().isEmpty == true ? null : gstin?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (existing.exists) {
      if (bumpBillCount) data['billCount'] = FieldValue.increment(1);
      await ref.set(data, SetOptions(merge: true));
    } else {
      await ref.set({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'billCount': bumpBillCount ? 1 : 0,
      });
    }
  }

  static List<ShopCustomer> filterSuggestions(
    List<ShopCustomer> all,
    String query, {
    int limit = 6,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final digits = q.replaceAll(RegExp(r'\D'), '');
    final matches = all.where((c) {
      final nameHit = c.name.toLowerCase().contains(q);
      final phoneHit = digits.isNotEmpty &&
          c.phoneId.contains(digits);
      final phoneRawHit = c.phone.toLowerCase().contains(q);
      return nameHit || phoneHit || phoneRawHit;
    }).toList();
    if (matches.length <= limit) return matches;
    return matches.take(limit).toList();
  }
}
