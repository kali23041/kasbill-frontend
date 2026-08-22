import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_mod_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';
import 'create_mod_page.dart';
import 'view_mod_page.dart';

class ModPage extends StatefulWidget {
  const ModPage({super.key});

  @override
  State<ModPage> createState() => _ModPageState();
}

class _ModPageState extends State<ModPage> {
  final _search = TextEditingController();
  String _query = '';
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(ShopMod m) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return m.modNo.toLowerCase().contains(q) ||
        m.customer.name.toLowerCase().contains(q) ||
        (digits.isNotEmpty && (m.customer.phone ?? '').contains(digits)) ||
        m.items.any((i) => i.name.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final service = ShopModService();

    return StreamBuilder<List<ShopMod>>(
      stream: service.watchMod(),
      builder: (context, snap) {
        final list = snap.data ?? const <ShopMod>[];
        final completedList =
            list.where((m) => m.status == 'completed').toList();
        final cancelledList =
            list.where((m) => m.status == 'cancelled').toList();
        final completed = completedList.length;
        final cancelled = cancelledList.length;

        final now = DateTime.now();
        final monthList = completedList
            .where((m) => m.paidAt.year == now.year && m.paidAt.month == now.month)
            .toList();
        final monthSpend =
            monthList.fold<double>(0, (s, m) => s + m.totals.purchaseAmount);
        final monthGrams = monthList.fold<double>(
          0,
          (s, m) => s + m.items.fold<double>(0, (t, i) => t + i.netWeight),
        );

        var visible = switch (_filter) {
          'completed' => completedList,
          'cancelled' => cancelledList,
          _ => list,
        };
        visible = visible.where(_matches).toList();

        return RatnexPageScaffold(
          title: 'Mod',
          subtitle: 'Buy ornaments  ·  direct payment',
          showBack: true,
          trailing: RatnexHeaderChip(
            label: cancelled > 0
                ? '$cancelled cancelled'
                : '$completed purchases',
            color: cancelled > 0 ? RatnexColors.muted : RatnexColors.gold,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RatnexPrimaryButton(
                label: 'New Mod',
                icon: Icons.add,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateModPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Paid this month',
                      value: RatnexFormat.compact(monthSpend),
                      caption: '${monthList.length} purchases',
                      icon: Icons.swap_horiz,
                      accent: RatnexColors.info,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Gold taken in',
                      value: RatnexFormat.grams(monthGrams),
                      caption: 'net weight',
                      icon: Icons.scale_outlined,
                      accent: RatnexColors.gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'All time',
                      value: '$completed',
                      caption: '$cancelled cancelled',
                      icon: Icons.handshake_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RatnexSearchField(
                hint: 'Search MOD no, customer or item',
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 10),
              RatnexFilterChips(
                selected: _filter,
                options: [
                  (value: 'all', label: 'All', count: list.length),
                  (value: 'completed', label: 'Completed', count: completed),
                  (value: 'cancelled', label: 'Cancelled', count: cancelled),
                ],
                onSelected: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 14),
              const RatnexSectionLabel(text: 'All purchases'),
              const SizedBox(height: 8),
              if (snap.hasError)
                RatnexPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Could not load mod: ${snap.error}',
                      style: RatnexTheme.label(size: 13),
                    ),
                  ),
                )
              else if (!snap.hasData)
                const RatnexListSkeleton()
              else if (list.isEmpty)
                RatnexEmptyState(
                  icon: Icons.handshake_outlined,
                  title: 'No old-gold purchases yet',
                  message:
                      'Buy customer ornaments with a proper appraisal, capture their ID proof and pay on the spot.',
                  actionLabel: 'New purchase',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateModPage()),
                  ),
                )
              else if (visible.isEmpty)
                RatnexEmptyState(
                  icon: Icons.search_off,
                  title: 'Nothing matches',
                  message: 'Try a different MOD number, name or filter.',
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
                        _ModRow(
                          mod: visible[i],
                          currency: currency,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ViewModPage(mod: visible[i]),
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

class _ModRow extends StatelessWidget {
  final ShopMod mod;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _ModRow({
    required this.mod,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = mod.items.isNotEmpty
        ? StockImageHelper.decodeBase64(mod.items.first.imageBase64)
        : null;
    final date = DateFormat('d MMM').format(mod.paidAt);

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
                    mod.customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RatnexTheme.label(
                      size: 13,
                      weight: FontWeight.w700,
                      color: RatnexColors.ink,
                    ),
                  ),
                  Text(
                    '${mod.modNo} · $date',
                    style: RatnexTheme.label(size: 11),
                  ),
                  Text(
                    mod.items.length == 1
                        ? mod.items.first.name
                        : '${mod.items.length} items · ${mod.paymentModeLabel}',
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
                  currency.format(mod.totals.purchaseAmount.round()),
                  style: RatnexTheme.money(size: 13, color: RatnexColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  mod.statusLabel,
                  style: RatnexTheme.label(
                    size: 11,
                    weight: FontWeight.w700,
                    color: mod.status == 'cancelled'
                        ? RatnexColors.muted
                        : RatnexColors.up,
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
