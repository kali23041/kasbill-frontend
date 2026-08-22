import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/export_service.dart';
import '../services/shop_ledger_service.dart';
import '../services/shop_profile_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';
import 'udhaar_detail_page.dart';

/// The collections screen: who owes what, who is overdue, and one tap to
/// chase them.
class UdhaarPage extends StatefulWidget {
  const UdhaarPage({super.key});

  @override
  State<UdhaarPage> createState() => _UdhaarPageState();
}

class _UdhaarPageState extends State<UdhaarPage> {
  final _ledger = ShopLedgerService();
  final _profile = ShopProfileService();
  final _search = TextEditingController();

  String _query = '';
  String _filter = 'pending';
  bool _exporting = false;
  ShopProfile? _shop;

  @override
  void initState() {
    super.initState();
    _profile.watchProfile().first.then((p) {
      if (mounted) setState(() => _shop = p);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _remind(UdhaarAccount a) async {
    final message = WhatsAppService.udhaarReminder(
      shopName: _shop?.shopName ?? 'our shop',
      customerName: a.name,
      outstanding: a.outstanding,
      daysOverdue: a.daysOverdue,
      upiId: _shop?.upiId,
    );
    final ok = await WhatsAppService.send(a.phone, message);
    if (!mounted) return;
    if (!ok) {
      await WhatsAppService.copy(message);
      if (mounted) {
        RatnexSnack.show(context, 'Reminder copied to clipboard');
      }
    }
  }

  Future<void> _export(List<UdhaarAccount> accounts) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final result = await ExportService.udhaar(accounts);
      await ExportService.share(result, subject: 'Ratnex udhaar');
      if (mounted) {
        RatnexSnack.success(context, 'Exported ${result.rowCount} accounts');
      }
    } catch (e) {
      if (mounted) RatnexSnack.error(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UdhaarAccount>>(
      stream: _ledger.watchAccounts(),
      builder: (context, snap) {
        final all = snap.data ?? const <UdhaarAccount>[];
        final loading = !snap.hasData && !snap.hasError;

        final pending = all.where((a) => !a.isSettled).toList();
        final overdue = all.where((a) => a.isOverdue).toList();
        final settled = all.where((a) => a.isSettled).toList();

        var visible = switch (_filter) {
          'overdue' => overdue,
          'settled' => settled,
          'all' => all,
          _ => pending,
        };

        final q = _query.trim().toLowerCase();
        if (q.isNotEmpty) {
          final digits = q.replaceAll(RegExp(r'\D'), '');
          visible = visible
              .where((a) =>
                  a.name.toLowerCase().contains(q) ||
                  (digits.isNotEmpty && a.phoneId.contains(digits)))
              .toList();
        }

        final total = ShopLedgerService.totalOutstanding(all);
        final overdueTotal = ShopLedgerService.totalOverdue(all);
        final buckets = ShopLedgerService.ageingBuckets(all);

        return RatnexPageScaffold(
          title: 'Udhaar',
          subtitle: pending.isEmpty
              ? 'Everything has been collected'
              : '${pending.length} customers owe you money',
          showBack: true,
          trailing: IconButton(
            tooltip: 'Export CSV',
            onPressed: _exporting || all.isEmpty ? null : () => _export(all),
            icon: _exporting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: RatnexColors.gold,
                    ),
                  )
                : Icon(Icons.ios_share, color: RatnexColors.ink, size: 20),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: RatnexColors.rateBoard,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL OUTSTANDING',
                      style: RatnexTheme.label(
                        size: 10.5,
                        weight: FontWeight.w700,
                        color: RatnexColors.rateAccent,
                      ).copyWith(letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      RatnexFormat.money(total),
                      style: RatnexTheme.money(
                        size: 34,
                        color: RatnexColors.onRateBoard,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 14,
                          color: overdueTotal > 0
                              ? RatnexColors.down
                              : RatnexColors.rateAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          overdueTotal > 0
                              ? '${RatnexFormat.money(overdueTotal)} overdue across ${overdue.length} customers'
                              : 'Nothing is overdue',
                          style: RatnexTheme.label(
                            size: 12,
                            color: RatnexColors.rateAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (total > 0) ...[
                const SizedBox(height: 12),
                _AgeingBar(buckets: buckets, total: total),
              ],
              const SizedBox(height: 14),
              RatnexSearchField(
                hint: 'Search by name or phone',
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 10),
              RatnexFilterChips(
                selected: _filter,
                options: [
                  (
                    value: 'pending',
                    label: 'Pending',
                    count: pending.length
                  ),
                  (
                    value: 'overdue',
                    label: 'Overdue',
                    count: overdue.length
                  ),
                  (
                    value: 'settled',
                    label: 'Settled',
                    count: settled.length
                  ),
                  (value: 'all', label: 'All', count: all.length),
                ],
                onSelected: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 14),
              if (loading)
                const RatnexListSkeleton()
              else if (all.isEmpty)
                RatnexEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No khata entries yet',
                  message:
                      'When a bill is left part-paid it lands here automatically. You can also add udhaar by hand from any customer.',
                )
              else if (visible.isEmpty)
                RatnexEmptyState(
                  icon: _filter == 'overdue'
                      ? Icons.check_circle_outline
                      : Icons.search_off,
                  title: _filter == 'overdue'
                      ? 'Nothing is overdue'
                      : 'Nothing matches',
                  message: _filter == 'overdue'
                      ? 'Every customer is still inside their due date.'
                      : 'Try a different name, number or filter.',
                )
              else
                ...visible.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AccountRow(
                      account: a,
                      onRemind: () => _remind(a),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UdhaarDetailPage(
                            phoneId: a.phoneId,
                            name: a.name,
                            phone: a.phone,
                          ),
                        ),
                      ),
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

class _AgeingBar extends StatelessWidget {
  final Map<String, double> buckets;
  final double total;

  const _AgeingBar({required this.buckets, required this.total});

  static const _colors = <String, Color>{
    'Not due': Color(0xFF1B7A4E),
    '0-30d': Color(0xFF9A7B2F),
    '31-60d': Color(0xFFB4531B),
    '61-90d': Color(0xFFB42318),
    '90d+': Color(0xFF7A1410),
  };

  @override
  Widget build(BuildContext context) {
    final entries =
        buckets.entries.where((e) => e.value > 0).toList(growable: false);
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: entries
                  .map(
                    (e) => Expanded(
                      flex: (e.value / total * 1000).round().clamp(1, 1000),
                      child: ColoredBox(
                        color: _colors[e.key] ?? RatnexColors.muted,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 5,
          children: entries.map((e) {
            final color = _colors[e.key] ?? RatnexColors.muted;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${e.key} · ${RatnexFormat.compact(e.value)}',
                  style: RatnexTheme.label(size: 11),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  final UdhaarAccount account;
  final VoidCallback onTap;
  final VoidCallback onRemind;

  const _AccountRow({
    required this.account,
    required this.onTap,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    final color = account.isSettled
        ? RatnexColors.up
        : account.isOverdue
            ? RatnexColors.down
            : RatnexColors.warn;

    return RatnexCard(
      onTap: onTap,
      borderColor: account.isOverdue
          ? RatnexColors.down.withValues(alpha: 0.3)
          : null,
      child: Row(
        children: [
          RatnexAvatar(name: account.name, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name.isEmpty ? account.phone : account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RatnexTheme.label(
                    size: 14,
                    weight: FontWeight.w700,
                    color: RatnexColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  account.isSettled
                      ? 'Settled · ${RatnexFormat.relativeDays(account.lastActivityAt)}'
                      : account.isOverdue
                          ? '${account.daysOverdue} days overdue'
                          : account.oldestDueAt == null
                              ? 'No due date'
                              : 'Due ${RatnexFormat.date(account.oldestDueAt)}',
                  style: RatnexTheme.label(size: 11.5, color: color),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                RatnexFormat.money(account.outstanding),
                style: RatnexTheme.money(size: 15, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                '${account.entryCount} entries',
                style: RatnexTheme.label(size: 10.5),
              ),
            ],
          ),
          if (!account.isSettled) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Send WhatsApp reminder',
              onPressed: onRemind,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.chat_outlined,
                size: 19,
                color: Color(0xFF25D366),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
