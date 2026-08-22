import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local preferences (theme, language, app lock, bill drafts).
///
/// Kept out of Firestore on purpose: these are per-device choices and must be
/// readable before the first network round-trip so the app never flashes the
/// wrong theme or language at launch.
class AppPrefs {
  AppPrefs._();

  static final AppPrefs instance = AppPrefs._();

  static const _kThemeMode = 'ratnex.themeMode';
  static const _kLocale = 'ratnex.locale';
  static const _kAppLock = 'ratnex.appLock';
  static const _kBillDraft = 'ratnex.billDraft';
  static const _kCompactLists = 'ratnex.compactLists';
  static const _kHaptics = 'ratnex.haptics';
  static const _kPrinterFormat = 'ratnex.printerFormat';
  static const _kOnboardedTips = 'ratnex.onboardedTips';
  static const _kLastBackupAt = 'ratnex.lastBackupAt';

  SharedPreferences? _prefs;

  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);
  final ValueNotifier<bool> appLockEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<bool> compactLists = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hapticsEnabled = ValueNotifier<bool>(true);

  /// a4 | thermal80 | thermal58
  final ValueNotifier<String> printerFormat =
      ValueNotifier<String>('a4');

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    themeMode.value = _decodeThemeMode(p.getString(_kThemeMode));
    final code = p.getString(_kLocale);
    locale.value = (code == null || code.isEmpty) ? null : Locale(code);
    appLockEnabled.value = p.getBool(_kAppLock) ?? false;
    compactLists.value = p.getBool(_kCompactLists) ?? false;
    hapticsEnabled.value = p.getBool(_kHaptics) ?? true;
    printerFormat.value = p.getString(_kPrinterFormat) ?? 'a4';
  }

  static ThemeMode _decodeThemeMode(String? raw) {
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  static String _encodeThemeMode(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _prefs?.setString(_kThemeMode, _encodeThemeMode(mode));
  }

  Future<void> setLocale(Locale? value) async {
    locale.value = value;
    if (value == null) {
      await _prefs?.remove(_kLocale);
    } else {
      await _prefs?.setString(_kLocale, value.languageCode);
    }
  }

  Future<void> setAppLock(bool value) async {
    appLockEnabled.value = value;
    await _prefs?.setBool(_kAppLock, value);
  }

  Future<void> setCompactLists(bool value) async {
    compactLists.value = value;
    await _prefs?.setBool(_kCompactLists, value);
  }

  Future<void> setHaptics(bool value) async {
    hapticsEnabled.value = value;
    await _prefs?.setBool(_kHaptics, value);
  }

  Future<void> setPrinterFormat(String value) async {
    printerFormat.value = value;
    await _prefs?.setString(_kPrinterFormat, value);
  }

  bool tipSeen(String key) {
    final seen = _prefs?.getStringList(_kOnboardedTips) ?? const [];
    return seen.contains(key);
  }

  Future<void> markTipSeen(String key) async {
    final seen = <String>{..._prefs?.getStringList(_kOnboardedTips) ?? const []}
      ..add(key);
    await _prefs?.setStringList(_kOnboardedTips, seen.toList());
  }

  DateTime? get lastBackupAt {
    final ms = _prefs?.getInt(_kLastBackupAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> markBackedUp() async {
    await _prefs?.setInt(
      _kLastBackupAt,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ---- Bill draft autosave -------------------------------------------------

  Future<void> saveBillDraft(Map<String, dynamic> draft) async {
    await _prefs?.setString(_kBillDraft, jsonEncode(draft));
  }

  Map<String, dynamic>? readBillDraft() {
    final raw = _prefs?.getString(_kBillDraft);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearBillDraft() async {
    await _prefs?.remove(_kBillDraft);
  }
}
