import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../ledger/udhaar_detail_page.dart';
import '../repairs/view_repair_page.dart';
import '../services/notifications_service.dart';
import '../services/reminder_scanner_service.dart';
import '../services/shop_profile_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';

/// Everything that needs chasing today, in one list.
class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final _notifications = NotificationsService.instance;
  final _scanner = ReminderScannerService();
  final _profile = ShopProfileService();

  String _filter = 'all';
  ShopProfile? _shop;

  @override
  void initState() {
    super.initState();
    _profile.watchProfile().first.then((p) {
      if (mounted) setState(() => _shop = p);
    }).catchError((_) {});
    _scanner.scanIfStale();
  }

  Future<void> _refresh() async {
    await _scanner.scan();
  }

  Future<void> _act(ShopReminder r) async {
    await _notifications.markRead(r.id);
    if (!mounted) return;

    switch (r.kind) {
      case 'udhaar':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UdhaarDetailPage(
              phoneId: r.targetId ?? '',
              name: r.title.split(' owes').first,
              phone: r.phone ?? '',
            ),
          ),
        );
      case 'repair':
        if (r.targetId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ViewRepairPage(jobNo: r.targetId!),
            ),
          );
        }
      default:
        await _sendMessage(r);
    }
  }

  Future<void> _sendMessage(ShopReminder r) async {
    if (r.phone == null || r.phone!.isEmpty) return;
    final shopName = _shop?.shopName ?? 'our shop';
    final message = [
      'Namaste 🙏',
      '',
      r.title,
      r.body,
      '',
      'Please visit the shop or call us.',
      '— $shopName',
    ].join('\n');
    final ok = await WhatsAppService.send(r.phone, message);
    if (!ok && mounted) {
      await WhatsAppService.copy(message);
      if (mounted) RatnexSnack.show(context, 'Message copied to clipboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ShopReminder>>(
      stream: _notifications.watchReminders(),
      builder: (context, snap) {
        final all = snap.data ?? const <ShopReminder>[];
        final unread = all.where((r) => !r.read).length;

        final visible = _filter == 'all'
            ? all
            : all.where((r) => r.kind == _filter).toList();

        int countOf(String kind) =>
            all.where((r) => r.kind == kind).length;

        return RatnexPageScaffold(
          title: 'Reminders',
          subtitle: all.isEmpty
              ? 'Nothing needs chasing right now'
              : '$unread new · ${all.length} open',
          showBack: true,
          onRefresh: _refresh,
          trailing: all.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Mark all read',
                  onPressed: () => _notifications.markAllRead(),
                  icon: Icon(Icons.done_all, color: RatnexColors.ink),
                ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (all.isNotEmpty) ...[
                RatnexFilterChips(
                  selected: _filter,
                  options: [
                    (value: 'all', label: 'All', count: all.length),
                    if (countOf('girviDue') > 0)
                      (
                        value: 'girviDue',
                        label: 'Girvi',
                        count: countOf('girviDue')
                      ),
                    if (countOf('udhaar') > 0)
                      (
                        value: 'udhaar',
                        label: 'Udhaar',
                        count: countOf('udhaar')
                      ),
                    if (countOf('scheme') > 0)
                      (
                        value: 'scheme',
                        label: 'Schemes',
                        count: countOf('scheme')
                      ),
                    if (countOf('repair') > 0)
                      (
                        value: 'repair',
                        label: 'Jobs',
                        count: countOf('repair')
                      ),
                  ],
                  onSelected: (v) => setState(() => _filter = v),
                ),
                const SizedBox(height: 14),
              ],
              if (!snap.hasData)
                const RatnexListSkeleton(rows: 3)
              else if (all.isEmpty)
                RatnexEmptyState(
                  icon: Icons.notifications_none,
                  title: 'All clear',
                  message:
                      'Girvi due dates, overdue udhaar, missed scheme installments and ready job cards all show up here.',
                  actionLabel: 'Check again',
                  onAction: _refresh,
                )
              else
                ...visible.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReminderTile(
                      reminder: r,
                      onTap: () => _act(r),
                      onDismiss: () => _notifications.dismiss(r.id),
                      onMessage:
                          r.phone == null ? null : () => _sendMessage(r),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final ShopReminder reminder;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final VoidCallback? onMessage;

  const _ReminderTile({
    required this.reminder,
    required this.onTap,
    required this.onDismiss,
    this.onMessage,
  });

  ({IconData icon, Color color}) get _look {
    switch (reminder.kind) {
      case 'girviDue':
        return (icon: Icons.account_balance_outlined, color: RatnexColors.violet);
      case 'udhaar':
        return (
          icon: Icons.account_balance_wallet_outlined,
          color: RatnexColors.down
        );
      case 'scheme':
        return (icon: Icons.savings_outlined, color: RatnexColors.gold);
      case 'repair':
        return (icon: Icons.build_outlined, color: RatnexColors.warn);
      default:
        return (icon: Icons.info_outline, color: RatnexColors.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final look = _look;
    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: RatnexColors.muted.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.check, color: RatnexColors.muted),
      ),
      child: RatnexCard(
        onTap: onTap,
        borderColor: reminder.read
            ? null
            : look.color.withValues(alpha: 0.32),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: look.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(look.icon, size: 17, color: look.color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!reminder.read) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: look.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          reminder.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RatnexTheme.label(
                            size: 13.5,
                            weight: reminder.read
                                ? FontWeight.w600
                                : FontWeight.w700,
                            color: RatnexColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reminder.body,
                    maxLines: 2,
                    style: RatnexTheme.label(size: 11.5),
                  ),
                  if (reminder.dueAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${reminder.isOverdue ? 'Was due' : 'Due'} ${RatnexFormat.date(reminder.dueAt)}',
                      style: RatnexTheme.label(
                        size: 10.5,
                        color: reminder.isOverdue
                            ? RatnexColors.down
                            : RatnexColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onMessage != null)
              IconButton(
                tooltip: 'Send WhatsApp',
                onPressed: onMessage,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.chat_outlined,
                  size: 19,
                  color: Color(0xFF25D366),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
