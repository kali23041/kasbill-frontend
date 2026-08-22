import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_customers_service.dart';
import '../services/shop_karigar_service.dart';
import '../services/shop_repairs_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/calc_text_field.dart';
import '../widgets/ratnex_ui.dart';

class CreateRepairPage extends StatefulWidget {
  final RepairJob? existing;

  const CreateRepairPage({super.key, this.existing});

  @override
  State<CreateRepairPage> createState() => _CreateRepairPageState();
}

class _CreateRepairPageState extends State<CreateRepairPage> {
  final _service = ShopRepairsService();
  final _customers = ShopCustomersService();
  final _karigars = ShopKarigarService();
  final _formKey = GlobalKey<FormState>();

  late final _name =
      TextEditingController(text: widget.existing?.customerName ?? '');
  late final _phone =
      TextEditingController(text: widget.existing?.customerPhone ?? '');
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _estimate = TextEditingController(
    text: widget.existing == null || widget.existing!.estimate == 0
        ? ''
        : widget.existing!.estimate.toStringAsFixed(0),
  );
  late final _advance = TextEditingController(
    text: widget.existing == null || widget.existing!.advance == 0
        ? ''
        : widget.existing!.advance.toStringAsFixed(0),
  );

  late String _type = widget.existing?.type ?? RepairJobType.repair;
  late DateTime _promisedAt =
      widget.existing?.promisedAt ?? DateTime.now().add(const Duration(days: 7));
  late final List<_ItemDraft> _items = widget.existing == null
      ? [_ItemDraft()]
      : widget.existing!.items.map(_ItemDraft.from).toList();

  String? _karigarId;
  String? _karigarName;
  List<ShopCustomer> _knownCustomers = const [];
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _karigarId = widget.existing?.karigarId;
    _karigarName = widget.existing?.karigarName;
    _customers.watchCustomers().first.then((list) {
      if (mounted) setState(() => _knownCustomers = list);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _description.dispose();
    _estimate.dispose();
    _advance.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  void _autofillFromPhone(String value) {
    final id = customerPhoneDocId(value);
    if (id == null) return;
    for (final c in _knownCustomers) {
      if (c.phoneId == id && _name.text.trim().isEmpty) {
        setState(() => _name.text = c.name);
        return;
      }
    }
  }

  Future<void> _pickImage(_ItemDraft item) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: RatnexColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined,
                  color: RatnexColors.ink),
              title: Text(
                'Take a photo',
                style: RatnexTheme.label(size: 13.5, color: RatnexColors.ink),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  Icon(Icons.photo_library_outlined, color: RatnexColors.ink),
              title: Text(
                'Pick from gallery',
                style: RatnexTheme.label(size: 13.5, color: RatnexColors.ink),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await StockImageHelper.pickCompressed(source: source);
      if (picked == null || !mounted) return;
      setState(() {
        item.imageBase64 = picked.base64;
        item.imageMime = picked.mime;
      });
    } catch (e) {
      if (mounted) RatnexSnack.error(context, 'Could not add photo: $e');
    }
  }

  Future<void> _pickKarigar() async {
    final list = await _karigars.watchKarigars().first;
    if (!mounted) return;
    if (list.isEmpty) {
      RatnexSnack.show(context, 'Add a karigar first from Profile → Karigar');
      return;
    }
    final chosen = await showModalBottomSheet<Karigar>(
      context: context,
      backgroundColor: RatnexColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                'Assign to karigar',
                style: RatnexTheme.brand(size: 18),
              ),
            ),
            ListTile(
              leading: Icon(Icons.clear, color: RatnexColors.muted),
              title: Text(
                'Nobody yet',
                style: RatnexTheme.label(size: 13.5, color: RatnexColors.ink),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            ...list.map(
              (k) => ListTile(
                leading: RatnexAvatar(name: k.name, size: 34),
                title: Text(
                  k.name,
                  style: RatnexTheme.label(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: RatnexColors.ink,
                  ),
                ),
                subtitle: Text(
                  k.specialty ?? 'Goldsmith',
                  style: RatnexTheme.label(size: 11.5),
                ),
                onTap: () => Navigator.pop(ctx, k),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _karigarId = chosen?.id;
      _karigarName = chosen?.name;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final items = _items
        .where((i) => i.name.text.trim().isNotEmpty)
        .map((i) => i.toItem())
        .toList();
    if (items.isEmpty) {
      RatnexSnack.error(context, 'Add at least one item');
      return;
    }

    setState(() => _saving = true);
    try {
      final draft = RepairJob(
        jobNo: widget.existing?.jobNo ?? '',
        type: _type,
        customerName: _name.text.trim(),
        customerPhone:
            _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        items: items,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        status: widget.existing?.status ?? RepairStatus.received,
        estimate: parseAmount(_estimate.text),
        advance: parseAmount(_advance.text),
        finalAmount: widget.existing?.finalAmount ?? 0,
        karigarId: _karigarId,
        karigarName: _karigarName,
        receivedAt: widget.existing?.receivedAt,
        promisedAt: _promisedAt,
      );

      if (_isEdit) {
        await _service.updateJob(draft);
      } else {
        final saved = await _service.createJob(draft);
        // Keep the customer book in step with the counter.
        await _customers.upsertFromBill(
          name: saved.customerName,
          phone: saved.customerPhone,
          bumpBillCount: false,
        );
      }
      if (!mounted) return;
      RatnexSnack.success(
        context,
        _isEdit ? 'Job card updated' : 'Job card created',
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
      title: _isEdit ? 'Edit job card' : 'New job card',
      subtitle: 'Token, photo and a promised date so nothing gets lost',
      showBack: true,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RatnexSectionLabel(text: 'WORK TYPE'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RepairJobType.all.map((t) {
                final active = t == _type;
                return ChoiceChip(
                  label: Text(RepairJobType.label(t)),
                  selected: active,
                  onSelected: (_) => setState(() => _type = t),
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
            const SizedBox(height: 18),
            const RatnexSectionLabel(text: 'CUSTOMER'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              onChanged: _autofillFromPhone,
              validator: RatnexValidate.phoneError,
              style: RatnexTheme.label(size: 14, color: RatnexColors.ink),
              decoration: _decoration('Phone', '10-digit mobile'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Customer name is required'
                  : null,
              style: RatnexTheme.label(size: 14, color: RatnexColors.ink),
              decoration: _decoration('Customer name', 'Full name'),
            ),
            const SizedBox(height: 18),
            RatnexSectionLabel(
              text: 'ITEMS RECEIVED',
              actionLabel: 'Add item',
              onAction: () => setState(() => _items.add(_ItemDraft())),
            ),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ItemEditor(
                  draft: e.value,
                  index: e.key,
                  canRemove: _items.length > 1,
                  onRemove: () => setState(() {
                    _items[e.key].dispose();
                    _items.removeAt(e.key);
                  }),
                  onPickImage: () => _pickImage(e.value),
                  onChanged: () => setState(() {}),
                ),
              );
            }),
            const SizedBox(height: 6),
            TextFormField(
              controller: _description,
              maxLines: 3,
              style: RatnexTheme.label(size: 13.5, color: RatnexColors.ink),
              decoration: _decoration(
                'Work to be done',
                'Solder the broken link, polish and rhodium the whole piece',
              ),
            ),
            const SizedBox(height: 18),
            const RatnexSectionLabel(text: 'MONEY & DATES'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CalcTextField(
                    controller: _estimate,
                    label: 'Estimate',
                    prefix: '₹ ',
                    allowDecimal: false,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CalcTextField(
                    controller: _advance,
                    label: 'Advance taken',
                    prefix: '₹ ',
                    allowDecimal: false,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _promisedAt,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _promisedAt = picked);
              },
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: RatnexColors.panel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: RatnexColors.hairline),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 17,
                      color: RatnexColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Promised delivery',
                      style: RatnexTheme.label(size: 13),
                    ),
                    const Spacer(),
                    Text(
                      RatnexFormat.date(_promisedAt),
                      style: RatnexTheme.label(
                        size: 13.5,
                        weight: FontWeight.w700,
                        color: RatnexColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickKarigar,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: RatnexColors.panel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: RatnexColors.hairline),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.handyman_outlined,
                      size: 17,
                      color: RatnexColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Text('Karigar', style: RatnexTheme.label(size: 13)),
                    const Spacer(),
                    Text(
                      _karigarName ?? 'Not assigned',
                      style: RatnexTheme.label(
                        size: 13.5,
                        weight: FontWeight.w700,
                        color: _karigarName == null
                            ? RatnexColors.muted
                            : RatnexColors.ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: RatnexColors.muted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
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
                      _isEdit ? 'Save changes' : 'Create job card',
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

class _ItemDraft {
  final TextEditingController name;
  final TextEditingController weight;
  final TextEditingController condition;
  String? imageBase64;
  String? imageMime;

  _ItemDraft({String? name, String? weight, String? condition})
      : name = TextEditingController(text: name ?? ''),
        weight = TextEditingController(text: weight ?? ''),
        condition = TextEditingController(text: condition ?? '');

  factory _ItemDraft.from(RepairItem item) {
    final d = _ItemDraft(
      name: item.name,
      weight: item.grossWeight == 0 ? '' : item.grossWeight.toString(),
      condition: item.condition ?? '',
    );
    d.imageBase64 = item.imageBase64;
    d.imageMime = item.imageMime;
    return d;
  }

  RepairItem toItem() => RepairItem(
        name: name.text.trim(),
        grossWeight: parseAmount(weight.text),
        condition:
            condition.text.trim().isEmpty ? null : condition.text.trim(),
        imageBase64: imageBase64,
        imageMime: imageMime,
      );

  void dispose() {
    name.dispose();
    weight.dispose();
    condition.dispose();
  }
}

class _ItemEditor extends StatelessWidget {
  final _ItemDraft draft;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onPickImage;
  final VoidCallback onChanged;

  const _ItemEditor({
    required this.draft,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onPickImage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = StockImageHelper.decodeBase64(draft.imageBase64);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RatnexColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RatnexColors.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'ITEM ${index + 1}',
                style: RatnexTheme.label(size: 10, weight: FontWeight.w700)
                    .copyWith(letterSpacing: 0.5),
              ),
              const Spacer(),
              if (canRemove)
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: RatnexColors.down,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onPickImage,
                child: Container(
                  width: 62,
                  height: 62,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: RatnexColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: RatnexColors.hairline),
                  ),
                  child: bytes == null
                      ? Icon(
                          Icons.add_a_photo_outlined,
                          size: 20,
                          color: RatnexColors.muted,
                        )
                      : Image.memory(bytes, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: draft.name,
                      textCapitalization: TextCapitalization.words,
                      style: RatnexTheme.label(
                        size: 13.5,
                        color: RatnexColors.ink,
                      ),
                      decoration: _inner('Item', 'Gold bangle'),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: draft.weight,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: RatnexTheme.money(size: 13.5),
                            decoration: _inner('Weight', 'grams'),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: draft.condition,
                            style: RatnexTheme.label(
                              size: 13,
                              color: RatnexColors.ink,
                            ),
                            decoration: _inner('Condition', 'Clasp broken'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inner(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: RatnexTheme.label(size: 11),
      hintStyle: RatnexTheme.label(size: 12),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: RatnexColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: RatnexColors.gold),
      ),
    );
  }
}
