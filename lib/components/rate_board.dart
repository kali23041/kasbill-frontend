import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../pages/metal_detail_page.dart';
import '../services/ibja_rates_service.dart';
import '../services/shop_rates_service.dart';
import '../theme/ratnex_theme.dart';

class RateBoardItem {
  final String label;
  final String? value;
  final double? delta;
  final String? subtitle;
  final String unit;
  final String? heroTag;
  final VoidCallback? onTap;

  const RateBoardItem({
    required this.label,
    required this.value,
    this.delta,
    this.subtitle,
    this.unit = '/g',
    this.heroTag,
    this.onTap,
  });
}

/// Dark live-rate strip matching the home dashboard rate card.
class RatnexRateBoard extends StatelessWidget {
  final bool loading;
  final String? error;
  final String header;
  final List<RateBoardItem> items;
  final VoidCallback onRetry;
  final bool wrap;
  final bool scrollable;
  final String? emptyMessage;

  const RatnexRateBoard({
    super.key,
    required this.loading,
    required this.error,
    required this.header,
    required this.items,
    required this.onRetry,
    this.wrap = false,
    this.scrollable = false,
    this.emptyMessage,
  });

  /// Home board: only metals the shop has saved, horizontally slidable.
  factory RatnexRateBoard.fromShopMetals({
    required bool loading,
    required String? error,
    required List<ShopMetalRate>? metals,
    required NumberFormat currency,
    required VoidCallback onRetry,
    IbjaRates? liveRates,
    required BuildContext context,
  }) {
    final header = liveRates == null
        ? 'YOUR METAL RATES'
        : 'YOUR METALS  ·  ${DateFormat('d MMM').format(liveRates.date)}  ·  ${liveRates.session}';

    final items = (metals ?? const <ShopMetalRate>[])
        .map((m) {
          final live = liveRates?.onlineRatePerGram(
                metalType: m.metalType,
                karat: m.karat,
              ) ??
              m.liveRatePerGram;
          return RateBoardItem(
            label: _shortLabel(m),
            value: currency.format(m.shopRatePerGram.round()),
            subtitle: live != null
                ? 'Live ${currency.format(live.round())}'
                : null,
            heroTag: 'metal-rate-${m.id}',
            onTap: () {
              Navigator.of(context).push(
                MetalDetailPage.route(
                  metal: m,
                  liveRatePerGram: live,
                ),
              );
            },
          );
        })
        .toList();

    return RatnexRateBoard(
      loading: loading,
      error: error,
      header: header,
      items: items,
      onRetry: onRetry,
      scrollable: true,
      emptyMessage: 'Add metals in Profile → Metals & Diamonds',
    );
  }

  factory RatnexRateBoard.fromIbja({
    required bool loading,
    required String? error,
    required IbjaRates? rates,
    required NumberFormat currency,
    required VoidCallback onRetry,
    bool expanded = false,
  }) {
    final header = rates == null
        ? 'IBJA LIVE RATES'
        : 'IBJA  ·  ${DateFormat('d MMM').format(rates.date)}  ·  ${rates.session}';

    final items = rates == null
        ? const <RateBoardItem>[]
        : expanded
            ? [
                RateBoardItem(
                  label: '18K',
                  value: currency.format(rates.gold18kPerGram.round()),
                ),
                RateBoardItem(
                  label: '20K',
                  value: currency.format(rates.gold20kPerGram.round()),
                ),
                RateBoardItem(
                  label: '22K',
                  value: currency.format(rates.gold22kPerGram.round()),
                  delta: rates.delta22kPct,
                ),
                RateBoardItem(
                  label: '24K',
                  value: currency.format(rates.gold24kPerGram.round()),
                  delta: rates.delta24kPct,
                ),
                RateBoardItem(
                  label: 'Ag 999',
                  value: currency.format(rates.silver999PerGram.round()),
                  delta: rates.deltaSilverPct,
                ),
                RateBoardItem(
                  label: 'Ag 970',
                  value: currency.format(rates.silver970PerGram.round()),
                ),
                RateBoardItem(
                  label: 'Ag 925',
                  value: currency.format(rates.silver925PerGram.round()),
                ),
                RateBoardItem(
                  label: 'Ag 900',
                  value: currency.format(rates.silver900PerGram.round()),
                ),
                RateBoardItem(
                  label: 'Ag 800',
                  value: currency.format(rates.silver800PerGram.round()),
                ),
                const RateBoardItem(label: 'Platinum', value: null),
              ]
            : [
                RateBoardItem(
                  label: '22K Gold',
                  value: currency.format(rates.gold22kPerGram.round()),
                  delta: rates.delta22kPct,
                ),
                RateBoardItem(
                  label: '24K Gold',
                  value: currency.format(rates.gold24kPerGram.round()),
                  delta: rates.delta24kPct,
                ),
                RateBoardItem(
                  label: 'Silver',
                  value: currency.format(rates.silverPerGram.round()),
                  delta: rates.deltaSilverPct,
                ),
              ];

    return RatnexRateBoard(
      loading: loading,
      error: error,
      header: header,
      items: items,
      onRetry: onRetry,
      wrap: expanded,
    );
  }

  static String _shortLabel(ShopMetalRate m) {
    if (m.metalType == 'gold' && m.karat != null) return '${m.karat}K';
    if (m.metalType == 'silver' && m.karat != null) return 'Ag ${m.karat}';
    if (m.metalType == 'platinum') return 'Pt';
    if (m.metalType == 'custom') {
      final name = m.customName?.trim() ?? 'Custom';
      return name.length > 10 ? '${name.substring(0, 9)}…' : name;
    }
    return m.label;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: BoxDecoration(
        color: RatnexColors.rateBoard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  header,
                  style: RatnexTheme.label(
                    size: 10,
                    weight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5),
                  ).copyWith(letterSpacing: 0.5),
                ),
              ),
              GestureDetector(
                onTap: loading ? null : onRetry,
                child: Icon(
                  Icons.refresh,
                  size: 16,
                  color: Colors.white.withValues(alpha: loading ? 0.25 : 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RatnexColors.rateAccent,
                ),
              ),
            )
          else if (error != null && items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    error!,
                    style: RatnexTheme.label(
                      size: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: RatnexColors.rateAccent,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Text(
                emptyMessage ?? 'Rates unavailable',
                textAlign: TextAlign.center,
                style: RatnexTheme.label(
                  size: 12,
                  color: Colors.white70,
                ),
              ),
            )
          else if (scrollable)
            _ScrollableRateRow(items: items)
          else if (wrap)
            _WrappedRateGrid(items: items)
          else
            Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Container(width: 1, height: 44, color: Colors.white12),
                  Expanded(child: _RateCol(item: items[i])),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ScrollableRateRow extends StatelessWidget {
  final List<RateBoardItem> items;

  const _ScrollableRateRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / 3;
        return SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => Container(
              width: 1,
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 14),
              color: Colors.white12,
            ),
            itemBuilder: (context, index) {
              return SizedBox(
                width: slot,
                child: _RateCol(item: items[index]),
              );
            },
          ),
        );
      },
    );
  }
}

class _WrappedRateGrid extends StatelessWidget {
  final List<RateBoardItem> items;

  const _WrappedRateGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final rows = <List<RateBoardItem>>[];
    for (var i = 0; i < items.length; i += 3) {
      rows.add(items.sublist(i, i + 3 > items.length ? items.length : i + 3));
    }

    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < rows[r].length; i++) ...[
                if (i > 0)
                  Container(width: 1, height: 44, color: Colors.white12),
                Expanded(child: _RateCol(item: rows[r][i])),
              ],
              for (var p = rows[r].length; p < 3; p++) ...[
                Container(width: 1, height: 44, color: Colors.white12),
                const Expanded(child: SizedBox()),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _RateCol extends StatelessWidget {
  final RateBoardItem item;

  const _RateCol({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasDelta = item.delta != null;
    final up = (item.delta ?? 0) >= 0;
    final deltaColor = up ? const Color(0xFF6FCF97) : const Color(0xFFFF8A80);
    final valueText = item.value ?? '—';

    Widget col = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          item.label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: RatnexTheme.label(
            size: 10,
            weight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.55),
          ).copyWith(letterSpacing: 0.6),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: valueText,
                style: RatnexTheme.money(
                  size: 15,
                  color: RatnexColors.rateAccent,
                ),
              ),
              if (item.value != null)
                TextSpan(
                  text: item.unit,
                  style: RatnexTheme.label(
                    size: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (hasDelta)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 16,
                color: deltaColor,
              ),
              Text(
                '${up ? '+' : ''}${item.delta!.toStringAsFixed(2)}%',
                style: RatnexTheme.label(
                  size: 11,
                  weight: FontWeight.w600,
                  color: deltaColor,
                ),
              ),
            ],
          )
        else if (item.subtitle != null)
          Text(
            item.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RatnexTheme.label(
              size: 10,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          )
        else
          const SizedBox(height: 14),
      ],
    );

    if (item.heroTag != null) {
      col = Hero(
        tag: item.heroTag!,
        child: Material(
          color: Colors.transparent,
          child: col,
        ),
      );
    }

    if (item.onTap != null) {
      return InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(8),
        child: col,
      );
    }
    return col;
  }
}
