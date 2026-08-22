import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/mod_pdf_service.dart';
import '../services/shop_mod_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';
import 'create_mod_page.dart';

class ViewModPage extends StatefulWidget {
  final ShopMod mod;

  const ViewModPage({super.key, required this.mod});

  @override
  State<ViewModPage> createState() => _ViewModPageState();
}

class _ViewModPageState extends State<ViewModPage> {
  late ShopMod mod;
  final _service = ShopModService();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    mod = widget.mod;
  }

  Future<void> _refresh() async {
    final latest = await _service.getMod(mod.modNo);
    if (latest != null && mounted) setState(() => mod = latest);
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel purchase?'),
        content: const Text('Mark this mod as cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel mod'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.markCancelled(mod.modNo);
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
            for (final format in ModPrintFormat.values)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(ModPdfService.formatLabel(format)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ModPdfService.printMod(mod, format);
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
                      await ModPdfService.shareMod(mod, format);
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

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM yyyy').format(mod.paidAt);

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
                        Text(mod.modNo, style: RatnexTheme.brand(size: 22)),
                        Text(
                          'Paid $dateStr · ${mod.paymentModeLabel}',
                          style: RatnexTheme.label(size: 12),
                        ),
                      ],
                    ),
                  ),
                  if (mod.status != 'cancelled')
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () async {
                        final updated =
                            await Navigator.of(context).push<ShopMod>(
                          MaterialPageRoute(
                            builder: (_) => CreateModPage(existing: mod),
                          ),
                        );
                        if (updated != null && mounted) {
                          setState(() => mod = updated);
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
                                      mod.customer.name,
                                      style: RatnexTheme.label(
                                        size: 16,
                                        weight: FontWeight.w700,
                                        color: RatnexColors.ink,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    mod.statusLabel,
                                    style: RatnexTheme.label(
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: mod.status == 'cancelled'
                                          ? RatnexColors.muted
                                          : RatnexColors.up,
                                    ),
                                  ),
                                ],
                              ),
                              if (mod.customer.phone != null)
                                Text(
                                  mod.customer.phone!,
                                  style: RatnexTheme.label(size: 12),
                                ),
                              if (mod.customer.address != null)
                                Text(
                                  mod.customer.address!,
                                  style: RatnexTheme.label(size: 12),
                                ),
                              if (mod.idProofType != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'ID: ${mod.idProofType}'
                                  '${mod.idProofNumber != null ? ' · ${mod.idProofNumber}' : ''}',
                                  style: RatnexTheme.label(size: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        BarcodeWidget(
                          barcode: Barcode.qrCode(),
                          data: mod.modNo,
                          width: 64,
                          height: 64,
                          drawText: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ornaments',
                    style: RatnexTheme.label(
                      size: 11,
                      weight: FontWeight.w600,
                      color: RatnexColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _panel(
                    child: Column(
                      children: [
                        for (var i = 0; i < mod.items.length; i++) ...[
                          if (i > 0)
                            Divider(color: RatnexColors.hairline),
                          _ItemDetail(
                            item: mod.items[i],
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
                        _kv(
                          'Appraisal',
                          _currency.format(mod.totals.appraisalValue.round()),
                        ),
                        if (mod.totals.makingDeduction > 0)
                          _kv(
                            'Making (${mod.deductionPercent}%)',
                            '- ${_currency.format(mod.totals.makingDeduction.round())}',
                          ),
                        if (mod.totals.stoneDeduction > 0)
                          _kv(
                            'Stone deduction',
                            '- ${_currency.format(mod.totals.stoneDeduction.round())}',
                          ),
                        if (mod.totals.otherDeduction > 0)
                          _kv(
                            'Other deduction',
                            '- ${_currency.format(mod.totals.otherDeduction.round())}',
                          ),
                        Divider(color: RatnexColors.hairline),
                        _kv(
                          'Paid to customer',
                          _currency.format(mod.totals.purchaseAmount.round()),
                          bold: true,
                        ),
                        _kv('Payment', mod.paymentModeLabel),
                        if (mod.paymentRef != null)
                          _kv('Reference', mod.paymentRef!),
                      ],
                    ),
                  ),
                  if (mod.notes != null && mod.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _panel(
                      child: Text(
                        mod.notes!,
                        style: RatnexTheme.label(size: 13),
                      ),
                    ),
                  ],
                  if (mod.status != 'cancelled') ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RatnexColors.down,
                        side: BorderSide(color: RatnexColors.down),
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: const Text('Cancel purchase'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: RatnexTheme.label(
                size: 13,
                weight: bold ? FontWeight.w700 : FontWeight.w500,
                color: RatnexColors.ink,
              ),
            ),
          ),
          Text(
            v,
            style: bold
                ? RatnexTheme.money(size: 15, color: RatnexColors.gold)
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

class _ItemDetail extends StatelessWidget {
  final ModItem item;
  final NumberFormat currency;

  const _ItemDetail({required this.item, required this.currency});

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
                      child: Icon(
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
                    size: 14,
                    weight: FontWeight.w700,
                    color: RatnexColors.ink,
                  ),
                ),
                Text(
                  [
                    if (item.metalLabel != null) item.metalLabel!,
                    if (item.purity != null) '${item.purity}%',
                    '${item.grossWeight}g gross',
                    if (item.stoneWeight > 0) '${item.stoneWeight}g stone',
                    '${item.netWeight}g net',
                  ].join(' · '),
                  style: RatnexTheme.label(size: 11),
                ),
                Text(
                  '${currency.format(item.ratePerGram.round())}/g → ${currency.format(item.appraisalValue.round())}',
                  style: RatnexTheme.money(size: 13, color: RatnexColors.gold),
                ),
                if (item.notes != null)
                  Text(item.notes!, style: RatnexTheme.label(size: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
