import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_girvi_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';
import 'create_girvi_page.dart';
import 'view_girvi_page.dart';

class GirviPage extends StatelessWidget {
  const GirviPage({super.key});

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
        final active = list.where((g) => g.effectiveStatus == 'active').length;
        final overdue =
            list.where((g) => g.effectiveStatus == 'overdue').length;

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
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: RatnexColors.gold),
                  ),
                )
              else if (list.isEmpty)
                RatnexPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.account_balance_outlined,
                          size: 32,
                          color: RatnexColors.gold,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No girvi yet',
                          style: RatnexTheme.label(
                            size: 15,
                            weight: FontWeight.w700,
                            color: RatnexColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Record a gold loan from New Girvi.',
                          style: RatnexTheme.label(size: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else
                RatnexPanel(
                  child: Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            color: RatnexColors.hairline,
                          ),
                        _GirviRow(
                          girvi: list[i],
                          currency: currency,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ViewGirviPage(girvi: list[i]),
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
                        child: const Icon(
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
