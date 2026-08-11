import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/shop_bills_service.dart';
import '../services/shop_cash_service.dart';
import '../services/shop_customers_service.dart';
import '../services/shop_girvi_service.dart';
import '../services/shop_gst_service.dart';
import '../services/shop_profile_service.dart';
import '../services/shop_rates_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';
import 'girvi_saved_page.dart';

class CreateGirviPage extends StatefulWidget {
  final ShopGirvi? existing;

  const CreateGirviPage({super.key, this.existing});

  @override
  State<CreateGirviPage> createState() => _CreateGirviPageState();
}

class _CreateGirviPageState extends State<CreateGirviPage> {
  final _girvi = ShopGirviService();
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
  final _loanCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '2');
  final _tenureCtrl = TextEditingController(text: '6');
  final _notesCtrl = TextEditingController();

  final List<GirviItem> _items = [];
  List<ShopCustomer> _allCustomers = const [];
  List<ShopMetalRate> _metalRates = const [];
  StreamSubscription<List<ShopCustomer>>? _custSub;
  StreamSubscription<List<ShopMetalRate>>? _metalSub;

  bool _saving = false;
  bool _showCustomerMore = false;
  bool _showNotes = false;
  String? _suggestField;
  bool _fillingCustomer = false;
  DateTime _startedAt = DateTime.now();
  bool _loanTouched = false;
  String _disbursementMode = 'cash';

  static const _disburseModes = [
    ('cash', 'Cash'),
    ('upi', 'UPI'),
    ('bank', 'Bank'),
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
      _loanCtrl.text = e.loanAmount.round().toString();
      _rateCtrl.text = e.interestRatePercent.toString();
      _tenureCtrl.text = e.tenureMonths.toString();
      _notesCtrl.text = e.notes ?? '';
      _startedAt = e.startedAt;
      _disbursementMode = e.disbursementMode;
      _loanTouched = true;
      _showCustomerMore = e.customer.address?.isNotEmpty ?? false;
      _showNotes = e.notes?.isNotEmpty ?? false;
    }
    void refresh() => setState(() {});
    _loanCtrl.addListener(refresh);
    _rateCtrl.addListener(refresh);
    _tenureCtrl.addListener(refresh);
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
    _loanCtrl.dispose();
    _rateCtrl.dispose();
    _tenureCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _appraisal =>
      _items.fold<double>(0, (s, i) => s + i.appraisalValue);

  int get _tenure {
    final t = int.tryParse(_tenureCtrl.text.trim()) ?? 1;
    return t < 1 ? 1 : t;
  }

  double get _interestRate =>
      double.tryParse(_rateCtrl.text.trim()) ?? 0;

  double get _loanAmount {
    final v = double.tryParse(_loanCtrl.text.trim());
    if (v != null) return v;
    if (!_loanTouched && _appraisal > 0) {
      return (_appraisal * 0.75).roundToDouble();
    }
    return 0;
  }

  DateTime get _dueDate {
    final s = DateTime(_startedAt.year, _startedAt.month, _startedAt.day);
    return DateTime(s.year, s.month + _tenure, s.day);
  }

  GirviTotals get _totals => GirviTotals.compute(
        items: _items,
        loanAmount: _loanAmount,
        interestRatePercent: _interestRate,
        tenureMonths: _tenure,
        paidAmount: widget.existing?.totals.paidAmount ?? 0,
      );

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
    final item = await showModalBottomSheet<GirviItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RatnexColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _AddGirviItemSheet(
        metals: _metalRates,
        currency: _currency,
      ),
    );
    if (item == null) return;
    setState(() {
      _items.add(item);
      if (!_loanTouched) {
        _loanCtrl.text = (_appraisal * 0.75).round().toString();
      }
    });
  }

  Future<void> _save() async {
    if (_customerName.text.trim().isEmpty) {
      _toast('Enter customer name');
      return;
    }
    if (_items.isEmpty) {
      _toast('Add at least one pledged item');
      return;
    }
    if (_loanAmount <= 0) {
      _toast('Enter loan amount');
      return;
    }

    setState(() => _saving = true);
    try {
      final profile = await _profile.watchProfile().first;
      final gst = await _gst.getSettings();
      final totals = _totals;
      final draft = ShopGirvi(
        girviNo: widget.existing?.girviNo ?? '',
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
        loanAmount: _loanAmount,
        interestRatePercent: _interestRate,
        tenureMonths: _tenure,
        startedAt: _startedAt,
        dueDate: _dueDate,
        status: widget.existing?.status == 'closed' ? 'closed' : 'active',
        totals: totals,
        payments: widget.existing?.payments ?? const [],
        disbursementMode: _disbursementMode,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        shopSnapshot: BillShopSnapshot.fromProfile(
          profile,
          gstNumber: gst.isConfigured ? gst.gstNumber : null,
        ),
      );

      final ShopGirvi saved;
      if (_isEdit) {
        await _girvi.updateGirvi(draft);
        saved = draft;
      } else {
        saved = await _girvi.createGirvi(draft);
      }

      await _customers.upsertFromBill(
        name: draft.customer.name,
        phone: draft.customer.phone,
        address: draft.customer.address,
        bumpBillCount: false,
      );

      try {
        if (saved.disbursementMode == 'cash') {
          await _cash.recordGirviCashOut(
            girviNo: saved.girviNo,
            amount: saved.loanAmount,
          );
        } else {
          await _cash.clearGirviCashOut(saved.girviNo);
        }
      } catch (e) {
        debugPrint('Cash out girvi: $e');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GirviSavedPage(girvi: saved, wasEdit: _isEdit),
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

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    final suggestedLoan = (_appraisal * 0.75).round();
    if (!_loanTouched &&
        _appraisal > 0 &&
        (_loanCtrl.text.isEmpty ||
            _loanCtrl.text == '0' ||
            int.tryParse(_loanCtrl.text) == suggestedLoan)) {
      // keep suggested in sync when appraisal changes and user hasn't typed
    }

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
                      _isEdit ? 'Edit girvi' : 'New girvi',
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
                    title: 'Customer',
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
                    title: 'Pledged items (${_items.length})',
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
                                _ItemRow(
                                  item: _items[i],
                                  currency: _currency,
                                  onDelete: () => setState(() {
                                    _items.removeAt(i);
                                    if (!_loanTouched && _appraisal > 0) {
                                      _loanCtrl.text =
                                          (_appraisal * 0.75).round().toString();
                                    }
                                  }),
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    title: 'Loan',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appraisal ${_currency.format(_appraisal.round())}',
                          style: RatnexTheme.label(
                            size: 12,
                            weight: FontWeight.w700,
                            color: RatnexColors.ink,
                          ),
                        ),
                        if (_appraisal > 0 && !_loanTouched)
                          Text(
                            'Suggested loan ~75%: ${_currency.format(suggestedLoan)}',
                            style: RatnexTheme.label(size: 11),
                          ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _loanCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          decoration: _dec('Amount given *'),
                          style: _fs(),
                          onChanged: (_) =>
                              setState(() => _loanTouched = true),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Paid via',
                          style: RatnexTheme.label(
                            size: 12,
                            weight: FontWeight.w600,
                            color: RatnexColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final m in _disburseModes)
                              ChoiceChip(
                                label: Text(m.$2),
                                selected: _disbursementMode == m.$1,
                                onSelected: (_) =>
                                    setState(() => _disbursementMode = m.$1),
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
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _rateCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: _dec('Interest % / mo'),
                                style: _fs(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _tenureCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _dec('Tenure months'),
                                style: _fs(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startedAt,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _startedAt = picked);
                            }
                          },
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: RatnexColors.muted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Start ${DateFormat('d MMM yyyy').format(_startedAt)}'
                                ' · Due ${DateFormat('d MMM yyyy').format(_dueDate)}',
                                style: RatnexTheme.label(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: RatnexColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                            maxLines: 2,
                            decoration: _dec('Optional notes'),
                            style: _fs(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _card(
                    title: 'Summary',
                    child: Column(
                      children: [
                        _totalRow('Appraisal', totals.appraisalValue),
                        _totalRow('Loan given', totals.loanAmount),
                        _totalRow('Interest till due', totals.interestTillDue),
                        const Divider(color: RatnexColors.hairline),
                        _totalRow('Amount due', totals.amountDue, bold: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_items.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: RatnexColors.panel,
                  border: Border(
                    top: BorderSide(color: RatnexColors.hairline),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Loan ${_currency.format(totals.loanAmount.round())}',
                        style: RatnexTheme.label(size: 11),
                      ),
                    ),
                    Text(
                      'Due ${_currency.format(totals.amountDue.round())}',
                      style: RatnexTheme.money(
                        size: 16,
                        color: RatnexColors.gold,
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

  Widget _suggestBox(List<ShopCustomer> list) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: RatnexColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RatnexColors.hairline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: RatnexColors.hairline),
            ListTile(
              dense: true,
              title: Text(
                list[i].name,
                style: RatnexTheme.label(
                  size: 13,
                  weight: FontWeight.w700,
                  color: RatnexColors.ink,
                ),
              ),
              subtitle: Text(list[i].phone, style: RatnexTheme.label(size: 11)),
              onTap: () => _applyCustomer(list[i]),
            ),
          ],
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
              size: 18,
              color: RatnexColors.gold,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: RatnexTheme.label(
                size: 13,
                weight: FontWeight.w700,
                color: RatnexColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            title.toUpperCase(),
            style: RatnexTheme.label(
              size: 11,
              weight: FontWeight.w700,
              color: RatnexColors.muted,
            ).copyWith(letterSpacing: 0.4),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  TextStyle _fs() => RatnexTheme.label(
        size: 14,
        weight: FontWeight.w600,
        color: RatnexColors.ink,
      );

  Widget _totalRow(String label, double value, {bool bold = false}) {
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
            _currency.format(value.round()),
            style: bold
                ? RatnexTheme.money(size: 16, color: RatnexColors.ink)
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

class _ItemRow extends StatelessWidget {
  final GirviItem item;
  final NumberFormat currency;
  final VoidCallback onDelete;

  const _ItemRow({
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

class _AddGirviItemSheet extends StatefulWidget {
  final List<ShopMetalRate> metals;
  final NumberFormat currency;

  const _AddGirviItemSheet({
    required this.metals,
    required this.currency,
  });

  @override
  State<_AddGirviItemSheet> createState() => _AddGirviItemSheetState();
}

class _AddGirviItemSheetState extends State<_AddGirviItemSheet> {
  final _name = TextEditingController();
  final _gross = TextEditingController();
  final _net = TextEditingController();
  final _rate = TextEditingController();
  ShopMetalRate? _metal;
  String? _imageBase64;
  String? _imageMime;

  @override
  void initState() {
    super.initState();
    if (widget.metals.isNotEmpty) {
      _metal = widget.metals.first;
      _rate.text = _metal!.shopRatePerGram.round().toString();
    }
    void refresh() => setState(() {});
    _net.addListener(refresh);
    _rate.addListener(refresh);
  }

  @override
  void dispose() {
    _name.dispose();
    _gross.dispose();
    _net.dispose();
    _rate.dispose();
    super.dispose();
  }

  double get _appraisal {
    final net = double.tryParse(_net.text.trim()) ?? 0;
    final rate = double.tryParse(_rate.text.trim()) ?? 0;
    return appraisalFor(netWeight: net, ratePerGram: rate);
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
    Navigator.pop(
      context,
      GirviItem.compute(
        name: name,
        metalLabel: _metal?.label,
        karat: _metal?.karat,
        grossWeight: double.tryParse(_gross.text.trim()) ?? net,
        netWeight: net,
        ratePerGram: rate,
        imageBase64: _imageBase64,
        imageMime: _imageMime,
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
        height: MediaQuery.sizeOf(context).height * 0.88,
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
                      'Pledge item',
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
                                      'Add photo',
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
                          controller: _net,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _dec('Net g *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _dec('Rate ₹/g *'),
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
                      child: const Text('Add to girvi'),
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
