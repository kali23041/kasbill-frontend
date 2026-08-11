import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/bill_pdf_service.dart';
import '../services/shop_bills_service.dart';
import '../theme/ratnex_theme.dart';
import 'create_bill_page.dart';
import 'view_bill_page.dart';

/// Shown after a bill is saved — animated success + share / print / view actions.
class BillSavedPage extends StatefulWidget {
  final ShopBill bill;
  final bool wasEdit;

  const BillSavedPage({
    super.key,
    required this.bill,
    this.wasEdit = false,
  });

  @override
  State<BillSavedPage> createState() => _BillSavedPageState();
}

class _BillSavedPageState extends State<BillSavedPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _checkDraw;
  BillPrintFormat _shareFormat = BillPrintFormat.thermal80;
  bool _busy = false;

  ShopBill get bill => widget.bill;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0, 0.55, curve: Curves.elasticOut),
    );
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 0.7, curve: Curves.easeOut),
    );
    _checkDraw = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _done() => Navigator.of(context).pop(bill);

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        backgroundColor: RatnexColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _done,
                  child: Text(
                    'Done',
                    style: RatnexTheme.label(
                      size: 14,
                      weight: FontWeight.w700,
                      color: RatnexColors.gold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: _ctrl,
                      builder: (context, _) {
                        return Opacity(
                          opacity: _fade.value.clamp(0, 1),
                          child: Column(
                            children: [
                              Transform.scale(
                                scale: _scale.value,
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    color: RatnexColors.up.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: CustomPaint(
                                    painter: _TickPainter(
                                      progress: _checkDraw.value,
                                      color: RatnexColors.up,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                widget.wasEdit
                                    ? 'Bill updated'
                                    : 'Bill saved',
                                style: RatnexTheme.brand(size: 28),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                bill.billNo,
                                style: RatnexTheme.label(
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: RatnexColors.muted,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: RatnexColors.panel,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: RatnexColors.hairline),
                      ),
                      child: Column(
                        children: [
                          _summaryRow('Customer', bill.customer.name),
                          if (bill.customer.phone != null)
                            _summaryRow('Phone', bill.customer.phone!),
                          _summaryRow(
                            'Items',
                            '${bill.items.length}',
                          ),
                          _summaryRow(
                            'Status',
                            bill.statusLabel,
                          ),
                          const Divider(color: RatnexColors.hairline),
                          _summaryRow(
                            'Grand total',
                            currency.format(bill.totals.grandTotal.round()),
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'SHARE FORMAT',
                      style: RatnexTheme.label(
                        size: 11,
                        weight: FontWeight.w700,
                        color: RatnexColors.muted,
                      ).copyWith(letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in BillPrintFormat.values)
                          ChoiceChip(
                            label: Text(BillPdfService.formatLabel(f)),
                            selected: _shareFormat == f,
                            onSelected: (_) =>
                                setState(() => _shareFormat = f),
                            selectedColor: RatnexColors.ink,
                            labelStyle: RatnexTheme.label(
                              size: 12,
                              weight: FontWeight.w600,
                              color: _shareFormat == f
                                  ? Colors.white
                                  : RatnexColors.ink,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.share_outlined,
                            label: 'Share',
                            filled: true,
                            onTap: _busy
                                ? null
                                : () => _run(
                                      () => BillPdfService.shareBill(
                                        bill,
                                        _shareFormat,
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.print_outlined,
                            label: 'Print',
                            filled: false,
                            onTap: _busy
                                ? null
                                : () => _run(
                                      () => BillPdfService.printBill(
                                        bill,
                                        _shareFormat,
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'MORE OPTIONS',
                      style: RatnexTheme.label(
                        size: 11,
                        weight: FontWeight.w700,
                        color: RatnexColors.muted,
                      ).copyWith(letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 8),
                    _OptionTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'View bill',
                      subtitle: 'Full details & payment',
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ViewBillPage(bill: bill),
                          ),
                          result: bill,
                        );
                      },
                    ),
                    _OptionTile(
                      icon: Icons.edit_outlined,
                      title: 'Edit bill',
                      subtitle: 'Change items or payment',
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => CreateBillPage(existing: bill),
                          ),
                          result: bill,
                        );
                      },
                    ),
                    _OptionTile(
                      icon: Icons.add_circle_outline,
                      title: 'New bill',
                      subtitle: 'Start another invoice',
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const CreateBillPage(),
                          ),
                          result: bill,
                        );
                      },
                    ),
                    for (final f in BillPrintFormat.values)
                      _OptionTile(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'Share ${BillPdfService.formatLabel(f)}',
                        subtitle: 'PDF ready to send',
                        onTap: _busy
                            ? null
                            : () => _run(
                                  () => BillPdfService.shareBill(bill, f),
                                ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _done,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RatnexColors.ink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Done',
                          style: RatnexTheme.label(
                            size: 15,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: RatnexTheme.label(
                size: 13,
                color: RatnexColors.muted,
              ),
            ),
          ),
          Text(
            value,
            style: bold
                ? RatnexTheme.money(size: 18, color: RatnexColors.ink)
                : RatnexTheme.label(
                    size: 13,
                    weight: FontWeight.w700,
                    color: RatnexColors.ink,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: RatnexColors.ink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            style: RatnexTheme.label(
              size: 14,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: RatnexColors.ink,
          side: const BorderSide(color: RatnexColors.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: RatnexTheme.label(
            size: 14,
            weight: FontWeight.w700,
            color: RatnexColors.ink,
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: RatnexColors.panel,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RatnexColors.hairline),
            ),
            child: ListTile(
              leading: Icon(icon, color: RatnexColors.ink),
              title: Text(
                title,
                style: RatnexTheme.label(
                  size: 14,
                  weight: FontWeight.w700,
                  color: RatnexColors.ink,
                ),
              ),
              subtitle: Text(subtitle, style: RatnexTheme.label(size: 11)),
              trailing: const Icon(
                Icons.chevron_right,
                color: RatnexColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  final double progress;
  final Color color;

  _TickPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.72, size.height * 0.36);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final extract = metric.extractPath(0, metric.length * progress.clamp(0, 1));
    canvas.drawPath(extract, paint);
  }

  @override
  bool shouldRepaint(covariant _TickPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
