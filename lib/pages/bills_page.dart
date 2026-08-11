import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_bills_service.dart';
import '../theme/ratnex_theme.dart';
import 'create_bill_page.dart';
import 'view_bill_page.dart';

class BillsPage extends StatelessWidget {
  const BillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('d MMM yyyy').format(DateTime.now());
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final billsService = ShopBillsService();

    return StreamBuilder<List<ShopBill>>(
      stream: billsService.watchBills(),
      builder: (context, snap) {
        final bills = snap.data ?? const <ShopBill>[];
        final todayCount = bills.where((b) {
          final d = b.billedAt ?? b.createdAt;
          if (d == null) return false;
          final now = DateTime.now();
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).length;

        return RatnexPageScaffold(
          title: 'Bills',
          subtitle: 'Invoices  ·  $today',
          trailing: RatnexHeaderChip(
            label: '$todayCount today',
            color: RatnexColors.gold,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RatnexPrimaryButton(
                label: 'New Bill',
                icon: Icons.add,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateBillPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const RatnexSectionLabel(text: 'All invoices'),
              const SizedBox(height: 8),
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
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: RatnexColors.gold),
                  ),
                )
              else if (bills.isEmpty)
                RatnexPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 32,
                          color: RatnexColors.gold,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No bills yet',
                          style: RatnexTheme.label(
                            size: 15,
                            weight: FontWeight.w700,
                            color: RatnexColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create your first bill from New Bill.',
                          style: RatnexTheme.label(size: 13),
                        ),
                      ],
                    ),
                  ),
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
                      const Divider(height: 1, color: RatnexColors.hairline),
                      ...List.generate(bills.length, (index) {
                        final bill = bills[index];
                        final time = bill.billedAt ?? bill.createdAt;
                        final timeStr = time == null
                            ? '—'
                            : DateFormat('h:mm a').format(time);

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
                                          color: _statusColor(bill.paymentStatus),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        currency.format(
                                          bill.totals.grandTotal.round(),
                                        ),
                                        textAlign: TextAlign.right,
                                        style: RatnexTheme.money(
                                          size: 12,
                                          color: RatnexColors.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (index != bills.length - 1)
                              const Divider(
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
