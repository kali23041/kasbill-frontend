import 'package:flutter/foundation.dart';

import '../utils/ratnex_format.dart';
import 'notifications_service.dart';
import 'shop_girvi_service.dart';
import 'shop_ledger_service.dart';
import 'shop_repairs_service.dart';
import 'shop_schemes_service.dart';
import 'shop_settings_service.dart';

/// Walks the shop's data and files reminders for anything coming due.
///
/// Runs on the device rather than in a Cloud Function so it works on the free
/// Firebase plan; the reminders it writes are also exactly what a Function
/// would read if the shop later upgrades.
class ReminderScannerService {
  ReminderScannerService({
    ShopGirviService? girvi,
    ShopLedgerService? ledger,
    ShopSchemesService? schemes,
    ShopRepairsService? repairs,
    ShopSettingsService? settings,
    NotificationsService? notifications,
  })  : _girvi = girvi ?? ShopGirviService(),
        _ledger = ledger ?? ShopLedgerService(),
        _schemes = schemes ?? ShopSchemesService(),
        _repairs = repairs ?? ShopRepairsService(),
        _settings = settings ?? ShopSettingsService(),
        _notifications = notifications ?? NotificationsService.instance;

  final ShopGirviService _girvi;
  final ShopLedgerService _ledger;
  final ShopSchemesService _schemes;
  final ShopRepairsService _repairs;
  final ShopSettingsService _settings;
  final NotificationsService _notifications;

  static DateTime? _lastRun;

  /// How far ahead to warn about a due date.
  static const lookaheadDays = 7;

  /// Scans at most once every six hours per app session.
  Future<void> scanIfStale() async {
    final last = _lastRun;
    if (last != null && DateTime.now().difference(last).inHours < 6) return;
    _lastRun = DateTime.now();
    await scan();
  }

  Future<void> scan() async {
    try {
      final settings = await _settings.getSettings();
      await Future.wait([
        if (settings.remindGirviDue) _scanGirvi(),
        if (settings.remindUdhaar) _scanUdhaar(),
        if (settings.remindSchemeInstallment) _scanSchemes(),
        _scanRepairs(),
      ]);
    } catch (e) {
      debugPrint('Reminder scan skipped: $e');
    }
  }

  Future<void> _scanGirvi() async {
    final loans = await _girvi.watchGirvi().first;
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: lookaheadDays));

    for (final g in loans) {
      if (g.status == 'closed') continue;
      final due = g.dueDate;
      if (due.isAfter(horizon)) continue;

      final overdue = now.isAfter(due);
      final days = overdue
          ? now.difference(due).inDays
          : due.difference(now).inDays;
      await _notifications.upsertReminder(
        ShopReminder(
          id: 'girviDue_${g.girviNo}',
          kind: 'girviDue',
          title: overdue
              ? 'Girvi ${g.girviNo} is overdue'
              : 'Girvi ${g.girviNo} due soon',
          body: overdue
              ? '${g.customer.name} — ${RatnexFormat.money(g.totals.balance)} outstanding, $days days past due'
              : '${g.customer.name} — ${RatnexFormat.money(g.totals.amountDue)} due in $days days',
          targetId: g.girviNo,
          phone: g.customer.phone,
          dueAt: due,
        ),
      );
    }
  }

  Future<void> _scanUdhaar() async {
    final accounts = await _ledger.watchAccounts(onlyOutstanding: true).first;
    for (final a in accounts) {
      if (!a.isOverdue) continue;
      await _notifications.upsertReminder(
        ShopReminder(
          id: 'udhaar_${a.phoneId}',
          kind: 'udhaar',
          title: '${a.name} owes ${RatnexFormat.money(a.outstanding)}',
          body: '${a.daysOverdue} days past due — tap to send a reminder',
          targetId: a.phoneId,
          phone: a.phone,
          dueAt: a.oldestDueAt,
        ),
      );
    }
  }

  Future<void> _scanSchemes() async {
    final schemes = await _schemes.watchSchemes().first;
    for (final s in schemes) {
      if (!s.isActive) continue;
      final members = await _schemes.watchMembers(s.id).first;
      for (final m in members) {
        if (!m.isDue) continue;
        await _notifications.upsertReminder(
          ShopReminder(
            id: 'scheme_${s.id}_${m.id}',
            kind: 'scheme',
            title: '${m.name} — ${s.name} installment due',
            body:
                'Installment ${m.paidCount + 1} of ${RatnexFormat.money(s.monthlyAmount)}, ${m.daysOverdue} days late',
            targetId: '${s.id}/${m.id}',
            phone: m.phone,
            dueAt: m.nextDueAt,
          ),
        );
      }
    }
  }

  Future<void> _scanRepairs() async {
    final jobs = await _repairs.watchJobs().first;
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 2));

    for (final j in jobs) {
      if (!j.isOpen) continue;
      final promised = j.promisedAt;

      if (j.status == RepairStatus.ready) {
        await _notifications.upsertReminder(
          ShopReminder(
            id: 'repairReady_${j.jobNo}',
            kind: 'repair',
            title: 'Token ${j.jobNo} ready for pickup',
            body:
                '${j.customerName} — tell them it is ready${j.balance > 0.5 ? ', ${RatnexFormat.money(j.balance)} balance' : ''}',
            targetId: j.jobNo,
            phone: j.customerPhone,
            dueAt: promised,
          ),
        );
        continue;
      }

      if (promised == null || promised.isAfter(horizon)) continue;
      await _notifications.upsertReminder(
        ShopReminder(
          id: 'repair_${j.jobNo}',
          kind: 'repair',
          title: j.isLate
              ? 'Token ${j.jobNo} is ${j.daysLate} days late'
              : 'Token ${j.jobNo} promised soon',
          body: '${j.customerName} — ${RepairJobType.label(j.type)}',
          targetId: j.jobNo,
          phone: j.customerPhone,
          dueAt: promised,
        ),
      );
    }
  }
}
