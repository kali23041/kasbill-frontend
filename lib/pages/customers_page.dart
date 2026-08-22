import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/export_service.dart';
import '../services/shop_bills_service.dart';
import '../services/shop_customers_service.dart';
import '../services/shop_ledger_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';
import 'customer_detail_page.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

enum _CustomerSort { name, spend, recent, outstanding }

class _CustomersPageState extends State<CustomersPage> {
  final _customers = ShopCustomersService();
  final _bills = ShopBillsService();
  final _ledger = ShopLedgerService();
  final _search = TextEditingController();

  String _query = '';
  _CustomerSort _sort = _CustomerSort.recent;
  bool _exporting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Bills are the source of truth for spend and last-visit; the customers
  /// collection only carries identity, so the two are joined here.
  Map<String, ({double spend, int count, DateTime? last})> _rollup(
    List<ShopBill> bills,
  ) {
    final out = <String, ({double spend, int count, DateTime? last})>{};
    for (final b in bills) {
      if (b.paymentStatus == 'cancelled') continue;
      final id = customerPhoneDocId(b.customer.phone);
      if (id == null) continue;
      final prev = out[id];
      final at = b.billedAt;
      final prevLast = prev?.last;
      out[id] = (
        spend: (prev?.spend ?? 0) + b.totals.grandTotal,
        count: (prev?.count ?? 0) + 1,
        last: prevLast == null
            ? at
            : (at != null && at.isAfter(prevLast) ? at : prevLast),
      );
    }
    return out;
  }

  Future<void> _export(
    List<ShopCustomer> customers,
    List<UdhaarAccount> udhaar,
  ) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final result = await ExportService.customers(
        customers,
        udhaarByPhone: {for (final a in udhaar) a.phoneId: a},
      );
      await ExportService.share(result, subject: 'Ratnex customers');
      if (mounted) {
        RatnexSnack.success(
          context,
          'Exported ${result.rowCount} customers',
        );
      }
    } catch (e) {
      if (mounted) RatnexSnack.error(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ShopCustomer>>(
      stream: _customers.watchCustomers(),
      builder: (context, custSnap) {
        return StreamBuilder<List<ShopBill>>(
          stream: _bills.watchBills(),
          builder: (context, billSnap) {
            return StreamBuilder<List<UdhaarAccount>>(
              stream: _ledger.watchAccounts(),
              builder: (context, udhaarSnap) {
                final customers = custSnap.data ?? const <ShopCustomer>[];
                final bills = billSnap.data ?? const <ShopBill>[];
                final udhaar = udhaarSnap.data ?? const <UdhaarAccount>[];
                final loading = !custSnap.hasData && !custSnap.hasError;

                final rollup = _rollup(bills);
                final owedBy = {for (final a in udhaar) a.phoneId: a};

                var visible = customers;
                if (_query.trim().isNotEmpty) {
                  visible = ShopCustomersService.filterSuggestions(
                    customers,
                    _query,
                    limit: 1000,
                  );
                }

                visible = [...visible]..sort((a, b) {
                    switch (_sort) {
                      case _CustomerSort.name:
                        return a.name
                            .toLowerCase()
                            .compareTo(b.name.toLowerCase());
                      case _CustomerSort.spend:
                        return (rollup[b.phoneId]?.spend ?? 0)
                            .compareTo(rollup[a.phoneId]?.spend ?? 0);
                      case _CustomerSort.outstanding:
                        return (owedBy[b.phoneId]?.outstanding ?? 0)
                            .compareTo(owedBy[a.phoneId]?.outstanding ?? 0);
                      case _CustomerSort.recent:
                        final at = rollup[a.phoneId]?.last ??
                            a.updatedAt ??
                            DateTime(2000);
                        final bt = rollup[b.phoneId]?.last ??
                            b.updatedAt ??
                            DateTime(2000);
                        return bt.compareTo(at);
                    }
                  });

                final totalSpend =
                    rollup.values.fold<double>(0, (s, r) => s + r.spend);
                final repeat = rollup.values.where((r) => r.count > 1).length;
                final owed = ShopLedgerService.totalOutstanding(udhaar);

                return RatnexPageScaffold(
                  title: 'Customers',
                  subtitle: '${customers.length} people have bought from you',
                  showBack: true,
                  trailing: IconButton(
                    tooltip: 'Export CSV',
                    onPressed: _exporting || customers.isEmpty
                        ? null
                        : () => _export(customers, udhaar),
                    icon: _exporting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: RatnexColors.gold,
                            ),
                          )
                        : Icon(
                            Icons.ios_share,
                            color: RatnexColors.ink,
                            size: 20,
                          ),
                  ),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RatnexStatTile(
                              label: 'Lifetime sales',
                              value: RatnexFormat.compact(totalSpend),
                              caption: '${bills.length} bills',
                              icon: Icons.payments_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RatnexStatTile(
                              label: 'Repeat buyers',
                              value: '$repeat',
                              caption: customers.isEmpty
                                  ? '—'
                                  : '${((repeat / customers.length) * 100).round()}% of all',
                              icon: Icons.repeat,
                              accent: RatnexColors.up,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RatnexStatTile(
                              label: 'Udhaar out',
                              value: RatnexFormat.compact(owed),
                              caption: '${udhaar.where((a) => !a.isSettled).length} accounts',
                              icon: Icons.account_balance_wallet_outlined,
                              accent: owed > 0
                                  ? RatnexColors.down
                                  : RatnexColors.up,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      RatnexSearchField(
                        hint: 'Search by name or phone',
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: 10),
                      RatnexFilterChips(
                        selected: _sort.name,
                        options: const [
                          (value: 'recent', label: 'Recent', count: null),
                          (value: 'spend', label: 'Top spend', count: null),
                          (
                            value: 'outstanding',
                            label: 'Owes most',
                            count: null
                          ),
                          (value: 'name', label: 'A–Z', count: null),
                        ],
                        onSelected: (v) => setState(
                          () => _sort = _CustomerSort.values
                              .firstWhere((e) => e.name == v),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (loading)
                        const RatnexListSkeleton()
                      else if (customers.isEmpty)
                        RatnexEmptyState(
                          icon: Icons.people_outline,
                          title: 'No customers yet',
                          message:
                              'Customers are added automatically the moment you bill them. Make your first bill and they will show up here.',
                        )
                      else if (visible.isEmpty)
                        RatnexEmptyState(
                          icon: Icons.search_off,
                          title: 'Nothing matches that search',
                          message:
                              'Try part of the name, or the last few digits of the phone number.',
                          actionLabel: 'Clear search',
                          onAction: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        )
                      else
                        ...visible.map((c) {
                          final r = rollup[c.phoneId];
                          final account = owedBy[c.phoneId];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CustomerRow(
                              customer: c,
                              spend: r?.spend ?? 0,
                              billCount: r?.count ?? c.billCount,
                              lastVisit: r?.last,
                              outstanding: account?.outstanding ?? 0,
                              overdue: account?.isOverdue ?? false,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CustomerDetailPage(customer: c),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CustomerRow extends StatelessWidget {
  final ShopCustomer customer;
  final double spend;
  final int billCount;
  final DateTime? lastVisit;
  final double outstanding;
  final bool overdue;
  final VoidCallback onTap;

  const _CustomerRow({
    required this.customer,
    required this.spend,
    required this.billCount,
    required this.lastVisit,
    required this.outstanding,
    required this.overdue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RatnexCard(
      onTap: onTap,
      child: Row(
        children: [
          RatnexAvatar(name: customer.name, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        customer.name.isEmpty ? 'Unnamed' : customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RatnexTheme.label(
                          size: 14,
                          weight: FontWeight.w700,
                          color: RatnexColors.ink,
                        ),
                      ),
                    ),
                    if (billCount > 1) ...[
                      const SizedBox(width: 6),
                      RatnexBadge(
                        label: '${billCount}x',
                        color: RatnexColors.up,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${customer.phone} · ${RatnexFormat.relativeDays(lastVisit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RatnexTheme.label(size: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                RatnexFormat.money(spend),
                style: RatnexTheme.money(size: 14),
              ),
              const SizedBox(height: 4),
              if (outstanding > 0.5)
                RatnexBadge(
                  label: '${RatnexFormat.money(outstanding)} due',
                  color: overdue ? RatnexColors.down : RatnexColors.warn,
                )
              else
                Text(
                  'Lifetime',
                  style: RatnexTheme.label(size: 10.5),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
