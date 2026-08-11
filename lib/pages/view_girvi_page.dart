import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/girvi_pdf_service.dart';
import '../services/shop_girvi_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';
import 'create_girvi_page.dart';

class ViewGirviPage extends StatefulWidget {
  final ShopGirvi girvi;

  const ViewGirviPage({super.key, required this.girvi});

  @override
  State<ViewGirviPage> createState() => _ViewGirviPageState();
}

class _ViewGirviPageState extends State<ViewGirviPage> {
  late ShopGirvi girvi;
  final _service = ShopGirviService();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    girvi = widget.girvi;
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'closed':
        return RatnexColors.muted;
      case 'overdue':
        return RatnexColors.down;
      default:
        return RatnexColors.up;
    }
  }

  Future<void> _refresh() async {
    final latest = await _service.getGirvi(girvi.girviNo);
    if (latest != null && mounted) setState(() => girvi = latest);
  }

  Future<void> _markClosed() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close girvi?'),
        content: const Text('Mark this pledge as fully settled / closed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.markClosed(girvi.girviNo);
    await _refresh();
  }

  Future<void> _addPayment() async {
    final ctrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record payment'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: const InputDecoration(hintText: 'Amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              Navigator.pop(context, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;
    await _service.addPayment(
      girvi.girviNo,
      GirviPayment(amount: amount, paidAt: DateTime.now()),
    );
    await _refresh();
  }

  Future<void> _printSheet() async {
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
              'Print / Share',
              style: RatnexTheme.label(
                size: 16,
                weight: FontWeight.w700,
                color: RatnexColors.ink,
              ),
            ),
            for (final format in GirviPrintFormat.values)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(GirviPdfService.formatLabel(format)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await GirviPdfService.printGirvi(girvi, format);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Print failed: $e')),
                      );
                    }
                  }
                },
                trailing: IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await GirviPdfService.shareGirvi(girvi, format);
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

  @override
  Widget build(BuildContext context) {
    final status = girvi.effectiveStatus;
    final dueStr = DateFormat('d MMM yyyy').format(girvi.dueDate);
    final startStr = DateFormat('d MMM yyyy').format(girvi.startedAt);

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
                        Text(girvi.girviNo, style: RatnexTheme.brand(size: 22)),
                        Text(
                          'Start $startStr · Due $dueStr',
                          style: RatnexTheme.label(size: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () async {
                      final updated =
                          await Navigator.of(context).push<ShopGirvi>(
                        MaterialPageRoute(
                          builder: (_) => CreateGirviPage(existing: girvi),
                        ),
                      );
                      if (updated != null && mounted) {
                        setState(() => girvi = updated);
                      } else {
                        await _refresh();
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    color: RatnexColors.ink,
                  ),
                  IconButton(
                    tooltip: 'Print',
                    onPressed: _printSheet,
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
                    child: Row(
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
                                      girvi.customer.name,
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
                                      color: _statusColor(status)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      girvi.statusLabel,
                                      style: RatnexTheme.label(
                                        size: 12,
                                        weight: FontWeight.w700,
                                        color: _statusColor(status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (girvi.customer.phone != null)
                                Text(
                                  girvi.customer.phone!,
                                  style: RatnexTheme.label(size: 12),
                                ),
                              if (girvi.customer.address != null)
                                Text(
                                  girvi.customer.address!,
                                  style: RatnexTheme.label(size: 12),
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
                                data: girvi.girviNo,
                                width: 72,
                                height: 72,
                                drawText: false,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Scan girvi', style: RatnexTheme.label(size: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ITEMS (${girvi.items.length})',
                          style: RatnexTheme.label(
                            size: 11,
                            weight: FontWeight.w700,
                            color: RatnexColors.muted,
                          ).copyWith(letterSpacing: 0.4),
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < girvi.items.length; i++) ...[
                          if (i > 0)
                            const Divider(color: RatnexColors.hairline),
                          _ItemTile(
                            item: girvi.items[i],
                            currency: _currency,
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
                          'Appraisal',
                          _currency.format(girvi.totals.appraisalValue.round()),
                        ),
                        _row(
                          'Loan given',
                          _currency.format(girvi.loanAmount.round()),
                        ),
                        _row(
                          'Interest ${girvi.interestRatePercent}% / mo × ${girvi.tenureMonths}',
                          _currency.format(girvi.totals.interestTillDue.round()),
                        ),
                        _row(
                          'Interest so far',
                          _currency.format(girvi.interestSoFar.round()),
                        ),
                        const Divider(color: RatnexColors.hairline),
                        _row(
                          'Amount due (till due date)',
                          _currency.format(girvi.totals.amountDue.round()),
                          bold: true,
                        ),
                        _row(
                          'Paid',
                          _currency.format(girvi.totals.paidAmount.round()),
                        ),
                        _row(
                          'Balance',
                          _currency.format(girvi.totals.balance.round()),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  if (girvi.payments.isNotEmpty) ...[
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
                          for (final p in girvi.payments)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.paidAt == null
                                          ? 'Payment'
                                          : DateFormat('d MMM yyyy')
                                              .format(p.paidAt!),
                                      style: RatnexTheme.label(size: 12),
                                    ),
                                  ),
                                  Text(
                                    _currency.format(p.amount.round()),
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
                  if (girvi.notes != null && girvi.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _panel(
                      child: Text(
                        girvi.notes!,
                        style: RatnexTheme.label(
                          size: 13,
                          color: RatnexColors.ink,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (status != 'closed') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _addPayment,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: RatnexColors.ink,
                              side: const BorderSide(
                                color: RatnexColors.hairline,
                              ),
                              minimumSize: const Size.fromHeight(46),
                            ),
                            child: const Text('Add payment'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _markClosed,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: RatnexColors.ink,
                              side: const BorderSide(
                                color: RatnexColors.hairline,
                              ),
                              minimumSize: const Size.fromHeight(46),
                            ),
                            child: const Text('Mark closed'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _printSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RatnexColors.ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Print / Share receipt'),
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
                ? RatnexTheme.money(size: 15, color: RatnexColors.ink)
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

class _ItemTile extends StatelessWidget {
  final GirviItem item;
  final NumberFormat currency;

  const _ItemTile({required this.item, required this.currency});

  @override
  Widget build(BuildContext context) {
    final thumb = StockImageHelper.decodeBase64(item.imageBase64);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64,
              height: 64,
              child: thumb != null
                  ? Image.memory(thumb, fit: BoxFit.cover)
                  : Container(
                      color: RatnexColors.goldSoft,
                      child: const Icon(
                        Icons.diamond_outlined,
                        color: RatnexColors.gold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: RatnexTheme.label(
                    size: 13,
                    weight: FontWeight.w700,
                    color: RatnexColors.ink,
                  ),
                ),
                Text(
                  '${item.metalLabel ?? 'Metal'} · ${item.netWeight}g · ${currency.format(item.ratePerGram.round())}/g',
                  style: RatnexTheme.label(size: 11),
                ),
                Text(
                  'Appraisal ${currency.format(item.appraisalValue.round())}',
                  style: RatnexTheme.money(size: 13, color: RatnexColors.gold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
