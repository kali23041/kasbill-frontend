import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/mod_pdf_service.dart';
import '../services/shop_mod_service.dart';
import '../theme/ratnex_theme.dart';
import 'create_mod_page.dart';
import 'view_mod_page.dart';

class ModSavedPage extends StatefulWidget {
  final ShopMod mod;
  final bool wasEdit;

  const ModSavedPage({
    super.key,
    required this.mod,
    this.wasEdit = false,
  });

  @override
  State<ModSavedPage> createState() => _ModSavedPageState();
}

class _ModSavedPageState extends State<ModSavedPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  ModPrintFormat _format = ModPrintFormat.thermal80;
  bool _busy = false;

  ShopMod get mod => widget.mod;

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

  void _done() => Navigator.of(context).pop(mod);

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
                          child: Transform.scale(
                            scale: _scale.value.clamp(0.6, 1.2),
                            child: Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: RatnexColors.goldSoft,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 40,
                                    color: RatnexColors.gold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  widget.wasEdit
                                      ? 'Mod updated'
                                      : 'Mod saved',
                                  style: RatnexTheme.brand(size: 28),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  mod.modNo,
                                  style: RatnexTheme.label(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: RatnexColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${mod.customer.name} · ${currency.format(mod.totals.purchaseAmount.round())}',
                                  style: RatnexTheme.label(size: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Receipt format',
                      style: RatnexTheme.label(
                        size: 12,
                        weight: FontWeight.w600,
                        color: RatnexColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final f in ModPrintFormat.values)
                          ChoiceChip(
                            label: Text(ModPdfService.formatLabel(f)),
                            selected: _format == f,
                            onSelected: (_) => setState(() => _format = f),
                            selectedColor: RatnexColors.goldSoft,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => ModPdfService.shareMod(mod, _format),
                                ),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share receipt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RatnexColors.ink,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => ModPdfService.printMod(mod, _format),
                                ),
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Print'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ViewModPage(mod: mod),
                          ),
                        );
                      },
                      child: const Text('View details'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => CreateModPage(existing: mod),
                          ),
                        );
                      },
                      child: const Text('Edit'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const CreateModPage(),
                          ),
                        );
                      },
                      child: Text(
                        'New mod',
                        style: RatnexTheme.label(
                          size: 14,
                          weight: FontWeight.w700,
                          color: RatnexColors.gold,
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
}
