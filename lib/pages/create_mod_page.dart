import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/shop_bills_service.dart';
import '../services/shop_cash_service.dart';
import '../services/shop_customers_service.dart';
import '../services/shop_mod_service.dart';
import '../services/shop_gst_service.dart';
import '../services/shop_profile_service.dart';
import '../services/shop_rates_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';
import 'mod_saved_page.dart';

class CreateModPage extends StatefulWidget {
  final ShopMod? existing;

  const CreateModPage({super.key, this.existing});

  @override
  State<CreateModPage> createState() => _CreateModPageState();
}

class _CreateModPageState extends State<CreateModPage> {
  final _mod = ShopModService();
  final _cash = ShopCashService();
  final _profile = ShopProfileService();
  final _gst = ShopGstService();
  final _customers = ShopCustomersService();
  final _metals = ShopRatesService();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerAddress = TextEditingController();
  final _deductionPct = TextEditingController(text: '0');
  final _stoneDeduction = TextEditingController(text: '0');
  final _otherDeduction = TextEditingController(text: '0');
  final _purchaseCtrl = TextEditingController();
  final _paymentRef = TextEditingController();
  final _idProofType = TextEditingController();
  final _idProofNumber = TextEditingController();
  final _notesCtrl = TextEditingController();

  final List<ModItem> _items = [];
  List<ShopCustomer> _allCustomers = const [];
  List<ShopMetalRate> _metalRates = const [];
  StreamSubscription<List<ShopCustomer>>? _custSub;
  StreamSubscription<List<ShopMetalRate>>? _metalSub;

  bool _saving = false;
  bool _showCustomerMore = false;
  bool _showNotes = false;
  bool _showIdProof = false;
  bool _purchaseTouched = false;
  String? _suggestField;
  bool _fillingCustomer = false;
  String _paymentMode = 'cash';
  DateTime _paidAt = DateTime.now();

  static const _modes = [
    ('cash', 'Cash'),
    ('upi', 'UPI'),
    ('bank', 'Bank'),
    ('card', 'Card'),
    ('other', 'Other'),
  ];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _customerName.text = e.customer.name;
      _customerPhone.text = e.customer.phone ?? '';
      _customerAddress.text = e.customer.address ?? '';
      _items.addAll(e.items);
      _deductionPct.text = e.deductionPercent.toString();
      _stoneDeduction.text = e.totals.stoneDeduction.round().toString();
      _otherDeduction.text = e.totals.otherDeduction.round().toString();
      _purchaseCtrl.text = e.totals.purchaseAmount.round().toString();
      _paymentMode = e.paymentMode;
      _paymentRef.text = e.paymentRef ?? '';
      _idProofType.text = e.idProofType ?? '';
      _idProofNumber.text = e.idProofNumber ?? '';
      _notesCtrl.text = e.notes ?? '';
      _paidAt = e.paidAt;
      _purchaseTouched = true;
      _showCustomerMore = e.customer.address?.isNotEmpty ?? false;
      _showNotes = e.notes?.isNotEmpty ?? false;
      _showIdProof = (e.idProofType?.isNotEmpty ?? false) ||
          (e.idProofNumber?.isNotEmpty ?? false);
    }
    void refresh() {
      if (!_purchaseTouched) _syncPurchase();
      setState(() {});
    }

    _deductionPct.addListener(refresh);
    _stoneDeduction.addListener(refresh);
    _otherDeduction.addListener(refresh);
    _purchaseCtrl.addListener(() => setState(() {}));
    _customerName.addListener(() {
      if (!_fillingCustomer) setState(() {});
    });
    _customerPhone.addListener(() {
      if (!_fillingCustomer) setState(() {});
    });
    _custSub = _customers.watchCustomers().listen((list) {
      if (mounted) setState(() => _allCustomers = list);
    });
    _metalSub = _metals.watchMetals().listen((list) {
      if (mounted) setState(() => _metalRates = list);
    });
  }

  @override
  void dispose() {
    _custSub?.cancel();
    _metalSub?.cancel();
    _customerName.dispose();
    _customerPhone.dispose();
    _customerAddress.dispose();
    _deductionPct.dispose();
    _stoneDeduction.dispose();
    _otherDeduction.dispose();
    _purchaseCtrl.dispose();
    _paymentRef.dispose();
    _idProofType.dispose();
    _idProofNumber.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _deductionPercent =>
      double.tryParse(_deductionPct.text.trim()) ?? 0;

  double get _stoneAmt =>
      double.tryParse(_stoneDeduction.text.trim()) ?? 0;

  double get _otherAmt =>
      double.tryParse(_otherDeduction.text.trim()) ?? 0;

  ModTotals get _computedTotals => ModTotals.compute(
        items: _items,
        deductionPercent: _deductionPercent,
        stoneDeduction: _stoneAmt,
        otherDeduction: _otherAmt,
      );

  double get _purchaseAmount {
    final v = double.tryParse(_purchaseCtrl.text.trim());
    if (v != null) return v;
    return _computedTotals.purchaseAmount;
  }

  void _syncPurchase() {
    final suggested = _computedTotals.purchaseAmount.round();
    if (_purchaseCtrl.text != suggested.toString()) {
      _purchaseCtrl.text = suggested.toString();
    }
  }

  List<ShopCustomer> get _suggestions {
    if (_suggestField == null) return const [];
    final q = _suggestField == 'phone'
        ? _customerPhone.text
        : _customerName.text;
    return ShopCustomersService.filterSuggestions(_allCustomers, q);
  }

  void _applyCustomer(ShopCustomer c) {
    _fillingCustomer = true;
    _customerName.text = c.name;
    _customerPhone.text = c.phone;
    _customerAddress.text = c.address ?? '';
    setState(() {
      _suggestField = null;
      _showCustomerMore = c.address?.isNotEmpty ?? false;
    });
    _fillingCustomer = false;
    FocusScope.of(context).unfocus();
  }

  Future<void> _addItem() async {
    final item = await showModalBottomSheet<ModItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RatnexColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _AddModItemSheet(
        metals: _metalRates,
        currency: _currency,
      ),
    );
    if (item == null) return;
    setState(() {
      _items.add(item);
      if (!_purchaseTouched) _syncPurchase();
    });
  }

  Future<void> _save() async {
    if (_customerName.text.trim().isEmpty) {
      _toast('Enter customer name');
      return;
    }
    if (_items.isEmpty) {
      _toast('Add at least one ornament');
      return;
    }
    if (_purchaseAmount <= 0) {
      _toast('Enter purchase amount');
      return;
    }

    setState(() => _saving = true);
    try {
      final profile = await _profile.watchProfile().first;
      final gst = await _gst.getSettings();
      final base = ModTotals.compute(
        items: _items,
        deductionPercent: _deductionPercent,
        stoneDeduction: _stoneAmt,
        otherDeduction: _otherAmt,
        purchaseOverride: _purchaseAmount,
      );
      final draft = ShopMod(
        modNo: widget.existing?.modNo ?? '',
        customer: BillCustomer(
          name: _customerName.text.trim(),
          phone: _customerPhone.text.trim().isEmpty
              ? null
              : _customerPhone.text.trim(),
          address: _customerAddress.text.trim().isEmpty
              ? null
              : _customerAddress.text.trim(),
        ),
        items: List.of(_items),
        totals: base,
        deductionPercent: _deductionPercent,
        paymentMode: _paymentMode,
        paymentRef: _paymentRef.text.trim().isEmpty
            ? null
            : _paymentRef.text.trim(),
        paidAt: _paidAt,
        status: widget.existing?.status == 'cancelled'
            ? 'cancelled'
            : 'completed',
        idProofType: _idProofType.text.trim().isEmpty
            ? null
            : _idProofType.text.trim(),
        idProofNumber: _idProofNumber.text.trim().isEmpty
            ? null
            : _idProofNumber.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        shopSnapshot: BillShopSnapshot.fromProfile(
          profile,
          gstNumber: gst.isConfigured ? gst.gstNumber : null,
        ),
      );

      final ShopMod saved;
      if (_isEdit) {
        await _mod.updateMod(draft);
        saved = draft;
      } else {
        saved = await _mod.createMod(draft);
      }

      await _customers.upsertFromBill(
        name: draft.customer.name,
        phone: draft.customer.phone,
        address: draft.customer.address,
        bumpBillCount: false,
      );

      try {
        if (saved.paymentMode == 'cash' && saved.status != 'cancelled') {
          await _cash.recordModCashOut(
            modNo: saved.modNo,
            amount: saved.totals.purchaseAmount,
          );
        } else {
          await _cash.clearModCashOut(saved.modNo);
        }
      } catch (e) {
        debugPrint('Cash out mod: $e');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ModSavedPage(mod: saved, wasEdit: _isEdit),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: RatnexColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: RatnexColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: RatnexColors.hairline),
        ),
      );

  TextStyle _fs() => RatnexTheme.label(size: 14, color: RatnexColors.ink);

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: RatnexColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RatnexColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: RatnexTheme.label(
              size: 12,
              weight: FontWeight.w700,
              color: RatnexColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _plus({
    required bool expanded,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.remove : Icons.add,
              size: 16,
              color: RatnexColors.gold,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: RatnexTheme.label(
                size: 12,
                weight: FontWeight.w600,
                color: RatnexColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestBox(List<ShopCustomer> list) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: RatnexColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RatnexColors.hairline),
      ),
      child: Column(
        children: [
          for (final c in list.take(5))
            ListTile(
              dense: true,
              title: Text(c.name, style: _fs()),
              subtitle: Text(c.phone, style: RatnexTheme.label(size: 11)),
              onTap: () => _applyCustomer(c),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = ModTotals.compute(
      items: _items,
      deductionPercent: _deductionPercent,
      stoneDeduction: _stoneAmt,
      otherDeduction: _otherAmt,
      purchaseOverride: _purchaseAmount,
    );

    return Scaffold(
      backgroundColor: RatnexColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        backgroundColor: RatnexColors.ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add item'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 14, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    color: RatnexColors.ink,
                  ),
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit mod' : 'New mod',
                      style: RatnexTheme.brand(size: 24),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? 'Saving…' : 'Save',
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
                children: [
                  _card(
                    title: 'Seller / Customer',
                    child: Column(
                      children: [
                        TextField(
                          controller: _customerName,
                          textCapitalization: TextCapitalization.words,
                          decoration: _dec('Customer name *'),
                          style: _fs(),
                          onTap: () => setState(() => _suggestField = 'name'),
                          onChanged: (_) =>
                              setState(() => _suggestField = 'name'),
                        ),
                        if (_suggestField == 'name' && _suggestions.isNotEmpty)
                          _suggestBox(_suggestions),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _customerPhone,
                          keyboardType: TextInputType.phone,
                          decoration: _dec('Phone'),
                          style: _fs(),
                          onTap: () => setState(() => _suggestField = 'phone'),
                          onChanged: (_) =>
                              setState(() => _suggestField = 'phone'),
                        ),
                        if (_suggestField == 'phone' &&
                            _suggestions.isNotEmpty)
                          _suggestBox(_suggestions),
                        const SizedBox(height: 8),
                        _plus(
                          expanded: _showCustomerMore,
                          label: 'More details',
                          onTap: () => setState(
                            () => _showCustomerMore = !_showCustomerMore,
                          ),
                        ),
                        if (_showCustomerMore) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _customerAddress,
                            decoration: _dec('Address'),
                            style: _fs(),
                            onTap: () =>
                                setState(() => _suggestField = null),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    title: 'Ornaments (${_items.length})',
                    child: _items.isEmpty
                        ? Text(
                            'Tap Add item to photograph jewellery and set weight.',
                            style: RatnexTheme.label(size: 13),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < _items.length; i++) ...[
                                if (i > 0)
                                  const Divider(color: RatnexColors.hairline),
                                _ModItemRow(
                                  item: _items[i],
                                  currency: _currency,
                                  onDelete: () => setState(() {
                                    _items.removeAt(i);
                                    if (!_purchaseTouched) _syncPurchase();
                                  }),
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    title: 'Purchase',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appraisal ${_currency.format(totals.appraisalValue.round())}',
                          style: RatnexTheme.label(
                            size: 12,
                            weight: FontWeight.w700,
                            color: RatnexColors.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _deductionPct,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                decoration: _dec('Making / wastage %'),
                                style: _fs(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _stoneDeduction,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: _dec('Stone ₹'),
                                style: _fs(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _otherDeduction,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _dec('Other deduction ₹'),
                          style: _fs(),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _purchaseCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _dec('Amount paid to customer *'),
                          style: _fs(),
                          onChanged: (_) =>
                              setState(() => _purchaseTouched = true),
                        ),
                        if (!_purchaseTouched && totals.appraisalValue > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Auto: appraisal − deductions',
                              style: RatnexTheme.label(size: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    title: 'Payment',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final m in _modes)
                              ChoiceChip(
                                label: Text(m.$2),
                                selected: _paymentMode == m.$1,
                                onSelected: (_) =>
                                    setState(() => _paymentMode = m.$1),
                                selectedColor: RatnexColors.goldSoft,
                                labelStyle: RatnexTheme.label(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: RatnexColors.ink,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _paymentRef,
                          decoration: _dec('UPI / cheque / ref (optional)'),
                          style: _fs(),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            'Paid on ${DateFormat('d MMM yyyy').format(_paidAt)}',
                            style: RatnexTheme.label(
                              size: 13,
                              weight: FontWeight.w600,
                              color: RatnexColors.ink,
                            ),
                          ),
                          trailing: const Icon(Icons.calendar_today, size: 18),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _paidAt,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 1)),
                            );
                            if (picked != null) {
                              setState(() => _paidAt = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    title: 'Extras',
                    child: Column(
                      children: [
                        _plus(
                          expanded: _showIdProof,
                          label: 'ID proof',
                          onTap: () =>
                              setState(() => _showIdProof = !_showIdProof),
                        ),
                        if (_showIdProof) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _idProofType,
                            decoration: _dec('Aadhaar / PAN / other'),
                            style: _fs(),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _idProofNumber,
                            decoration: _dec('ID number'),
                            style: _fs(),
                          ),
                        ],
                        const SizedBox(height: 8),
                        _plus(
                          expanded: _showNotes,
                          label: 'Notes',
                          onTap: () =>
                              setState(() => _showNotes = !_showNotes),
                        ),
                        if (_showNotes) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _notesCtrl,
                            maxLines: 3,
                            decoration: _dec('Notes'),
                            style: _fs(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: RatnexColors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Pay customer',
                          style: RatnexTheme.label(
                            size: 13,
                            color: Colors.white70,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _currency.format(totals.purchaseAmount.round()),
                          style: RatnexTheme.money(
                            size: 22,
                            color: RatnexColors.gold,
                          ),
                        ),
                      ],
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
}

class _ModItemRow extends StatelessWidget {
  final ModItem item;
  final NumberFormat currency;
  final VoidCallback onDelete;

  const _ModItemRow({
    required this.item,
    required this.currency,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = StockImageHelper.decodeBase64(item.imageBase64);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52,
              height: 52,
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
                  '${item.netWeight}g · ${item.metalLabel ?? 'Metal'} · ${currency.format(item.ratePerGram.round())}/g',
                  style: RatnexTheme.label(size: 11),
                ),
                Text(
                  currency.format(item.appraisalValue.round()),
                  style: RatnexTheme.money(size: 13, color: RatnexColors.gold),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            color: RatnexColors.muted,
          ),
        ],
      ),
    );
  }
}

class _AddModItemSheet extends StatefulWidget {
  final List<ShopMetalRate> metals;
  final NumberFormat currency;

  const _AddModItemSheet({
    required this.metals,
    required this.currency,
  });

  @override
  State<_AddModItemSheet> createState() => _AddModItemSheetState();
}

class _AddModItemSheetState extends State<_AddModItemSheet> {
  final _name = TextEditingController();
  final _gross = TextEditingController();
  final _stone = TextEditingController(text: '0');
  final _net = TextEditingController();
  final _rate = TextEditingController();
  final _purity = TextEditingController();
  final _notes = TextEditingController();
  ShopMetalRate? _metal;
  String? _imageBase64;
  String? _imageMime;
  bool _netTouched = false;

  @override
  void initState() {
    super.initState();
    if (widget.metals.isNotEmpty) {
      _metal = widget.metals.first;
      _rate.text = _metal!.shopRatePerGram.round().toString();
    }
    void refresh() {
      if (!_netTouched) _syncNet();
      setState(() {});
    }

    _gross.addListener(refresh);
    _stone.addListener(refresh);
    _net.addListener(() => setState(() {}));
    _rate.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _gross.dispose();
    _stone.dispose();
    _net.dispose();
    _rate.dispose();
    _purity.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _syncNet() {
    final gross = double.tryParse(_gross.text.trim()) ?? 0;
    final stone = double.tryParse(_stone.text.trim()) ?? 0;
    final net = (gross - stone).clamp(0, double.infinity);
    final text = net == 0 ? '' : net.toStringAsFixed(3);
    if (_net.text != text) _net.text = text;
  }

  double get _appraisal {
    final net = double.tryParse(_net.text.trim()) ?? 0;
    final rate = double.tryParse(_rate.text.trim()) ?? 0;
    return modAppraisalFor(netWeight: net, ratePerGram: rate);
  }

  Future<void> _pick(ImageSource source) async {
    final result = await StockImageHelper.pickCompressed(source: source);
    if (result == null) return;
    setState(() {
      _imageBase64 = result.base64;
      _imageMime = result.mime;
    });
  }

  void _submit() {
    final name = _name.text.trim();
    final net = double.tryParse(_net.text.trim());
    final rate = double.tryParse(_rate.text.trim());
    if (name.isEmpty || net == null || net <= 0 || rate == null || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter name, net weight and rate')),
      );
      return;
    }
    final gross = double.tryParse(_gross.text.trim()) ?? net;
    final stone = double.tryParse(_stone.text.trim()) ?? 0;
    Navigator.pop(
      context,
      ModItem.compute(
        name: name,
        metalLabel: _metal?.label,
        karat: _metal?.karat,
        purity: double.tryParse(_purity.text.trim()),
        grossWeight: gross,
        stoneWeight: stone,
        netWeight: net,
        ratePerGram: rate,
        imageBase64: _imageBase64,
        imageMime: _imageMime,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  InputDecoration _dec(String h) => InputDecoration(
        hintText: h,
        isDense: true,
        filled: true,
        fillColor: RatnexColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: RatnexColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: RatnexColors.hairline),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final thumb = StockImageHelper.decodeBase64(_imageBase64);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: RatnexColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ornament item',
                      style: RatnexTheme.label(
                        size: 18,
                        weight: FontWeight.w700,
                        color: RatnexColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  AspectRatio(
                    aspectRatio: 1.4,
                    child: Material(
                      color: RatnexColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _pick(ImageSource.camera),
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: RatnexColors.hairline),
                          ),
                          child: thumb != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.memory(
                                    thumb,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.add_a_photo_outlined,
                                      color: RatnexColors.gold,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add photo (saved as base64)',
                                      style: RatnexTheme.label(
                                        size: 13,
                                        weight: FontWeight.w700,
                                        color: RatnexColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined, size: 16),
                        label: const Text('Camera'),
                      ),
                      TextButton.icon(
                        onPressed: () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_outlined, size: 16),
                        label: const Text('Gallery'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    decoration: _dec('Item name *'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),
                  if (widget.metals.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _metal?.id,
                      items: widget.metals
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(m.label),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        final m = widget.metals.firstWhere((e) => e.id == id);
                        setState(() {
                          _metal = m;
                          _rate.text = m.shopRatePerGram.round().toString();
                        });
                      },
                      decoration: _dec('Metal'),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _purity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Purity / touch % (optional)'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _gross,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _dec('Gross g'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _stone,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _dec('Stone g'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _net,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Net g *'),
                    onChanged: (_) => setState(() => _netTouched = true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _rate,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Rate ₹/g *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notes,
                    decoration: _dec('Item notes (optional)'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: RatnexColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: RatnexColors.hairline),
                    ),
                    child: Row(
                      children: [
                        Text('Appraisal', style: RatnexTheme.label(size: 12)),
                        const Spacer(),
                        Text(
                          widget.currency.format(_appraisal.round()),
                          style: RatnexTheme.money(
                            size: 18,
                            color: RatnexColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RatnexColors.ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Add to mod'),
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
}
