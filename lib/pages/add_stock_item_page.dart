import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/shop_categories_service.dart';
import '../services/shop_gst_service.dart';
import '../services/shop_rates_service.dart';
import '../services/shop_settings_service.dart';
import '../services/shop_stock_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/barcode_scan_sheet.dart';
import '../widgets/ratnex_ui.dart';

class AddStockItemPage extends StatefulWidget {
  final StockItem? existing;

  const AddStockItemPage({super.key, this.existing});

  @override
  State<AddStockItemPage> createState() => _AddStockItemPageState();
}

class _AddStockItemPageState extends State<AddStockItemPage> {
  final _stockService = ShopStockService();
  final _categoriesService = ShopCategoriesService();
  final _metalsService = ShopRatesService();
  final _gstService = ShopGstService();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _huidCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _sizeCtrl = TextEditingController();
  final _grossCtrl = TextEditingController();
  final _netCtrl = TextEditingController();
  final _stoneWtCtrl = TextEditingController(text: '0');
  final _wastageCtrl = TextEditingController(text: '0');
  final _makingCtrl = TextEditingController(text: '0');
  final _stoneChargeCtrl = TextEditingController(text: '0');
  final _otherCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  final _shopRateCtrl = TextEditingController();

  ShopCategory? _category;
  ShopMetalRate? _metal;
  double? _liveRate;
  bool _editingRate = false;
  bool _applyGst = false;
  double _gstPercent = 3;
  String _makingType = 'flat';
  String _status = 'in_stock';
  String? _imageBase64;
  String? _imageMime;
  bool _saving = false;
  bool _pickingImage = false;

  bool get _isEdit => widget.existing != null;

  void _onCalcInputsChanged() {
    if (mounted) setState(() {});
  }

  void _applyMetalRates(ShopMetalRate metal, {bool force = false}) {
    setState(() {
      _metal = metal;
      _liveRate = metal.liveRatePerGram;
      if (force || !_editingRate || _shopRateCtrl.text.isEmpty) {
        _shopRateCtrl.text = metal.shopRatePerGram.round().toString();
        _editingRate = false;
      }
    });
  }

  StockPriceBreakdown get _priceBreakdown {
    return calculateStockPrice(
      netWeight: _parse(_netCtrl) ?? 0,
      shopRatePerGram: _parse(_shopRateCtrl) ??
          _metal?.shopRatePerGram ??
          widget.existing?.shopRatePerGram ??
          0,
      wastagePercent: _parse(_wastageCtrl) ?? 0,
      makingChargeType: _makingType,
      makingCharge: _parse(_makingCtrl) ?? 0,
      stoneCharge: _parse(_stoneChargeCtrl) ?? 0,
      otherCharge: _parse(_otherCtrl) ?? 0,
    );
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _skuCtrl.text = e.sku ?? '';
      _huidCtrl.text = e.huid ?? '';
      _barcodeCtrl.text = (e.barcode != null && e.barcode!.isNotEmpty)
          ? e.barcode!
          : generateStockBarcode();
      _qtyCtrl.text = e.quantity.toString();
      _sizeCtrl.text = e.size ?? '';
      _grossCtrl.text = _numStr(e.grossWeight);
      _netCtrl.text = _numStr(e.netWeight);
      _stoneWtCtrl.text = _numStr(e.stoneWeight);
      _wastageCtrl.text = _numStr(e.wastagePercent);
      _makingCtrl.text = _numStr(e.makingCharge);
      _stoneChargeCtrl.text = _numStr(e.stoneCharge);
      _otherCtrl.text = _numStr(e.otherCharge);
      _notesCtrl.text = e.notes ?? '';
      _shopRateCtrl.text = e.shopRatePerGram.round().toString();
      _liveRate = e.liveRatePerGram;
      _makingType = e.makingChargeType;
      _status = e.status;
      _applyGst = e.applyGst;
      _gstPercent = e.gstPercent ?? 3;
      _imageBase64 = e.imageBase64;
      _imageMime = e.imageMime;
    } else {
      _barcodeCtrl.text = generateStockBarcode();
    }

    for (final c in [
      _netCtrl,
      _shopRateCtrl,
      _wastageCtrl,
      _makingCtrl,
      _stoneChargeCtrl,
      _otherCtrl,
    ]) {
      c.addListener(_onCalcInputsChanged);
    }
  }

  String _numStr(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toString();
  }

  @override
  void dispose() {
    for (final c in [
      _netCtrl,
      _shopRateCtrl,
      _wastageCtrl,
      _makingCtrl,
      _stoneChargeCtrl,
      _otherCtrl,
    ]) {
      c.removeListener(_onCalcInputsChanged);
    }
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _huidCtrl.dispose();
    _barcodeCtrl.dispose();
    _qtyCtrl.dispose();
    _sizeCtrl.dispose();
    _grossCtrl.dispose();
    _netCtrl.dispose();
    _stoneWtCtrl.dispose();
    _wastageCtrl.dispose();
    _makingCtrl.dispose();
    _stoneChargeCtrl.dispose();
    _otherCtrl.dispose();
    _notesCtrl.dispose();
    _shopRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _pickingImage = true);
    try {
      final result = await StockImageHelper.pickCompressed(source: source);
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _imageBase64 = result.base64;
          _imageMime = result.mime;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  void _showImageSource() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RatnexColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_imageBase64 != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: RatnexColors.down),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _imageBase64 = null;
                    _imageMime = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  /// Returns the name of another stock item already carrying [huid].
  Future<String?> _findDuplicateHuid(String huid) async {
    try {
      final items = await ShopStockService().watchStock().first;
      for (final item in items) {
        if (item.id == widget.existing?.id) continue;
        if ((item.huid ?? '').trim().toUpperCase() == huid) return item.name;
      }
    } catch (_) {
      // A failed lookup should never block saving stock.
    }
    return null;
  }

  Future<void> _scanBarcodeIntoField() async {
    final code = await showBarcodeScanner(
      context,
      title: 'Scan barcode',
      hint: 'Scan the printed tag to attach its code to this item',
    );
    if (code == null || !mounted) return;
    setState(() => _barcodeCtrl.text = code);
    RatnexSnack.success(context, 'Barcode attached');
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Enter item name');
      return;
    }
    if (_category == null && widget.existing == null) {
      _toast('Select a category');
      return;
    }
    if (_metal == null && widget.existing == null) {
      _toast('Select a metal');
      return;
    }

    final qty = int.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty < 0) {
      _toast('Enter a valid quantity');
      return;
    }

    final gross = _parse(_grossCtrl);
    final net = _parse(_netCtrl);
    if (gross == null || gross <= 0 || net == null || net <= 0) {
      _toast('Enter gross and net weight (g)');
      return;
    }
    if (net > gross) {
      _toast('Net weight cannot exceed gross weight');
      return;
    }

    // Hallmarking is mandatory, so a malformed or reused HUID is worth
    // catching at the counter rather than during an inspection.
    final huid = _huidCtrl.text.trim().toUpperCase();
    if (huid.isNotEmpty) {
      final settings = await ShopSettingsService().getSettings();
      if (settings.validateHuid && !RatnexValidate.isHuid(huid)) {
        _toast('HUID must be exactly 6 letters or digits');
        return;
      }
      final duplicate = await _findDuplicateHuid(huid);
      if (duplicate != null) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text('HUID already used', style: RatnexTheme.brand(size: 19)),
            content: Text(
              'HUID $huid is already on "$duplicate". A hallmark ID belongs to exactly one piece.',
              style: RatnexTheme.label(size: 13, color: RatnexColors.ink),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Fix it',
                  style: RatnexTheme.label(size: 13, weight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Save anyway',
                  style: RatnexTheme.label(
                    size: 13,
                    weight: FontWeight.w700,
                    color: RatnexColors.down,
                  ),
                ),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    final category = _category;
    final metal = _metal;
    final existing = widget.existing;

    final categoryId = category?.id ?? existing!.categoryId;
    final categoryName = category?.name ?? existing!.categoryName;
    final metalId = metal?.id ?? existing!.metalId;
    final metalLabel = metal?.label ?? existing!.metalLabel;
    final metalType = metal?.metalType ?? existing!.metalType;
    final karat = metal?.karat ?? existing?.karat;
    final shopRate = _parse(_shopRateCtrl) ??
        metal?.shopRatePerGram ??
        existing!.shopRatePerGram;
    final liveRate = _liveRate ?? metal?.liveRatePerGram ?? existing?.liveRatePerGram;
    final breakdown = calculateStockPrice(
      netWeight: net,
      shopRatePerGram: shopRate,
      wastagePercent: _parse(_wastageCtrl) ?? 0,
      makingChargeType: _makingType,
      makingCharge: _parse(_makingCtrl) ?? 0,
      stoneCharge: _parse(_stoneChargeCtrl) ?? 0,
      otherCharge: _parse(_otherCtrl) ?? 0,
    );
    final gstAmount =
        _applyGst ? breakdown.total * (_gstPercent / 100) : 0.0;
    final priceWithGst =
        _applyGst ? breakdown.total + gstAmount : breakdown.total;

    var status = _status;
    if (status == 'in_stock' && qty <= ShopStockService.lowStockThreshold) {
      status = 'low';
    }

    final item = StockItem(
      id: existing?.id ?? '',
      name: name,
      sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
      huid: _huidCtrl.text.trim().isEmpty ? null : _huidCtrl.text.trim(),
      barcode: _barcodeCtrl.text.trim().isEmpty
          ? generateStockBarcode()
          : _barcodeCtrl.text.trim(),
      categoryId: categoryId,
      categoryName: categoryName,
      metalId: metalId,
      metalLabel: metalLabel,
      metalType: metalType,
      karat: karat,
      shopRatePerGram: shopRate,
      liveRatePerGram: liveRate,
      grossWeight: gross,
      netWeight: net,
      stoneWeight: _parse(_stoneWtCtrl) ?? 0,
      wastagePercent: _parse(_wastageCtrl) ?? 0,
      makingChargeType: _makingType,
      makingCharge: _parse(_makingCtrl) ?? 0,
      stoneCharge: _parse(_stoneChargeCtrl) ?? 0,
      otherCharge: _parse(_otherCtrl) ?? 0,
      quantity: qty,
      size: _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
      status: status,
      imageBase64: _imageBase64,
      imageMime: _imageMime ?? 'image/jpeg',
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      calculatedPrice: breakdown.total,
      applyGst: _applyGst,
      gstPercent: _applyGst ? _gstPercent : null,
      gstAmount: _applyGst ? gstAmount : null,
      priceWithGst: _applyGst ? priceWithGst : null,
    );

    setState(() => _saving = true);
    try {
      await _stockService.saveItem(item, id: existing?.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Stock item updated' : 'Stock item added'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Save failed: $e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: RatnexColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: RatnexColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: RatnexColors.hairline),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bytes = StockImageHelper.decodeBase64(_imageBase64);

    return Scaffold(
      backgroundColor: RatnexColors.surface,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            right: -40,
            height: 220,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 0.95,
                    colors: [
                      RatnexColors.goldSoft.withValues(alpha: 0.55),
                      RatnexColors.surface.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
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
                          _isEdit ? 'Edit stock item' : 'Add stock item',
                          style: RatnexTheme.brand(size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                    children: [
                      _SectionCard(
                        title: 'Photo',
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickingImage ? null : _showImageSource,
                              child: Container(
                                height: 160,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: RatnexColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: RatnexColors.hairline,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _pickingImage
                                    ? Center(
                                        child: CircularProgressIndicator(
                                          color: RatnexColors.gold,
                                        ),
                                      )
                                    : bytes != null
                                        ? Image.memory(
                                            bytes,
                                            fit: BoxFit.cover,
                                          )
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add_a_photo_outlined,
                                                color: RatnexColors.gold,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Tap to add photo',
                                                style: RatnexTheme.label(
                                                  size: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Basics',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Item name *', style: RatnexTheme.label(size: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _nameCtrl,
                              textCapitalization: TextCapitalization.words,
                              style: _fieldStyle(),
                              decoration: _dec('e.g. 22K Necklace'),
                            ),
                            const SizedBox(height: 12),
                            Text('Category *', style: RatnexTheme.label(size: 12)),
                            const SizedBox(height: 6),
                            StreamBuilder<List<ShopCategory>>(
                              stream: _categoriesService.watchCategories(),
                              builder: (context, snap) {
                                final cats = snap.data ?? const <ShopCategory>[];
                                if (cats.isEmpty && !_isEdit) {
                                  return Text(
                                    'No categories yet. Add some in Profile → Categories.',
                                    style: RatnexTheme.label(size: 12),
                                  );
                                }
                                // Resolve edit selection once categories load.
                                if (_category == null &&
                                    widget.existing != null &&
                                    cats.isNotEmpty) {
                                  final match = cats.where(
                                    (c) => c.id == widget.existing!.categoryId,
                                  );
                                  if (match.isNotEmpty) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted && _category == null) {
                                        setState(
                                          () => _category = match.first,
                                        );
                                      }
                                    });
                                  }
                                }
                                return DropdownButtonFormField<String>(
                                  value: _category?.id ??
                                      (cats.any(
                                              (c) =>
                                                  c.id ==
                                                  widget.existing?.categoryId)
                                          ? widget.existing!.categoryId
                                          : null),
                                  items: cats
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (id) {
                                    final c = cats.firstWhere((e) => e.id == id);
                                    setState(() => _category = c);
                                  },
                                  decoration: _dec('Select category'),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('SKU / Tag',
                                          style: RatnexTheme.label(size: 12)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _skuCtrl,
                                        style: _fieldStyle(),
                                        decoration: _dec('Tag no'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('HUID',
                                          style: RatnexTheme.label(size: 12)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _huidCtrl,
                                        style: _fieldStyle(),
                                        maxLength: 6,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9a-zA-Z]'),
                                          ),
                                        ],
                                        onChanged: (_) => setState(() {}),
                                        decoration: _dec('6 characters')
                                            .copyWith(
                                          counterText: '',
                                          errorText: RatnexValidate.huidError(
                                            _huidCtrl.text,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Quantity *',
                                          style: RatnexTheme.label(size: 12)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _qtyCtrl,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        style: _fieldStyle(),
                                        decoration: _dec('pcs'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Size',
                                          style: RatnexTheme.label(size: 12)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _sizeCtrl,
                                        style: _fieldStyle(),
                                        decoration: _dec('e.g. 18"'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Barcode (auto-generated)',
                              style: RatnexTheme.label(size: 12),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                              decoration: BoxDecoration(
                                color: RatnexColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: RatnexColors.hairline),
                              ),
                              child: Column(
                                children: [
                                  BarcodeWidget(
                                    barcode: Barcode.code128(),
                                    data: _barcodeCtrl.text,
                                    width: double.infinity,
                                    height: 64,
                                    drawText: false,
                                    color: RatnexColors.ink,
                                    backgroundColor: Colors.transparent,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _barcodeCtrl.text,
                                          style: RatnexTheme.label(
                                            size: 13,
                                            weight: FontWeight.w700,
                                            color: RatnexColors.ink,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Scan an existing tag',
                                        onPressed: _scanBarcodeIntoField,
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(
                                          Icons.qr_code_scanner,
                                          size: 19,
                                          color: RatnexColors.gold,
                                        ),
                                      ),
                                      if (!_isEdit)
                                        TextButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _barcodeCtrl.text =
                                                  generateStockBarcode();
                                            });
                                          },
                                          icon: Icon(
                                            Icons.refresh,
                                            size: 16,
                                            color: RatnexColors.gold,
                                          ),
                                          label: Text(
                                            'Regenerate',
                                            style: RatnexTheme.label(
                                              size: 12,
                                              weight: FontWeight.w700,
                                              color: RatnexColors.gold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('Status', style: RatnexTheme.label(size: 12)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final s in const [
                                  ('in_stock', 'In stock'),
                                  ('low', 'Low'),
                                  ('sold', 'Sold'),
                                ])
                                  ChoiceChip(
                                    label: Text(s.$2),
                                    selected: _status == s.$1,
                                    onSelected: (_) =>
                                        setState(() => _status = s.$1),
                                    selectedColor: RatnexColors.ink,
                                    labelStyle: RatnexTheme.label(
                                      size: 12,
                                      weight: FontWeight.w600,
                                      color: _status == s.$1
                                          ? Colors.white
                                          : RatnexColors.ink,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Metal & rates',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Metal *', style: RatnexTheme.label(size: 12)),
                            const SizedBox(height: 6),
                            StreamBuilder<List<ShopMetalRate>>(
                              stream: _metalsService.watchMetals(),
                              builder: (context, snap) {
                                final metals =
                                    snap.data ?? const <ShopMetalRate>[];
                                if (metals.isEmpty && !_isEdit) {
                                  return Text(
                                    'No metals yet. Add rates in Profile → Metals & Diamonds.',
                                    style: RatnexTheme.label(size: 12),
                                  );
                                }
                                if (_metal == null &&
                                    widget.existing != null &&
                                    metals.isNotEmpty) {
                                  final match = metals.where(
                                    (m) => m.id == widget.existing!.metalId,
                                  );
                                  if (match.isNotEmpty) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted && _metal == null) {
                                        setState(() {
                                          _metal = match.first;
                                          _liveRate ??=
                                              match.first.liveRatePerGram;
                                        });
                                      }
                                    });
                                  }
                                }
                                return DropdownButtonFormField<String>(
                                  value: _metal?.id ??
                                      (metals.any(
                                              (m) =>
                                                  m.id ==
                                                  widget.existing?.metalId)
                                          ? widget.existing!.metalId
                                          : null),
                                  items: metals
                                      .map(
                                        (m) => DropdownMenuItem(
                                          value: m.id,
                                          child: Text(m.label),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (id) {
                                    final m =
                                        metals.firstWhere((e) => e.id == id);
                                    _applyMetalRates(m, force: true);
                                  },
                                  decoration: _dec('Select metal'),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: RatnexColors.rateBoard,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'SHOP RATE ₹/g',
                                          style: RatnexTheme.label(
                                            size: 10,
                                            weight: FontWeight.w600,
                                            color: Colors.white
                                                .withValues(alpha: 0.5),
                                          ).copyWith(letterSpacing: 0.5),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _editingRate = !_editingRate;
                                            if (!_editingRate &&
                                                _metal != null) {
                                              _shopRateCtrl.text = _metal!
                                                  .shopRatePerGram
                                                  .round()
                                                  .toString();
                                            }
                                          });
                                        },
                                        icon: Icon(
                                          _editingRate
                                              ? Icons.lock_outline
                                              : Icons.edit_outlined,
                                          size: 14,
                                          color: RatnexColors.rateAccent,
                                        ),
                                        label: Text(
                                          _editingRate ? 'Lock' : 'Edit rate',
                                          style: RatnexTheme.label(
                                            size: 11,
                                            weight: FontWeight.w700,
                                            color: RatnexColors.rateAccent,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              RatnexColors.rateAccent,
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_editingRate)
                                    TextField(
                                      controller: _shopRateCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.]'),
                                        ),
                                      ],
                                      style: RatnexTheme.money(
                                        size: 18,
                                        color: RatnexColors.rateAccent,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: 'Shop rate',
                                        hintStyle: RatnexTheme.label(
                                          size: 14,
                                          color: Colors.white54,
                                        ),
                                        filled: true,
                                        fillColor:
                                            Colors.white.withValues(alpha: 0.08),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      _shopRateCtrl.text.isEmpty
                                          ? '—'
                                          : '${_currency.format(int.tryParse(_shopRateCtrl.text) ?? (_parse(_shopRateCtrl)?.round() ?? 0))}/g',
                                      style: RatnexTheme.money(
                                        size: 18,
                                        color: RatnexColors.rateAccent,
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Live  ${_rateText(_liveRate ?? _metal?.liveRatePerGram ?? widget.existing?.liveRatePerGram)}',
                                    style: RatnexTheme.label(
                                      size: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Weights (g)',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _numField(
                                    'Gross *',
                                    _grossCtrl,
                                    '0.000',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _numField('Net *', _netCtrl, '0.000'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _numField('Stone weight', _stoneWtCtrl, '0'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Charges',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _numField('Wastage %', _wastageCtrl, '0'),
                            const SizedBox(height: 12),
                            Text('Making charge type',
                                style: RatnexTheme.label(size: 12)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final t in const [
                                  ('flat', 'Flat ₹'),
                                  ('per_gram', '₹ / g'),
                                  ('percent', '% of metal'),
                                ])
                                  ChoiceChip(
                                    label: Text(t.$2),
                                    selected: _makingType == t.$1,
                                    onSelected: (_) =>
                                        setState(() => _makingType = t.$1),
                                    selectedColor: RatnexColors.ink,
                                    labelStyle: RatnexTheme.label(
                                      size: 12,
                                      weight: FontWeight.w600,
                                      color: _makingType == t.$1
                                          ? Colors.white
                                          : RatnexColors.ink,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _numField('Making charge', _makingCtrl, '0'),
                            const SizedBox(height: 12),
                            _numField('Stone charge ₹', _stoneChargeCtrl, '0'),
                            const SizedBox(height: 12),
                            _numField('Other charge ₹', _otherCtrl, '0'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(height: 12),
                      StreamBuilder<ShopGstSettings>(
                        stream: _gstService.watchSettings(),
                        builder: (context, snap) {
                          final gst = snap.data;
                          if (gst == null || !gst.isConfigured) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SectionCard(
                              title: 'GST',
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Apply GST (${gst.gstPercent % 1 == 0 ? gst.gstPercent.round() : gst.gstPercent}%)',
                                  style: RatnexTheme.label(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: RatnexColors.ink,
                                  ),
                                ),
                                subtitle: Text(
                                  'GSTIN ${gst.gstNumber}',
                                  style: RatnexTheme.label(size: 11),
                                ),
                                value: _applyGst,
                                activeThumbColor: RatnexColors.gold,
                                onChanged: (v) {
                                  setState(() {
                                    _applyGst = v;
                                    _gstPercent = gst.gstPercent;
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      _PriceSummaryCard(
                        breakdown: _priceBreakdown,
                        currency: _currency,
                        netWeight: _parse(_netCtrl) ?? 0,
                        shopRate: _parse(_shopRateCtrl) ?? 0,
                        applyGst: _applyGst,
                        gstPercent: _gstPercent,
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Notes',
                        child: TextField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          style: _fieldStyle(),
                          decoration: _dec('Optional notes'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RatnexColors.ink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            _saving
                                ? 'Saving…'
                                : (_isEdit ? 'Update item' : 'Save item'),
                            style: RatnexTheme.label(
                              size: 14,
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
        ],
      ),
    );
  }

  String _rateText(double? v) {
    if (v == null) return '—';
    return '${_currency.format(v.round())}/g';
  }

  TextStyle _fieldStyle() => RatnexTheme.label(
        size: 14,
        weight: FontWeight.w600,
        color: RatnexColors.ink,
      );

  Widget _numField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: RatnexTheme.label(size: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: _fieldStyle(),
          decoration: _dec(hint),
        ),
      ],
    );
  }
}

class _PriceSummaryCard extends StatelessWidget {
  final StockPriceBreakdown breakdown;
  final NumberFormat currency;
  final double netWeight;
  final double shopRate;
  final bool applyGst;
  final double gstPercent;

  const _PriceSummaryCard({
    required this.breakdown,
    required this.currency,
    required this.netWeight,
    required this.shopRate,
    this.applyGst = false,
    this.gstPercent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final gstAmount = applyGst ? breakdown.total * (gstPercent / 100) : 0.0;
    final total = applyGst ? breakdown.total + gstAmount : breakdown.total;

    Widget row(String label, double value, {bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: RatnexTheme.label(
                  size: 12,
                  weight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: bold ? RatnexColors.ink : RatnexColors.muted,
                ),
              ),
            ),
            Text(
              currency.format(value.round()),
              style: bold
                  ? RatnexTheme.money(size: 18, color: RatnexColors.ink)
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
            'AUTO PRICE',
            style: RatnexTheme.label(
              size: 11,
              weight: FontWeight.w700,
              color: RatnexColors.muted,
            ).copyWith(letterSpacing: 0.4),
          ),
          const SizedBox(height: 4),
          Text(
            'Net ${netWeight.toStringAsFixed(3)} g × ${currency.format(shopRate.round())}/g',
            style: RatnexTheme.label(size: 11),
          ),
          const SizedBox(height: 8),
          row('Metal value', breakdown.metalValue),
          row('Wastage', breakdown.wastage),
          row('Making', breakdown.making),
          row('Stone charge', breakdown.stoneCharge),
          row('Other', breakdown.otherCharge),
          row('Taxable value', breakdown.total),
          if (applyGst) row('GST (${gstPercent % 1 == 0 ? gstPercent.round() : gstPercent}%)', gstAmount),
          Divider(height: 16, color: RatnexColors.hairline),
          row(applyGst ? 'Total (incl. GST)' : 'Total price', total, bold: true),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

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
