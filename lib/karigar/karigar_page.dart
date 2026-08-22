import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/export_service.dart';
import '../services/shop_karigar_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/calc_text_field.dart';
import '../widgets/ratnex_ui.dart';
import 'karigar_detail_page.dart';

/// Goldsmith accounts — grams issued, grams returned, and the wastage in
/// between. This is where an unwatched shop bleeds money.
class KarigarPage extends StatefulWidget {
  const KarigarPage({super.key});

  @override
  State<KarigarPage> createState() => _KarigarPageState();
}

class _KarigarPageState extends State<KarigarPage> {
  final _service = ShopKarigarService();
  final _search = TextEditingController();
  String _query = '';
  bool _exporting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addKarigar() async {
    final draft = await showModalBottomSheet<Karigar>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const KarigarFormSheet(),
    );
    if (draft == null || !mounted) return;
    try {
      await _service.createKarigar(draft);
      if (mounted) RatnexSnack.success(context, '${draft.name} added');
    } catch (e) {
      if (mounted) RatnexSnack.error(context, '$e');
    }
  }

  Future<void> _export(List<Karigar> list) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final result = await ExportService.karigars(list);
      await ExportService.share(result, subject: 'Ratnex karigar accounts');
      if (mounted) {
        RatnexSnack.success(context, 'Exported ${result.rowCount} karigars');
      }
    } catch (e) {
      if (mounted) RatnexSnack.error(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Karigar>>(
      stream: _service.watchKarigars(),
      builder: (context, snap) {
        final all = snap.data ?? const <Karigar>[];
        final loading = !snap.hasData && !snap.hasError;

        var visible = all;
        final q = _query.trim().toLowerCase();
        if (q.isNotEmpty) {
          visible = all
              .where((k) =>
                  k.name.toLowerCase().contains(q) ||
                  (k.specialty ?? '').toLowerCase().contains(q) ||
                  (k.phone ?? '').contains(q))
              .toList();
        }

        final withKarigars = ShopKarigarService.totalWithKarigars(all);
        final labourDue = ShopKarigarService.totalLabourDue(all);
        final overLimit = all.where((k) => k.wastageOverLimit).length;

        return RatnexPageScaffold(
          title: 'Karigar',
          subtitle: all.isEmpty
              ? 'Metal issued to goldsmiths'
              : '${all.length} goldsmiths on your books',
          showBack: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Export CSV',
                onPressed:
                    _exporting || all.isEmpty ? null : () => _export(all),
                icon: _exporting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: RatnexColors.gold,
                        ),
                      )
                    : Icon(Icons.ios_share, color: RatnexColors.ink, size: 20),
              ),
              IconButton(
                tooltip: 'Add karigar',
                onPressed: _addKarigar,
                icon: Icon(Icons.add_circle_outline, color: RatnexColors.ink),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RatnexStatTile(
                      label: 'With karigars',
                      value: RatnexFormat.grams(withKarigars),
                      caption: 'not yet returned',
                      icon: Icons.handyman_outlined,
                      accent: withKarigars > 0
                          ? RatnexColors.warn
                          : RatnexColors.up,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Labour due',
                      value: RatnexFormat.compact(labourDue),
                      caption: 'unpaid making',
                      icon: Icons.payments_outlined,
                      accent: RatnexColors.info,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RatnexStatTile(
                      label: 'Over limit',
                      value: '$overLimit',
                      caption: overLimit == 0
                          ? 'Wastage in range'
                          : 'Check these',
                      icon: Icons.warning_amber_outlined,
                      accent: overLimit == 0
                          ? RatnexColors.up
                          : RatnexColors.down,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RatnexSearchField(
                hint: 'Search karigar name or work',
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 14),
              if (loading)
                const RatnexListSkeleton(rows: 3)
              else if (all.isEmpty)
                RatnexEmptyState(
                  icon: Icons.handyman_outlined,
                  title: 'No karigars yet',
                  message:
                      'Add each goldsmith you work with, then record every gram issued and received back. The wastage figure tells you who is costing you money.',
                  actionLabel: 'Add a karigar',
                  onAction: _addKarigar,
                )
              else if (visible.isEmpty)
                RatnexEmptyState(
                  icon: Icons.search_off,
                  title: 'No karigar matches',
                  message: 'Try a different name or type of work.',
                )
              else
                ...visible.map(
                  (k) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _KarigarCard(
                      karigar: k,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => KarigarDetailPage(karigarId: k.id),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _KarigarCard extends StatelessWidget {
  final Karigar karigar;
  final VoidCallback onTap;

  const _KarigarCard({required this.karigar, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final holding = karigar.outstandingWeight > 0.0005;

    return RatnexCard(
      onTap: onTap,
      borderColor: karigar.wastageOverLimit
          ? RatnexColors.down.withValues(alpha: 0.3)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RatnexAvatar(name: karigar.name, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      karigar.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RatnexTheme.label(
                        size: 14,
                        weight: FontWeight.w700,
                        color: RatnexColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        karigar.specialty ?? 'Goldsmith',
                        if (karigar.phone != null) karigar.phone!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RatnexTheme.label(size: 11.5),
                    ),
                  ],
                ),
              ),
              if (holding)
                RatnexBadge(
                  label: RatnexFormat.grams(karigar.outstandingWeight),
                  color: karigar.wastageOverLimit
                      ? RatnexColors.down
                      : RatnexColors.warn,
                )
              else
                RatnexBadge(label: 'Settled', color: RatnexColors.up),
            ],
          ),
          const SizedBox(height: 11),
          Divider(height: 1, color: RatnexColors.hairline),
          const SizedBox(height: 10),
          Row(
            children: [
              _Mini(
                label: 'Issued',
                value: RatnexFormat.grams(karigar.issuedWeight),
              ),
              _Mini(
                label: 'Received',
                value: RatnexFormat.grams(karigar.receivedWeight),
              ),
              _Mini(
                label: 'Wastage',
                value: '${karigar.wastagePercent.toStringAsFixed(2)}%',
                color: karigar.wastageOverLimit ? RatnexColors.down : null,
              ),
              _Mini(
                label: 'Labour',
                value: RatnexFormat.compact(karigar.labourBalance),
                last: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  final bool last;
  final Color? color;

  const _Mini({
    required this.label,
    required this.value,
    this.last = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            last ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: RatnexTheme.label(size: 9.5, weight: FontWeight.w600)
                .copyWith(letterSpacing: 0.4),
          ),
          const SizedBox(height: 4),
          Text(value, style: RatnexTheme.money(size: 12.5, color: color)),
        ],
      ),
    );
  }
}

/// Add / edit a karigar. Shared by the list and the detail screen.
class KarigarFormSheet extends StatefulWidget {
  final Karigar? existing;

  const KarigarFormSheet({super.key, this.existing});

  @override
  State<KarigarFormSheet> createState() => _KarigarFormSheetState();
}

class _KarigarFormSheetState extends State<KarigarFormSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _specialty =
      TextEditingController(text: widget.existing?.specialty ?? '');
  late final _rate = TextEditingController(
    text: widget.existing == null || widget.existing!.labourRate == 0
        ? ''
        : widget.existing!.labourRate.toStringAsFixed(0),
  );
  late final _wastage = TextEditingController(
    text: widget.existing == null || widget.existing!.allowedWastagePercent == 0
        ? ''
        : widget.existing!.allowedWastagePercent.toString(),
  );
  late String _labourType = widget.existing?.labourType ?? 'per_gram';

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _specialty.dispose();
    _rate.dispose();
    _wastage.dispose();
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
                widget.existing == null ? 'Add karigar' : 'Edit karigar',
                style: RatnexTheme.brand(size: 21),
              ),
              const SizedBox(height: 16),
              _field(_name, 'Name', capitalize: true),
              const SizedBox(height: 12),
              _field(_phone, 'Phone', keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _field(
                _specialty,
                'Type of work',
                hint: 'Chains, settings, polishing',
                capitalize: true,
              ),
              const SizedBox(height: 14),
              Text(
                'LABOUR RATE',
                style: RatnexTheme.label(size: 10.5, weight: FontWeight.w700)
                    .copyWith(letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: const [
                  (value: 'per_gram', label: 'Per gram'),
                  (value: 'per_piece', label: 'Per piece'),
                  (value: 'percent', label: 'Percent'),
                ].map((o) {
                  final active = o.value == _labourType;
                  return ChoiceChip(
                    label: Text(o.label),
                    selected: active,
                    onSelected: (_) => setState(() => _labourType = o.value),
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
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CalcTextField(
                      controller: _rate,
                      label: 'Rate',
                      prefix: _labourType == 'percent' ? null : '₹ ',
                      suffix: switch (_labourType) {
                        'per_gram' => '/g',
                        'percent' => '%',
                        _ => '/pc',
                      },
                      allowDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CalcTextField(
                      controller: _wastage,
                      label: 'Allowed wastage',
                      suffix: '%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              RatnexNotice(
                message:
                    'Anything issued and not returned counts as wastage. Set the allowed percent and Ratnex flags whoever goes over it.',
                color: RatnexColors.info,
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  if (_name.text.trim().isEmpty) {
                    RatnexSnack.error(context, 'Name is required');
                    return;
                  }
                  Navigator.of(context).pop(
                    Karigar(
                      id: widget.existing?.id ?? '',
                      name: _name.text.trim(),
                      phone:
                          _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                      specialty: _specialty.text.trim().isEmpty
                          ? null
                          : _specialty.text.trim(),
                      labourType: _labourType,
                      labourRate: parseAmount(_rate.text),
                      allowedWastagePercent: parseAmount(_wastage.text),
                      status: widget.existing?.status ?? 'active',
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: RatnexColors.ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  widget.existing == null ? 'Add karigar' : 'Save changes',
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
    String? hint,
    TextInputType? keyboard,
    bool capitalize = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization:
          capitalize ? TextCapitalization.words : TextCapitalization.none,
      style: RatnexTheme.label(size: 13.5, color: RatnexColors.ink),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: RatnexTheme.label(size: 12.5),
        hintStyle: RatnexTheme.label(size: 12.5),
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
