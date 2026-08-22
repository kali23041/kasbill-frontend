import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_karigar_service.dart';
import '../services/shop_rates_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/calc_text_field.dart';
import '../widgets/ratnex_ui.dart';
import 'karigar_page.dart';

class KarigarDetailPage extends StatefulWidget {
  final String karigarId;

  const KarigarDetailPage({super.key, required this.karigarId});

  @override
  State<KarigarDetailPage> createState() => _KarigarDetailPageState();
}

class _KarigarDetailPageState extends State<KarigarDetailPage> {
  final _service = ShopKarigarService();
  final _rates = ShopRatesService();
  String _filter = 'all';

  Future<void> _addEntry(Karigar karigar, String type) async {
    final metals = await _rates.watchMetals().first;
    if (!mounted) return;
    final draft = await showModalBottomSheet<KarigarEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EntrySheet(
        karigar: karigar,
        type: type,
        metals: metals,
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await _service.addEntry(karigar.id, draft);
      if (!mounted) return;
      RatnexSnack.success(
        context,
        '${KarigarEntryType.label(type)} recorded',
      );
    } catch (e) {
      if (mounted) RatnexSnack.error(context, '$e');
    }
  }

  Future<void> _edit(Karigar karigar) async {
    final updated = await showModalBottomSheet<Karigar>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => KarigarFormSheet(existing: karigar),
    );
    if (updated == null || !mounted) return;
    await _service.updateKarigar(updated);
    if (mounted) RatnexSnack.success(context, 'Saved');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Karigar?>(
      stream: _service.watchKarigar(widget.karigarId),
      builder: (context, snap) {
        final karigar = snap.data;
        if (karigar == null) {
          return RatnexPageScaffold(
            title: 'Karigar',
            subtitle: snap.hasData ? 'Not found' : 'Loading…',
            showBack: true,
            body: snap.hasData
                ? RatnexEmptyState(
                    icon: Icons.help_outline,
                    title: 'Karigar not found',
                    message: 'They may have been removed from another device.',
                  )
                : const RatnexListSkeleton(rows: 3),
          );
        }

        return StreamBuilder<List<KarigarEntry>>(
          stream: _service.watchEntries(karigar.id),
          builder: (context, entrySnap) {
            final all = entrySnap.data ?? const <KarigarEntry>[];
            final visible = _filter == 'all'
                ? all
                : all.where((e) => e.type == _filter).toList();

            return RatnexPageScaffold(
              title: karigar.name,
              subtitle:
                  '${karigar.specialty ?? 'Goldsmith'}${karigar.phone != null ? ' · ${karigar.phone}' : ''}',
              showBack: true,
              trailing: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: RatnexColors.ink),
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      _edit(karigar);
                    case 'call':
                      WhatsAppService.call(karigar.phone);
                    case 'rebuild':
                      _service.rebuild(karigar.id).then((_) {
                        if (context.mounted) {
                          RatnexSnack.success(context, 'Totals recalculated');
                        }
                      });
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit karigar')),
                  const PopupMenuItem(value: 'call', child: Text('Call')),
                  const PopupMenuItem(
                    value: 'rebuild',
                    child: Text('Recalculate totals'),
                  ),
                ],
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: karigar.wastageOverLimit
                          ? RatnexColors.down.withValues(alpha: 0.09)
                          : RatnexColors.rateBoard,
                      borderRadius: BorderRadius.circular(14),
                      border: karigar.wastageOverLimit
                          ? Border.all(
                              color: RatnexColors.down.withValues(alpha: 0.3),
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STILL WITH KARIGAR',
                          style: RatnexTheme.label(
                            size: 10.5,
                            weight: FontWeight.w700,
                            color: karigar.wastageOverLimit
                                ? RatnexColors.down
                                : RatnexColors.rateAccent,
                          ).copyWith(letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          RatnexFormat.grams(karigar.outstandingWeight),
                          style: RatnexTheme.money(
                            size: 32,
                            color: karigar.wastageOverLimit
                                ? RatnexColors.ink
                                : RatnexColors.onRateBoard,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          karigar.issuedWeight == 0
                              ? 'Nothing issued yet'
                              : '${karigar.wastagePercent.toStringAsFixed(2)}% of ${RatnexFormat.grams(karigar.issuedWeight)} issued'
                                  '${karigar.allowedWastagePercent > 0 ? ' · allowed ${karigar.allowedWastagePercent.toStringAsFixed(2)}%' : ''}',
                          style: RatnexTheme.label(
                            size: 12,
                            color: karigar.wastageOverLimit
                                ? RatnexColors.down
                                : RatnexColors.rateAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (karigar.wastageOverLimit) ...[
                    const SizedBox(height: 12),
                    RatnexNotice(
                      message:
                          'Wastage is above the ${karigar.allowedWastagePercent.toStringAsFixed(2)}% you agreed. Check the entries below before issuing more metal.',
                      color: RatnexColors.down,
                      icon: Icons.warning_amber_outlined,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              _addEntry(karigar, KarigarEntryType.issue),
                          icon: const Icon(Icons.north_east, size: 17),
                          label: const Text('Issue'),
                          style: FilledButton.styleFrom(
                            backgroundColor: RatnexColors.ink,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              _addEntry(karigar, KarigarEntryType.receive),
                          icon: const Icon(Icons.south_west, size: 17),
                          label: const Text('Receive'),
                          style: FilledButton.styleFrom(
                            backgroundColor: RatnexColors.up,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _addEntry(karigar, KarigarEntryType.payment),
                          icon: const Icon(Icons.payments_outlined, size: 16),
                          label: const Text('Pay'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: RatnexColors.ink,
                            side: BorderSide(color: RatnexColors.hairline),
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: RatnexStatTile(
                          label: 'Issued',
                          value: RatnexFormat.grams(karigar.issuedWeight),
                          icon: Icons.north_east,
                          accent: RatnexColors.warn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RatnexStatTile(
                          label: 'Received',
                          value: RatnexFormat.grams(karigar.receivedWeight),
                          icon: Icons.south_west,
                          accent: RatnexColors.up,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RatnexStatTile(
                          label: 'Labour due',
                          value: RatnexFormat.compact(karigar.labourBalance),
                          caption:
                              '${RatnexFormat.compact(karigar.labourPaid)} paid',
                          icon: Icons.payments_outlined,
                          accent: RatnexColors.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const RatnexSectionLabel(text: 'ENTRIES'),
                  const SizedBox(height: 10),
                  RatnexFilterChips(
                    selected: _filter,
                    options: [
                      (value: 'all', label: 'All', count: all.length),
                      (
                        value: KarigarEntryType.issue,
                        label: 'Issued',
                        count: all
                            .where((e) => e.type == KarigarEntryType.issue)
                            .length
                      ),
                      (
                        value: KarigarEntryType.receive,
                        label: 'Received',
                        count: all
                            .where((e) => e.type == KarigarEntryType.receive)
                            .length
                      ),
                      (
                        value: KarigarEntryType.payment,
                        label: 'Payments',
                        count: all
                            .where((e) => e.type == KarigarEntryType.payment)
                            .length
                      ),
                    ],
                    onSelected: (v) => setState(() => _filter = v),
                  ),
                  const SizedBox(height: 12),
                  if (!entrySnap.hasData)
                    const RatnexListSkeleton(rows: 3)
                  else if (visible.isEmpty)
                    RatnexEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No entries yet',
                      message:
                          'Issue metal to start the account. Every gram that comes back gets logged against it.',
                    )
                  else
                    ...visible.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EntryTile(entry: e),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  final KarigarEntry entry;

  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isIssue = entry.type == KarigarEntryType.issue;
    final isPayment = entry.type == KarigarEntryType.payment;
    final color = isIssue
        ? RatnexColors.warn
        : isPayment
            ? RatnexColors.info
            : RatnexColors.up;

    return RatnexCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              isIssue
                  ? Icons.north_east
                  : isPayment
                      ? Icons.payments_outlined
                      : Icons.south_west,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.itemName?.isNotEmpty == true
                      ? entry.itemName!
                      : KarigarEntryType.label(entry.type),
                  style: RatnexTheme.label(
                    size: 13,
                    weight: FontWeight.w700,
                    color: RatnexColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    RatnexFormat.date(entry.entryAt ?? entry.createdAt),
                    if (entry.metalLabel != null) entry.metalLabel!,
                    if (entry.pieces > 0) '${entry.pieces} pcs',
                    if (entry.jobNo != null) 'Token ${entry.jobNo}',
                    if (entry.note != null && entry.note!.isNotEmpty)
                      entry.note!,
                  ].join(' · '),
                  maxLines: 2,
                  style: RatnexTheme.label(size: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isPayment
                    ? RatnexFormat.money(entry.paidAmount)
                    : '${isIssue ? '+' : '−'}${RatnexFormat.grams(entry.effectiveWeight)}',
                style: RatnexTheme.money(size: 13.5, color: color),
              ),
              if (!isPayment && entry.labourAmount > 0) ...[
                const SizedBox(height: 3),
                Text(
                  '${RatnexFormat.money(entry.labourAmount)} labour',
                  style: RatnexTheme.label(size: 10.5),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EntrySheet extends StatefulWidget {
  final Karigar karigar;
  final String type;
  final List<ShopMetalRate> metals;

  const _EntrySheet({
    required this.karigar,
    required this.type,
    required this.metals,
  });

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  final _item = TextEditingController();
  final _gross = TextEditingController();
  final _net = TextEditingController();
  final _pieces = TextEditingController();
  final _labour = TextEditingController();
  final _paid = TextEditingController();
  final _note = TextEditingController();

  String? _metalLabel;
  String _mode = 'cash';

  bool get _isPayment => widget.type == KarigarEntryType.payment;

  bool get _isReceive => widget.type == KarigarEntryType.receive;

  @override
  void initState() {
    super.initState();
    _metalLabel = widget.metals.isEmpty ? null : widget.metals.first.label;
    if (_isPayment) {
      _paid.text = widget.karigar.labourBalance <= 0
          ? ''
          : widget.karigar.labourBalance.toStringAsFixed(0);
    }
    if (_isReceive && widget.karigar.labourType == 'per_gram') {
      _net.addListener(_recalcLabour);
    }
  }

  void _recalcLabour() {
    final grams = parseAmount(_net.text);
    if (grams <= 0 || widget.karigar.labourRate <= 0) return;
    _labour.text = (grams * widget.karigar.labourRate).toStringAsFixed(0);
    setState(() {});
  }

  @override
  void dispose() {
    _net.removeListener(_recalcLabour);
    _item.dispose();
    _gross.dispose();
    _net.dispose();
    _pieces.dispose();
    _labour.dispose();
    _paid.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: RatnexColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: RatnexColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                switch (widget.type) {
                  KarigarEntryType.receive => 'Receive from karigar',
                  KarigarEntryType.payment => 'Pay labour',
                  _ => 'Issue metal',
                },
                style: RatnexTheme.brand(size: 21),
              ),
              const SizedBox(height: 4),
              Text(widget.karigar.name, style: RatnexTheme.label(size: 12.5)),
              const SizedBox(height: 16),
              if (_isPayment) ...[
                CalcTextField(
                  controller: _paid,
                  label: 'Amount paid',
                  prefix: '₹ ',
                  allowDecimal: false,
                ),
                const SizedBox(height: 10),
                Text(
                  'Labour outstanding: ${RatnexFormat.money(widget.karigar.labourBalance)}',
                  style: RatnexTheme.label(size: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['cash', 'upi', 'bank'].map((m) {
                    final active = m == _mode;
                    return ChoiceChip(
                      label: Text(m.toUpperCase()),
                      selected: active,
                      onSelected: (_) => setState(() => _mode = m),
                      labelStyle: RatnexTheme.label(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: active ? Colors.white : RatnexColors.muted,
                      ),
                      selectedColor: RatnexColors.ink,
                      backgroundColor: RatnexColors.panel,
                      side: BorderSide(color: RatnexColors.hairline),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
              ] else ...[
                _field(_item, 'Item / description', capitalize: true),
                if (widget.metals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.metals.take(5).map((m) {
                      final active = m.label == _metalLabel;
                      return ChoiceChip(
                        label: Text(m.label),
                        selected: active,
                        onSelected: (_) =>
                            setState(() => _metalLabel = m.label),
                        labelStyle: RatnexTheme.label(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: active ? Colors.white : RatnexColors.muted,
                        ),
                        selectedColor: RatnexColors.ink,
                        backgroundColor: RatnexColors.panel,
                        side: BorderSide(color: RatnexColors.hairline),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CalcTextField(
                        controller: _gross,
                        label: 'Gross weight',
                        suffix: 'g',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CalcTextField(
                        controller: _net,
                        label: 'Net weight',
                        suffix: 'g',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CalcTextField(
                        controller: _pieces,
                        label: 'Pieces',
                        allowDecimal: false,
                      ),
                    ),
                    if (_isReceive) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: CalcTextField(
                          controller: _labour,
                          label: 'Labour charge',
                          prefix: '₹ ',
                          allowDecimal: false,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _field(_note, 'Note (optional)'),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  final gross = parseAmount(_gross.text);
                  final net = parseAmount(_net.text);
                  final paid = parseAmount(_paid.text);
                  if (_isPayment && paid <= 0) {
                    RatnexSnack.error(context, 'Enter an amount');
                    return;
                  }
                  if (!_isPayment && gross <= 0 && net <= 0) {
                    RatnexSnack.error(context, 'Enter a weight');
                    return;
                  }
                  Navigator.of(context).pop(
                    KarigarEntry(
                      id: '',
                      type: widget.type,
                      metalLabel: _isPayment ? null : _metalLabel,
                      grossWeight: gross,
                      netWeight: net,
                      pieces: parseAmount(_pieces.text).round(),
                      itemName:
                          _item.text.trim().isEmpty ? null : _item.text.trim(),
                      labourAmount: parseAmount(_labour.text),
                      paidAmount: paid,
                      paymentMode: _isPayment ? _mode : null,
                      note:
                          _note.text.trim().isEmpty ? null : _note.text.trim(),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _isReceive
                      ? RatnexColors.up
                      : RatnexColors.ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  switch (widget.type) {
                    KarigarEntryType.receive => 'Record receipt',
                    KarigarEntryType.payment => 'Record payment',
                    _ => 'Issue metal',
                  },
                  style: RatnexTheme.label(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool capitalize = false,
  }) {
    return TextField(
      controller: controller,
      textCapitalization:
          capitalize ? TextCapitalization.words : TextCapitalization.none,
      style: RatnexTheme.label(size: 13.5, color: RatnexColors.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: RatnexTheme.label(size: 12.5),
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
      ),
    );
  }
}
