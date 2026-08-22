import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ratnex_theme.dart';
import '../utils/haptics.dart';
import '../utils/ratnex_format.dart';

/// Numeric input that also accepts arithmetic — a shop can type `12.5+3.2`
/// or `4*2750` and the field resolves it on blur or on submit.
class CalcTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? suffix;
  final String? prefix;
  final bool allowDecimal;
  final bool enabled;
  final int? maxLength;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<double>? onEvaluated;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Widget? trailing;
  final bool autofocus;

  const CalcTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.suffix,
    this.prefix,
    this.allowDecimal = true,
    this.enabled = true,
    this.maxLength,
    this.validator,
    this.onChanged,
    this.onEvaluated,
    this.focusNode,
    this.textInputAction,
    this.trailing,
    this.autofocus = false,
  });

  @override
  State<CalcTextField> createState() => _CalcTextFieldState();
}

class _CalcTextFieldState extends State<CalcTextField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _ownsFocus = false;
  String? _preview;

  @override
  void initState() {
    super.initState();
    _ownsFocus = widget.focusNode == null;
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _resolve();
  }

  void _onChanged(String value) {
    final next = RatnexCalc.looksLikeExpression(value)
        ? RatnexCalc.evaluate(value)
        : null;
    if (next != null) {
      final formatted = _format(next);
      if (formatted != _preview) setState(() => _preview = formatted);
    } else if (_preview != null) {
      setState(() => _preview = null);
    }
    widget.onChanged?.call(value);
  }

  String _format(double value) {
    if (widget.allowDecimal) {
      final s = value.toStringAsFixed(3);
      return s
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return value.round().toString();
  }

  /// Replaces the expression with its result.
  void _resolve() {
    final raw = widget.controller.text;
    if (!RatnexCalc.looksLikeExpression(raw)) {
      if (_preview != null) setState(() => _preview = null);
      return;
    }
    final value = RatnexCalc.evaluate(raw);
    if (value == null) return;
    final formatted = _format(value);
    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    Haptics.light();
    setState(() => _preview = null);
    widget.onEvaluated?.call(value);
    widget.onChanged?.call(formatted);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focus,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          maxLength: widget.maxLength,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: (_) => _resolve(),
          onChanged: _onChanged,
          validator: widget.validator,
          keyboardType: TextInputType.numberWithOptions(
            decimal: widget.allowDecimal,
            signed: false,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              widget.allowDecimal
                  ? RegExp(r'[0-9+\-*/×÷.() ]')
                  : RegExp(r'[0-9+\-*/×÷() ]'),
            ),
          ],
          style: RatnexTheme.money(size: 15, weight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            counterText: '',
            prefixText: widget.prefix,
            suffixText: widget.suffix,
            suffixIcon: widget.trailing,
            labelStyle: RatnexTheme.label(size: 12.5),
            hintStyle: RatnexTheme.label(size: 13),
            suffixStyle: RatnexTheme.label(size: 12.5),
            filled: true,
            fillColor: RatnexColors.panel,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: RatnexColors.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: RatnexColors.gold, width: 1.4),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: RatnexColors.hairline),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: RatnexColors.down),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: RatnexColors.down, width: 1.4),
            ),
          ),
        ),
        if (_preview != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 4),
            child: Row(
              children: [
                Icon(Icons.calculate_outlined, size: 13, color: RatnexColors.gold),
                const SizedBox(width: 5),
                Text(
                  '= $_preview${widget.suffix == null ? '' : ' ${widget.suffix}'} · tap done to apply',
                  style: RatnexTheme.label(
                    size: 11,
                    weight: FontWeight.w600,
                    color: RatnexColors.gold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Parses a field that may still hold an unresolved expression.
double parseAmount(String raw, {double fallback = 0}) {
  final direct = double.tryParse(raw.trim());
  if (direct != null) return direct;
  return RatnexCalc.evaluate(raw) ?? fallback;
}
