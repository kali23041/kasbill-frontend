import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main_shell.dart';

class AuthHelpers {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;
  static final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  static String? emailDocId(String? email) {
    if (email == null || email.trim().isEmpty) return null;
    return email.trim().toLowerCase();
  }

  /// Create new user doc with role Shop + free plan (merge-safe for first write).
  static Future<void> storeUserInfo(User user, {String? displayName}) async {
    final id = emailDocId(user.email);
    if (id == null) return;

    await firestore.collection('users').doc(id).set({
      'email': user.email,
      'displayName': displayName ?? user.displayName ?? '',
      'photoURL': user.photoURL ?? '',
      'phoneNumber': user.phoneNumber ?? '',
      'role': 'Shop',
      'plan': 'free',
      'planStartedOn': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update last login; create Shop doc if missing. Never overwrites role/plan.
  static Future<void> updateOrCreateUserInfo(User user) async {
    final id = emailDocId(user.email);
    if (id == null) return;

    final ref = firestore.collection('users').doc(id);
    final snap = await ref.get();

    if (snap.exists) {
      final data = snap.data() ?? {};
      final updates = <String, dynamic>{
        'lastLogin': FieldValue.serverTimestamp(),
        'displayName': user.displayName ?? data['displayName'] ?? '',
        'photoURL': user.photoURL ?? data['photoURL'] ?? '',
      };
      // Backfill free plan only if missing (never reset an existing plan).
      if (data['plan'] == null) {
        updates['plan'] = 'free';
        updates['planStartedOn'] = FieldValue.serverTimestamp();
      }
      await ref.update(updates);
    } else {
      await storeUserInfo(user);
    }
  }

  static Future<UserCredential?> signInWithGoogle() async {
    // Always clear cached Google session so the account picker is shown.
    try {
      await googleSignIn.disconnect();
    } catch (_) {}
    try {
      await googleSignIn.signOut();
    } catch (_) {}

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    if (googleAuth.accessToken == null || googleAuth.idToken == null) {
      throw Exception('Google auth tokens missing. Check Firebase SHA-1 / OAuth setup.');
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return auth.signInWithCredential(credential);
  }

  static String googleErrorMessage(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('apiexception: 10') || s.contains('sign_in_failed')) {
      return 'Google Sign-In config error (ApiException 10). Add Debug SHA-1 in Firebase Console and download a fresh google-services.json.';
    }
    if (s.contains('network')) {
      return 'Network error. Check your connection and try again.';
    }
    if (s.contains('sign_in_canceled') || s.contains('canceled')) {
      return 'Google Sign-In was cancelled.';
    }
    return 'Google Sign-In failed. Please try again.';
  }

  static void goToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  static Future<void> signOut() async {
    try {
      await googleSignIn.disconnect();
    } catch (_) {}
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    await auth.signOut();
  }
}
