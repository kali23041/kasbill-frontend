import 'package:flutter/material.dart';

import '../services/shop_rates_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';

/// "Gold 22K ₹7,240 ▲ +45 since yesterday" — a shop owner reads the rupee
/// move, not the percentage.
class RateDeltaStrip extends StatefulWidget {
  final List<ShopMetalRate> metals;

  const RateDeltaStrip({super.key, required this.metals});

  @override
  State<RateDeltaStrip> createState() => _RateDeltaStripState();
}

class _RateDeltaStripState extends State<RateDeltaStrip> {
  final _service = ShopRatesService();
  final _deltas = <String, ({double change, double percent, DateTime? since})>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RateDeltaStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metals.length != widget.metals.length) _load();
  }

  Future<void> _load() async {
    for (final m in widget.metals.take(4)) {
      final delta = await _service.rateDelta(m.id, m.shopRatePerGram);
      if (!mounted) return;
      if (delta != null && delta.change.abs() >= 0.5) {
        _deltas[m.id] = delta;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _deltas.isEmpty) return const SizedBox.shrink();

    final entries = widget.metals
        .where((m) => _deltas.containsKey(m.id))
        .take(3)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final metal = entries[i];
          final delta = _deltas[metal.id]!;
          final up = delta.change >= 0;
          final color = up ? RatnexColors.up : RatnexColors.down;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withValues(alpha: 0.24)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metal.label,
                  style: RatnexTheme.label(
                    size: 11,
                    weight: FontWeight.w600,
                    color: RatnexColors.ink,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  size: 16,
                  color: color,
                ),
                Text(
                  '${up ? '+' : '−'}${RatnexFormat.money(delta.change.abs())}',
                  style: RatnexTheme.label(
                    size: 11,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'since ${RatnexFormat.relativeDays(delta.since).toLowerCase()}',
                  style: RatnexTheme.label(size: 10),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
