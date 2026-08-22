import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../auth/auth_helpers.dart';

/// Handles messages that arrive while the app is terminated or backgrounded.
/// Must be a top-level function — the Flutter engine spins up a fresh isolate
/// for it, so it cannot close over anything.
@pragma('vm:entry-point')
Future<void> ratnexBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint('Ratnex background push: ${message.messageId}');
}

class RatnexNotificationChannel {
  static const reminders = 'ratnex_reminders';
  static const rates = 'ratnex_rates';
  static const general = 'ratnex_general';
}

/// A due-date nudge stored at `users/{email}/reminders/{id}`.
///
/// Written by the app whenever it notices something is due, so the same list
/// drives both the in-app inbox and (via a Cloud Function reading this
/// subcollection) an actual push.
class ShopReminder {
  final String id;
  final String kind; // girviDue | udhaar | scheme | repair | cash | plan | rate
  final String title;
  final String body;
  final String? targetId;
  final String? phone;
  final DateTime? dueAt;
  final bool read;
  final bool dismissed;
  final DateTime? createdAt;

  const ShopReminder({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.targetId,
    this.phone,
    this.dueAt,
    this.read = false,
    this.dismissed = false,
    this.createdAt,
  });

  bool get isOverdue {
    final d = dueAt;
    return d != null && DateTime.now().isAfter(d);
  }

  factory ShopReminder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ShopReminder(
      id: doc.id,
      kind: (d['kind'] as String?) ?? 'general',
      title: (d['title'] as String?) ?? '',
      body: (d['body'] as String?) ?? '',
      targetId: d['targetId'] as String?,
      phone: d['phone'] as String?,
      dueAt: (d['dueAt'] as Timestamp?)?.toDate(),
      read: d['read'] as bool? ?? false,
      dismissed: d['dismissed'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'kind': kind,
        'title': title,
        'body': body,
        'targetId': targetId,
        'phone': phone,
        'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt!),
        'read': read,
        'dismissed': dismissed,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// Push (FCM) + on-device notifications + the reminder inbox.
class NotificationsService {
  NotificationsService._();

  static final NotificationsService instance = NotificationsService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _started = false;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>>? _userRef() {
    final email = AuthHelpers.emailDocId(_auth.currentUser?.email);
    if (email == null) return null;
    return _firestore.collection('users').doc(email);
  }

  /// users/{email}/devices/{token} — one document per install.
  CollectionReference<Map<String, dynamic>>? _devices() =>
      _userRef()?.collection('devices');

  /// users/{email}/reminders/{id}
  CollectionReference<Map<String, dynamic>>? _reminders() =>
      _userRef()?.collection('reminders');

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      await _initLocal();
      await _initMessaging();
    } catch (e) {
      // Never let notification setup break app launch.
      debugPrint('Notifications setup skipped: $e');
    }
  }

  Future<void> _initLocal() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: darwin, macOS: darwin),
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          RatnexNotificationChannel.reminders,
          'Reminders',
          description: 'Girvi due dates, udhaar and scheme installments',
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          RatnexNotificationChannel.rates,
          'Rate alerts',
          description: 'Gold and silver rate movements',
          importance: Importance.defaultImportance,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          RatnexNotificationChannel.general,
          'General',
          description: 'Account and app updates',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  Future<void> _initMessaging() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    await _saveToken();
    messaging.onTokenRefresh.listen((token) => _saveToken(token: token));
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await showLocal(
      title: n.title ?? 'Ratnex',
      body: n.body ?? '',
      channel: message.data['channel'] as String? ??
          RatnexNotificationChannel.general,
    );
  }

  Future<void> showLocal({
    required String title,
    required String body,
    String channel = RatnexNotificationChannel.general,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        channel == RatnexNotificationChannel.reminders
            ? 'Reminders'
            : channel == RatnexNotificationChannel.rates
                ? 'Rate alerts'
                : 'General',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Stores the FCM token so a Cloud Function can target this shop.
  Future<void> _saveToken({String? token}) async {
    final col = _devices();
    if (col == null) return;
    try {
      final value = token ?? await FirebaseMessaging.instance.getToken();
      if (value == null || value.isEmpty) return;
      await col.doc(value).set({
        'token': value,
        'platform': Platform.operatingSystem,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FCM token save skipped: $e');
    }
  }

  /// Removes this device's token so a signed-out phone stops getting pushes.
  Future<void> detachToken() async {
    final col = _devices();
    if (col == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await col.doc(token).delete();
    } catch (_) {
      // Sign-out must not fail because of this.
    }
  }

  // ---- Reminder inbox ------------------------------------------------------

  Stream<List<ShopReminder>> watchReminders({bool includeDismissed = false}) {
    final col = _reminders();
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      var list = snap.docs.map(ShopReminder.fromDoc).toList();
      if (!includeDismissed) {
        list = list.where((r) => !r.dismissed).toList();
      }
      list.sort((a, b) {
        if (a.read != b.read) return a.read ? 1 : -1;
        final ad = a.dueAt ?? a.createdAt ?? DateTime(2000);
        final bd = b.dueAt ?? b.createdAt ?? DateTime(2000);
        return ad.compareTo(bd);
      });
      return list;
    });
  }

  Stream<int> watchUnreadCount() => watchReminders()
      .map((list) => list.where((r) => !r.read).length);

  /// Upserts by a stable id so the same due date never stacks up duplicates.
  Future<void> upsertReminder(ShopReminder reminder) async {
    final col = _reminders();
    if (col == null) return;
    final id = reminder.id.isEmpty
        ? '${reminder.kind}_${reminder.targetId ?? DateTime.now().millisecondsSinceEpoch}'
        : reminder.id;
    final ref = col.doc(id);
    final existing = await ref.get();
    if (existing.exists) {
      await ref.set({
        'title': reminder.title,
        'body': reminder.body,
        'dueAt':
            reminder.dueAt == null ? null : Timestamp.fromDate(reminder.dueAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }
    await ref.set(reminder.toMap());
  }

  Future<void> markRead(String id) async {
    final col = _reminders();
    if (col == null) return;
    await col.doc(id).set({'read': true}, SetOptions(merge: true));
  }

  Future<void> markAllRead() async {
    final col = _reminders();
    if (col == null) return;
    final snap = await col.where('read', isEqualTo: false).get();
    final batch = _firestore.batch();
    for (final d in snap.docs) {
      batch.set(d.reference, {'read': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> dismiss(String id) async {
    final col = _reminders();
    if (col == null) return;
    await col.doc(id).set(
      {'dismissed': true, 'read': true},
      SetOptions(merge: true),
    );
  }

  Future<void> clearFor(String kind, String targetId) async {
    final col = _reminders();
    if (col == null) return;
    await col.doc('${kind}_$targetId').delete().catchError((_) {});
  }
}
