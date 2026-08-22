import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_bills_service.dart';
import '../services/shop_girvi_service.dart';
import '../services/shop_insights_service.dart';
import '../services/shop_settings_service.dart';
import '../services/shop_stock_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';

/// Margin, dead stock, weight sold, busiest hours, girvi ageing and how this
/// period compares with last year.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _bills = ShopBillsService();
  final _stock = ShopStockService();
  final _girvi = ShopGirviService();
  final _settings = ShopSettingsService();

  String _period = 'month';
  bool _compareLastYear = false;

  DateTimeRange get _range {
    final now = DateTime.now();
    return switch (_period) {
      'today' => DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        ),
      'week' => DateTimeRange(
          start: DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1)),
          end: DateTime(now.year, now.month, now.day),
        ),
      'year' => DateTimeRange(
          start: RatnexFormat.financialYearStart(now),
          end: DateTime(now.year, now.month, now.day),
        ),
      _ => DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final comparison = _compareLastYear
        ? ShopInsightsService.sameWindowLastYear(range)
        : ShopInsightsService.previousWindow(range);

    return StreamBuilder<ShopSettings>(
      stream: _settings.watchSettings(),
      builder: (context, settingsSnap) {
        final settings = settingsSnap.data ?? ShopSettings.defaults;

        return StreamBuilder<List<ShopBill>>(
          stream: _bills.watchBills(),
          builder: (context, billSnap) {
            return StreamBuilder<List<StockItem>>(
              stream: _stock.watchStock(),
              builder: (context, stockSnap) {
                return StreamBuilder<List<ShopGirvi>>(
                  stream: _girvi.watchGirvi(),
                  builder: (context, girviSnap) {
                    final loading = !billSnap.hasData && !billSnap.hasError;
                    final insights = ShopInsightsService.compute(
                      range: range,
                      bills: billSnap.data ?? const [],
                      stock: stockSnap.data ?? const [],
                      girvi: girviSnap.data ?? const [],
                      deadStockDays: settings.deadStockDays,
                      comparisonRange: comparison,
                    );

                    return RatnexPageScaffold(
                      title: 'Reports',
                      subtitle:
                          '${RatnexFormat.shortDate(range.start)} – ${RatnexFormat.shortDate(range.end)}',
                      showBack: true,
                      body: loading
                          ? const RatnexListSkeleton(rows: 4)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RatnexFilterChips(
                                  selected: _period,
                                  options: const [
                                    (
                                      value: 'today',
                                      label: 'Today',
                                      count: null
                                    ),
                                    (
                                      value: 'week',
                                      label: 'This week',
                                      count: null
                                    ),
                                    (
                                      value: 'month',
                                      label: 'This month',
                                      count: null
                                    ),
                                    (
                                      value: 'year',
                                      label: 'This FY',
                                      count: null
                                    ),
                                  ],
                                  onSelected: (v) =>
                                      setState(() => _period = v),
                                ),
                                const SizedBox(height: 14),
                                _MarginCard(insights: insights),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: RatnexStatTile(
                                        label: 'Weight sold',
                                        value: RatnexFormat.grams(
                                          insights.gramsSold,
                                        ),
                                        caption: 'net weight billed',
                                        icon: Icons.scale_outlined,
                                        accent: RatnexColors.gold,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: RatnexStatTile(
                                        label: 'Bills',
                                        value: '${insights.billCount}',
                                        caption:
                                            'avg ${RatnexFormat.compact(insights.avgBill)}',
                                        icon: Icons.receipt_long_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: RatnexStatTile(
                                        label: 'Metal value',
                                        value: RatnexFormat.compact(
                                          insights.metalValue,
                                        ),
                                        caption: 'pass-through',
                                        icon: Icons.diamond_outlined,
                                        accent: RatnexColors.info,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _ComparisonCard(
                                  insights: insights,
                                  comparingLastYear: _compareLastYear,
                                  onToggle: () => setState(
                                    () => _compareLastYear = !_compareLastYear,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const RatnexSectionLabel(
                                  text: 'WHAT SELLS BEST',
                                ),
                                const SizedBox(height: 10),
                                if (insights.byCategory.isEmpty)
                                  _emptyLine('No sales in this period yet.')
                                else
                                  ...insights.byCategory.take(6).map(
                                        (c) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 9),
                                          child: _SliceRow(
                                            slice: c,
                                            max: insights
                                                .byCategory.first.revenue,
                                          ),
                                        ),
                                      ),
                                const SizedBox(height: 18),
                                const RatnexSectionLabel(text: 'BY METAL'),
                                const SizedBox(height: 10),
                                if (insights.byMetal.isEmpty)
                                  _emptyLine('Nothing billed yet.')
                                else
                                  ...insights.byMetal.take(5).map(
                                        (c) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 9),
                                          child: _SliceRow(
                                            slice: c,
                                            max: insights.byMetal.first.revenue,
                                            showGrams: true,
                                          ),
                                        ),
                                      ),
                                const SizedBox(height: 18),
                                const RatnexSectionLabel(
                                  text: 'BUSIEST HOURS',
                                ),
                                const SizedBox(height: 10),
                                _HourHeatmap(insights: insights),
                                const SizedBox(height: 18),
                                RatnexSectionLabel(
                                  text:
                                      'DEAD STOCK · OVER ${settings.deadStockDays} DAYS',
                                ),
                                const SizedBox(height: 10),
                                if (insights.deadStock.isEmpty)
                                  RatnexNotice(
                                    message:
                                        'Nothing has been sitting untouched for more than ${settings.deadStockDays} days. Your capital is moving.',
                                    color: RatnexColors.up,
                                    icon: Icons.check_circle_outline,
                                  )
                                else ...[
                                  RatnexNotice(
                                    message:
                                        '${RatnexFormat.money(insights.deadStockValue)} is locked up in ${insights.deadStock.length} items that have not moved. Consider a promotion or melting them down.',
                                    color: RatnexColors.warn,
                                    icon: Icons.hourglass_bottom,
                                  ),
                                  const SizedBox(height: 10),
                                  ...insights.deadStock.take(10).map(
                                        (d) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 9),
                                          child: _DeadStockRow(entry: d),
                                        ),
                                      ),
                                ],
                                const SizedBox(height: 18),
                                const RatnexSectionLabel(
                                  text: 'GIRVI AGEING',
                                ),
                                const SizedBox(height: 10),
                                ...insights.girviAgeing
                                    .where((g) => g.count > 0)
                                    .map(
                                      (g) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 9),
                                        child: _AgeRow(slice: g),
                                      ),
                                    ),
                                if (insights.girviAgeing
                                    .every((g) => g.count == 0))
                                  _emptyLine('No open girvi loans.'),
                                const SizedBox(height: 10),
                              ],
                            ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _emptyLine(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text, style: RatnexTheme.label(size: 12.5)),
      );
}

class _MarginCard extends StatelessWidget {
  final InsightsSnapshot insights;

  const _MarginCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RatnexColors.rateBoard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTIMATED MARGIN',
                      style: RatnexTheme.label(
                        size: 10.5,
                        weight: FontWeight.w700,
                        color: RatnexColors.rateAccent,
                      ).copyWith(letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      RatnexFormat.money(insights.estimatedMargin),
                      style: RatnexTheme.money(
                        size: 32,
                        color: RatnexColors.onRateBoard,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'REVENUE',
                    style: RatnexTheme.label(
                      size: 10,
                      weight: FontWeight.w700,
                      color: RatnexColors.rateAccent,
                    ).copyWith(letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    RatnexFormat.compact(insights.revenue),
                    style: RatnexTheme.money(
                      size: 18,
                      color: RatnexColors.onRateBoard,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${insights.marginPercent.toStringAsFixed(1)}% margin',
                    style: RatnexTheme.label(
                      size: 11.5,
                      color: RatnexColors.rateAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Wastage, making and other charges — metal is bought and sold at close to the same rate, so it is not counted as profit.',
            style: RatnexTheme.label(
              size: 11,
              color: RatnexColors.rateAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final InsightsSnapshot insights;
  final bool comparingLastYear;
  final VoidCallback onToggle;

  const _ComparisonCard({
    required this.insights,
    required this.comparingLastYear,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final growth = insights.growthPercent;
    final up = growth >= 0;
    final color = up ? RatnexColors.up : RatnexColors.down;

    return RatnexCard(
      onTap: onToggle,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              up ? Icons.trending_up : Icons.trending_down,
              size: 19,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insights.previousRevenue <= 0
                      ? 'No comparison data'
                      : '${up ? '+' : ''}${growth.toStringAsFixed(1)}% vs ${comparingLastYear ? 'last year' : 'previous period'}',
                  style: RatnexTheme.label(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: insights.previousRevenue <= 0
                        ? RatnexColors.ink
                        : color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insights.previousRevenue <= 0
                      ? 'Tap to switch comparison'
                      : '${RatnexFormat.compact(insights.previousRevenue)} then · ${RatnexFormat.compact(insights.revenue)} now · tap to switch',
                  style: RatnexTheme.label(size: 11.5),
                ),
              ],
            ),
          ),
          Icon(Icons.swap_horiz, size: 18, color: RatnexColors.muted),
        ],
      ),
    );
  }
}

class _SliceRow extends StatelessWidget {
  final CategorySlice slice;
  final double max;
  final bool showGrams;

  const _SliceRow({
    required this.slice,
    required this.max,
    this.showGrams = false,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (slice.revenue / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                slice.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RatnexTheme.label(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: RatnexColors.ink,
                ),
              ),
            ),
            Text(
              showGrams && slice.grams > 0
                  ? '${RatnexFormat.grams(slice.grams)} · ${RatnexFormat.compact(slice.revenue)}'
                  : '${RatnexFormat.compact(slice.revenue)} · ${RatnexFormat.compact(slice.margin)} margin',
              style: RatnexTheme.label(size: 11.5),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: RatnexColors.hairline,
            valueColor: AlwaysStoppedAnimation(RatnexColors.gold),
          ),
        ),
      ],
    );
  }
}

class _HourHeatmap extends StatelessWidget {
  final InsightsSnapshot insights;

  const _HourHeatmap({required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.byHour.isEmpty) {
      return Text(
        'No bills in this period yet.',
        style: RatnexTheme.label(size: 12.5),
      );
    }

    // Shops typically open around 10 and close around 21.
    const from = 9;
    const to = 22;
    final max = insights.byHour.values.fold<double>(0, (a, b) => b > a ? b : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 74,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(to - from + 1, (i) {
              final hour = from + i;
              final value = insights.byHour[hour] ?? 0;
              final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.05, 1.0);
              final peak = value > 0 && value == max;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: 56 * fraction,
                        decoration: BoxDecoration(
                          color: value == 0
                              ? RatnexColors.hairline
                              : peak
                                  ? RatnexColors.gold
                                  : RatnexColors.gold
                                      .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        hour % 3 == 0 ? '$hour' : '',
                        style: RatnexTheme.label(size: 9),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          insights.busiestHour == null
              ? 'Not enough data yet.'
              : 'Busiest around ${_formatHour(insights.busiestHour!)} — ${insights.billsByHour[insights.busiestHour!] ?? 0} bills. Make sure your best salesperson is on the floor then.',
          style: RatnexTheme.label(size: 11.5),
        ),
      ],
    );
  }

  String _formatHour(int hour) {
    final suffix = hour >= 12 ? 'pm' : 'am';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h$suffix';
  }
}

class _DeadStockRow extends StatelessWidget {
  final DeadStockItem entry;

  const _DeadStockRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return RatnexCard(
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: RatnexColors.warn.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.hourglass_bottom,
              size: 16,
              color: RatnexColors.warn,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RatnexTheme.label(
                    size: 13,
                    weight: FontWeight.w700,
                    color: RatnexColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.item.categoryName} · ${RatnexFormat.grams(entry.item.netWeight)} · idle ${entry.daysIdle} days',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RatnexTheme.label(size: 11),
                ),
              ],
            ),
          ),
          Text(
            RatnexFormat.money(entry.lockedValue),
            style: RatnexTheme.money(size: 13),
          ),
        ],
      ),
    );
  }
}

class _AgeRow extends StatelessWidget {
  final GirviAgeSlice slice;

  const _AgeRow({required this.slice});

  @override
  Widget build(BuildContext context) {
    final overdue = slice.label == 'Past due';
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: overdue ? RatnexColors.down : RatnexColors.violet,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            slice.label,
            style: RatnexTheme.label(
              size: 12.5,
              weight: FontWeight.w600,
              color: overdue ? RatnexColors.down : RatnexColors.ink,
            ),
          ),
        ),
        Text(
          '${slice.count} loans · ${RatnexFormat.compact(slice.principal)}',
          style: RatnexTheme.label(size: 11.5),
        ),
      ],
    );
  }
}
