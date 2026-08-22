import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_schemes_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/calc_text_field.dart';
import '../widgets/ratnex_ui.dart';

class CreateSchemePage extends StatefulWidget {
  final SavingsScheme? existing;

  const CreateSchemePage({super.key, this.existing});

  @override
  State<CreateSchemePage> createState() => _CreateSchemePageState();
}

class _CreateSchemePageState extends State<CreateSchemePage> {
  final _service = ShopSchemesService();
  final _formKey = GlobalKey<FormState>();

  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _amount = TextEditingController(
    text: widget.existing?.monthlyAmount.toStringAsFixed(0) ?? '2000',
  );
  late final _duration = TextEditingController(
    text: '${widget.existing?.durationMonths ?? 11}',
  );
  late final _bonusValue = TextEditingController(
    text: widget.existing?.bonusValue.toStringAsFixed(
          widget.existing?.bonusType == SchemeBonusType.percent ? 1 : 0,
        ) ??
        '1',
  );
  late final _terms = TextEditingController(text: widget.existing?.terms ?? '');

  late String _accrual = widget.existing?.accrual ?? SchemeAccrual.grams;
  late String _metalType = widget.existing?.metalType ?? 'gold';
  late String _bonusType =
      widget.existing?.bonusType ?? SchemeBonusType.freeInstallment;
  late bool _allowCustom = widget.existing?.allowCustomAmount ?? false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _duration.dispose();
    _bonusValue.dispose();
    _terms.dispose();
    super.dispose();
  }

  double get _monthly => parseAmount(_amount.text);

  int get _months => parseAmount(_duration.text, fallback: 11).round();

  double get _bonus => parseAmount(_bonusValue.text);

  double get _memberPays => _monthly * _months;

  double get _shopGives {
    switch (_bonusType) {
      case SchemeBonusType.freeInstallment:
        return _monthly * _bonus;
      case SchemeBonusType.percent:
        return _memberPays * (_bonus / 100);
      case SchemeBonusType.flat:
        return _bonus;
      default:
        return 0;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_monthly <= 0 || _months <= 0) {
      RatnexSnack.error(context, 'Set a monthly amount and duration');
      return;
    }

    setState(() => _saving = true);
    try {
      final draft = SavingsScheme(
        id: widget.existing?.id ?? '',
        name: _name.text.trim(),
        monthlyAmount: _monthly,
        durationMonths: _months,
        accrual: _accrual,
        metalType: _metalType,
        bonusType: _bonusType,
        bonusValue: _bonus,
        allowCustomAmount: _allowCustom,
        status: widget.existing?.status ?? 'active',
        terms: _terms.text.trim().isEmpty ? null : _terms.text.trim(),
        startedAt: widget.existing?.startedAt,
      );

      if (_isEdit) {
        await _service.updateScheme(draft);
      } else {
        await _service.createScheme(draft);
      }
      if (!mounted) return;
      RatnexSnack.success(
        context,
        _isEdit ? 'Scheme updated' : 'Scheme created',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) RatnexSnack.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RatnexPageScaffold(
      title: _isEdit ? 'Edit scheme' : 'New scheme',
      subtitle: 'Set the monthly amount, duration and what the member gets',
      showBack: true,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Give the plan a name' : null,
              style: RatnexTheme.label(size: 14, color: RatnexColors.ink),
              decoration: _decoration('Scheme name', 'Swarna Nidhi 11+1'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: CalcTextField(
                    controller: _amount,
                    label: 'Monthly amount',
                    prefix: '₹ ',
                    allowDecimal: false,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CalcTextField(
                    controller: _duration,
                    label: 'Months',
                    allowDecimal: false,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const RatnexSectionLabel(text: 'WHAT THE MEMBER SAVES'),
            const SizedBox(height: 8),
            _OptionGroup(
              options: SchemeAccrual.all
                  .map((v) => (value: v, label: SchemeAccrual.label(v)))
                  .toList(),
              selected: _accrual,
              onSelected: (v) => setState(() => _accrual = v),
            ),
            if (_accrual == SchemeAccrual.grams) ...[
              const SizedBox(height: 10),
              _OptionGroup(
                options: const [
                  (value: 'gold', label: 'Gold'),
                  (value: 'silver', label: 'Silver'),
                ],
                selected: _metalType,
                onSelected: (v) => setState(() => _metalType = v),
              ),
              const SizedBox(height: 8),
              RatnexNotice(
                message:
                    'Each installment buys grams at that day\'s rate, so the member is protected if prices rise before maturity.',
                color: RatnexColors.info,
                icon: Icons.shield_outlined,
              ),
            ],
            const SizedBox(height: 18),
            const RatnexSectionLabel(text: 'BONUS AT MATURITY'),
            const SizedBox(height: 8),
            _OptionGroup(
              options: SchemeBonusType.all
                  .map((v) => (value: v, label: SchemeBonusType.label(v)))
                  .toList(),
              selected: _bonusType,
              onSelected: (v) => setState(() => _bonusType = v),
              wrap: true,
            ),
            if (_bonusType != SchemeBonusType.none) ...[
              const SizedBox(height: 12),
              CalcTextField(
                controller: _bonusValue,
                label: switch (_bonusType) {
                  SchemeBonusType.freeInstallment => 'Free installments',
                  SchemeBonusType.percent => 'Bonus percent',
                  _ => 'Bonus amount',
                },
                prefix: _bonusType == SchemeBonusType.flat ? '₹ ' : null,
                suffix: _bonusType == SchemeBonusType.percent ? '%' : null,
                allowDecimal: _bonusType == SchemeBonusType.percent,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: _allowCustom,
              onChanged: (v) => setState(() => _allowCustom = v),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: RatnexColors.gold,
              title: Text(
                'Allow a different amount each month',
                style: RatnexTheme.label(
                  size: 13,
                  weight: FontWeight.w600,
                  color: RatnexColors.ink,
                ),
              ),
              subtitle: Text(
                'Useful when members pay whatever they can that month',
                style: RatnexTheme.label(size: 11.5),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _terms,
              maxLines: 4,
              style: RatnexTheme.label(size: 13, color: RatnexColors.ink),
              decoration: _decoration(
                'Terms (printed on the passbook)',
                'Missed installments extend the maturity date. Bonus applies only if all installments are paid on time.',
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: RatnexColors.goldSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Member pays over $_months months',
                    value: RatnexFormat.money(_memberPays),
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'You add at maturity',
                    value: RatnexFormat.money(_shopGives),
                    color: RatnexColors.down,
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: RatnexColors.gold.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Member redeems',
                    value: RatnexFormat.money(_memberPays + _shopGives),
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: RatnexColors.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
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
                      _isEdit ? 'Save changes' : 'Create scheme',
                      style: RatnexTheme.label(
                        size: 14,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: RatnexColors.down),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: RatnexColors.down, width: 1.4),
      ),
    );
  }
}

class _OptionGroup extends StatelessWidget {
  final List<({String value, String label})> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool wrap;

  const _OptionGroup({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.wrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final chips = options.map((o) {
      final active = o.value == selected;
      return ChoiceChip(
        label: Text(o.label),
        selected: active,
        onSelected: (_) => onSelected(o.value),
        labelStyle: RatnexTheme.label(
          size: 12,
          weight: FontWeight.w600,
          color: active ? Colors.white : RatnexColors.muted,
        ),
        selectedColor: RatnexColors.ink,
        backgroundColor: RatnexColors.panel,
        side: BorderSide(color: RatnexColors.hairline),
        showCheckmark: false,
      );
    }).toList();

    if (wrap) return Wrap(spacing: 8, runSpacing: 8, children: chips);
    return Row(
      children: chips
          .map((c) => Padding(padding: const EdgeInsets.only(right: 8), child: c))
          .toList(),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: RatnexTheme.label(
              size: 12.5,
              weight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? RatnexColors.ink : null,
            ),
          ),
        ),
        Text(
          value,
          style: RatnexTheme.money(
            size: bold ? 16 : 14,
            color: color ?? RatnexColors.ink,
          ),
        ),
      ],
    );
  }
}
