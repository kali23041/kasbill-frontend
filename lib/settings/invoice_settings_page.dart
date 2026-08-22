import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_settings_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';

/// GST rules expect a continuous invoice series per financial year. This is
/// where the shop switches from the random bill numbers to a real one.
class InvoiceSettingsPage extends StatefulWidget {
  const InvoiceSettingsPage({super.key});

  @override
  State<InvoiceSettingsPage> createState() => _InvoiceSettingsPageState();
}

class _InvoiceSettingsPageState extends State<InvoiceSettingsPage> {
  final _service = ShopSettingsService();
  final _prefix = TextEditingController();
  final _terms = TextEditingController();
  final _footer = TextEditingController();

  String _preview = '…';
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _service.getSettings();
    final preview = await _service.previewNextInvoiceNumber();
    if (!mounted) return;
    setState(() {
      _prefix.text = settings.invoicePrefix;
      _terms.text = settings.invoiceTerms ?? '';
      _footer.text = settings.invoiceFooter ?? '';
      _preview = preview;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _prefix.dispose();
    _terms.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _patch(Map<String, dynamic> fields) async {
    await _service.patch(fields);
    final preview = await _service.previewNextInvoiceNumber();
    if (mounted) setState(() => _preview = preview);
  }

  Future<void> _saveText() async {
    setState(() => _saving = true);
    try {
      await _patch({
        'invoicePrefix': _prefix.text.trim().isEmpty
            ? 'RTX'
            : _prefix.text.trim().toUpperCase(),
        'invoiceTerms': _terms.text.trim().isEmpty ? null : _terms.text.trim(),
        'invoiceFooter':
            _footer.text.trim().isEmpty ? null : _footer.text.trim(),
      });
      if (mounted) RatnexSnack.success(context, 'Saved');
    } catch (e) {
      if (mounted) RatnexSnack.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ShopSettings>(
      stream: _service.watchSettings(),
      builder: (context, snap) {
        final settings = snap.data ?? ShopSettings.defaults;

        return RatnexPageScaffold(
          title: 'Invoice numbering',
          subtitle: 'A continuous series per financial year',
          showBack: true,
          body: !_loaded
              ? const RatnexListSkeleton(rows: 3)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: RatnexColors.rateBoard,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEXT INVOICE NUMBER',
                            style: RatnexTheme.label(
                              size: 10.5,
                              weight: FontWeight.w700,
                              color: RatnexColors.rateAccent,
                            ).copyWith(letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            settings.sequentialInvoiceNo
                                ? _preview
                                : 'RTX2508141945 (automatic)',
                            style: RatnexTheme.money(
                              size: settings.sequentialInvoiceNo ? 26 : 19,
                              color: RatnexColors.onRateBoard,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Financial year ${RatnexFormat.financialYear(DateTime.now())}',
                            style: RatnexTheme.label(
                              size: 12,
                              color: RatnexColors.rateAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    RatnexNotice(
                      message: settings.sequentialInvoiceNo
                          ? 'Numbers are handed out one at a time inside a transaction, so two people billing at once never get the same number.'
                          : 'Automatic numbers are unique but not continuous. GST rules expect a continuous series — turn this on before your next filing.',
                      color: settings.sequentialInvoiceNo
                          ? RatnexColors.up
                          : RatnexColors.warn,
                      icon: settings.sequentialInvoiceNo
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_outlined,
                    ),
                    const SizedBox(height: 14),
                    RatnexPanel(
                      child: Column(
                        children: [
                          _SwitchTile(
                            title: 'Sequential numbering',
                            subtitle: 'RTX/25-26/0001, RTX/25-26/0002 …',
                            value: settings.sequentialInvoiceNo,
                            onChanged: (v) =>
                                _patch({'sequentialInvoiceNo': v}),
                          ),
                          Divider(
                            height: 1,
                            indent: 12,
                            endIndent: 12,
                            color: RatnexColors.hairline,
                          ),
                          _SwitchTile(
                            title: 'Include financial year',
                            subtitle: 'Adds 25-26 to the number',
                            value: settings.includeFinancialYear,
                            onChanged: (v) =>
                                _patch({'includeFinancialYear': v}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _prefix,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 8,
                      onChanged: (_) => setState(() {}),
                      style: RatnexTheme.money(size: 15),
                      decoration: _decoration(
                        'Prefix',
                        'Usually your shop initials',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Digits',
                          style: RatnexTheme.label(size: 12.5),
                        ),
                        const Spacer(),
                        ...[3, 4, 5, 6].map((n) {
                          final active = settings.invoicePadding == n;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text('$n'),
                              selected: active,
                              onSelected: (_) => _patch({'invoicePadding': n}),
                              labelStyle: RatnexTheme.label(
                                size: 12,
                                weight: FontWeight.w700,
                                color:
                                    active ? Colors.white : RatnexColors.muted,
                              ),
                              selectedColor: RatnexColors.ink,
                              backgroundColor: RatnexColors.panel,
                              side: BorderSide(color: RatnexColors.hairline),
                              showCheckmark: false,
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const RatnexSectionLabel(text: 'PRINTED ON EVERY INVOICE'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _terms,
                      maxLines: 4,
                      style: RatnexTheme.label(
                        size: 13,
                        color: RatnexColors.ink,
                      ),
                      decoration: _decoration(
                        'Terms & conditions',
                        'Goods once sold will not be taken back. Exchange within 7 days with the original bill.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _footer,
                      maxLines: 2,
                      style: RatnexTheme.label(
                        size: 13,
                        color: RatnexColors.ink,
                      ),
                      decoration: _decoration(
                        'Footer line',
                        'Thank you for shopping with us',
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _saving ? null : _saveText,
                      style: FilledButton.styleFrom(
                        backgroundColor: RatnexColors.ink,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Save',
                              style: RatnexTheme.label(
                                size: 13.5,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  InputDecoration _decoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      labelStyle: RatnexTheme.label(size: 12.5),
      hintStyle: RatnexTheme.label(size: 12.5),
      filled: true,
      fillColor: RatnexColors.panel,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: RatnexColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: RatnexColors.gold, width: 1.4),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
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
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: RatnexColors.gold,
          ),
        ],
      ),
    );
  }
}
