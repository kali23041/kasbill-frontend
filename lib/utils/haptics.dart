import 'package:flutter/services.dart';

import '../services/app_prefs_service.dart';

/// Thin wrapper so every touchpoint honours the "vibration feedback" setting.
class Haptics {
  Haptics._();

  static bool get _on => AppPrefs.instance.hapticsEnabled.value;

  static void tap() {
    if (_on) HapticFeedback.selectionClick();
  }

  static void success() {
    if (_on) HapticFeedback.mediumImpact();
  }

  static void warning() {
    if (_on) HapticFeedback.heavyImpact();
  }

  static void light() {
    if (_on) HapticFeedback.lightImpact();
  }
}
