import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../l10n/app_l10n.dart';
import '../services/app_lock_service.dart';
import '../services/app_prefs_service.dart';
import '../services/shop_settings_service.dart';
import '../theme/ratnex_theme.dart';
import '../widgets/ratnex_ui.dart';
import '../staff/staff_page.dart';
import 'backup_page.dart';
import 'invoice_settings_page.dart';
import 'notification_settings_page.dart';

/// One place for everything that changes how Ratnex behaves.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _service = ShopSettingsService();
  final _prefs = AppPrefs.instance;

  String _biometricLabel = 'Device PIN';

  @override
  void initState() {
    super.initState();
    AppLockService.instance.describeAvailable().then((label) {
      if (mounted) setState(() => _biometricLabel = label);
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    if (!value) {
      await _prefs.setAppLock(false);
      return;
    }
    final available = await AppLockService.instance.isAvailable();
    if (!available) {
      if (mounted) {
        RatnexSnack.error(
          context,
          'Set up a screen lock on your phone first',
        );
      }
      return;
    }
    final ok = await AppLockService.instance.authenticate(
      reason: 'Confirm it is you before turning on app lock',
    );
    if (!ok) {
      if (mounted) RatnexSnack.show(context, 'App lock not turned on');
      return;
    }
    await _prefs.setAppLock(true);
    if (mounted) RatnexSnack.success(context, 'App lock is on');
  }

  Future<void> _pickTheme() async {
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: RatnexColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Theme', style: RatnexTheme.brand(size: 20)),
            const SizedBox(height: 8),
            ...[
              (ThemeMode.light, 'Light', Icons.light_mode_outlined),
              (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
              (ThemeMode.system, 'Match device', Icons.brightness_auto_outlined),
            ].map(
              (o) => ListTile(
                leading: Icon(o.$3, color: RatnexColors.ink),
                title: Text(
                  o.$2,
                  style: RatnexTheme.label(
                    size: 13.5,
                    color: RatnexColors.ink,
                    weight: FontWeight.w600,
                  ),
                ),
                trailing: _prefs.themeMode.value == o.$1
                    ? Icon(Icons.check, color: RatnexColors.gold)
                    : null,
                onTap: () => Navigator.pop(ctx, o.$1),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) await _prefs.setThemeMode(picked);
  }

  Future<void> _pickLanguage() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: RatnexColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Language', style: RatnexTheme.brand(size: 20)),
            const SizedBox(height: 4),
            Text(
              'Shop screens follow this language',
              style: RatnexTheme.label(size: 12),
            ),
            const SizedBox(height: 10),
            ...L10n.languageNames.entries.map(
              (e) => ListTile(
                title: Text(
                  e.value,
                  style: RatnexTheme.label(
                    size: 14,
                    color: RatnexColors.ink,
                    weight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  L10n.languageEnglishNames[e.key] ?? e.key,
                  style: RatnexTheme.label(size: 11.5),
                ),
                trailing: _prefs.locale.value?.languageCode == e.key
                    ? Icon(Icons.check, color: RatnexColors.gold)
                    : null,
                onTap: () => Navigator.pop(ctx, e.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) await _prefs.setLocale(Locale(picked));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ShopSettings>(
      stream: _service.watchSettings(),
      builder: (context, snap) {
        final settings = snap.data ?? ShopSettings.defaults;

        return RatnexPageScaffold(
          title: 'Settings',
          subtitle: 'How Ratnex looks, prints and warns you',
          showBack: true,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RatnexSectionLabel(text: 'APPEARANCE'),
              const SizedBox(height: 8),
              RatnexPanel(
                child: Column(
                  children: [
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: _prefs.themeMode,
                      builder: (context, mode, _) => _Row(
                        icon: Icons.palette_outlined,
                        title: 'Theme',
                        value: switch (mode) {
                          ThemeMode.dark => 'Dark',
                          ThemeMode.system => 'Match device',
                          ThemeMode.light => 'Light',
                        },
                        onTap: _pickTheme,
                      ),
                    ),
                    _divider(),
                    ValueListenableBuilder<Locale?>(
                      valueListenable: _prefs.locale,
                      builder: (context, locale, _) => _Row(
                        icon: Icons.translate,
                        title: 'Language',
                        value: locale == null
                            ? 'English'
                            : L10n.languageNames[locale.languageCode] ??
                                'English',
                        onTap: _pickLanguage,
                      ),
                    ),
                    _divider(),
                    ValueListenableBuilder<bool>(
                      valueListenable: _prefs.compactLists,
                      builder: (context, on, _) => _SwitchRow(
                        icon: Icons.density_small_outlined,
                        title: 'Compact lists',
                        subtitle: 'Fit more rows on screen',
                        value: on,
                        onChanged: _prefs.setCompactLists,
                      ),
                    ),
                    _divider(),
                    ValueListenableBuilder<bool>(
                      valueListenable: _prefs.hapticsEnabled,
                      builder: (context, on, _) => _SwitchRow(
                        icon: Icons.vibration,
                        title: 'Vibration feedback',
                        subtitle: 'A small buzz on save and on errors',
                        value: on,
                        onChanged: _prefs.setHaptics,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const RatnexSectionLabel(text: 'PRIVACY & SECURITY'),
              const SizedBox(height: 8),
              RatnexPanel(
                child: Column(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _prefs.appLockEnabled,
                      builder: (context, on, _) => _SwitchRow(
                        icon: Icons.lock_outline,
                        title: 'App lock',
                        subtitle:
                            'Ask for $_biometricLabel before opening Ratnex',
                        value: on,
                        onChanged: _toggleAppLock,
                      ),
                    ),
                    _divider(),
                    _Row(
                      icon: Icons.groups_outlined,
                      title: 'Staff & permissions',
                      value: 'Manage',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StaffPage()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const RatnexSectionLabel(text: 'BILLS & PRINTING'),
              const SizedBox(height: 8),
              RatnexPanel(
                child: Column(
                  children: [
                    _Row(
                      icon: Icons.tag,
                      title: 'Invoice numbering',
                      value: settings.sequentialInvoiceNo
                          ? 'Sequential'
                          : 'Automatic',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const InvoiceSettingsPage(),
                        ),
                      ),
                    ),
                    _divider(),
                    _SwitchRow(
                      icon: Icons.spellcheck,
                      title: 'Amount in words',
                      subtitle: 'Print "Rupees Forty Two Thousand Only"',
                      value: settings.showAmountInWords,
                      onChanged: (v) =>
                          _service.patch({'showAmountInWords': v}),
                    ),
                    _divider(),
                    _SwitchRow(
                      icon: Icons.table_chart_outlined,
                      title: 'HSN summary',
                      subtitle: 'Required on GST invoices',
                      value: settings.showHsnSummary,
                      onChanged: (v) => _service.patch({'showHsnSummary': v}),
                    ),
                    _divider(),
                    _SwitchRow(
                      icon: Icons.exposure_zero,
                      title: 'Round off totals',
                      subtitle: 'Round the grand total to the nearest rupee',
                      value: settings.roundOffTotals,
                      onChanged: (v) => _service.patch({'roundOffTotals': v}),
                    ),
                    _divider(),
                    ValueListenableBuilder<String>(
                      valueListenable: _prefs.printerFormat,
                      builder: (context, format, _) => _Row(
                        icon: Icons.print_outlined,
                        title: 'Paper size',
                        value: switch (format) {
                          'thermal80' => '80mm thermal',
                          'thermal58' => '58mm thermal',
                          _ => 'A4',
                        },
                        onTap: () async {
                          final picked = await showModalBottomSheet<String>(
                            context: context,
                            backgroundColor: RatnexColors.panel,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            builder: (ctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 12),
                                  Text(
                                    'Paper size',
                                    style: RatnexTheme.brand(size: 20),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Most counters use an 80mm thermal roll',
                                    style: RatnexTheme.label(size: 12),
                                  ),
                                  const SizedBox(height: 10),
                                  ...[
                                    ('a4', 'A4', 'Full page invoice'),
                                    (
                                      'thermal80',
                                      '80mm thermal',
                                      'Counter receipt printer'
                                    ),
                                    (
                                      'thermal58',
                                      '58mm thermal',
                                      'Small pocket printer'
                                    ),
                                  ].map(
                                    (o) => ListTile(
                                      title: Text(
                                        o.$2,
                                        style: RatnexTheme.label(
                                          size: 13.5,
                                          color: RatnexColors.ink,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        o.$3,
                                        style: RatnexTheme.label(size: 11.5),
                                      ),
                                      trailing: format == o.$1
                                          ? Icon(
                                              Icons.check,
                                              color: RatnexColors.gold,
                                            )
                                          : null,
                                      onTap: () => Navigator.pop(ctx, o.$1),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          );
                          if (picked != null) {
                            await _prefs.setPrinterFormat(picked);
                            await _service.patch({'printerFormat': picked});
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const RatnexSectionLabel(text: 'COMPLIANCE'),
              const SizedBox(height: 8),
              RatnexPanel(
                child: Column(
                  children: [
                    _SwitchRow(
                      icon: Icons.currency_rupee,
                      title: 'Warn on large cash',
                      subtitle:
                          'Section 269ST — cash of ₹2,00,000 or more attracts a penalty',
                      value: settings.warnCash269ST,
                      onChanged: (v) => _service.patch({'warnCash269ST': v}),
                    ),
                    _divider(),
                    _SwitchRow(
                      icon: Icons.badge_outlined,
                      title: 'Ask for PAN above ₹2 lakh',
                      subtitle: 'Required on high-value jewellery sales',
                      value: settings.requirePanAboveLimit,
                      onChanged: (v) =>
                          _service.patch({'requirePanAboveLimit': v}),
                    ),
                    _divider(),
                    _SwitchRow(
                      icon: Icons.perm_identity,
                      title: 'KYC on girvi',
                      subtitle: 'Capture an ID proof for every pawn loan',
                      value: settings.requireKycOnGirvi,
                      onChanged: (v) =>
                          _service.patch({'requireKycOnGirvi': v}),
                    ),
                    _divider(),
                    _SwitchRow(
                      icon: Icons.verified_outlined,
                      title: 'Check HUID format',
                      subtitle: 'Hallmark IDs must be 6 letters or digits',
                      value: settings.validateHuid,
                      onChanged: (v) => _service.patch({'validateHuid': v}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const RatnexSectionLabel(text: 'BEHAVIOUR'),
              const SizedBox(height: 8),
              RatnexPanel(
                child: Column(
                  children: [
                    _SwitchRow(
                      icon: Icons.lock_clock_outlined,
                      title: 'Lock the rate on a bill',
                      subtitle:
                          'A live rate refresh will not change a bill you are already writing',
                      value: settings.lockRateOnBill,
                      onChanged: (v) => _service.patch({'lockRateOnBill': v}),
                    ),
                    _divider(),
                    _SwitchRow(
                      icon: Icons.save_outlined,
                      title: 'Autosave drafts',
                      subtitle: 'Recover a half-written bill after a mis-tap',
                      value: settings.autoSaveDrafts,
                      onChanged: (v) => _service.patch({'autoSaveDrafts': v}),
                    ),
                    _divider(),
                    _StepperRow(
                      icon: Icons.hourglass_empty,
                      title: 'Dead stock after',
                      value: '${settings.deadStockDays} days',
                      onDecrease: settings.deadStockDays <= 30
                          ? null
                          : () => _service.patch(
                                {'deadStockDays': settings.deadStockDays - 30},
                              ),
                      onIncrease: settings.deadStockDays >= 365
                          ? null
                          : () => _service.patch(
                                {'deadStockDays': settings.deadStockDays + 30},
                              ),
                    ),
                    _divider(),
                    _StepperRow(
                      icon: Icons.event_busy_outlined,
                      title: 'Udhaar due after',
                      value: '${settings.udhaarDueDays} days',
                      onDecrease: settings.udhaarDueDays <= 7
                          ? null
                          : () => _service.patch(
                                {'udhaarDueDays': settings.udhaarDueDays - 7},
                              ),
                      onIncrease: settings.udhaarDueDays >= 180
                          ? null
                          : () => _service.patch(
                                {'udhaarDueDays': settings.udhaarDueDays + 7},
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const RatnexSectionLabel(text: 'DATA'),
              const SizedBox(height: 8),
              RatnexPanel(
                child: Column(
                  children: [
                    _Row(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications & reminders',
                      value: 'Manage',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationSettingsPage(),
                        ),
                      ),
                    ),
                    _divider(),
                    _Row(
                      icon: Icons.cloud_download_outlined,
                      title: 'Backup & export',
                      value: 'CSV, GST',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BackupPage()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Ratnex · gold billing for jewellery shops',
                  style: RatnexTheme.label(size: 11),
                ),
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

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  const _Row({
    required this.icon,
    required this.title,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 19, color: RatnexColors.ink),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: RatnexTheme.label(
                  size: 13.5,
                  weight: FontWeight.w600,
                  color: RatnexColors.ink,
                ),
              ),
            ),
            if (value != null)
              Text(value!, style: RatnexTheme.label(size: 12.5)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 18, color: RatnexColors.muted),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
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

class _StepperRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const _StepperRow({
    required this.icon,
    required this.title,
    required this.value,
    this.onDecrease,
    this.onIncrease,
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
            child: Text(
              title,
              style: RatnexTheme.label(
                size: 13.5,
                weight: FontWeight.w600,
                color: RatnexColors.ink,
              ),
            ),
          ),
          IconButton(
            onPressed: onDecrease,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.remove_circle_outline,
              size: 20,
              color: onDecrease == null
                  ? RatnexColors.hairline
                  : RatnexColors.muted,
            ),
          ),
          SizedBox(
            width: 66,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: RatnexTheme.money(size: 13),
            ),
          ),
          IconButton(
            onPressed: onIncrease,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.add_circle_outline,
              size: 20,
              color: onIncrease == null
                  ? RatnexColors.hairline
                  : RatnexColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
