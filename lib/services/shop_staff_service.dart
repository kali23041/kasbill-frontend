import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_helpers.dart';

/// Named capabilities a staff member can hold.
class Perm {
  static const viewBills = 'viewBills';
  static const createBills = 'createBills';
  static const editBills = 'editBills';
  static const deleteBills = 'deleteBills';
  static const viewStock = 'viewStock';
  static const editStock = 'editStock';
  static const viewGirvi = 'viewGirvi';
  static const editGirvi = 'editGirvi';
  static const viewMod = 'viewMod';
  static const editMod = 'editMod';
  static const viewUdhaar = 'viewUdhaar';
  static const collectUdhaar = 'collectUdhaar';
  static const viewSchemes = 'viewSchemes';
  static const editSchemes = 'editSchemes';
  static const viewRepairs = 'viewRepairs';
  static const editRepairs = 'editRepairs';
  static const viewKarigar = 'viewKarigar';
  static const editKarigar = 'editKarigar';
  static const viewCash = 'viewCash';
  static const editCash = 'editCash';

  /// Money-sensitive: cost prices, margins, whole-shop analytics.
  static const viewProfit = 'viewProfit';
  static const viewAnalytics = 'viewAnalytics';
  static const editRates = 'editRates';
  static const editSettings = 'editSettings';
  static const manageStaff = 'manageStaff';
  static const exportData = 'exportData';

  static const all = <String>[
    viewBills, createBills, editBills, deleteBills,
    viewStock, editStock,
    viewGirvi, editGirvi,
    viewMod, editMod,
    viewUdhaar, collectUdhaar,
    viewSchemes, editSchemes,
    viewRepairs, editRepairs,
    viewKarigar, editKarigar,
    viewCash, editCash,
    viewProfit, viewAnalytics, editRates, editSettings, manageStaff, exportData,
  ];

  static String label(String p) {
    switch (p) {
      case viewBills:
        return 'See bills';
      case createBills:
        return 'Make bills';
      case editBills:
        return 'Edit bills';
      case deleteBills:
        return 'Delete bills';
      case viewStock:
        return 'See stock';
      case editStock:
        return 'Add / edit stock';
      case viewGirvi:
        return 'See girvi';
      case editGirvi:
        return 'Create girvi';
      case viewMod:
        return 'See old-gold purchases';
      case editMod:
        return 'Buy old gold';
      case viewUdhaar:
        return 'See udhaar';
      case collectUdhaar:
        return 'Collect udhaar';
      case viewSchemes:
        return 'See schemes';
      case editSchemes:
        return 'Manage schemes';
      case viewRepairs:
        return 'See job cards';
      case editRepairs:
        return 'Manage job cards';
      case viewKarigar:
        return 'See karigar accounts';
      case editKarigar:
        return 'Issue / receive metal';
      case viewCash:
        return 'See cash book';
      case editCash:
        return 'Edit cash book';
      case viewProfit:
        return 'See profit & cost';
      case viewAnalytics:
        return 'See reports';
      case editRates:
        return 'Change rates';
      case editSettings:
        return 'Change settings';
      case manageStaff:
        return 'Manage staff';
      case exportData:
        return 'Export data';
      default:
        return p;
    }
  }
}

class StaffRole {
  static const owner = 'owner';
  static const manager = 'manager';
  static const salesperson = 'salesperson';
  static const accountant = 'accountant';

  static const all = [owner, manager, salesperson, accountant];

  static String label(String r) {
    switch (r) {
      case manager:
        return 'Manager';
      case salesperson:
        return 'Salesperson';
      case accountant:
        return 'Accountant';
      default:
        return 'Owner';
    }
  }

  static String description(String r) {
    switch (r) {
      case manager:
        return 'Everything except staff and settings';
      case salesperson:
        return 'Billing and stock only — no profit, no reports';
      case accountant:
        return 'Reports, GST and cash book — cannot bill';
      default:
        return 'Full access to everything';
    }
  }

  /// Sensible starting permissions. A salesperson deliberately cannot see
  /// profit or delete anything.
  static Set<String> defaultPermissions(String role) {
    switch (role) {
      case manager:
        return {
          ...Perm.all,
        }..removeAll({Perm.manageStaff, Perm.editSettings});
      case salesperson:
        return {
          Perm.viewBills,
          Perm.createBills,
          Perm.viewStock,
          Perm.viewGirvi,
          Perm.viewMod,
          Perm.viewUdhaar,
          Perm.collectUdhaar,
          Perm.viewSchemes,
          Perm.viewRepairs,
          Perm.editRepairs,
        };
      case accountant:
        return {
          Perm.viewBills,
          Perm.viewStock,
          Perm.viewGirvi,
          Perm.viewMod,
          Perm.viewUdhaar,
          Perm.viewSchemes,
          Perm.viewRepairs,
          Perm.viewKarigar,
          Perm.viewCash,
          Perm.editCash,
          Perm.viewProfit,
          Perm.viewAnalytics,
          Perm.exportData,
        };
      default:
        return {...Perm.all};
    }
  }
}

class StaffMember {
  final String id; // lowercased email
  final String email;
  final String name;
  final String role;
  final Set<String> permissions;
  final bool active;
  final String? phone;
  final DateTime? addedAt;
  final DateTime? lastActiveAt;

  const StaffMember({
    required this.id,
    required this.email,
    required this.name,
    this.role = StaffRole.salesperson,
    this.permissions = const {},
    this.active = true,
    this.phone,
    this.addedAt,
    this.lastActiveAt,
  });

  bool can(String permission) =>
      active && (role == StaffRole.owner || permissions.contains(permission));

  factory StaffMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final perms = (d['permissions'] as List?)?.whereType<String>().toSet() ??
        <String>{};
    return StaffMember(
      id: doc.id,
      email: (d['email'] as String?)?.trim() ?? doc.id,
      name: (d['name'] as String?)?.trim() ?? '',
      role: (d['role'] as String?) ?? StaffRole.salesperson,
      permissions: perms,
      active: d['active'] as bool? ?? true,
      phone: d['phone'] as String?,
      addedAt: (d['addedAt'] as Timestamp?)?.toDate(),
      lastActiveAt: (d['lastActiveAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap({bool includeAddedAt = false}) {
    final map = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'name': name.trim(),
      'role': role,
      'permissions': permissions.toList(),
      'active': active,
      'phone': phone?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (includeAddedAt) map['addedAt'] = FieldValue.serverTimestamp();
    return map;
  }

  StaffMember copyWith({
    String? name,
    String? role,
    Set<String>? permissions,
    bool? active,
    String? phone,
  }) {
    return StaffMember(
      id: id,
      email: email,
      name: name ?? this.name,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      active: active ?? this.active,
      phone: phone ?? this.phone,
      addedAt: addedAt,
      lastActiveAt: lastActiveAt,
    );
  }
}

/// Staff accounts for a shop, at `users/{ownerEmail}/staff/{staffEmail}`.
///
/// This gates the UI. Firestore security rules must mirror it server-side —
/// see `firestore.rules` in the repo root.
class ShopStaffService {
  ShopStaffService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _staff() =>
      _userRef()?.collection('staff');

  Stream<List<StaffMember>> watchStaff() {
    final col = _staff();
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(StaffMember.fromDoc).toList();
      list.sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        final ra = StaffRole.all.indexOf(a.role);
        final rb = StaffRole.all.indexOf(b.role);
        if (ra != rb) return ra.compareTo(rb);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    });
  }

  Future<void> addStaff({
    required String email,
    required String name,
    required String role,
    Set<String>? permissions,
    String? phone,
  }) async {
    final col = _staff();
    if (col == null) throw Exception('Not signed in');
    final id = AuthHelpers.emailDocId(email);
    if (id == null) throw Exception('Enter a valid email');
    if (id == AuthHelpers.emailDocId(_auth.currentUser?.email)) {
      throw Exception('You already own this shop');
    }
    final existing = await col.doc(id).get();
    if (existing.exists) throw Exception('$email is already on your staff');

    await col.doc(id).set(
          StaffMember(
            id: id,
            email: id,
            name: name,
            role: role,
            permissions: permissions ?? StaffRole.defaultPermissions(role),
            phone: phone,
          ).toMap(includeAddedAt: true),
        );
  }

  Future<void> updateStaff(StaffMember member) async {
    final col = _staff();
    if (col == null) throw Exception('Not signed in');
    await col.doc(member.id).set(member.toMap(), SetOptions(merge: true));
  }

  Future<void> removeStaff(String id) async {
    final col = _staff();
    if (col == null) throw Exception('Not signed in');
    await col.doc(id).delete();
  }

  Future<void> setActive(String id, bool active) async {
    final col = _staff();
    if (col == null) throw Exception('Not signed in');
    await col.doc(id).set({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Permissions for the signed-in user against [ownerEmail]'s shop. The owner
  /// always holds every permission.
  Stream<StaffMember?> watchMyMembership(String ownerEmail) {
    final me = AuthHelpers.emailDocId(_auth.currentUser?.email);
    final owner = AuthHelpers.emailDocId(ownerEmail);
    if (me == null || owner == null) return Stream.value(null);
    if (me == owner) {
      return Stream.value(
        StaffMember(
          id: me,
          email: me,
          name: _auth.currentUser?.displayName ?? 'Owner',
          role: StaffRole.owner,
          permissions: {...Perm.all},
        ),
      );
    }
    return _firestore
        .collection('users')
        .doc(owner)
        .collection('staff')
        .doc(me)
        .snapshots()
        .map((s) => s.exists ? StaffMember.fromDoc(s) : null);
  }

  Future<void> touchLastActive(String ownerEmail) async {
    final me = AuthHelpers.emailDocId(_auth.currentUser?.email);
    final owner = AuthHelpers.emailDocId(ownerEmail);
    if (me == null || owner == null || me == owner) return;
    try {
      await _firestore
          .collection('users')
          .doc(owner)
          .collection('staff')
          .doc(me)
          .set(
        {'lastActiveAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Best-effort only — never block sign-in on this.
    }
  }
}
