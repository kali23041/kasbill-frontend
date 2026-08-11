import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/shop_rates_service.dart';
import '../services/shop_stock_service.dart';
import '../theme/ratnex_theme.dart';
import 'metals_diamonds_page.dart';

class MetalDetailPage extends StatelessWidget {
  final ShopMetalRate metal;
  final double? liveRatePerGram;

  const MetalDetailPage({
    super.key,
    required this.metal,
    this.liveRatePerGram,
  });

  static Route<void> route({
    required ShopMetalRate metal,
    double? liveRatePerGram,
  }) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return MetalDetailPage(
          metal: metal,
          liveRatePerGram: liveRatePerGram,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final rates = ShopRatesService();
    final stock = ShopStockService();
    final live = liveRatePerGram ?? metal.liveRatePerGram;

    return Scaffold(
      backgroundColor: RatnexColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    color: RatnexColors.ink,
                  ),
                  Expanded(
                    child: Text(
                      metal.label,
                      style: RatnexTheme.brand(size: 24),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MetalsDiamondsPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Edit',
                      style: RatnexTheme.label(
                        size: 14,
                        weight: FontWeight.w700,
                        color: RatnexColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                children: [
                  Hero(
                    tag: 'metal-rate-${metal.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        decoration: BoxDecoration(
                          color: RatnexColors.rateBoard,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metal.label.toUpperCase(),
                              style: RatnexTheme.label(
                                size: 11,
                                weight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.55),
                              ).copyWith(letterSpacing: 0.6),
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: currency
                                        .format(metal.shopRatePerGram.round()),
                                    style: RatnexTheme.money(
                                      size: 32,
                                      color: RatnexColors.rateAccent,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' /g',
                                    style: RatnexTheme.label(
                                      size: 14,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (live != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Live ${currency.format(live.round())}/g',
                                style: RatnexTheme.label(
                                  size: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                            if (metal.updatedAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Updated ${DateFormat('d MMM yyyy · h:mm a').format(metal.updatedAt!)}',
                                style: RatnexTheme.label(
                                  size: 11,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<MetalRatePoint>>(
                    stream: rates.watchHistory(metal.id),
                    builder: (context, histSnap) {
                      final history = histSnap.data ?? const <MetalRatePoint>[];
                      final points = history.isEmpty
                          ? [
                              MetalRatePoint(
                                id: 'now',
                                date: DateTime.now(),
                                shopRatePerGram: metal.shopRatePerGram,
                                liveRatePerGram: metal.liveRatePerGram,
                              ),
                            ]
                          : history;

                      final ratesOnly =
                          points.map((p) => p.shopRatePerGram).toList();
                      final high =
                          ratesOnly.reduce((a, b) => a > b ? a : b);
                      final low =
                          ratesOnly.reduce((a, b) => a < b ? a : b);
                      final first = ratesOnly.first;
                      final last = ratesOnly.last;
                      final changePct =
                          first > 0 ? ((last - first) / first) * 100 : 0.0;
                      final up = changePct >= 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rate history',
                            style: RatnexTheme.label(
                              size: 12,
                              weight: FontWeight.w700,
                              color: RatnexColors.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 220,
                            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                            decoration: BoxDecoration(
                              color: RatnexColors.panel,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: RatnexColors.hairline),
                            ),
                            child: _RateChart(
                              points: points,
                              currency: currency,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatChip(
                                  label: 'High',
                                  value: currency.format(high.round()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatChip(
                                  label: 'Low',
                                  value: currency.format(low.round()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatChip(
                                  label: 'Change',
                                  value:
                                      '${up ? '+' : ''}${changePct.toStringAsFixed(1)}%',
                                  valueColor: changePct.abs() < 0.05
                                      ? RatnexColors.muted
                                      : (up
                                          ? RatnexColors.up
                                          : RatnexColors.down),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  StreamBuilder<List<StockItem>>(
                    stream: stock.watchStock(),
                    builder: (context, stockSnap) {
                      final items = (stockSnap.data ?? const <StockItem>[])
                          .where(
                            (i) =>
                                i.metalId == metal.id && i.status != 'sold',
                          )
                          .toList();
                      final pcs = items.fold<int>(0, (s, i) => s + i.quantity);
                      final weight = items.fold<double>(
                        0,
                        (s, i) => s + i.netWeight * i.quantity,
                      );

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: RatnexColors.panel,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: RatnexColors.hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Linked stock',
                              style: RatnexTheme.label(
                                size: 12,
                                weight: FontWeight.w700,
                                color: RatnexColors.muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatChip(
                                    label: 'Items',
                                    value: '${items.length}',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatChip(
                                    label: 'Pieces',
                                    value: '$pcs',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatChip(
                                    label: 'Net g',
                                    value: weight.toStringAsFixed(1),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatChip({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: RatnexColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RatnexColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: RatnexTheme.label(size: 10)),
          const SizedBox(height: 4),
          Text(
            value,
            style: RatnexTheme.label(
              size: 14,
              weight: FontWeight.w700,
              color: valueColor ?? RatnexColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _RateChart extends StatelessWidget {
  final List<MetalRatePoint> points;
  final NumberFormat currency;

  const _RateChart({required this.points, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Text('No history yet', style: RatnexTheme.label(size: 13)),
      );
    }

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].shopRatePerGram),
    ];

    var minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    var maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if ((maxY - minY).abs() < 1) {
      minY -= 50;
      maxY += 50;
    } else {
      final pad = (maxY - minY) * 0.12;
      minY -= pad;
      maxY += pad;
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).clamp(1, 999).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: RatnexColors.hairline,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(
                NumberFormat.compactCurrency(
                  locale: 'en_IN',
                  symbol: '₹',
                  decimalDigits: 0,
                ).format(v),
                style: RatnexTheme.label(size: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: points.length <= 4
                  ? 1
                  : (points.length / 4).ceilToDouble(),
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('d MMM').format(points[i].date),
                    style: RatnexTheme.label(size: 9),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) {
              return touched.map((t) {
                final i = t.x.round().clamp(0, points.length - 1);
                final p = points[i];
                return LineTooltipItem(
                  '${DateFormat('d MMM').format(p.date)}\n${currency.format(p.shopRatePerGram.round())}/g',
                  RatnexTheme.label(
                    size: 11,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: points.length > 2,
            color: RatnexColors.gold,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: points.length <= 12,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                radius: 3.5,
                color: RatnexColors.gold,
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: RatnexColors.gold.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
