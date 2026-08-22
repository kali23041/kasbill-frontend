import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/bill_pdf_service.dart';
import '../services/shop_bills_service.dart';
import '../services/shop_profile_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';
import 'create_bill_page.dart';

class ViewBillPage extends StatefulWidget {
  final ShopBill bill;

  const ViewBillPage({super.key, required this.bill});

  @override
  State<ViewBillPage> createState() => _ViewBillPageState();
}

class _ViewBillPageState extends State<ViewBillPage> {
  late ShopBill bill;
  bool _customerDetails = false;
  final Set<int> _expandedItems = {};
  ShopProfile? _shop;

  Future<void> _whatsapp() async {
    final message = WhatsAppService.billMessage(
      shopName: _shop?.shopName ?? 'our shop',
      customerName: bill.customer.name,
      billNo: bill.billNo,
      amount: bill.totals.grandTotal,
      balance: bill.totals.balance,
      upiId: _shop?.upiId,
    );
    final ok = await WhatsAppService.send(bill.customer.phone, message);
    if (!mounted || ok) return;
    if (bill.customer.phone == null || bill.customer.phone!.trim().isEmpty) {
      RatnexSnack.error(context, 'This bill has no customer phone number');
      return;
    }
    await WhatsAppService.copy(message);
    if (mounted) {
      RatnexSnack.show(context, 'WhatsApp unavailable — message copied');
    }
  }

  @override
  void initState() {
    super.initState();
    bill = widget.bill;
    ShopProfileService().watchProfile().first.then((p) {
      if (mounted) setState(() => _shop = p);
    }).catchError((_) {});
    final c = bill.customer;
    _customerDetails = (c.phone?.isNotEmpty ?? false) ||
        (c.address?.isNotEmpty ?? false) ||
        (c.gstin?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final date = bill.billedAt ?? bill.createdAt ?? DateTime.now();
    final dateStr = DateFormat('d MMM yyyy · h:mm a').format(date);
    final hasDetails = (bill.customer.phone?.isNotEmpty ?? false) ||
        (bill.customer.address?.isNotEmpty ?? false) ||
        (bill.customer.gstin?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: RatnexColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
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
                        Text(bill.billNo, style: RatnexTheme.brand(size: 22)),
                        Text(dateStr, style: RatnexTheme.label(size: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () async {
                      final updated = await Navigator.of(context).push<ShopBill>(
                        MaterialPageRoute(
                          builder: (_) => CreateBillPage(existing: bill),
                        ),
                      );
                      if (updated != null && context.mounted) {
                        setState(() {
                          bill = updated;
                          final c = bill.customer;
                          _customerDetails =
                              (c.phone?.isNotEmpty ?? false) ||
                              (c.address?.isNotEmpty ?? false) ||
                              (c.gstin?.isNotEmpty ?? false);
                        });
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    color: RatnexColors.ink,
                  ),
                  IconButton(
                    tooltip: 'Print',
                    onPressed: () => _showPrintSheet(context),
                    icon: const Icon(Icons.print_outlined),
                    color: RatnexColors.ink,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                children: [
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          bill.customer.name,
                                          style: RatnexTheme.label(
                                            size: 16,
                                            weight: FontWeight.w700,
                                            color: RatnexColors.ink,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(bill.paymentStatus)
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          bill.statusLabel,
                                          style: RatnexTheme.label(
                                            size: 12,
                                            weight: FontWeight.w700,
                                            color: _statusColor(
                                              bill.paymentStatus,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (bill.paymentMode != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Paid via ${bill.paymentMode}',
                                        style: RatnexTheme.label(size: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: RatnexColors.hairline,
                                    ),
                                  ),
                                  child: BarcodeWidget(
                                    barcode: Barcode.qrCode(),
                                    data: bill.billNo,
                                    width: 72,
                                    height: 72,
                                    drawText: false,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Scan bill',
                                  style: RatnexTheme.label(size: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (hasDetails) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => setState(
                              () => _customerDetails = !_customerDetails,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _customerDetails ? Icons.remove : Icons.add,
                                  size: 16,
                                  color: RatnexColors.gold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Details',
                                  style: RatnexTheme.label(
                                    size: 12,
                                    weight: FontWeight.w700,
                                    color: RatnexColors.gold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_customerDetails) ...[
                            if (bill.customer.phone != null)
                              Text(
                                bill.customer.phone!,
                                style: RatnexTheme.label(size: 12),
                              ),
                            if (bill.customer.address != null)
                              Text(
                                bill.customer.address!,
                                style: RatnexTheme.label(size: 12),
                              ),
                            if (bill.customer.gstin != null)
                              Text(
                                'GSTIN ${bill.customer.gstin}',
                                style: RatnexTheme.label(size: 12),
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ITEMS (${bill.items.length})',
                          style: RatnexTheme.label(
                            size: 11,
                            weight: FontWeight.w700,
                            color: RatnexColors.muted,
                          ).copyWith(letterSpacing: 0.4),
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < bill.items.length; i++) ...[
                          if (i > 0)
                            Divider(color: RatnexColors.hairline),
                          _ViewItemRow(
                            item: bill.items[i],
                            currency: currency,
                            expanded: _expandedItems.contains(i),
                            onToggle: () {
                              setState(() {
                                if (_expandedItems.contains(i)) {
                                  _expandedItems.remove(i);
                                } else {
                                  _expandedItems.add(i);
                                }
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _panel(
                    child: Column(
                      children: [
                        _row(
                          'Taxable',
                          currency.format(bill.totals.taxable.round()),
                        ),
                        _row('GST', currency.format(bill.totals.gst.round())),
                        Divider(color: RatnexColors.hairline),
                        _row(
                          'Grand total',
                          currency.format(bill.totals.grandTotal.round()),
                          bold: true,
                        ),
                        if (bill.totals.hasExchange) ...[
                          _row(
                            'Old gold credit',
                            '− ${currency.format(bill.totals.exchangeValue.round())}',
                          ),
                          _row(
                            'Net payable',
                            currency.format(bill.totals.netPayable.round()),
                            bold: true,
                          ),
                        ],
                        _row(
                          'Paid',
                          currency.format(bill.totals.paidAmount.round()),
                        ),
                        _row(
                          'Balance',
                          currency.format(bill.totals.balance.round()),
                          bold: true,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            RatnexFormat.amountInWords(bill.totals.netPayable),
                            style: RatnexTheme.label(
                              size: 11.5,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (bill.exchange.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OLD GOLD TAKEN IN',
                            style: RatnexTheme.label(
                              size: 10.5,
                              weight: FontWeight.w700,
                            ).copyWith(letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 10),
                          for (final e in bill.exchange)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.name,
                                          style: RatnexTheme.label(
                                            size: 13,
                                            weight: FontWeight.w600,
                                            color: RatnexColors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${RatnexFormat.grams(e.netWeight)} @ ${currency.format(e.ratePerGram.round())}/g'
                                          '${e.deductionPercent > 0 ? ' · less ${e.deductionPercent.toStringAsFixed(1)}%' : ''}',
                                          style: RatnexTheme.label(size: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    currency.format(e.value.round()),
                                    style: RatnexTheme.money(
                                      size: 13,
                                      color: RatnexColors.up,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (bill.notes != null && bill.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _panel(
                      child: Text(
                        bill.notes!,
                        style: RatnexTheme.label(
                          size: 13,
                          color: RatnexColors.ink,
                        ),
                      ),
                    ),
                  ],
                  if (bill.payments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PAYMENTS',
                            style: RatnexTheme.label(
                              size: 11,
                              weight: FontWeight.w700,
                              color: RatnexColors.muted,
                            ).copyWith(letterSpacing: 0.4),
                          ),
                          const SizedBox(height: 8),
                          for (final p in bill.payments)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.paidAt == null
                                          ? p.mode
                                          : '${p.mode} · ${DateFormat('d MMM').format(p.paidAt!)}',
                                      style: RatnexTheme.label(size: 12),
                                    ),
                                  ),
                                  Text(
                                    currency.format(p.amount.round()),
                                    style: RatnexTheme.label(
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: RatnexColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _showPrintSheet(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RatnexColors.ink,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.print_outlined, size: 18),
                            label: Text(
                              'Print / Share',
                              style: RatnexTheme.label(
                                size: 14,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _whatsapp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          child: const Icon(Icons.chat_outlined, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

  Future<void> _showPrintSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: RatnexColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text(
              'Print format',
              style: RatnexTheme.label(
                size: 16,
                weight: FontWeight.w700,
                color: RatnexColors.ink,
              ),
            ),
            for (final format in BillPrintFormat.values)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(BillPdfService.formatLabel(format)),
                subtitle: const Text('Print or share PDF'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await BillPdfService.printBill(bill, format);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Print failed: $e')),
                      );
                    }
                  }
                },
                trailing: IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await BillPdfService.shareBill(bill, format);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Share failed: $e')),
                        );
                      }
                    }
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RatnexColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RatnexColors.hairline),
      ),
      child: child,
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: RatnexTheme.label(
                size: 13,
                weight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold ? RatnexColors.ink : RatnexColors.muted,
              ),
            ),
          ),
          Text(
            value,
            style: bold
                ? RatnexTheme.money(size: 16, color: RatnexColors.ink)
                : RatnexTheme.label(
                    size: 13,
                    weight: FontWeight.w600,
                    color: RatnexColors.ink,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ViewItemRow extends StatelessWidget {
  final BillLineItem item;
  final NumberFormat currency;
  final bool expanded;
  final VoidCallback onToggle;

  const _ViewItemRow({
    required this.item,
    required this.currency,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final qtySuffix = item.qty > 1 ? ' · ×${item.qty}' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: RatnexColors.muted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.name,
                    style: RatnexTheme.label(
                      size: 14,
                      weight: FontWeight.w700,
                      color: RatnexColors.ink,
                    ),
                  ),
                ),
                Text(
                  currency.format(item.lineTotal.round()),
                  style: RatnexTheme.money(size: 14, color: RatnexColors.ink),
                ),
              ],
            ),
          ),
        ),
        if (item.barcode != null && item.barcode!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: RatnexColors.hairline),
              ),
              child: Column(
                children: [
                  BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: item.barcode!,
                    height: 36,
                    drawText: false,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.barcode!,
                    style: RatnexTheme.label(size: 9, color: RatnexColors.ink),
                  ),
                ],
              ),
            ),
          ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.netWeight}g$qtySuffix · ${currency.format(item.ratePerGram.round())}/g',
                  style: RatnexTheme.label(size: 11),
                ),
                if (item.grossWeight != item.netWeight)
                  Text(
                    'Gross ${item.grossWeight}g',
                    style: RatnexTheme.label(size: 11),
                  ),
                if (item.makingCharge > 0)
                  Text(
                    'Making ${currency.format(item.makingCharge.round())} (${item.makingType})',
                    style: RatnexTheme.label(size: 11),
                  ),
                if (item.wastagePercent > 0)
                  Text(
                    'Wastage ${item.wastagePercent}%',
                    style: RatnexTheme.label(size: 11),
                  ),
                if (item.stoneCharge > 0)
                  Text(
                    'Stone ${currency.format(item.stoneCharge.round())}',
                    style: RatnexTheme.label(size: 11),
                  ),
                if (item.otherCharge > 0)
                  Text(
                    'Other ${currency.format(item.otherCharge.round())}',
                    style: RatnexTheme.label(size: 11),
                  ),
                Text(
                  'Taxable ${currency.format(item.taxableAmount.round())}'
                  '${item.applyGst ? ' · GST ${currency.format(item.gstAmount.round())}' : ''}',
                  style: RatnexTheme.label(size: 11),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
