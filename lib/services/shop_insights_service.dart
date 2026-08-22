import 'package:flutter/material.dart' show DateTimeRange;

import 'shop_bills_service.dart';
import 'shop_girvi_service.dart';
import 'shop_stock_service.dart';

/// Estimated margin on one billed line.
///
/// A jeweller buys and sells metal at close to the same rate, so the metal
/// value is largely pass-through. The real margin is wastage plus making plus
/// other charges — which is exactly what this computes. It is an estimate, and
/// the UI says so.
class LineMargin {
  final double metalValue;
  final double wastageValue;
  final double makingValue;
  final double otherValue;

  const LineMargin({
    required this.metalValue,
    required this.wastageValue,
    required this.makingValue,
    required this.otherValue,
  });

  double get margin => wastageValue + makingValue + otherValue;

  double get revenue => metalValue + margin;

  static LineMargin forItem(BillLineItem item) {
    final qty = item.qty <= 0 ? 1 : item.qty;
    final metal = item.netWeight * item.ratePerGram * qty;
    final wastage = metal * (item.wastagePercent / 100);

    final double making;
    switch (item.makingType) {
      case 'per_gram':
        making = item.makingCharge * item.netWeight * qty;
      case 'percent':
        making = (metal + wastage) * (item.makingCharge / 100);
      default:
        making = item.makingCharge * qty;
    }

    return LineMargin(
      metalValue: metal,
      wastageValue: wastage,
      makingValue: making,
      otherValue: item.otherCharge * qty,
    );
  }
}

class CategorySlice {
  final String label;
  final double revenue;
  final double margin;
  final double grams;
  final int count;

  const CategorySlice({
    required this.label,
    required this.revenue,
    required this.margin,
    required this.grams,
    required this.count,
  });
}

class DeadStockItem {
  final StockItem item;
  final int daysIdle;

  const DeadStockItem({required this.item, required this.daysIdle});

  double get lockedValue => item.addedLineValue;
}

class GirviAgeSlice {
  final String label;
  final int count;
  final double principal;

  const GirviAgeSlice({
    required this.label,
    required this.count,
    required this.principal,
  });
}

class InsightsSnapshot {
  final double revenue;
  final double estimatedMargin;
  final double metalValue;
  final double gramsSold;
  final int billCount;
  final double avgBill;
  final List<CategorySlice> byCategory;
  final List<CategorySlice> byMetal;
  final Map<int, double> byHour;
  final Map<int, int> billsByHour;
  final List<DeadStockItem> deadStock;
  final double deadStockValue;
  final List<GirviAgeSlice> girviAgeing;
  final double previousRevenue;

  const InsightsSnapshot({
    this.revenue = 0,
    this.estimatedMargin = 0,
    this.metalValue = 0,
    this.gramsSold = 0,
    this.billCount = 0,
    this.avgBill = 0,
    this.byCategory = const [],
    this.byMetal = const [],
    this.byHour = const {},
    this.billsByHour = const {},
    this.deadStock = const [],
    this.deadStockValue = 0,
    this.girviAgeing = const [],
    this.previousRevenue = 0,
  });

  double get marginPercent => revenue <= 0 ? 0 : (estimatedMargin / revenue) * 100;

  double get growthPercent =>
      previousRevenue <= 0 ? 0 : ((revenue - previousRevenue) / previousRevenue) * 100;

  /// The hour with the most rupees through the till.
  int? get busiestHour {
    if (byHour.isEmpty) return null;
    var best = byHour.entries.first;
    for (final e in byHour.entries) {
      if (e.value > best.value) best = e;
    }
    return best.key;
  }
}

/// The reports a shop owner actually acts on: margin, dead stock, weight sold,
/// busiest hours and how old the pawn book is.
class ShopInsightsService {
  ShopInsightsService._();

  static bool _inRange(DateTimeRange range, DateTime? at) {
    if (at == null) return false;
    final d = DateTime(at.year, at.month, at.day);
    final s = DateTime(range.start.year, range.start.month, range.start.day);
    final e = DateTime(range.end.year, range.end.month, range.end.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  /// The equivalent window immediately before [range], for growth comparison.
  static DateTimeRange previousWindow(DateTimeRange range) {
    final days = range.end.difference(range.start).inDays + 1;
    final end = range.start.subtract(const Duration(days: 1));
    return DateTimeRange(start: end.subtract(Duration(days: days - 1)), end: end);
  }

  /// Same window one year earlier — festival seasons only compare like for like.
  static DateTimeRange sameWindowLastYear(DateTimeRange range) {
    return DateTimeRange(
      start: DateTime(
        range.start.year - 1,
        range.start.month,
        range.start.day,
      ),
      end: DateTime(range.end.year - 1, range.end.month, range.end.day),
    );
  }

  static InsightsSnapshot compute({
    required DateTimeRange range,
    required List<ShopBill> bills,
    required List<StockItem> stock,
    required List<ShopGirvi> girvi,
    required int deadStockDays,
    DateTimeRange? comparisonRange,
  }) {
    final active = bills.where((b) {
      if (b.paymentStatus == 'cancelled') return false;
      return _inRange(range, b.billedAt ?? b.createdAt);
    }).toList();

    var revenue = 0.0;
    var margin = 0.0;
    var metal = 0.0;
    var grams = 0.0;

    final categories = <String, _Agg>{};
    final metals = <String, _Agg>{};
    final byHour = <int, double>{};
    final billsByHour = <int, int>{};

    for (final b in active) {
      revenue += b.totals.grandTotal;
      final at = b.billedAt ?? b.createdAt;
      if (at != null) {
        byHour[at.hour] = (byHour[at.hour] ?? 0) + b.totals.grandTotal;
        billsByHour[at.hour] = (billsByHour[at.hour] ?? 0) + 1;
      }

      for (final item in b.items) {
        final qty = item.qty <= 0 ? 1 : item.qty;
        final m = LineMargin.forItem(item);
        margin += m.margin;
        metal += m.metalValue;
        grams += item.netWeight * qty;

        final catKey = (item.category ?? 'Uncategorised').trim().isEmpty
            ? 'Uncategorised'
            : item.category!.trim();
        (categories[catKey] ??= _Agg(catKey)).add(
          revenue: item.lineTotal,
          margin: m.margin,
          grams: item.netWeight * qty,
        );

        final metalKey = (item.metalLabel ?? 'Other').trim().isEmpty
            ? 'Other'
            : item.metalLabel!.trim();
        (metals[metalKey] ??= _Agg(metalKey)).add(
          revenue: item.lineTotal,
          margin: m.margin,
          grams: item.netWeight * qty,
        );
      }
    }

    // Dead stock: sitting untouched past the shop's own threshold.
    final now = DateTime.now();
    final dead = <DeadStockItem>[];
    for (final s in stock) {
      if (s.status == 'sold' || s.quantity <= 0) continue;
      final since = s.updatedAt ?? s.createdAt;
      if (since == null) continue;
      final idle = now.difference(since).inDays;
      if (idle < deadStockDays) continue;
      dead.add(DeadStockItem(item: s, daysIdle: idle));
    }
    dead.sort((a, b) => b.lockedValue.compareTo(a.lockedValue));

    // Girvi ageing by how long the loan has been running.
    final ageBuckets = <String, _GirviAgg>{
      '0-3 months': _GirviAgg(),
      '3-6 months': _GirviAgg(),
      '6-12 months': _GirviAgg(),
      'Over a year': _GirviAgg(),
      'Past due': _GirviAgg(),
    };
    for (final g in girvi) {
      if (g.status == 'closed') continue;
      final key = now.isAfter(g.dueDate)
          ? 'Past due'
          : switch (now.difference(g.startedAt).inDays) {
              < 90 => '0-3 months',
              < 180 => '3-6 months',
              < 365 => '6-12 months',
              _ => 'Over a year',
            };
      ageBuckets[key]!.add(g.loanAmount);
    }

    var previousRevenue = 0.0;
    if (comparisonRange != null) {
      for (final b in bills) {
        if (b.paymentStatus == 'cancelled') continue;
        if (!_inRange(comparisonRange, b.billedAt ?? b.createdAt)) continue;
        previousRevenue += b.totals.grandTotal;
      }
    }

    List<CategorySlice> sorted(Map<String, _Agg> map) {
      final list = map.values.map((a) => a.toSlice()).toList()
        ..sort((x, y) => y.revenue.compareTo(x.revenue));
      return list;
    }

    return InsightsSnapshot(
      revenue: revenue,
      estimatedMargin: margin,
      metalValue: metal,
      gramsSold: grams,
      billCount: active.length,
      avgBill: active.isEmpty ? 0 : revenue / active.length,
      byCategory: sorted(categories),
      byMetal: sorted(metals),
      byHour: byHour,
      billsByHour: billsByHour,
      deadStock: dead,
      deadStockValue: dead.fold<double>(0, (s, d) => s + d.lockedValue),
      girviAgeing: ageBuckets.entries
          .map(
            (e) => GirviAgeSlice(
              label: e.key,
              count: e.value.count,
              principal: e.value.principal,
            ),
          )
          .toList(),
      previousRevenue: previousRevenue,
    );
  }
}

class _Agg {
  _Agg(this.label);

  final String label;
  double revenue = 0;
  double margin = 0;
  double grams = 0;
  int count = 0;

  void add({
    required double revenue,
    required double margin,
    required double grams,
  }) {
    this.revenue += revenue;
    this.margin += margin;
    this.grams += grams;
    count++;
  }

  CategorySlice toSlice() => CategorySlice(
        label: label,
        revenue: revenue,
        margin: margin,
        grams: grams,
        count: count,
      );
}

class _GirviAgg {
  int count = 0;
  double principal = 0;

  void add(double amount) {
    count++;
    principal += amount;
  }
}
