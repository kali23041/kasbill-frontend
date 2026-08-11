import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/shop_cash_service.dart';
import '../theme/ratnex_theme.dart';

/// Opening-cash dialog. Safe to call from shell or home (uses root navigator).
Future<void> showDailyCashPrompt(BuildContext context) async {
  if (!context.mounted) return;

  final result = await showDialog<double>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) => const _DailyCashDialog(),
  );

  if (!context.mounted) return;

  final cash = ShopCashService();
  try {
    if (result == null) {
      // Dialog dismissed unexpectedly — still mark prompted so it doesn't loop.
      await cash.skipOpeningCash();
      return;
    }
    await cash.setOpeningCash(result);
  } catch (e) {
    debugPrint('setOpeningCash: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save cash: $e')),
      );
    }
  }
}

class _DailyCashDialog extends StatefulWidget {
  const _DailyCashDialog();

  @override
  State<_DailyCashDialog> createState() => _DailyCashDialogState();
}

class _DailyCashDialogState extends State<_DailyCashDialog> {
  final _amountCtrl = TextEditingController();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        'Cash for today',
        style: RatnexTheme.label(
          size: 18,
          weight: FontWeight.w700,
          color: RatnexColors.ink,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Do you want to add opening cash for today? Each day starts at ${_currency.format(0)}.',
            style: RatnexTheme.label(size: 13, color: RatnexColors.ink),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              hintText: 'Opening cash amount',
              prefixText: '₹ ',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(0.0),
          child: Text(
            'Skip',
            style: RatnexTheme.label(size: 13, color: RatnexColors.muted),
          ),
        ),
        TextButton(
          onPressed: () {
            final v = double.tryParse(_amountCtrl.text.trim()) ?? 0;
            Navigator.of(context).pop(v);
          },
          child: Text(
            'Add cash',
            style: RatnexTheme.label(
              size: 13,
              weight: FontWeight.w700,
              color: RatnexColors.gold,
            ),
          ),
        ),
      ],
    );
  }
}
