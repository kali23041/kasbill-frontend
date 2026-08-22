import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/notifications_service.dart';
import '../services/reminder_scanner_service.dart';
import '../services/shop_settings_service.dart';
import '../theme/ratnex_theme.dart';
import '../widgets/ratnex_ui.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _service = ShopSettingsService();
  final _scanner = ReminderScannerService();
  bool _scanning = false;

  Future<void> _rescan() async {
    setState(() => _scanning = true);
    try {
      await _scanner.scan();
      if (mounted) RatnexSnack.success(context, 'Reminders refreshed');
    } catch (e) {
      if (mounted) RatnexSnack.error(context, '$e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _test() async {
    await NotificationsService.instance.showLocal(
      title: 'Ratnex test',
      body: 'Notifications are working on this phone.',
      channel: RatnexNotificationChannel.general,
    );
    if (mounted) RatnexSnack.show(context, 'Test notification sent');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ShopSettings>(
      stream: _service.watchSettings(),
      builder: (context, snap) {
        final s = snap.data ?? ShopSettings.defaults;

        return RatnexPageScaffold(
          title: 'Notifications',
          subtitle: 'What Ratnex should remind you about',
          showBack: true,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RatnexPanel(
                child: Column(
                  children: [
                    _Toggle(
                      icon: Icons.account_balance_outlined,
                      title: 'Girvi due dates',
                      subtitle: 'A week before, and again once overdue',
                      value: s.remindGirviDue,
                      onChanged: (v) => _service.patch({'remindGirviDue': v}),
                    ),
                    _divider(),
                    _Toggle(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Udhaar overdue',
                      subtitle: 'When a khata passes its due date',
                      value: s.remindUdhaar,
                      onChanged: (v) => _service.patch({'remindUdhaar': v}),
                    ),
                    _divider(),
                    _Toggle(
                      icon: Icons.savings_outlined,
                      title: 'Scheme installments',
                      subtitle: 'When a member misses a month',
                      value: s.remindSchemeInstallment,
                      onChanged: (v) =>
                          _service.patch({'remindSchemeInstallment': v}),
                    ),
                    _divider(),
                    _Toggle(
                      icon: Icons.point_of_sale_outlined,
                      title: 'Daily cash',
                      subtitle: 'A nudge to set your opening cash each morning',
                      value: s.remindDailyCash,
                      onChanged: (v) => _service.patch({'remindDailyCash': v}),
                    ),
                    _divider(),
                    _Toggle(
                      icon: Icons.trending_up,
                      title: 'Rate movement',
                      subtitle:
                          'When gold moves more than ₹${s.rateChangeThreshold.toStringAsFixed(0)} a gram',
                      value: s.remindRateChange,
                      onChanged: (v) => _service.patch({'remindRateChange': v}),
                    ),
                  ],
                ),
              ),
              if (s.remindRateChange) ...[
                const SizedBox(height: 12),
                RatnexPanel(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Alert me when the rate moves by',
                            style: RatnexTheme.label(
                              size: 13,
                              weight: FontWeight.w600,
                              color: RatnexColors.ink,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: s.rateChangeThreshold <= 10
                              ? null
                              : () => _service.patch({
                                    'rateChangeThreshold':
                                        s.rateChangeThreshold - 10,
                                  }),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.remove_circle_outline,
                            size: 20,
                            color: RatnexColors.muted,
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            '₹${s.rateChangeThreshold.toStringAsFixed(0)}',
                            textAlign: TextAlign.center,
                            style: RatnexTheme.money(size: 13),
                          ),
                        ),
                        IconButton(
                          onPressed: s.rateChangeThreshold >= 500
                              ? null
                              : () => _service.patch({
                                    'rateChangeThreshold':
                                        s.rateChangeThreshold + 10,
                                  }),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.add_circle_outline,
                            size: 20,
                            color: RatnexColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              RatnexNotice(
                message:
                    'Reminders are worked out on this phone whenever you open Ratnex, so they keep working without any paid Firebase plan.',
                color: RatnexColors.info,
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _scanning ? null : _rescan,
                      icon: _scanning
                          ? SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: RatnexColors.gold,
                              ),
                            )
                          : const Icon(Icons.refresh, size: 17),
                      label: const Text('Refresh now'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RatnexColors.ink,
                        side: BorderSide(color: RatnexColors.hairline),
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _test,
                      icon: const Icon(Icons.notifications_active_outlined,
                          size: 17),
                      label: const Text('Send a test'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RatnexColors.ink,
                        side: BorderSide(color: RatnexColors.hairline),
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _divider() => Divider(
        height: 1,
        indent: 12,
        endIndent: 12,
        color: RatnexColors.hairline,
      );
}

class _Toggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Icon(icon, size: 19, color: RatnexColors.ink),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RatnexTheme.label(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: RatnexColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: RatnexTheme.label(size: 11.5)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: RatnexColors.gold,
          ),
        ],
      ),
    );
  }
}
