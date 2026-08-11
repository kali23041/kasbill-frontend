import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/shop_bills_service.dart';
import '../services/shop_customers_service.dart';
import '../services/shop_gst_service.dart';
import '../services/shop_profile_service.dart';
import '../services/shop_stock_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';
import 'bill_saved_page.dart';

class CreateBillPage extends StatefulWidget {
  final ShopBill? existing;

  const CreateBillPage({super.key, this.existing});

  @override
  State<CreateBillPage> createState() => _CreateBillPageState();
}

class _CreateBillPageState extends State<CreateBillPage> {
  final _bills = ShopBillsService();
  final _stock = ShopStockService();
  final _profile = ShopProfileService();
  final _gst = ShopGstService();
  final _customers = ShopCustomersService();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerAddress = TextEditingController();
  final _customerGstin = TextEditingController();
  final _paidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  final List<BillLineItem> _items = [];
  final Set<int> _expandedItems = {};
  String? _paymentMode;
  bool _saving = false;
  bool _showCustomerMore = false;
  bool _showNotes = false;
  /// Which customer field is driving suggestions: `name` | `phone` | null
  String? _suggestField;
  List<ShopCustomer> _allCustomers = const [];
  bool _fillingCustomer = false;
  StreamSubscription<List<ShopCustomer>>? _customersSub;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _customerName.text = e.customer.name;
      _customerPhone.text = e.customer.phone ?? '';
      _customerAddress.text = e.customer.address ?? '';
      _customerGstin.text = e.customer.gstin ?? '';
      _items.addAll(e.items);
      _paymentMode = e.paymentMode;
      _paidCtrl.text = e.totals.paidAmount.round().toString();
      _notesCtrl.text = e.notes ?? '';
      _showCustomerMore =
          (e.customer.address?.isNotEmpty ?? false) ||
          (e.customer.gstin?.isNotEmpty ?? false);
      _showNotes = e.notes?.isNotEmpty ?? false;
    }
    _paidCtrl.addListener(() => setState(() {}));
    void onCustomerType() {
      if (_fillingCustomer) return;
      setState(() {});
    }

    _customerName.addListener(onCustomerType);
    _customerPhone.addListener(onCustomerType);
    _customersSub = _customers.watchCustomers().listen((list) {
      if (!mounted) return;
      setState(() => _allCustomers = list);
    });
  }

  @override
  void dispose() {
    _customersSub?.cancel();
    _customerName.dispose();
    _customerPhone.dispose();
    _customerAddress.dispose();
    _customerGstin.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  BillTotals get _totals {
    final paid = double.tryParse(_paidCtrl.text.trim()) ?? 0;
    return BillTotals.fromItems(items: _items, paidAmount: paid);
  }

  String get _status => ShopBill.statusFromPaid(
        grandTotal: _totals.grandTotal,
        paidAmount: _totals.paidAmount,
      );

  Future<void> _openAddItem({int? editIndex}) async {
    final gst = await _gst.getSettings();
    if (!mounted) return;
    final existing = editIndex != null ? _items[editIndex] : null;
    final item = await showModalBottomSheet<BillLineItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RatnexColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _AddBillItemSheet(
        stockStream: _stock.watchStock(),
        gstConfigured: gst.isConfigured,
        defaultGstPercent: gst.gstPercent,
        currency: _currency,
        existing: existing,
      ),
    );
    if (item == null) return;
    setState(() {
      if (editIndex != null) {
        _items[editIndex] = item;
        _expandedItems.add(editIndex);
      } else {
        _items.add(item);
        _expandedItems.add(_items.length - 1);
      }
    });
  }

  Future<void> _save() async {
    if (_customerName.text.trim().isEmpty) {
      _toast('Enter customer name');
      return;
    }
    if (_items.isEmpty) {
      _toast('Add at least one item');
      return;
    }

    setState(() => _saving = true);
    try {
      final profile = await _profile.watchProfile().first;
      final gst = await _gst.getSettings();
      final totals = _totals;
      final status = _status;
      final paid = totals.paidAmount;
      final payments = <BillPayment>[];
      if (paid > 0 && _paymentMode != null) {
        payments.add(BillPayment(
          amount: paid,
          mode: _paymentMode!,
          paidAt: DateTime.now(),
        ));
      }

      final draft = ShopBill(
        billNo: widget.existing?.billNo ?? '',
        customer: BillCustomer(
          name: _customerName.text.trim(),
          phone: _customerPhone.text.trim().isEmpty
              ? null
              : _customerPhone.text.trim(),
          address: _customerAddress.text.trim().isEmpty
              ? null
              : _customerAddress.text.trim(),
          gstin: _customerGstin.text.trim().isEmpty
              ? null
              : _customerGstin.text.trim(),
        ),
        items: List.of(_items),
        totals: totals,
        paymentStatus: status,
        paymentMode: _paymentMode,
        payments: payments.isNotEmpty
            ? payments
            : (widget.existing?.payments ?? const []),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        shopSnapshot: BillShopSnapshot.fromProfile(
          profile,
          gstNumber: gst.isConfigured ? gst.gstNumber : null,
        ),
        billedAt: widget.existing?.billedAt ?? DateTime.now(),
      );

      final ShopBill saved;
      if (_isEdit) {
        await _bills.updateBill(draft);
        saved = draft;
      } else {
        saved = await _bills.createBill(draft);
      }

      await _customers.upsertFromBill(
        name: draft.customer.name,
        phone: draft.customer.phone,
        address: draft.customer.address,
        gstin: draft.customer.gstin,
        bumpBillCount: !_isEdit,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BillSavedPage(
            bill: saved,
            wasEdit: _isEdit,
          ),
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

  void _applyCustomer(ShopCustomer c) {
    _fillingCustomer = true;
    _customerName.text = c.name;
    _customerPhone.text = c.phone;
    _customerAddress.text = c.address ?? '';
    _customerGstin.text = c.gstin ?? '';
    setState(() {
      _suggestField = null;
      _showCustomerMore =
          (c.address?.isNotEmpty ?? false) || (c.gstin?.isNotEmpty ?? false);
    });
    _fillingCustomer = false;
    FocusScope.of(context).unfocus();
  }

  List<ShopCustomer> get _customerSuggestions {
    if (_suggestField == null) return const [];
    final query = _suggestField == 'phone'
        ? _customerPhone.text
        : _customerName.text;
    return ShopCustomersService.filterSuggestions(_allCustomers, query);
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
    final status = _status;

    return Scaffold(
      backgroundColor: RatnexColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddItem(),
        backgroundColor: RatnexColors.ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
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
                      _isEdit ? 'Edit bill' : 'New bill',
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
                  _Card(
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
                        if (_suggestField == 'name' &&
                            _customerSuggestions.isNotEmpty)
                          _CustomerSuggestions(
                            suggestions: _customerSuggestions,
                            onPick: _applyCustomer,
                          ),
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
                            _customerSuggestions.isNotEmpty)
                          _CustomerSuggestions(
                            suggestions: _customerSuggestions,
                            onPick: _applyCustomer,
                          ),
                        const SizedBox(height: 8),
                        _ExpandToggle(
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
                            onTap: () => setState(() => _suggestField = null),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _customerGstin,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _dec('Customer GSTIN'),
                            style: _fs(),
                            onTap: () => setState(() => _suggestField = null),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: 'Items (${_items.length})',
                    child: _items.isEmpty
                        ? Text(
                            'Tap + Add item to pick stock or create a custom line.',
                            style: RatnexTheme.label(size: 13),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < _items.length; i++) ...[
                                if (i > 0)
                                  const Divider(color: RatnexColors.hairline),
                                _BillItemRow(
                                  item: _items[i],
                                  currency: _currency,
                                  expanded: _expandedItems.contains(i),
                                  onToggle: () {
                                    setState(() {
                                      if (_expandedItems.contains(i)) {
                                        _expandedItems.remove(i);
                                      } else {
                                        _expandedItems.add(i);
                                      }
                                    });
                                  },
                                  onEdit: () => _openAddItem(editIndex: i),
                                  onDelete: () {
                                    setState(() {
                                      _items.removeAt(i);
                                      _expandedItems.remove(i);
                                      final next = <int>{};
                                      for (final e in _expandedItems) {
                                        if (e > i) {
                                          next.add(e - 1);
                                        } else if (e < i) {
                                          next.add(e);
                                        }
                                      }
                                      _expandedItems
                                        ..clear()
                                        ..addAll(next);
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: 'Payment',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment mode', style: RatnexTheme.label(size: 12)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final m in const [
                              ('cash', 'Cash'),
                              ('online', 'Online'),
                              ('upi', 'UPI'),
                              ('card', 'Card'),
                              ('mixed', 'Mixed'),
                            ])
                              ChoiceChip(
                                label: Text(m.$2),
                                selected: _paymentMode == m.$1,
                                onSelected: (_) =>
                                    setState(() => _paymentMode = m.$1),
                                selectedColor: RatnexColors.ink,
                                labelStyle: RatnexTheme.label(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: _paymentMode == m.$1
                                      ? Colors.white
                                      : RatnexColors.ink,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Amount paid', style: RatnexTheme.label(size: 12)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _paidCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          decoration: _dec('0'),
                          style: _fs(),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                          style: RatnexTheme.label(
                            size: 13,
                            weight: FontWeight.w700,
                            color: status == 'paid'
                                ? RatnexColors.up
                                : status == 'partial'
                                    ? RatnexColors.gold
                                    : RatnexColors.down,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ExpandToggle(
                          expanded: _showNotes,
                          label: 'Notes',
                          onTap: () => setState(() => _showNotes = !_showNotes),
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
                  _Card(
                    title: 'Totals',
                    child: Column(
                      children: [
                        _totalRow('Taxable', totals.taxable),
                        _totalRow('GST', totals.gst),
                        const Divider(color: RatnexColors.hairline),
                        _totalRow('Grand total', totals.grandTotal, bold: true),
                        _totalRow('Paid', totals.paidAmount),
                        _totalRow('Balance', totals.balance, bold: true),
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
                        'Taxable ${_currency.format(totals.taxable.round())}'
                        '${totals.gst > 0 ? ' · GST ${_currency.format(totals.gst.round())}' : ''}',
                        style: RatnexTheme.label(size: 11),
                      ),
                    ),
                    Text(
                      _currency.format(totals.grandTotal.round()),
                      style: RatnexTheme.money(
                        size: 18,
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

class _ExpandToggle extends StatelessWidget {
  final bool expanded;
  final String label;
  final VoidCallback onTap;

  const _ExpandToggle({
    required this.expanded,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
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
}

class _CustomerSuggestions extends StatelessWidget {
  final List<ShopCustomer> suggestions;
  final ValueChanged<ShopCustomer> onPick;

  const _CustomerSuggestions({
    required this.suggestions,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
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
          for (var i = 0; i < suggestions.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: RatnexColors.hairline),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                suggestions[i].name,
                style: RatnexTheme.label(
                  size: 13,
                  weight: FontWeight.w700,
                  color: RatnexColors.ink,
                ),
              ),
              subtitle: Text(
                suggestions[i].phone +
                    (suggestions[i].address?.isNotEmpty == true
                        ? ' · ${suggestions[i].address}'
                        : ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RatnexTheme.label(size: 11),
              ),
              trailing: const Icon(
                Icons.person_outline,
                size: 18,
                color: RatnexColors.muted,
              ),
              onTap: () => onPick(suggestions[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _BillItemRow extends StatelessWidget {
  final BillLineItem item;
  final NumberFormat currency;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BillItemRow({
    required this.item,
    required this.currency,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final qtySuffix = item.qty > 1 ? ' · ×${item.qty}' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: RatnexColors.muted,
                ),
                const SizedBox(width: 4),
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
                        '${item.netWeight}g$qtySuffix',
                        style: RatnexTheme.label(size: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  currency.format(item.lineTotal.round()),
                  style: RatnexTheme.money(size: 15, color: RatnexColors.gold),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: RatnexColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rate ${currency.format(item.ratePerGram.round())}/g'
                  ' · Gross ${item.grossWeight}g',
                  style: RatnexTheme.label(size: 11),
                ),
                if (item.makingCharge > 0)
                  Text(
                    'Making ${currency.format(item.makingCharge.round())}'
                    ' (${item.makingType})',
                    style: RatnexTheme.label(size: 11),
                  ),
                if (item.wastagePercent > 0)
                  Text(
                    'Wastage ${item.wastagePercent}%',
                    style: RatnexTheme.label(size: 11),
                  ),
                if (item.stoneCharge > 0 || item.otherCharge > 0)
                  Text(
                    [
                      if (item.stoneCharge > 0)
                        'Stone ${currency.format(item.stoneCharge.round())}',
                      if (item.otherCharge > 0)
                        'Other ${currency.format(item.otherCharge.round())}',
                    ].join(' · '),
                    style: RatnexTheme.label(size: 11),
                  ),
                Text(
                  'Taxable ${currency.format(item.taxableAmount.round())}'
                  '${item.applyGst ? ' · GST ${currency.format(item.gstAmount.round())}' : ''}',
                  style: RatnexTheme.label(size: 11),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit item'),
                  style: TextButton.styleFrom(
                    foregroundColor: RatnexColors.ink,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
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
}

class _AddBillItemSheet extends StatefulWidget {
  final Stream<List<StockItem>> stockStream;
  final bool gstConfigured;
  final double defaultGstPercent;
  final NumberFormat currency;
  final BillLineItem? existing;

  const _AddBillItemSheet({
    required this.stockStream,
    required this.gstConfigured,
    required this.defaultGstPercent,
    required this.currency,
    this.existing,
  });

  @override
  State<_AddBillItemSheet> createState() => _AddBillItemSheetState();
}

class _AddBillItemSheetState extends State<_AddBillItemSheet> {
  late int _tab; // 0 stock, 1 custom
  StockItem? _stock;
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _gross = TextEditingController();
  final _net = TextEditingController();
  final _rate = TextEditingController();
  final _making = TextEditingController(text: '0');
  final _wastage = TextEditingController(text: '0');
  final _stone = TextEditingController(text: '0');
  final _other = TextEditingController(text: '0');
  final _qty = TextEditingController(text: '1');
  String _makingType = 'flat';
  bool _applyGst = false;
  bool _showCharges = false;
  String? _category;
  String? _metalLabel;
  int? _karat;
  String? _stockId;
  String? _barcode;

  bool get _isEdit => widget.existing != null;
  bool get _showForm => _tab == 1 || _stock != null || _isEdit;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _tab = e.stockId != null ? 0 : 1;
      _stockId = e.stockId;
      _name.text = e.name;
      _gross.text = e.grossWeight.toString();
      _net.text = e.netWeight.toString();
      _rate.text = e.ratePerGram.round().toString();
      _making.text = e.makingCharge.toString();
      _wastage.text = e.wastagePercent.toString();
      _stone.text = e.stoneCharge.toString();
      _other.text = e.otherCharge.toString();
      _qty.text = e.qty.toString();
      _makingType = e.makingType;
      _applyGst = e.applyGst && widget.gstConfigured;
      _category = e.category;
      _metalLabel = e.metalLabel;
      _karat = e.karat;
      _barcode = e.barcode;
      _showCharges = e.makingCharge > 0 ||
          e.wastagePercent > 0 ||
          e.stoneCharge > 0 ||
          e.otherCharge > 0 ||
          e.applyGst ||
          e.grossWeight != e.netWeight;
    } else {
      _tab = 0;
      _barcode = generateStockBarcode();
    }
    void refresh() => setState(() {});
    _net.addListener(refresh);
    _rate.addListener(refresh);
    _qty.addListener(refresh);
    _making.addListener(refresh);
    _wastage.addListener(refresh);
    _stone.addListener(refresh);
    _other.addListener(refresh);
    _gross.addListener(refresh);
    _search.addListener(refresh);
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _gross.dispose();
    _net.dispose();
    _rate.dispose();
    _making.dispose();
    _wastage.dispose();
    _stone.dispose();
    _other.dispose();
    _qty.dispose();
    super.dispose();
  }

  BillLineItem? get _preview {
    final name = _name.text.trim();
    final net = double.tryParse(_net.text.trim());
    final rate = double.tryParse(_rate.text.trim());
    final qty = int.tryParse(_qty.text.trim()) ?? 1;
    if (name.isEmpty || net == null || net <= 0 || rate == null || rate <= 0) {
      return null;
    }
    return BillLineItem.compute(
      stockId: _stock?.id ?? _stockId,
      name: name,
      category: _stock?.categoryName ?? _category,
      metalLabel: _stock?.metalLabel ?? _metalLabel,
      karat: _stock?.karat ?? _karat,
      barcode: (_stock?.barcode?.isNotEmpty == true)
          ? _stock!.barcode
          : (_barcode?.isNotEmpty == true ? _barcode : generateStockBarcode()),
      grossWeight: double.tryParse(_gross.text.trim()) ?? net,
      netWeight: net,
      ratePerGram: rate,
      makingCharge: double.tryParse(_making.text.trim()) ?? 0,
      makingType: _makingType,
      wastagePercent: double.tryParse(_wastage.text.trim()) ?? 0,
      stoneCharge: double.tryParse(_stone.text.trim()) ?? 0,
      otherCharge: double.tryParse(_other.text.trim()) ?? 0,
      qty: qty,
      applyGst: _applyGst && widget.gstConfigured,
      gstPercent: widget.defaultGstPercent,
    );
  }

  void _fillFromStock(StockItem s) {
    setState(() {
      _stock = s;
      _stockId = s.id;
      _category = s.categoryName;
      _metalLabel = s.metalLabel;
      _karat = s.karat;
      _barcode = (s.barcode != null && s.barcode!.isNotEmpty)
          ? s.barcode
          : generateStockBarcode();
      _name.text = s.name;
      _gross.text = s.grossWeight.toString();
      _net.text = s.netWeight.toString();
      _rate.text = s.shopRatePerGram.round().toString();
      _making.text = s.makingCharge.toString();
      _wastage.text = s.wastagePercent.toString();
      _stone.text = s.stoneCharge.toString();
      _other.text = s.otherCharge.toString();
      _makingType = s.makingChargeType;
      _applyGst = s.applyGst && widget.gstConfigured;
      _qty.text = '1';
      _showCharges = s.makingCharge > 0 ||
          s.wastagePercent > 0 ||
          s.stoneCharge > 0 ||
          s.otherCharge > 0 ||
          s.applyGst ||
          s.grossWeight != s.netWeight;
    });
  }

  void _submit() {
    final item = _preview;
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter name, net weight and rate')),
      );
      return;
    }
    Navigator.pop(context, item);
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
    final maxH = MediaQuery.sizeOf(context).height * 0.9;
    final preview = _preview;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: maxH,
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
                      _isEdit ? 'Edit bill item' : 'Add bill item',
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
            if (!_isEdit)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('From stock'),
                        selected: _tab == 0,
                        onSelected: (_) => setState(() => _tab = 0),
                        selectedColor: RatnexColors.ink,
                        labelStyle: RatnexTheme.label(
                          size: 12,
                          weight: FontWeight.w700,
                          color: _tab == 0 ? Colors.white : RatnexColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Custom'),
                        selected: _tab == 1,
                        onSelected: (_) => setState(() {
                          _tab = 1;
                          _stock = null;
                          _stockId = null;
                          _barcode = generateStockBarcode();
                        }),
                        selectedColor: RatnexColors.ink,
                        labelStyle: RatnexTheme.label(
                          size: 12,
                          weight: FontWeight.w700,
                          color: _tab == 1 ? Colors.white : RatnexColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  if (_tab == 0 && !_isEdit)
                    StreamBuilder<List<StockItem>>(
                      stream: widget.stockStream,
                      builder: (context, snap) {
                        final stock = snap.data ?? const <StockItem>[];
                        if (stock.isEmpty) {
                          return Text(
                            'No stock items. Switch to Custom or add stock first.',
                            style: RatnexTheme.label(size: 13),
                          );
                        }
                        final q = _search.text.trim().toLowerCase();
                        final filtered = q.isEmpty
                            ? stock
                            : stock
                                .where(
                                  (s) =>
                                      s.name.toLowerCase().contains(q) ||
                                      s.categoryName.toLowerCase().contains(q) ||
                                      s.metalLabel.toLowerCase().contains(q),
                                )
                                .toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _search,
                              decoration: _dec('Search stock…'),
                              style: RatnexTheme.label(
                                size: 14,
                                weight: FontWeight.w600,
                                color: RatnexColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_stock != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Selected: ${_stock!.name}',
                                  style: RatnexTheme.label(
                                    size: 12,
                                    weight: FontWeight.w700,
                                    color: RatnexColors.gold,
                                  ),
                                ),
                              ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 280),
                              child: GridView.builder(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.78,
                                ),
                                itemBuilder: (context, i) {
                                  final s = filtered[i];
                                  return _StockPickTile(
                                    item: s,
                                    currency: widget.currency,
                                    selected: _stock?.id == s.id,
                                    onTap: () => _fillFromStock(s),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  if (_showForm) ...[
                    if (_tab == 0 && !_isEdit) const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      decoration: _dec('Item name *'),
                      style: RatnexTheme.label(
                        size: 14,
                        weight: FontWeight.w600,
                        color: RatnexColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _net,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _dec('Net g *'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _rate,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _dec('Rate ₹/g *'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: _qty,
                            keyboardType: TextInputType.number,
                            decoration: _dec('Qty'),
                          ),
                        ),
                      ],
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: RatnexColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: RatnexColors.hairline),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Line total',
                              style: RatnexTheme.label(size: 12),
                            ),
                            const Spacer(),
                            Text(
                              widget.currency.format(preview.lineTotal.round()),
                              style: RatnexTheme.money(
                                size: 18,
                                color: RatnexColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _ExpandToggle(
                      expanded: _showCharges,
                      label: 'Charges & GST',
                      onTap: () =>
                          setState(() => _showCharges = !_showCharges),
                    ),
                    if (_showCharges) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _gross,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _dec('Gross g'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _making,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _dec('Making'),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final t in const [
                            ('flat', 'Flat'),
                            ('per_gram', '₹/g'),
                            ('percent', '%'),
                          ])
                            ChoiceChip(
                              label: Text(t.$2),
                              selected: _makingType == t.$1,
                              onSelected: (_) =>
                                  setState(() => _makingType = t.$1),
                              selectedColor: RatnexColors.ink,
                              labelStyle: RatnexTheme.label(
                                size: 11,
                                weight: FontWeight.w600,
                                color: _makingType == t.$1
                                    ? Colors.white
                                    : RatnexColors.ink,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _wastage,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: _dec('Wastage %'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _stone,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: _dec('Stone ₹'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _other,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _dec('Other ₹'),
                      ),
                      if (widget.gstConfigured)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Apply GST (${widget.defaultGstPercent}%)',
                            style: RatnexTheme.label(
                              size: 13,
                              weight: FontWeight.w700,
                              color: RatnexColors.ink,
                            ),
                          ),
                          value: _applyGst,
                          activeThumbColor: RatnexColors.gold,
                          onChanged: (v) => setState(() => _applyGst = v),
                        ),
                    ],
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
                        child: Text(_isEdit ? 'Update item' : 'Add to bill'),
                      ),
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
}

class _StockPickTile extends StatelessWidget {
  final StockItem item;
  final NumberFormat currency;
  final bool selected;
  final VoidCallback onTap;

  const _StockPickTile({
    required this.item,
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = StockImageHelper.decodeBase64(item.imageBase64);

    return Material(
      color: RatnexColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? RatnexColors.gold : RatnexColors.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(11),
                      ),
                      child: thumb != null
                          ? Image.memory(thumb, fit: BoxFit.cover)
                          : Container(
                              color: RatnexColors.goldSoft,
                              child: const Icon(
                                Icons.diamond_outlined,
                                color: RatnexColors.gold,
                                size: 32,
                              ),
                            ),
                    ),
                    if (selected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: RatnexColors.gold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RatnexTheme.label(
                        size: 12,
                        weight: FontWeight.w700,
                        color: RatnexColors.ink,
                      ),
                    ),
                    Text(
                      '${item.netWeight}g · ${currency.format(item.shopRatePerGram.round())}/g',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RatnexTheme.label(size: 10),
                    ),
                    Text(
                      currency.format(item.displayPrice.round()),
                      style: RatnexTheme.money(
                        size: 12,
                        color: RatnexColors.gold,
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
