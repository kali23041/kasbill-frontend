import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_girvi_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';
import 'create_girvi_page.dart';
import 'view_girvi_page.dart';

class GirviPage extends StatefulWidget {
  const GirviPage({super.key});

  @override
  State<GirviPage> createState() => _GirviPageState();
}

class _GirviPageState extends State<GirviPage> {
  final _search = TextEditingController();
  String _query = '';
  String _filter = 'open';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(ShopGirvi g) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return g.girviNo.toLowerCase().contains(q) ||
        g.customer.name.toLowerCase().contains(q) ||
        (digits.isNotEmpty && (g.customer.phone ?? '').contains(digits)) ||
        g.items.any((i) => i.name.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final service = ShopGirviService();

    return StreamBuilder<List<ShopGirvi>>(
      stream: service.watchGirvi(),
      builder: (context, snap) {
        final list = snap.data ?? const <ShopGirvi>[];
        final activeList =
            list.where((g) => g.effectiveStatus == 'active').toList();
        final overdueList =
            list.where((g) => g.effectiveStatus == 'overdue').toList();
        final closedList = list.where((g) => g.status == 'closed').toList();
        final active = activeList.length;
        final overdue = overdueList.length;

        final openList = [...overdueList, ...activeList];
        final principalOut =
            openList.fold<double>(0, (s, g) => s + g.totals.balance);
        final dueSoon = activeList
            .where(
              (g) =>
                  g.dueDate.difference(DateTime.now()).inDays <= 7 &&
                  g.dueDate.isAfter(DateTime.now()),
            )
            .length;

        var visible = switch (_filter) {
          'overdue' => overdueList,
          'closed' => closedList,
          'all' => list,
          _ => openList,
        };
        visible = visible.where(_matches).toList();

        return RatnexPageScaffold(
          title: 'Girvi',
          subtitle: 'Gold loans  ·  pledge & interest',
          trailing: RatnexHeaderChip(
            label: overdue > 0 ? '$overdue overdue' : '$active active',
            color: overdue > 0 ? RatnexColors.down : RatnexColors.gold,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RatnexPrimaryButton(
                label: 'New Girvi',
                icon: Icons.add,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateGirviPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Money out',
                      value: RatnexFormat.compact(principalOut),
                      caption: '${openList.length} open pledges',
                      icon: Icons.account_balance_outlined,
                      accent: RatnexColors.violet,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Overdue',
                      value: '$overdue',
                      caption: overdue == 0 ? 'All on time' : 'Chase these',
                      icon: Icons.error_outline,
                      accent:
                          overdue == 0 ? RatnexColors.up : RatnexColors.down,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Due in 7d',
                      value: '$dueSoon',
                      caption: 'coming up',
                      icon: Icons.schedule,
                      accent: RatnexColors.warn,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RatnexSearchField(
                hint: 'Search girvi no, customer or item',
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 10),
              RatnexFilterChips(
                selected: _filter,
                options: [
                  (value: 'open', label: 'Open', count: openList.length),
                  (value: 'overdue', label: 'Overdue', count: overdue),
                  (value: 'closed', label: 'Closed', count: closedList.length),
                  (value: 'all', label: 'All', count: list.length),
                ],
                onSelected: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 14),
              const RatnexSectionLabel(text: 'All pledges'),
              const SizedBox(height: 8),
              if (snap.hasError)
                RatnexPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Could not load girvi: ${snap.error}',
                      style: RatnexTheme.label(size: 13),
                    ),
                  ),
                )
              else if (!snap.hasData)
                const RatnexListSkeleton()
              else if (list.isEmpty)
                RatnexEmptyState(
                  icon: Icons.account_balance_outlined,
                  title: 'No girvi yet',
                  message:
                      'Record a gold loan and Ratnex tracks the interest, the due date and reminds you before it lapses.',
                  actionLabel: 'New girvi',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateGirviPage()),
                  ),
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
                      ? 'Every open pledge is still inside its due date.'
                      : 'Try a different girvi number, name or filter.',
                )
              else
                RatnexPanel(
                  child: Column(
                    children: [
                      for (var i = 0; i < visible.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: RatnexColors.hairline,
                          ),
                        _GirviRow(
                          girvi: visible[i],
                          currency: currency,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ViewGirviPage(girvi: visible[i]),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GirviRow extends StatelessWidget {
  final ShopGirvi girvi;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _GirviRow({
    required this.girvi,
    required this.currency,
    required this.onTap,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'closed':
        return RatnexColors.muted;
      case 'overdue':
        return RatnexColors.down;
      default:
        return RatnexColors.up;
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumb = girvi.items.isNotEmpty
        ? StockImageHelper.decodeBase64(girvi.items.first.imageBase64)
        : null;
    final due = DateFormat('d MMM').format(girvi.dueDate);
    final status = girvi.effectiveStatus;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: thumb != null
                    ? Image.memory(thumb, fit: BoxFit.cover)
                    : Container(
                        color: RatnexColors.goldSoft,
                        child: Icon(
                          Icons.diamond_outlined,
                          color: RatnexColors.gold,
                          size: 22,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    girvi.customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RatnexTheme.label(
                      size: 13,
                      weight: FontWeight.w700,
                      color: RatnexColors.ink,
                    ),
                  ),
                  Text(
                    '${girvi.girviNo} · due $due',
                    style: RatnexTheme.label(size: 11),
                  ),
                  Text(
                    girvi.items.length == 1
                        ? girvi.items.first.name
                        : '${girvi.items.length} items',
                    style: RatnexTheme.label(size: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(girvi.loanAmount.round()),
                  style: RatnexTheme.money(size: 13, color: RatnexColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  girvi.statusLabel,
                  style: RatnexTheme.label(
                    size: 11,
                    weight: FontWeight.w700,
                    color: _statusColor(status),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
