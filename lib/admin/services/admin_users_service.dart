import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/auth_helpers.dart';
import '../admin_config.dart';

class AdminUser {
  final String email;
  final String displayName;
  final String role; // Shop | Admin
  final String plan; // free | premium
  final String? planBilling;
  final String? planStatus; // trial | active | expired
  final int? planAmount;
  final DateTime? planStartedOn;
  final DateTime? planExpiresOn;
  final String? planSource;
  final String? photoURL;
  final DateTime? lastLogin;
  final DateTime? createdAt;

  const AdminUser({
    required this.email,
    required this.displayName,
    required this.role,
    required this.plan,
    this.planBilling,
    this.planStatus,
    this.planAmount,
    this.planStartedOn,
    this.planExpiresOn,
    this.planSource,
    this.photoURL,
    this.lastLogin,
    this.createdAt,
  });

  bool get isAdmin => AdminUsersService.isAdminRole(role);

  String get statusLabel {
    switch (planStatus) {
      case 'trial':
        return 'Trial';
      case 'active':
        return 'Active';
      case 'expired':
        return 'Expired';
      default:
        return 'None';
    }
  }

  bool get isExpiringToday {
    if (planExpiresOn == null) return false;
    if (planStatus != 'trial' && planStatus != 'active') return false;
    final e = planExpiresOn!;
    final now = DateTime.now();
    return e.year == now.year && e.month == now.month && e.day == now.day;
  }

  bool get isExpiredLive {
    if (planStatus == 'expired') return true;
    if (planExpiresOn == null) return planStatus == null;
    return !planExpiresOn!.isAfter(DateTime.now());
  }

  factory AdminUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AdminUser(
      email: (d['email'] as String?)?.trim().toLowerCase() ?? doc.id,
      displayName: (d['displayName'] as String?)?.trim().isNotEmpty == true
          ? (d['displayName'] as String).trim()
          : ((d['shopName'] as String?)?.trim().isNotEmpty == true
              ? (d['shopName'] as String).trim()
              : doc.id),
      role: (d['role'] as String?) ?? 'Shop',
      plan: (d['plan'] as String?) ?? 'free',
      planBilling: d['planBilling'] as String?,
      planStatus: d['planStatus'] as String?,
      planAmount: (d['planAmount'] as num?)?.toInt(),
      planStartedOn: (d['planStartedOn'] as Timestamp?)?.toDate(),
      planExpiresOn: (d['planExpiresOn'] as Timestamp?)?.toDate(),
      planSource: d['planSource'] as String?,
      photoURL: d['photoURL'] as String?,
      lastLogin: (d['lastLogin'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AdminUsersService {
  AdminUsersService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Current signed-in user's role from Firestore.
  Stream<String?> watchCurrentRole() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return Stream.value(null);
    return _users.doc(email).snapshots().map((snap) {
      final role = (snap.data()?['role'] as String?)?.trim();
      return role;
    });
  }

  static bool isAdminRole(String? role) {
    final r = role?.trim().toLowerCase();
    return r == 'admin';
  }

  Future<bool> currentUserIsAdmin() async {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return false;
    if (AdminConfig.isAllowlisted(email)) return true;
    final snap = await _users.doc(email).get();
    return isAdminRole(snap.data()?['role'] as String?);
  }

  Stream<bool> watchCurrentUserIsAdmin() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return Stream.value(false);
    if (AdminConfig.isAllowlisted(email)) return Stream.value(true);
    return watchCurrentRole().map(isAdminRole);
  }

  /// Promotes the signed-in user to Admin (for first-time setup).
  Future<void> grantCurrentUserAdmin() async {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) throw Exception('Not signed in');
    await _users.doc(email).set(
      {
        'role': 'Admin',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<List<AdminUser>> watchAllUsers() {
    return _users.snapshots().map((snap) {
      final list = snap.docs.map(AdminUser.fromDoc).toList();
      list.sort((a, b) {
        final ae = a.planExpiresOn;
        final be = b.planExpiresOn;
        if (ae == null && be == null) {
          return a.email.compareTo(b.email);
        }
        if (ae == null) return 1;
        if (be == null) return -1;
        return ae.compareTo(be);
      });
      return list;
    });
  }

  Future<AdminUser?> getUser(String email) async {
    final id = AuthHelpers.emailDocId(email);
    if (id == null) return null;
    final snap = await _users.doc(id).get();
    if (!snap.exists) return null;
    return AdminUser.fromDoc(snap);
  }

  Future<void> updateRole({
    required String email,
    required String role,
  }) async {
    final id = AuthHelpers.emailDocId(email);
    if (id == null) throw Exception('Invalid email');
    if (role != 'Shop' && role != 'Admin') {
      throw Exception('Role must be Shop or Admin');
    }
    await _users.doc(id).set(
      {
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateUserPlan({
    required String email,
    required String plan,
    required String planBilling,
    required String planStatus,
    required DateTime? planExpiresOn,
    int? planAmount,
    DateTime? planStartedOn,
  }) async {
    final id = AuthHelpers.emailDocId(email);
    if (id == null) throw Exception('Invalid email');

    final data = <String, dynamic>{
      'plan': plan,
      'planBilling': planBilling,
      'planStatus': planStatus,
      'planAmount': planAmount ??
          (planBilling == 'yearly'
              ? 3999
              : planBilling == 'monthly'
                  ? 399
                  : 0),
      'planSource': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (planStartedOn != null) {
      data['planStartedOn'] = Timestamp.fromDate(planStartedOn);
    }
    if (planExpiresOn != null) {
      data['planExpiresOn'] = Timestamp.fromDate(planExpiresOn);
    } else {
      data['planExpiresOn'] = null;
    }

    await _users.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> grantTrial7Days(String email) async {
    final now = DateTime.now();
    await updateUserPlan(
      email: email,
      plan: 'free',
      planBilling: 'free',
      planStatus: 'trial',
      planAmount: 0,
      planStartedOn: now,
      planExpiresOn: now.add(const Duration(days: 7)),
    );
  }

  Future<void> activateMonthly30(String email) async {
    final now = DateTime.now();
    await updateUserPlan(
      email: email,
      plan: 'premium',
      planBilling: 'monthly',
      planStatus: 'active',
      planAmount: 399,
      planStartedOn: now,
      planExpiresOn: now.add(const Duration(days: 30)),
    );
  }

  Future<void> activateYearly365(String email) async {
    final now = DateTime.now();
    await updateUserPlan(
      email: email,
      plan: 'premium',
      planBilling: 'yearly',
      planStatus: 'active',
      planAmount: 3999,
      planStartedOn: now,
      planExpiresOn: now.add(const Duration(days: 365)),
    );
  }

  Future<void> markExpired(String email) async {
    final existing = await getUser(email);
    await updateUserPlan(
      email: email,
      plan: existing?.plan ?? 'free',
      planBilling: existing?.planBilling ?? 'free',
      planStatus: 'expired',
      planAmount: existing?.planAmount,
      planStartedOn: existing?.planStartedOn,
      planExpiresOn: existing?.planExpiresOn ?? DateTime.now(),
    );
  }
}
