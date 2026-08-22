import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_helpers.dart';

/// Append-only trail at `users/{email}/auditLog/{entryId}`.
///
/// Once a shop has staff, "who deleted that bill?" needs an answer.
class AuditLogService {
  AuditLogService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const create = 'create';
  static const update = 'update';
  static const delete = 'delete';
  static const payment = 'payment';
  static const export = 'export';
  static const login = 'login';

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  CollectionReference<Map<String, dynamic>>? _log() =>
      _userRef()?.collection('auditLog');

  /// Fire-and-forget: an audit write must never fail the user's action.
  Future<void> record({
    required String action,
    required String entity,
    String? entityId,
    String? summary,
    Map<String, dynamic>? details,
  }) async {
    final col = _log();
    if (col == null) return;
    try {
      await col.add({
        'action': action,
        'entity': entity,
        'entityId': entityId,
        'summary': summary,
        'details': details,
        'by': _auth.currentUser?.email,
        'byName': _auth.currentUser?.displayName,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Audit log skipped: $e');
    }
  }

  Stream<List<AuditEntry>> watchRecent({int limit = 200}) {
    final col = _log();
    if (col == null) return Stream.value(const []);
    return col
        .orderBy('at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(AuditEntry.fromDoc).toList());
  }
}

class AuditEntry {
  final String id;
  final String action;
  final String entity;
  final String? entityId;
  final String? summary;
  final String? by;
  final String? byName;
  final DateTime? at;

  const AuditEntry({
    required this.id,
    required this.action,
    required this.entity,
    this.entityId,
    this.summary,
    this.by,
    this.byName,
    this.at,
  });

  factory AuditEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AuditEntry(
      id: doc.id,
      action: (d['action'] as String?) ?? '',
      entity: (d['entity'] as String?) ?? '',
      entityId: d['entityId'] as String?,
      summary: d['summary'] as String?,
      by: d['by'] as String?,
      byName: d['byName'] as String?,
      at: (d['at'] as Timestamp?)?.toDate(),
    );
  }
}
