import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';

class ShopGstSettings {
  final String? gstNumber;
  final double gstPercent;
  final DateTime? updatedAt;

  const ShopGstSettings({
    this.gstNumber,
    this.gstPercent = 3,
    this.updatedAt,
  });

  bool get isConfigured {
    final n = gstNumber?.trim() ?? '';
    return n.length >= 15;
  }

  factory ShopGstSettings.fromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return const ShopGstSettings();
    return ShopGstSettings(
      gstNumber: data['gstNumber'] as String?,
      gstPercent: (data['gstPercent'] as num?)?.toDouble() ?? 3,
      updatedAt: (data['gstUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ShopGstService {
  ShopGstService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  Stream<ShopGstSettings> watchSettings() {
    final ref = _userRef();
    if (ref == null) {
      return Stream.value(const ShopGstSettings());
    }
    return ref.snapshots().map(
          (snap) => ShopGstSettings.fromUserDoc(snap.data()),
        );
  }

  Future<ShopGstSettings> getSettings() async {
    final ref = _userRef();
    if (ref == null) return const ShopGstSettings();
    final snap = await ref.get();
    return ShopGstSettings.fromUserDoc(snap.data());
  }

  Future<void> saveSettings({
    required String gstNumber,
    required double gstPercent,
  }) async {
    final ref = _userRef();
    if (ref == null) throw Exception('Not signed in');

    final cleaned = gstNumber.trim().toUpperCase();
    if (cleaned.length != 15) {
      throw Exception('GSTIN must be 15 characters');
    }
    if (gstPercent < 0 || gstPercent > 100) {
      throw Exception('Enter a valid GST %');
    }

    await ref.set({
      'gstNumber': cleaned,
      'gstPercent': gstPercent,
      'gstUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearSettings() async {
    final ref = _userRef();
    if (ref == null) throw Exception('Not signed in');
    await ref.set({
      'gstNumber': FieldValue.delete(),
      'gstPercent': FieldValue.delete(),
      'gstUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
