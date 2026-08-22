import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/girvi_pdf_service.dart';
import '../services/shop_girvi_service.dart';
import '../theme/ratnex_theme.dart';
import 'create_girvi_page.dart';
import 'view_girvi_page.dart';

class GirviSavedPage extends StatefulWidget {
  final ShopGirvi girvi;
  final bool wasEdit;

  const GirviSavedPage({
    super.key,
    required this.girvi,
    this.wasEdit = false,
  });

  @override
  State<GirviSavedPage> createState() => _GirviSavedPageState();
}

class _GirviSavedPageState extends State<GirviSavedPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _checkDraw;
  GirviPrintFormat _format = GirviPrintFormat.thermal80;
  bool _busy = false;

  ShopGirvi get girvi => widget.girvi;

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

  void _done() => Navigator.of(context).pop(girvi);

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
                                    ? 'Girvi updated'
                                    : 'Girvi saved',
                                style: RatnexTheme.brand(size: 28),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                girvi.girviNo,
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
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: RatnexColors.panel,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: RatnexColors.hairline),
                      ),
                      child: Column(
                        children: [
                          _row('Customer', girvi.customer.name),
                          _row(
                            'Loan',
                            currency.format(girvi.loanAmount.round()),
                          ),
                          _row(
                            'Due',
                            DateFormat('d MMM yyyy').format(girvi.dueDate),
                          ),
                          Divider(color: RatnexColors.hairline),
                          _row(
                            'Amount due',
                            currency.format(girvi.totals.amountDue.round()),
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'RECEIPT FORMAT',
                      style: RatnexTheme.label(
                        size: 11,
                        weight: FontWeight.w700,
                        color: RatnexColors.muted,
                      ).copyWith(letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final f in GirviPrintFormat.values)
                          ChoiceChip(
                            label: Text(GirviPdfService.formatLabel(f)),
                            selected: _format == f,
                            onSelected: (_) => setState(() => _format = f),
                            selectedColor: RatnexColors.ink,
                            labelStyle: RatnexTheme.label(
                              size: 12,
                              weight: FontWeight.w600,
                              color: _format == f
                                  ? Colors.white
                                  : RatnexColors.ink,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                        () => GirviPdfService.shareGirvi(
                                          girvi,
                                          _format,
                                        ),
                                      ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RatnexColors.ink,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.share_outlined, size: 18),
                              label: const Text('Share'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                        () => GirviPdfService.printGirvi(
                                          girvi,
                                          _format,
                                        ),
                                      ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: RatnexColors.ink,
                                side: BorderSide(
                                  color: RatnexColors.hairline,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.print_outlined, size: 18),
                              label: const Text('Print'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _option(
                      Icons.receipt_long_outlined,
                      'View girvi',
                      'Full details & payments',
                      () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ViewGirviPage(girvi: girvi),
                          ),
                          result: girvi,
                        );
                      },
                    ),
                    _option(
                      Icons.edit_outlined,
                      'Edit girvi',
                      'Change items or loan',
                      () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => CreateGirviPage(existing: girvi),
                          ),
                          result: girvi,
                        );
                      },
                    ),
                    _option(
                      Icons.add_circle_outline,
                      'New girvi',
                      'Start another pledge',
                      () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const CreateGirviPage(),
                          ),
                          result: girvi,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
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
                        child: const Text('Done'),
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

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: RatnexTheme.label(size: 13)),
          ),
          Text(
            value,
            style: bold
                ? RatnexTheme.money(size: 16, color: RatnexColors.ink)
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

  Widget _option(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: RatnexColors.panel,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
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
            trailing: Icon(Icons.chevron_right, color: RatnexColors.muted),
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
    final extract =
        metric.extractPath(0, metric.length * progress.clamp(0, 1));
    canvas.drawPath(extract, paint);
  }

  @override
  bool shouldRepaint(covariant _TickPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
