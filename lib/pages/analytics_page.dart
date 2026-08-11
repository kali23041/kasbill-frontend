import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/shop_analytics_service.dart';
import '../services/shop_bills_service.dart';
import '../services/shop_cash_service.dart';
import '../services/shop_girvi_service.dart';
import '../services/shop_mod_service.dart';
import '../theme/ratnex_theme.dart';

enum AnalyticsPeriod { daily, weekly, monthly, custom }

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final _billsService = ShopBillsService();
  final _girviService = ShopGirviService();
  final _modService = ShopModService();
  final _cashService = ShopCashService();

  final _subs = <StreamSubscription>[];

  AnalyticsPeriod _period = AnalyticsPeriod.daily;
  DateTime _anchor = ShopAnalyticsService.dayOnly(DateTime.now());
  DateTimeRange? _customRange;

  List<ShopBill> _bills = const [];
  List<ShopGirvi> _girvi = const [];
  List<ShopMod> _mods = const [];
  List<CashDay> _cashDays = const [];
  bool _cashLoading = false;
  bool _ready = false;

  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _subs.add(_billsService.watchBills().listen((v) {
      if (!mounted) return;
      setState(() {
        _bills = v;
        _ready = true;
      });
    }));
    _subs.add(_girviService.watchGirvi().listen((v) {
      if (!mounted) return;
      setState(() => _girvi = v);
    }));
    _subs.add(_modService.watchMod().listen((v) {
      if (!mounted) return;
      setState(() => _mods = v);
    }));
    _loadCash();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  DateTimeRange get _range {
    switch (_period) {
      case AnalyticsPeriod.daily:
        return ShopAnalyticsService.daily(_anchor);
      case AnalyticsPeriod.weekly:
        return ShopAnalyticsService.weekContaining(_anchor);
      case AnalyticsPeriod.monthly:
        return ShopAnalyticsService.monthContaining(_anchor);
      case AnalyticsPeriod.custom:
        return _customRange ?? ShopAnalyticsService.daily(_anchor);
    }
  }

  Future<void> _loadCash() async {
    setState(() => _cashLoading = true);
    final range = _range;
    try {
      final days =
          await _cashService.fetchDaysInRange(range.start, range.end);
      if (!mounted) return;
      setState(() {
        _cashDays = days;
        _cashLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cashDays = const [];
        _cashLoading = false;
      });
    }
  }

  void _setPeriod(AnalyticsPeriod period) {
    setState(() {
      _period = period;
      if (period == AnalyticsPeriod.custom && _customRange == null) {
        _customRange = DateTimeRange(
          start: _anchor.subtract(const Duration(days: 6)),
          end: _anchor,
        );
      }
    });
    if (period == AnalyticsPeriod.custom) {
      _pickCustomRange();
    } else {
      _loadCash();
    }
  }

  Future<void> _pickDaily() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: RatnexColors.gold,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _period = AnalyticsPeriod.daily;
      _anchor = ShopAnalyticsService.dayOnly(picked);
    });
    _loadCash();
  }

  Future<void> _pickCustomRange() async {
    final initial = _customRange ??
        DateTimeRange(
          start: _anchor.subtract(const Duration(days: 6)),
          end: _anchor,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: RatnexColors.gold,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _period = AnalyticsPeriod.custom;
      _customRange = DateTimeRange(
        start: ShopAnalyticsService.dayOnly(picked.start),
        end: ShopAnalyticsService.dayOnly(picked.end),
      );
      _anchor = ShopAnalyticsService.dayOnly(picked.end);
    });
    _loadCash();
  }

  void _shift(int direction) {
    setState(() {
      switch (_period) {
        case AnalyticsPeriod.daily:
          _anchor = _anchor.add(Duration(days: direction));
          break;
        case AnalyticsPeriod.weekly:
          _anchor = _anchor.add(Duration(days: 7 * direction));
          break;
        case AnalyticsPeriod.monthly:
          _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
          break;
        case AnalyticsPeriod.custom:
          break;
      }
    });
    if (_period != AnalyticsPeriod.custom) _loadCash();
  }

  String get _rangeLabel {
    final range = _range;
    final fmt = DateFormat('d MMM yyyy');
    if (ShopAnalyticsService.dayOnly(range.start) ==
        ShopAnalyticsService.dayOnly(range.end)) {
      return fmt.format(range.start);
    }
    return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final snap = ShopAnalyticsService.aggregate(
      range: _range,
      bills: _bills,
      girvi: _girvi,
      mods: _mods,
      cashDays: _cashDays,
    );
    final heatmapMonth = DateTime(_range.start.year, _range.start.month);
    final monthSnap = ShopAnalyticsService.aggregate(
      range: ShopAnalyticsService.monthContaining(heatmapMonth),
      bills: _bills,
      girvi: const [],
      mods: const [],
      cashDays: const [],
    );

    return Scaffold(
      backgroundColor: RatnexColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 14, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    color: RatnexColors.ink,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Analytics', style: RatnexTheme.brand(size: 28)),
                        Text(
                          _rangeLabel,
                          style: RatnexTheme.label(size: 12),
                        ),
                      ],
                    ),
                  ),
                  if (_cashLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            Expanded(
              child: !_ready
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                      children: [
                        _PeriodChips(
                          period: _period,
                          onSelect: _setPeriod,
                        ),
                        const SizedBox(height: 10),
                        _RangeNav(
                          period: _period,
                          label: _rangeLabel,
                          onPrev: _period == AnalyticsPeriod.custom
                              ? null
                              : () => _shift(-1),
                          onNext: _period == AnalyticsPeriod.custom
                              ? null
                              : () => _shift(1),
                          onTapLabel: () {
                            if (_period == AnalyticsPeriod.daily) {
                              _pickDaily();
                            } else if (_period == AnalyticsPeriod.custom) {
                              _pickCustomRange();
                            } else if (_period == AnalyticsPeriod.monthly ||
                                _period == AnalyticsPeriod.weekly) {
                              _pickDaily();
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _KpiGrid(
                          currency: _currency,
                          snap: snap,
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Sales trend',
                          child: snap.salesByDay.every((p) => p.sales == 0)
                              ? const _EmptyHint('No sales in this period')
                              : SizedBox(
                                  height: 200,
                                  child: _SalesTrendChart(
                                    points: snap.salesByDay,
                                    currency: _currency,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Payment mix',
                          child: snap.salesByPaymentMode.isEmpty
                              ? const _EmptyHint('No payment data')
                              : _PaymentBars(
                                  data: snap.salesByPaymentMode,
                                  total: snap.salesTotal,
                                  currency: _currency,
                                ),
                        ),
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Calendar',
                          child: _SalesHeatmap(
                            month: heatmapMonth,
                            points: monthSnap.salesByDay,
                            selected: _period == AnalyticsPeriod.daily
                                ? _anchor
                                : null,
                            onDayTap: (day) {
                              setState(() {
                                _period = AnalyticsPeriod.daily;
                                _anchor = day;
                              });
                              _loadCash();
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Girvi',
                          child: _MetricRows(
                            rows: [
                              (
                                'Loans started',
                                '${snap.girviStarted}',
                              ),
                              (
                                'Amount disbursed',
                                _currency.format(snap.girviLoaned.round()),
                              ),
                              (
                                'Repayments',
                                '${snap.girviPayments}',
                              ),
                              (
                                'Repaid amount',
                                _currency.format(snap.girviRepaid.round()),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Mod',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _MetricRows(
                                rows: [
                                  ('Purchases', '${snap.modCount}'),
                                  (
                                    'Amount paid',
                                    _currency
                                        .format(snap.modPurchased.round()),
                                  ),
                                ],
                              ),
                              if (snap.modByPaymentMode.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _PaymentBars(
                                  data: snap.modByPaymentMode,
                                  total: snap.modPurchased,
                                  currency: _currency,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Cash drawer',
                          child: _MetricRows(
                            rows: [
                              (
                                'Opening (sum)',
                                _currency.format(snap.cashOpeningSum.round()),
                              ),
                              (
                                'Cash out',
                                _currency.format(snap.cashOutTotal.round()),
                              ),
                              (
                                'Net opening − out',
                                _currency.format(
                                  (snap.cashOpeningSum - snap.cashOutTotal)
                                      .round(),
                                ),
                              ),
                            ],
                          ),
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

class _PeriodChips extends StatelessWidget {
  final AnalyticsPeriod period;
  final ValueChanged<AnalyticsPeriod> onSelect;

  const _PeriodChips({required this.period, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Widget chip(AnalyticsPeriod p, String label) {
      final selected = period == p;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelect(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? RatnexColors.ink : RatnexColors.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? RatnexColors.ink : RatnexColors.hairline,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: RatnexTheme.label(
                size: 11,
                weight: FontWeight.w700,
                color: selected ? Colors.white : RatnexColors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(AnalyticsPeriod.daily, 'Daily'),
        const SizedBox(width: 6),
        chip(AnalyticsPeriod.weekly, 'Weekly'),
        const SizedBox(width: 6),
        chip(AnalyticsPeriod.monthly, 'Monthly'),
        const SizedBox(width: 6),
        chip(AnalyticsPeriod.custom, 'Custom'),
      ],
    );
  }
}

class _RangeNav extends StatelessWidget {
  final AnalyticsPeriod period;
  final String label;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onTapLabel;

  const _RangeNav({
    required this.period,
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onTapLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          color: onPrev == null ? RatnexColors.hairline : RatnexColors.ink,
        ),
        Expanded(
          child: InkWell(
            onTap: onTapLabel,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: RatnexColors.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: RatnexColors.hairline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    period == AnalyticsPeriod.custom
                        ? Icons.date_range
                        : Icons.calendar_today_outlined,
                    size: 16,
                    color: RatnexColors.gold,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: RatnexTheme.label(
                        size: 13,
                        weight: FontWeight.w600,
                        color: RatnexColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          color: onNext == null ? RatnexColors.hairline : RatnexColors.ink,
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final NumberFormat currency;
  final AnalyticsSnapshot snap;

  const _KpiGrid({required this.currency, required this.snap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                label: 'Sales',
                value: currency.format(snap.salesTotal.round()),
                large: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiTile(
                label: 'Bills',
                value: '${snap.billCount}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                label: 'Customers',
                value: '${snap.customerCount}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiTile(
                label: 'Avg bill',
                value: currency.format(snap.avgBill.round()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiTile(
                label: 'GST',
                value: currency.format(snap.gstTotal.round()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final bool large;

  const _KpiTile({
    required this.label,
    required this.value,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: RatnexColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RatnexColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: RatnexTheme.label(
              size: 10,
              weight: FontWeight.w700,
              color: RatnexColors.muted,
            ).copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: large
                ? RatnexTheme.money(size: 26)
                : RatnexTheme.money(size: 18),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: RatnexColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RatnexColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: RatnexTheme.label(
              size: 12,
              weight: FontWeight.w700,
              color: RatnexColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: RatnexTheme.label(size: 13)),
    );
  }
}

class _MetricRows extends StatelessWidget {
  final List<(String, String)> rows;

  const _MetricRows({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: 8),
            Container(height: 1, color: RatnexColors.hairline),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  rows[i].$1,
                  style: RatnexTheme.label(size: 13, color: RatnexColors.muted),
                ),
              ),
              Text(
                rows[i].$2,
                style: RatnexTheme.money(size: 16),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PaymentBars extends StatelessWidget {
  final Map<String, double> data;
  final double total;
  final NumberFormat currency;

  const _PaymentBars({
    required this.data,
    required this.total,
    required this.currency,
  });

  String _label(String mode) {
    switch (mode.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      case 'card':
        return 'Card';
      case 'online':
        return 'Online';
      case 'bank':
        return 'Bank';
      case 'mixed':
        return 'Mixed';
      case 'other':
        return 'Other';
      default:
        return mode.isEmpty ? 'Unknown' : mode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = total <= 0
        ? entries.fold<double>(0, (s, e) => s > e.value ? s : e.value)
        : total;

    return Column(
      children: [
        for (final e in entries) ...[
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  _label(e.key),
                  style: RatnexTheme.label(size: 12),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max <= 0 ? 0 : (e.value / max).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: RatnexColors.goldSoft,
                    color: RatnexColors.gold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currency.format(e.value.round()),
                style: RatnexTheme.money(size: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SalesTrendChart extends StatelessWidget {
  final List<DailyPoint> points;
  final NumberFormat currency;

  const _SalesTrendChart({required this.points, required this.currency});

  @override
  Widget build(BuildContext context) {
    final maxY = points.fold<double>(0, (s, p) => p.sales > s ? p.sales : s);
    final yMax = maxY <= 0 ? 1.0 : maxY * 1.15;
    final showEvery = points.length > 10
        ? (points.length / 6).ceil()
        : (points.length > 7 ? 2 : 1);

    return BarChart(
      BarChartData(
        maxY: yMax,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final p = points[group.x.toInt()];
              return BarTooltipItem(
                '${DateFormat('d MMM').format(p.day)}\n${currency.format(p.sales.round())}',
                RatnexTheme.label(size: 11, color: Colors.white),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
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
              reservedSize: 36,
              getTitlesWidget: (v, meta) {
                if (v <= 0 || v >= yMax) return const SizedBox.shrink();
                return Text(
                  NumberFormat.compact().format(v),
                  style: RatnexTheme.label(size: 9),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                if (i % showEvery != 0 && i != points.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat(points.length > 14 ? 'd' : 'd/M')
                        .format(points[i].day),
                    style: RatnexTheme.label(size: 9),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].sales,
                  width: points.length > 20 ? 4 : (points.length > 10 ? 8 : 12),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                  color: RatnexColors.gold,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SalesHeatmap extends StatelessWidget {
  final DateTime month;
  final List<DailyPoint> points;
  final DateTime? selected;
  final ValueChanged<DateTime> onDayTap;

  const _SalesHeatmap({
    required this.month,
    required this.points,
    required this.selected,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final salesMap = <DateTime, double>{
      for (final p in points)
        ShopAnalyticsService.dayOnly(p.day): p.sales,
    };
    // Fill whole month for intensity even if range is shorter subset.
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final maxSales = salesMap.values.fold<double>(0, (s, v) => v > s ? v : s);
    final leading = first.weekday - DateTime.monday; // 0 = Mon

    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(month.year, month.month, d);
      final sales = salesMap[day] ?? 0;
      final intensity = maxSales <= 0 ? 0.0 : (sales / maxSales).clamp(0.0, 1.0);
      final isSelected = selected != null &&
          ShopAnalyticsService.dayOnly(selected!) == day;
      final inRange = salesMap.containsKey(day);

      cells.add(
        GestureDetector(
          onTap: () => onDayTap(day),
          child: Container(
            decoration: BoxDecoration(
              color: intensity <= 0
                  ? (inRange
                      ? RatnexColors.goldSoft.withValues(alpha: 0.35)
                      : RatnexColors.surface)
                  : Color.lerp(
                      RatnexColors.goldSoft,
                      RatnexColors.gold,
                      0.25 + intensity * 0.75,
                    ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? RatnexColors.ink : Colors.transparent,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$d',
              style: RatnexTheme.label(
                size: 11,
                weight: FontWeight.w600,
                color: intensity > 0.55 ? Colors.white : RatnexColors.ink,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Text(
          DateFormat('MMMM yyyy').format(month),
          style: RatnexTheme.label(
            size: 13,
            weight: FontWeight.w700,
            color: RatnexColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final w in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: RatnexTheme.label(
                      size: 10,
                      color: RatnexColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: cells,
        ),
        const SizedBox(height: 8),
        Text(
          'Tap a day for daily analytics',
          style: RatnexTheme.label(size: 11, color: RatnexColors.muted),
        ),
      ],
    );
  }
}
