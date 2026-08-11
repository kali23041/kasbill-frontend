import 'package:flutter/material.dart' show DateTimeRange;

import 'shop_bills_service.dart';
import 'shop_cash_service.dart';
import 'shop_girvi_service.dart';
import 'shop_mod_service.dart';

class DailyPoint {
  final DateTime day;
  final double sales;

  const DailyPoint({required this.day, required this.sales});
}

class AnalyticsSnapshot {
  final DateTimeRange range;
  final double salesTotal;
  final int billCount;
  final int customerCount;
  final double gstTotal;
  final double avgBill;
  final Map<String, double> salesByPaymentMode;
  final List<DailyPoint> salesByDay;
  final double girviLoaned;
  final int girviStarted;
  final double girviRepaid;
  final int girviPayments;
  final double modPurchased;
  final int modCount;
  final Map<String, double> modByPaymentMode;
  final double cashOpeningSum;
  final double cashOutTotal;

  const AnalyticsSnapshot({
    required this.range,
    this.salesTotal = 0,
    this.billCount = 0,
    this.customerCount = 0,
    this.gstTotal = 0,
    this.avgBill = 0,
    this.salesByPaymentMode = const {},
    this.salesByDay = const [],
    this.girviLoaned = 0,
    this.girviStarted = 0,
    this.girviRepaid = 0,
    this.girviPayments = 0,
    this.modPurchased = 0,
    this.modCount = 0,
    this.modByPaymentMode = const {},
    this.cashOpeningSum = 0,
    this.cashOutTotal = 0,
  });
}

class ShopAnalyticsService {
  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool rangeContains(DateTimeRange range, DateTime? at) {
    if (at == null) return false;
    final d = dayOnly(at);
    final s = dayOnly(range.start);
    final e = dayOnly(range.end);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  static DateTimeRange daily(DateTime day) {
    final d = dayOnly(day);
    return DateTimeRange(start: d, end: d);
  }

  /// Monday–Sunday week containing [anchor].
  static DateTimeRange weekContaining(DateTime anchor) {
    final d = dayOnly(anchor);
    final monday = d.subtract(Duration(days: d.weekday - DateTime.monday));
    final sunday = monday.add(const Duration(days: 6));
    return DateTimeRange(start: monday, end: sunday);
  }

  static DateTimeRange monthContaining(DateTime anchor) {
    final start = DateTime(anchor.year, anchor.month, 1);
    final end = DateTime(anchor.year, anchor.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  static List<DateTime> daysInRange(DateTimeRange range) {
    final out = <DateTime>[];
    var cursor = dayOnly(range.start);
    final last = dayOnly(range.end);
    while (!cursor.isAfter(last)) {
      out.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return out;
  }

  static AnalyticsSnapshot aggregate({
    required DateTimeRange range,
    required List<ShopBill> bills,
    required List<ShopGirvi> girvi,
    required List<ShopMod> mods,
    required List<CashDay> cashDays,
  }) {
    final activeBills = bills.where((b) {
      if (b.paymentStatus == 'cancelled') return false;
      return rangeContains(range, b.billedAt ?? b.createdAt);
    }).toList();

    final salesTotal =
        activeBills.fold<double>(0, (s, b) => s + b.totals.grandTotal);
    final gstTotal = activeBills.fold<double>(0, (s, b) => s + b.totals.gst);
    final customers = activeBills
        .map((b) => (b.customer.phone ?? b.customer.name).trim())
        .where((s) => s.isNotEmpty)
        .toSet();

    final modeMap = <String, double>{};
    for (final b in activeBills) {
      final mode = (b.paymentMode ?? 'unknown').toLowerCase();
      modeMap[mode] = (modeMap[mode] ?? 0) + b.totals.grandTotal;
    }

    final byDay = <DateTime, double>{};
    for (final day in daysInRange(range)) {
      byDay[day] = 0;
    }
    for (final b in activeBills) {
      final at = b.billedAt ?? b.createdAt;
      if (at == null) continue;
      final key = dayOnly(at);
      byDay[key] = (byDay[key] ?? 0) + b.totals.grandTotal;
    }
    final salesByDay = byDay.entries
        .map((e) => DailyPoint(day: e.key, sales: e.value))
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));

    double girviLoaned = 0;
    var girviStarted = 0;
    for (final g in girvi) {
      if (!rangeContains(range, g.startedAt)) continue;
      girviStarted++;
      girviLoaned += g.loanAmount;
    }

    double girviRepaid = 0;
    var girviPayments = 0;
    for (final g in girvi) {
      for (final p in g.payments) {
        if (!rangeContains(range, p.paidAt)) continue;
        girviPayments++;
        girviRepaid += p.amount;
      }
    }

    final activeMods = mods.where((m) {
      if (m.status == 'cancelled') return false;
      return rangeContains(range, m.paidAt);
    }).toList();
    final modPurchased =
        activeMods.fold<double>(0, (s, m) => s + m.totals.purchaseAmount);
    final modModes = <String, double>{};
    for (final m in activeMods) {
      final mode = m.paymentMode.toLowerCase();
      modModes[mode] = (modModes[mode] ?? 0) + m.totals.purchaseAmount;
    }

    double cashOpening = 0;
    double cashOut = 0;
    for (final c in cashDays) {
      if (!rangeContains(range, c.date)) continue;
      cashOpening += c.openingCash;
      cashOut += c.outsTotal;
    }

    final billCount = activeBills.length;
    return AnalyticsSnapshot(
      range: range,
      salesTotal: salesTotal,
      billCount: billCount,
      customerCount: customers.length,
      gstTotal: gstTotal,
      avgBill: billCount == 0 ? 0 : salesTotal / billCount,
      salesByPaymentMode: modeMap,
      salesByDay: salesByDay,
      girviLoaned: girviLoaned,
      girviStarted: girviStarted,
      girviRepaid: girviRepaid,
      girviPayments: girviPayments,
      modPurchased: modPurchased,
      modCount: activeMods.length,
      modByPaymentMode: modModes,
      cashOpeningSum: cashOpening,
      cashOutTotal: cashOut,
    );
  }
}
