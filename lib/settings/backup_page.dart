import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/app_prefs_service.dart';
import '../services/audit_log_service.dart';
import '../services/export_service.dart';
import '../services/shop_bills_service.dart';
import '../services/shop_customers_service.dart';
import '../services/shop_girvi_service.dart';
import '../services/shop_gst_service.dart';
import '../services/shop_karigar_service.dart';
import '../services/shop_ledger_service.dart';
import '../services/shop_mod_service.dart';
import '../services/shop_stock_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';

/// CSV and GST exports. Owners want a file they can hand to their CA — and
/// proof their data is not locked inside one app.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final _bills = ShopBillsService();
  final _stock = ShopStockService();
  final _customers = ShopCustomersService();
  final _ledger = ShopLedgerService();
  final _girvi = ShopGirviService();
  final _mod = ShopModService();
  final _karigar = ShopKarigarService();
  final _gst = ShopGstService();
  final _audit = AuditLogService();

  String? _running;
  DateTimeRange? _range;

  bool _inRange(DateTime? at) {
    final r = _range;
    if (r == null) return true;
    if (at == null) return false;
    final day = DateTime(at.year, at.month, at.day);
    return !day.isBefore(DateTime(r.start.year, r.start.month, r.start.day)) &&
        !day.isAfter(DateTime(r.end.year, r.end.month, r.end.day));
  }

  Future<void> _run(String key, Future<ExportResult> Function() build) async {
    if (_running != null) return;
    setState(() => _running = key);
    try {
      final result = await build();
      if (result.rowCount == 0) {
        if (mounted) {
          RatnexSnack.show(context, 'Nothing to export for that selection');
        }
        return;
      }
      await ExportService.share(result, subject: result.filename);
      await AppPrefs.instance.markBackedUp();
      await _audit.record(
        action: AuditLogService.export,
        entity: key,
        summary: '${result.rowCount} rows',
      );
      if (mounted) {
        RatnexSnack.success(context, 'Exported ${result.rowCount} rows');
        setState(() {});
      }
    } catch (e) {
      if (mounted) RatnexSnack.error(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  Future<List<ShopBill>> _rangedBills() async {
    final bills = await _bills.watchBills().first;
    return bills.where((b) => _inRange(b.billedAt ?? b.createdAt)).toList();
  }

  Future<String> _stateCode() async {
    final gst = await _gst.getSettings();
    final number = gst.gstNumber?.trim() ?? '';
    // The first two characters of a GSTIN are the state code.
    return number.length >= 2 ? number.substring(0, 2) : '';
  }

  @override
  Widget build(BuildContext context) {
    final lastBackup = AppPrefs.instance.lastBackupAt;

    return RatnexPageScaffold(
      title: 'Backup & export',
      subtitle: 'Take your data out as CSV whenever you want',
      showBack: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RatnexNotice(
            message: lastBackup == null
                ? 'You have not exported anything yet. A monthly export is a good habit.'
                : 'Last export ${RatnexFormat.relativeDays(lastBackup)} on ${RatnexFormat.date(lastBackup)}.',
            color: lastBackup == null ? RatnexColors.warn : RatnexColors.up,
            icon: lastBackup == null
                ? Icons.warning_amber_outlined
                : Icons.check_circle_outline,
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2015),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                initialDateRange: _range,
              );
              if (picked != null) setState(() => _range = picked);
            },
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: RatnexColors.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: RatnexColors.hairline),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range_outlined,
                    size: 17,
                    color: RatnexColors.muted,
                  ),
                  const SizedBox(width: 10),
                  Text('Date range', style: RatnexTheme.label(size: 13)),
                  const Spacer(),
                  Text(
                    _range == null
                        ? 'Everything'
                        : '${RatnexFormat.shortDate(_range!.start)} – ${RatnexFormat.shortDate(_range!.end)}',
                    style: RatnexTheme.label(
                      size: 13,
                      weight: FontWeight.w700,
                      color: RatnexColors.ink,
                    ),
                  ),
                  if (_range != null)
                    IconButton(
                      onPressed: () => setState(() => _range = null),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close,
                        size: 17,
                        color: RatnexColors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const RatnexSectionLabel(text: 'FOR YOUR CA'),
          const SizedBox(height: 8),
          RatnexPanel(
            child: Column(
              children: [
                _ExportRow(
                  icon: Icons.description_outlined,
                  title: 'GSTR-1 · B2B',
                  subtitle: 'Invoices where the customer gave a GSTIN',
                  busy: _running == 'gstr1_b2b',
                  onTap: () => _run('gstr1_b2b', () async {
                    return ExportService.gstr1B2B(
                      await _rangedBills(),
                      stateCode: await _stateCode(),
                    );
                  }),
                ),
                _divider(),
                _ExportRow(
                  icon: Icons.summarize_outlined,
                  title: 'GSTR-1 · B2CS',
                  subtitle: 'Everything else, summarised by tax rate',
                  busy: _running == 'gstr1_b2cs',
                  onTap: () => _run('gstr1_b2cs', () async {
                    return ExportService.gstr1B2CS(
                      await _rangedBills(),
                      stateCode: await _stateCode(),
                    );
                  }),
                ),
                _divider(),
                _ExportRow(
                  icon: Icons.table_chart_outlined,
                  title: 'HSN summary',
                  subtitle: 'Mandatory HSN-wise table',
                  busy: _running == 'gstr1_hsn',
                  onTap: () => _run(
                    'gstr1_hsn',
                    () async => ExportService.hsnSummary(await _rangedBills()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const RatnexSectionLabel(text: 'YOUR DATA'),
          const SizedBox(height: 8),
          RatnexPanel(
            child: Column(
              children: [
                _ExportRow(
                  icon: Icons.receipt_long_outlined,
                  title: 'Bills',
                  subtitle: 'One row per bill',
                  busy: _running == 'bills',
                  onTap: () => _run(
                    'bills',
                    () async => ExportService.bills(await _rangedBills()),
                  ),
                ),
                _divider(),
                _ExportRow(
                  icon: Icons.list_alt_outlined,
                  title: 'Bill line items',
                  subtitle: 'One row per item — what a CA reconciles against',
                  busy: _running == 'billItems',
                  onTap: () => _run(
                    'billItems',
                    () async => ExportService.billItems(await _rangedBills()),
                  ),
                ),
                _divider(),
                _ExportRow(
                  icon: Icons.inventory_2_outlined,
                  title: 'Stock',
                  subtitle: 'Every item with weights and values',
                  busy: _running == 'stock',
                  onTap: () => _run(
                    'stock',
                    () async =>
                        ExportService.stock(await _stock.watchStock().first),
                  ),
                ),
                _divider(),
                _ExportRow(
                  icon: Icons.people_outline,
                  title: 'Customers',
                  subtitle: 'With outstanding balances',
                  busy: _running == 'customers',
                  onTap: () => _run('customers', () async {
                    final list = await _customers.watchCustomers().first;
                    final accounts = await _ledger.watchAccounts().first;
                    return ExportService.customers(
                      list,
                      udhaarByPhone: {for (final a in accounts) a.phoneId: a},
                    );
                  }),
                ),
                _divider(),
                _ExportRow(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Udhaar',
                  subtitle: 'Outstanding khata with ageing',
                  busy: _running == 'udhaar',
                  onTap: () => _run(
                    'udhaar',
                    () async =>
                        ExportService.udhaar(await _ledger.watchAccounts().first),
                  ),
                ),
                _divider(),
                _ExportRow(
                  icon: Icons.account_balance_outlined,
                  title: 'Girvi',
                  subtitle: 'Pawn loans with interest and balances',
                  busy: _running == 'girvi',
                  onTap: () => _run('girvi', () async {
                    final loans = await _girvi.watchGirvi().first;
                    return ExportService.girvi(
                      loans.where((g) => _inRange(g.startedAt)).toList(),
                    );
                  }),
                ),
                _divider(),
                _ExportRow(
                  icon: Icons.swap_horiz,
                  title: 'Old gold purchases',
                  subtitle: 'MOD register with ID proofs',
                  busy: _running == 'mod',
                  onTap: () => _run('mod', () async {
                    final mods = await _mod.watchMod().first;
                    return ExportService.mod(
                      mods.where((m) => _inRange(m.paidAt)).toList(),
                    );
                  }),
                ),
                _divider(),
                _ExportRow(
                  icon: Icons.handyman_outlined,
                  title: 'Karigar accounts',
                  subtitle: 'Grams issued, returned and wasted',
                  busy: _running == 'karigars',
                  onTap: () => _run(
                    'karigars',
                    () async => ExportService.karigars(
                      await _karigar.watchKarigars().first,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RatnexNotice(
            message:
                'Files are saved to this device and opened in the share sheet, so you can send them to WhatsApp, Gmail or Drive.',
            color: RatnexColors.info,
            icon: Icons.folder_outlined,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        indent: 12,
        endIndent: 12,
        color: RatnexColors.hairline,
      );
}

class _ExportRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onTap;

  const _ExportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 19, color: RatnexColors.ink),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RatnexTheme.label(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: RatnexColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: RatnexTheme.label(size: 11.5)),
                ],
              ),
            ),
            if (busy)
              SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RatnexColors.gold,
                ),
              )
            else
              Icon(Icons.ios_share, size: 17, color: RatnexColors.muted),
          ],
        ),
      ),
    );
  }
}
