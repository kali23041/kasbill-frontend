import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';

class ShopProfile {
  final String? shopName;
  final String? ownerName;
  final String? phone;
  final String? whatsapp;
  final String? alternatePhone;
  final String? email;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;
  final String? shopType; // retail | wholesale | both | manufacturing
  final String? establishedYear;
  final String? tagline;
  final String? description;
  final String? bisHallmarkNo;
  final String? jewellersAssociationId;
  final String? tradeLicense;
  final String? openTime;
  final String? closeTime;
  final String? weeklyOff;
  final String? upiId;
  final String? bankName;
  final String? accountName;
  final String? accountNumber;
  final String? ifsc;
  final String? instagram;
  final String? website;
  final String? logoBase64;
  final bool hasGst;
  final DateTime? updatedAt;

  const ShopProfile({
    this.shopName,
    this.ownerName,
    this.phone,
    this.whatsapp,
    this.alternatePhone,
    this.email,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
    this.shopType,
    this.establishedYear,
    this.tagline,
    this.description,
    this.bisHallmarkNo,
    this.jewellersAssociationId,
    this.tradeLicense,
    this.openTime,
    this.closeTime,
    this.weeklyOff,
    this.upiId,
    this.bankName,
    this.accountName,
    this.accountNumber,
    this.ifsc,
    this.instagram,
    this.website,
    this.logoBase64,
    this.hasGst = false,
    this.updatedAt,
  });

  static bool _filled(String? v) => v != null && v.trim().isNotEmpty;

  /// Fields counted toward profile completion.
  List<({String key, String label, bool done})> get completionChecklist {
    final bankOk = _filled(upiId) ||
        (_filled(accountNumber) && _filled(ifsc) && _filled(accountName));
    final licenseOk =
        _filled(bisHallmarkNo) || _filled(jewellersAssociationId) || _filled(tradeLicense);
    final hoursOk = _filled(openTime) && _filled(closeTime);

    return [
      (key: 'shopName', label: 'Shop name', done: _filled(shopName)),
      (key: 'ownerName', label: 'Owner name', done: _filled(ownerName)),
      (key: 'phone', label: 'Phone', done: _filled(phone)),
      (key: 'address', label: 'Address', done: _filled(addressLine1)),
      (key: 'city', label: 'City', done: _filled(city)),
      (key: 'state', label: 'State', done: _filled(state)),
      (key: 'pincode', label: 'PIN code', done: _filled(pincode)),
      (key: 'shopType', label: 'Shop type', done: _filled(shopType)),
      (key: 'hours', label: 'Business hours', done: hoursOk),
      (key: 'payments', label: 'UPI / bank', done: bankOk),
      (key: 'license', label: 'License / BIS', done: licenseOk),
      (key: 'gst', label: 'GSTIN', done: hasGst),
      (key: 'whatsapp', label: 'WhatsApp', done: _filled(whatsapp)),
      (key: 'logo', label: 'Shop logo', done: _filled(logoBase64)),
    ];
  }

  int get completedCount =>
      completionChecklist.where((e) => e.done).length;

  int get totalCount => completionChecklist.length;

  double get completionPercent =>
      totalCount == 0 ? 0 : (completedCount / totalCount) * 100;

  bool get isComplete => completedCount == totalCount;

  String get displayName {
    if (_filled(shopName)) return shopName!.trim();
    if (_filled(ownerName)) return ownerName!.trim();
    return 'Shop profile';
  }

  factory ShopProfile.fromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return const ShopProfile();
    final p = data['shopProfile'];
    final map = p is Map<String, dynamic>
        ? p
        : (p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{});

    final gst = (data['gstNumber'] as String?)?.trim() ?? '';

    return ShopProfile(
      shopName: map['shopName'] as String?,
      ownerName: map['ownerName'] as String?,
      phone: map['phone'] as String?,
      whatsapp: map['whatsapp'] as String?,
      alternatePhone: map['alternatePhone'] as String?,
      email: map['email'] as String? ?? data['email'] as String?,
      addressLine1: map['addressLine1'] as String?,
      addressLine2: map['addressLine2'] as String?,
      city: map['city'] as String?,
      state: map['state'] as String?,
      pincode: map['pincode'] as String?,
      shopType: map['shopType'] as String?,
      establishedYear: map['establishedYear'] as String?,
      tagline: map['tagline'] as String?,
      description: map['description'] as String?,
      bisHallmarkNo: map['bisHallmarkNo'] as String?,
      jewellersAssociationId: map['jewellersAssociationId'] as String?,
      tradeLicense: map['tradeLicense'] as String?,
      openTime: map['openTime'] as String?,
      closeTime: map['closeTime'] as String?,
      weeklyOff: map['weeklyOff'] as String?,
      upiId: map['upiId'] as String?,
      bankName: map['bankName'] as String?,
      accountName: map['accountName'] as String?,
      accountNumber: map['accountNumber'] as String?,
      ifsc: map['ifsc'] as String?,
      instagram: map['instagram'] as String?,
      website: map['website'] as String?,
      logoBase64: map['logoBase64'] as String?,
      hasGst: gst.length >= 15,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'shopName': shopName?.trim(),
      'ownerName': ownerName?.trim(),
      'phone': phone?.trim(),
      'whatsapp': whatsapp?.trim(),
      'alternatePhone': alternatePhone?.trim(),
      'email': email?.trim(),
      'addressLine1': addressLine1?.trim(),
      'addressLine2': addressLine2?.trim(),
      'city': city?.trim(),
      'state': state?.trim(),
      'pincode': pincode?.trim(),
      'shopType': shopType,
      'establishedYear': establishedYear?.trim(),
      'tagline': tagline?.trim(),
      'description': description?.trim(),
      'bisHallmarkNo': bisHallmarkNo?.trim(),
      'jewellersAssociationId': jewellersAssociationId?.trim(),
      'tradeLicense': tradeLicense?.trim(),
      'openTime': openTime?.trim(),
      'closeTime': closeTime?.trim(),
      'weeklyOff': weeklyOff?.trim(),
      'upiId': upiId?.trim(),
      'bankName': bankName?.trim(),
      'accountName': accountName?.trim(),
      'accountNumber': accountNumber?.trim(),
      'ifsc': ifsc?.trim().toUpperCase(),
      'instagram': instagram?.trim(),
      'website': website?.trim(),
      'logoBase64': logoBase64,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class ShopProfileService {
  ShopProfileService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  Stream<ShopProfile> watchProfile() {
    final ref = _userRef();
    if (ref == null) return Stream.value(const ShopProfile());
    return ref.snapshots().map((snap) => ShopProfile.fromUserDoc(snap.data()));
  }

  Future<void> saveProfile(ShopProfile profile) async {
    final ref = _userRef();
    if (ref == null) throw Exception('Not signed in');

    await ref.set({
      'shopProfile': profile.toFirestoreMap(),
      if (profile.shopName != null && profile.shopName!.trim().isNotEmpty)
        'displayName': profile.shopName!.trim(),
    }, SetOptions(merge: true));
  }
}
