import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_mod_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';
import 'create_mod_page.dart';
import 'view_mod_page.dart';

class ModPage extends StatelessWidget {
  const ModPage({super.key});

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
        final completed =
            list.where((m) => m.status == 'completed').length;
        final cancelled =
            list.where((m) => m.status == 'cancelled').length;

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
                          Icons.handshake_outlined,
                          size: 32,
                          color: RatnexColors.gold,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No mod purchases yet',
                          style: RatnexTheme.label(
                            size: 15,
                            weight: FontWeight.w700,
                            color: RatnexColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Buy customer ornaments with appraisal and pay directly.',
                          style: RatnexTheme.label(size: 13),
                          textAlign: TextAlign.center,
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
                        _ModRow(
                          mod: list[i],
                          currency: currency,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ViewModPage(mod: list[i]),
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
