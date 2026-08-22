import 'package:flutter/material.dart';

import '../services/app_lock_service.dart';
import '../services/app_prefs_service.dart';
import '../theme/ratnex_theme.dart';

/// Holds the app behind a biometric prompt when "App lock" is on, and locks
/// again when the phone is backgrounded.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _prompting = false;
  DateTime? _backgroundedAt;

  /// Short grace period so switching to the camera or WhatsApp to send a bill
  /// does not force a re-unlock on the way back.
  static const _grace = Duration(seconds: 30);

  bool get _lockEnabled => AppPrefs.instance.appLockEnabled.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unlocked = !_lockEnabled;
    if (_lockEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_lockEnabled) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt ??= DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null && DateTime.now().difference(since) > _grace) {
        setState(() => _unlocked = false);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_prompting) return;
    _prompting = true;
    try {
      final ok = await AppLockService.instance.authenticate(
        reason: 'Unlock Ratnex',
      );
      if (!mounted) return;
      setState(() => _unlocked = ok);
    } finally {
      _prompting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppPrefs.instance.appLockEnabled,
      builder: (context, enabled, _) {
        if (!enabled || _unlocked) return widget.child;
        return Scaffold(
          backgroundColor: RatnexColors.surface,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: RatnexColors.goldSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 32,
                        color: RatnexColors.gold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Ratnex is locked', style: RatnexTheme.brand(size: 26)),
                    const SizedBox(height: 8),
                    Text(
                      'Unlock with your fingerprint, face or device PIN.',
                      textAlign: TextAlign.center,
                      style: RatnexTheme.label(size: 13),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 200,
                      child: FilledButton.icon(
                        onPressed: _unlock,
                        icon: const Icon(Icons.fingerprint, size: 18),
                        label: const Text('Unlock'),
                        style: FilledButton.styleFrom(
                          backgroundColor: RatnexColors.ink,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
