import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../components/rate_board.dart';
import '../components/ratnex_page_scaffold.dart';
import '../services/ibja_rates_service.dart';
import '../services/shop_rates_service.dart';
import '../theme/ratnex_theme.dart';

class MetalsDiamondsPage extends StatefulWidget {
  const MetalsDiamondsPage({super.key});

  @override
  State<MetalsDiamondsPage> createState() => _MetalsDiamondsPageState();
}

class _MetalsDiamondsPageState extends State<MetalsDiamondsPage> {
  final _ratesService = IbjaRatesService();
  final _shopRates = ShopRatesService();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  IbjaRates? _rates;
  bool _ratesLoading = true;
  String? _ratesError;
  int _segment = 0; // 0 metals, 1 diamonds

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    setState(() {
      _ratesLoading = true;
      _ratesError = null;
    });
    try {
      final rates = await _ratesService.fetchLatest();
      if (!mounted) return;
      setState(() {
        _rates = rates;
        _ratesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ratesError = 'Could not load IBJA rates';
        _ratesLoading = false;
      });
    }
  }

  Future<void> _openAddMetal({ShopMetalRate? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RatnexColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _AddMetalSheet(
        rates: _rates,
        currency: _currency,
        existing: existing,
        onSave: ({
          required metalType,
          customName,
          karat,
          required shopRate,
          liveRate,
        }) async {
          await _shopRates.saveMetal(
            id: existing?.id,
            metalType: metalType,
            customName: customName,
            karat: karat,
            shopRatePerGram: shopRate,
            liveRatePerGram: liveRate,
          );
        },
      ),
    );
  }

  Future<void> _openAddDiamond({ShopDiamondRate? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RatnexColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _AddDiamondSheet(
        existing: existing,
        onSave: (type, carat, shopRate) async {
          await _shopRates.saveDiamond(
            id: existing?.id,
            diamondType: type,
            carat: carat,
            shopRatePerCarat: shopRate,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('d MMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: RatnexColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_segment == 0) {
            _openAddMetal();
          } else {
            _openAddDiamond();
          }
        },
        backgroundColor: RatnexColors.ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          _segment == 0 ? 'Add metal' : 'Add diamond',
          style: RatnexTheme.label(
            size: 13,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            right: -40,
            height: 260,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Metals & Diamonds',
                              style: RatnexTheme.brand(size: 26),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Shop rates  ·  $today',
                              style: RatnexTheme.label(size: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: RatnexColors.gold,
                    onRefresh: _loadRates,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
                      children: [
                        RatnexRateBoard.fromIbja(
                          loading: _ratesLoading,
                          error: _ratesError,
                          rates: _rates,
                          currency: _currency,
                          onRetry: _loadRates,
                          expanded: true,
                        ),
                        const SizedBox(height: 14),
                        _SegmentBar(
                          index: _segment,
                          onChanged: (i) => setState(() => _segment = i),
                        ),
                        const SizedBox(height: 14),
                        if (_segment == 0) ...[
                          const RatnexSectionLabel(text: 'Your metal rates'),
                          const SizedBox(height: 8),
                          StreamBuilder<List<ShopMetalRate>>(
                            stream: _shopRates.watchMetals(),
                            builder: (context, snap) {
                              if (snap.hasError) {
                                return _EmptyNote(
                                  text: 'Could not load metals: ${snap.error}',
                                );
                              }
                              final items = snap.data;
                              if (items == null) {
                                return Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: RatnexColors.gold,
                                    ),
                                  ),
                                );
                              }
                              if (items.isEmpty) {
                                return const _EmptyNote(
                                  text:
                                      'No shop metal rates yet. Tap Add metal to set karat rates with live online reference.',
                                );
                              }
                              return RatnexPanel(
                                child: Column(
                                  children: [
                                    for (var i = 0; i < items.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          height: 1,
                                          indent: 12,
                                          endIndent: 12,
                                          color: RatnexColors.hairline,
                                        ),
                                      _MetalRow(
                                        item: items[i],
                                        currency: _currency,
                                        onEdit: () =>
                                            _openAddMetal(existing: items[i]),
                                        onDelete: () =>
                                            _shopRates.deleteMetal(items[i].id),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ] else ...[
                          const RatnexSectionLabel(text: 'Your diamond rates'),
                          const SizedBox(height: 8),
                          StreamBuilder<List<ShopDiamondRate>>(
                            stream: _shopRates.watchDiamonds(),
                            builder: (context, snap) {
                              if (snap.hasError) {
                                return _EmptyNote(
                                  text:
                                      'Could not load diamonds: ${snap.error}',
                                );
                              }
                              final items = snap.data;
                              if (items == null) {
                                return Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: RatnexColors.gold,
                                    ),
                                  ),
                                );
                              }
                              if (items.isEmpty) {
                                return const _EmptyNote(
                                  text:
                                      'No diamond rates yet. Add type + carat with your shop price (₹/ct).',
                                );
                              }
                              return RatnexPanel(
                                child: Column(
                                  children: [
                                    for (var i = 0; i < items.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          height: 1,
                                          indent: 12,
                                          endIndent: 12,
                                          color: RatnexColors.hairline,
                                        ),
                                      _DiamondRow(
                                        item: items[i],
                                        currency: _currency,
                                        onEdit: () => _openAddDiamond(
                                          existing: items[i],
                                        ),
                                        onDelete: () => _shopRates
                                            .deleteDiamond(items[i].id),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _SegmentBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: RatnexColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RatnexColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegChip(
              label: 'Metals',
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegChip(
              label: 'Diamonds',
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? RatnexColors.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: RatnexTheme.label(
              size: 13,
              weight: FontWeight.w700,
              color: selected ? Colors.white : RatnexColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;

  const _EmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return RatnexPanel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: RatnexTheme.label(size: 13, color: RatnexColors.muted),
        ),
      ),
    );
  }
}

class _MetalRow extends StatelessWidget {
  final ShopMetalRate item;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MetalRow({
    required this.item,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final live = item.liveRatePerGram;
    final shop = item.shopRatePerGram;

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: RatnexColors.goldSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.metalType == 'custom'
                    ? Icons.edit_outlined
                    : Icons.hexagon_outlined,
                size: 18,
                color: RatnexColors.gold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: RatnexTheme.label(
                      size: 13,
                      weight: FontWeight.w700,
                      color: RatnexColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    live != null
                        ? 'Live ${currency.format(live.round())}/g  ·  Shop ${currency.format(shop.round())}/g'
                        : 'Live —  ·  Shop ${currency.format(shop.round())}/g',
                    style: RatnexTheme.label(size: 11),
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
      ),
    );
  }
}

class _DiamondRow extends StatelessWidget {
  final ShopDiamondRate item;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DiamondRow({
    required this.item,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: RatnexColors.goldSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.diamond_outlined,
                size: 18,
                color: RatnexColors.gold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.typeLabel,
                    style: RatnexTheme.label(
                      size: 13,
                      weight: FontWeight.w700,
                      color: RatnexColors.ink,
                    ),
                  ),
                  Text(
                    '${item.carat} ct',
                    style: RatnexTheme.label(size: 11),
                  ),
                ],
              ),
            ),
            Text(
              '${currency.format(item.shopRatePerCarat.round())}/ct',
              style: RatnexTheme.money(size: 14, color: RatnexColors.ink),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              color: RatnexColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMetalSheet extends StatefulWidget {
  final IbjaRates? rates;
  final NumberFormat currency;
  final ShopMetalRate? existing;
  final Future<void> Function({
    required String metalType,
    String? customName,
    int? karat,
    required double shopRate,
    double? liveRate,
  }) onSave;

  const _AddMetalSheet({
    required this.rates,
    required this.currency,
    required this.existing,
    required this.onSave,
  });

  @override
  State<_AddMetalSheet> createState() => _AddMetalSheetState();
}

class _AddMetalSheetState extends State<_AddMetalSheet> {
  late String _metalType;
  int? _karat;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _metalType = widget.existing?.metalType ?? 'gold';
    _nameCtrl = TextEditingController(
      text: widget.existing?.customName ?? '',
    );
    if (widget.existing != null) {
      _karat = widget.existing!.karat;
    } else if (_metalType == 'gold') {
      _karat = 22;
    } else if (_metalType == 'silver') {
      _karat = 999;
    } else {
      _karat = null;
    }
    _rateCtrl = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.shopRatePerGram.round().toString()
          : '',
    );
    _prefillFromOnline();
  }

  void _prefillFromOnline() {
    if (widget.existing != null) return;
    final online = _onlineRate;
    if (online != null && _rateCtrl.text.isEmpty) {
      _rateCtrl.text = online.round().toString();
    }
  }

  double? get _onlineRate {
    if (_metalType == 'custom') return null;
    return widget.rates?.onlineRatePerGram(
      metalType: _metalType,
      karat: _karat,
    );
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = double.tryParse(_rateCtrl.text.trim());
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid shop rate')),
      );
      return;
    }
    if (_metalType == 'gold' && _karat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a karat')),
      );
      return;
    }
    if (_metalType == 'silver' && _karat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a silver purity')),
      );
      return;
    }
    if (_metalType == 'custom' && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a custom metal name')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(
        metalType: _metalType,
        customName: _metalType == 'custom' ? _nameCtrl.text.trim() : null,
        karat: _karat,
        shopRate: parsed,
        liveRate: _onlineRate,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  void _onMetalSelected(String type) {
    setState(() {
      _metalType = type;
      if (_metalType == 'gold') {
        _karat = 22;
      } else if (_metalType == 'silver') {
        _karat = 999;
      } else {
        _karat = null;
      }
      if (widget.existing == null) {
        final o = _onlineRate;
        _rateCtrl.text = o != null ? o.round().toString() : '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final online = _onlineRate;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: RatnexColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.existing == null ? 'Add metal rate' : 'Edit metal rate',
              style: RatnexTheme.label(
                size: 18,
                weight: FontWeight.w700,
                color: RatnexColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            Text('Metal', style: RatnexTheme.label(size: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in const [
                  ('gold', 'Gold'),
                  ('silver', 'Silver'),
                  ('platinum', 'Platinum'),
                  ('custom', 'Custom'),
                ])
                  _ChoiceChip(
                    label: m.$2,
                    selected: _metalType == m.$1,
                    onTap: () => _onMetalSelected(m.$1),
                  ),
              ],
            ),
            if (_metalType == 'custom') ...[
              const SizedBox(height: 14),
              Text('Custom metal name', style: RatnexTheme.label(size: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: RatnexTheme.label(
                  size: 15,
                  weight: FontWeight.w600,
                  color: RatnexColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Rose gold alloy, Palladium',
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
                ),
              ),
            ],
            if (_metalType == 'gold') ...[
              const SizedBox(height: 14),
              Text('Karat', style: RatnexTheme.label(size: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in const [18, 20, 22, 24])
                    _ChoiceChip(
                      label: '${k}K',
                      selected: _karat == k,
                      onTap: () {
                        setState(() {
                          _karat = k;
                          if (widget.existing == null) {
                            final o = _onlineRate;
                            _rateCtrl.text =
                                o != null ? o.round().toString() : '';
                          }
                        });
                      },
                    ),
                ],
              ),
            ],
            if (_metalType == 'silver') ...[
              const SizedBox(height: 14),
              Text('Purity / type', style: RatnexTheme.label(size: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in const [
                    (999, '999 Fine'),
                    (970, '970'),
                    (925, '925 Sterling'),
                    (900, '900'),
                    (800, '800'),
                  ])
                    _ChoiceChip(
                      label: p.$2,
                      selected: _karat == p.$1,
                      onTap: () {
                        setState(() {
                          _karat = p.$1;
                          if (widget.existing == null) {
                            final o = _onlineRate;
                            _rateCtrl.text =
                                o != null ? o.round().toString() : '';
                          }
                        });
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
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
                  Text(
                    'LIVE RATE (saved with shop rate)',
                    style: RatnexTheme.label(
                      size: 10,
                      weight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.5),
                    ).copyWith(letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    online != null
                        ? '${widget.currency.format(online.round())}/g'
                        : _metalType == 'custom'
                            ? 'No live feed — shop rate only'
                            : 'Unavailable for this metal',
                    style: RatnexTheme.money(
                      size: 20,
                      color: RatnexColors.rateAccent,
                    ),
                  ),
                  if (_metalType == 'gold' &&
                      (_karat == 18 || _karat == 20)) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Derived from 24K purity',
                      style: RatnexTheme.label(
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                  if (_metalType == 'silver' &&
                      _karat != null &&
                      _karat != 999) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Derived from IBJA 999 fine silver',
                      style: RatnexTheme.label(
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                  if (_metalType == 'silver' && _karat == 999) ...[
                    const SizedBox(height: 4),
                    Text(
                      'IBJA live fine silver',
                      style: RatnexTheme.label(
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('Shop rate (₹/g)', style: RatnexTheme.label(size: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: RatnexTheme.label(
                size: 15,
                weight: FontWeight.w600,
                color: RatnexColors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Enter shop selling rate',
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
              ),
            ),
            const SizedBox(height: 16),
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
                  _saving ? 'Saving…' : 'Save rate',
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
    );
  }
}

class _AddDiamondSheet extends StatefulWidget {
  final ShopDiamondRate? existing;
  final Future<void> Function(
    String diamondType,
    double carat,
    double shopRate,
  ) onSave;

  const _AddDiamondSheet({
    required this.existing,
    required this.onSave,
  });

  @override
  State<_AddDiamondSheet> createState() => _AddDiamondSheetState();
}

class _AddDiamondSheetState extends State<_AddDiamondSheet> {
  late String _type;
  late double _carat;
  late final TextEditingController _rateCtrl;
  bool _saving = false;

  static const _carats = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0];

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.diamondType ?? 'natural';
    _carat = widget.existing?.carat ?? 1.0;
    _rateCtrl = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.shopRatePerCarat.round().toString()
          : '',
    );
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = double.tryParse(_rateCtrl.text.trim());
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid shop rate')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(_type, _carat, parsed);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: RatnexColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.existing == null
                  ? 'Add diamond rate'
                  : 'Edit diamond rate',
              style: RatnexTheme.label(
                size: 18,
                weight: FontWeight.w700,
                color: RatnexColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            Text('Type', style: RatnexTheme.label(size: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in const [
                  ('natural', 'Natural'),
                  ('labgrown', 'Lab-grown'),
                  ('solitaire', 'Solitaire'),
                  ('loose', 'Loose'),
                ])
                  _ChoiceChip(
                    label: t.$2,
                    selected: _type == t.$1,
                    onTap: () => setState(() => _type = t.$1),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Carat', style: RatnexTheme.label(size: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _carats)
                  _ChoiceChip(
                    label: '${c % 1 == 0 ? c.toInt() : c} ct',
                    selected: _carat == c,
                    onTap: () => setState(() => _carat = c),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Shop rate (₹/ct)', style: RatnexTheme.label(size: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: RatnexTheme.label(
                size: 15,
                weight: FontWeight.w600,
                color: RatnexColors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Enter shop price per carat',
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
              ),
            ),
            const SizedBox(height: 16),
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
                  _saving ? 'Saving…' : 'Save rate',
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
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? RatnexColors.ink : RatnexColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? RatnexColors.ink : RatnexColors.hairline,
            ),
          ),
          child: Text(
            label,
            style: RatnexTheme.label(
              size: 12,
              weight: FontWeight.w600,
              color: selected ? Colors.white : RatnexColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
