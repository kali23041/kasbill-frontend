import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_bills_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/barcode_scan_sheet.dart';
import '../widgets/ratnex_ui.dart';
import 'create_bill_page.dart';
import 'view_bill_page.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  final _billsService = ShopBillsService();
  final _search = TextEditingController();

  String _query = '';
  String _filter = 'all';
  String _period = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _inPeriod(ShopBill b) {
    final d = b.billedAt ?? b.createdAt;
    if (d == null) return _period == 'all';
    final now = DateTime.now();
    switch (_period) {
      case 'today':
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case 'week':
        final monday = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return !d.isBefore(monday);
      case 'month':
        return d.year == now.year && d.month == now.month;
      default:
        return true;
    }
  }

  bool _matches(ShopBill b) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return b.billNo.toLowerCase().contains(q) ||
        b.customer.name.toLowerCase().contains(q) ||
        (digits.isNotEmpty && (b.customer.phone ?? '').contains(digits)) ||
        b.items.any(
          (i) =>
              i.name.toLowerCase().contains(q) ||
              (i.barcode ?? '').toLowerCase().contains(q),
        );
  }

  Future<void> _scan() async {
    final code = await showBarcodeScanner(
      context,
      title: 'Find a bill',
      hint: 'Scan the barcode printed on a tag or bill',
    );
    if (code == null || !mounted) return;
    setState(() {
      _search.text = code;
      _query = code;
      _filter = 'all';
      _period = 'all';
    });
  }

  Future<void> _repeatLast(List<ShopBill> bills) async {
    if (bills.isEmpty) return;
    final last = bills.first;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreateBillPage(duplicateOf: last)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('d MMM yyyy').format(DateTime.now());

    return StreamBuilder<List<ShopBill>>(
      stream: _billsService.watchBills(),
      builder: (context, snap) {
        final bills = snap.data ?? const <ShopBill>[];
        final now = DateTime.now();
        final todayBills = bills.where((b) {
          final d = b.billedAt ?? b.createdAt;
          if (d == null) return false;
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).toList();

        final periodBills = bills.where(_inPeriod).toList();
        final unpaid = periodBills
            .where((b) => b.paymentStatus == 'unpaid')
            .toList();
        final partial = periodBills
            .where((b) => b.paymentStatus == 'partial')
            .toList();
        final paid =
            periodBills.where((b) => b.paymentStatus == 'paid').toList();

        var visible = switch (_filter) {
          'unpaid' => unpaid,
          'partial' => partial,
          'paid' => paid,
          _ => periodBills,
        };
        visible = visible.where(_matches).toList();

        final todayTotal = todayBills
            .where((b) => b.paymentStatus != 'cancelled')
            .fold<double>(0, (s, b) => s + b.totals.grandTotal);
        final pendingTotal = [...unpaid, ...partial]
            .fold<double>(0, (s, b) => s + b.totals.balance);

        return RatnexPageScaffold(
          title: 'Bills',
          subtitle: 'Invoices  ·  $today',
          trailing: RatnexHeaderChip(
            label: '${todayBills.length} today',
            color: RatnexColors.gold,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RatnexStatTile(
                      label: "Today's sales",
                      value: RatnexFormat.compact(todayTotal),
                      caption: '${todayBills.length} bills',
                      icon: Icons.today_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Pending',
                      value: RatnexFormat.compact(pendingTotal),
                      caption: '${unpaid.length + partial.length} bills',
                      icon: Icons.hourglass_bottom,
                      accent: pendingTotal > 0
                          ? RatnexColors.down
                          : RatnexColors.up,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'All bills',
                      value: '${bills.length}',
                      caption: '${paid.length} settled',
                      icon: Icons.receipt_long_outlined,
                      accent: RatnexColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RatnexPrimaryButton(
                label: 'New Bill',
                icon: Icons.add,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateBillPage()),
                  );
                },
              ),
              if (bills.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _repeatLast(bills),
                  icon: const Icon(Icons.replay, size: 17),
                  label: Text(
                    'Repeat last bill · ${bills.first.customer.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RatnexColors.ink,
                    side: BorderSide(color: RatnexColors.hairline),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              RatnexSearchField(
                hint: 'Search bill no, customer or phone',
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                onScan: _scan,
              ),
              const SizedBox(height: 10),
              RatnexFilterChips(
                selected: _period,
                options: const [
                  (value: 'all', label: 'All time', count: null),
                  (value: 'today', label: 'Today', count: null),
                  (value: 'week', label: 'This week', count: null),
                  (value: 'month', label: 'This month', count: null),
                ],
                onSelected: (v) => setState(() => _period = v),
              ),
              const SizedBox(height: 8),
              RatnexFilterChips(
                selected: _filter,
                options: [
                  (value: 'all', label: 'All', count: periodBills.length),
                  (value: 'unpaid', label: 'Unpaid', count: unpaid.length),
                  (value: 'partial', label: 'Partial', count: partial.length),
                  (value: 'paid', label: 'Paid', count: paid.length),
                ],
                onSelected: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 14),
              if (snap.hasError)
                RatnexPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Could not load bills: ${snap.error}',
                      style: RatnexTheme.label(size: 13),
                    ),
                  ),
                )
              else if (!snap.hasData)
                const RatnexListSkeleton()
              else if (bills.isEmpty)
                RatnexEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No bills yet',
                  message:
                      'Make your first bill and it will show up here, along with the customer, their khata and your reports.',
                  actionLabel: 'Create a bill',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateBillPage()),
                  ),
                )
              else if (visible.isEmpty)
                RatnexEmptyState(
                  icon: Icons.search_off,
                  title: 'Nothing matches',
                  message:
                      'Try a different bill number, customer name or filter.',
                  actionLabel: 'Clear filters',
                  onAction: () {
                    _search.clear();
                    setState(() {
                      _query = '';
                      _filter = 'all';
                      _period = 'all';
                    });
                  },
                )
              else
                RatnexPanel(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'INVOICE',
                                style: RatnexTheme.label(
                                  size: 10,
                                  weight: FontWeight.w700,
                                ).copyWith(letterSpacing: 0.5),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'CUSTOMER',
                                style: RatnexTheme.label(
                                  size: 10,
                                  weight: FontWeight.w700,
                                ).copyWith(letterSpacing: 0.5),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'STATUS',
                                style: RatnexTheme.label(
                                  size: 10,
                                  weight: FontWeight.w700,
                                ).copyWith(letterSpacing: 0.5),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'AMOUNT',
                                style: RatnexTheme.label(
                                  size: 10,
                                  weight: FontWeight.w700,
                                ).copyWith(letterSpacing: 0.5),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: RatnexColors.hairline),
                      ...List.generate(visible.length, (index) {
                        final bill = visible[index];
                        final time = bill.billedAt ?? bill.createdAt;
                        final timeStr = time == null
                            ? '—'
                            : DateFormat('d MMM · h:mm a').format(time);

                        return Column(
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ViewBillPage(bill: bill),
                                  ),
                                );
                              },
                              onLongPress: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CreateBillPage(duplicateOf: bill),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bill.billNo,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: RatnexTheme.label(
                                              size: 11,
                                              weight: FontWeight.w700,
                                              color: RatnexColors.ink,
                                            ),
                                          ),
                                          Text(
                                            timeStr,
                                            style: RatnexTheme.label(size: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bill.customer.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: RatnexTheme.label(
                                              size: 12,
                                              weight: FontWeight.w600,
                                              color: RatnexColors.ink,
                                            ),
                                          ),
                                          Text(
                                            bill.items.isEmpty
                                                ? 'No items'
                                                : bill.items.length == 1
                                                    ? '1 item · ${bill.items.first.name}'
                                                    : '${bill.items.length} items · ${bill.items.first.name}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: RatnexTheme.label(size: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        bill.statusLabel,
                                        textAlign: TextAlign.center,
                                        style: RatnexTheme.label(
                                          size: 11,
                                          weight: FontWeight.w700,
                                          color:
                                              _statusColor(bill.paymentStatus),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        RatnexFormat.money(
                                          bill.totals.grandTotal,
                                        ),
                                        textAlign: TextAlign.right,
                                        style: RatnexTheme.money(size: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (index != visible.length - 1)
                              Divider(
                                height: 1,
                                indent: 12,
                                endIndent: 12,
                                color: RatnexColors.hairline,
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return RatnexColors.up;
      case 'partial':
        return RatnexColors.gold;
      case 'cancelled':
        return RatnexColors.muted;
      default:
        return RatnexColors.down;
    }
  }
}
