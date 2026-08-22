import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_ledger_service.dart';
import '../services/shop_profile_service.dart';
import '../services/shop_settings_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/haptics.dart';
import '../utils/ratnex_format.dart';
import '../widgets/calc_text_field.dart';
import '../widgets/ratnex_ui.dart';

/// One customer's khata: every rupee given and collected, with the actions to
/// move the balance.
class UdhaarDetailPage extends StatefulWidget {
  final String phoneId;
  final String name;
  final String phone;

  const UdhaarDetailPage({
    super.key,
    required this.phoneId,
    required this.name,
    required this.phone,
  });

  @override
  State<UdhaarDetailPage> createState() => _UdhaarDetailPageState();
}

class _UdhaarDetailPageState extends State<UdhaarDetailPage> {
  final _ledger = ShopLedgerService();
  final _profile = ShopProfileService();
  final _settings = ShopSettingsService();

  ShopProfile? _shop;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _profile.watchProfile().first.then((p) {
      if (mounted) setState(() => _shop = p);
    }).catchError((_) {});
  }

  Future<void> _openEntrySheet({required bool isPayment}) async {
    final settings = await _settings.getSettings();
    if (!mounted) return;
    final result = await showModalBottomSheet<_EntryDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EntrySheet(
        isPayment: isPayment,
        customerName: widget.name,
        defaultDueDays: settings.udhaarDueDays,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _ledger.addEntry(
        customerName: widget.name,
        phone: widget.phone,
        entry: LedgerEntry(
          id: '',
          type: result.type,
          amount: result.amount,
          source: LedgerSource.manual,
          mode: result.mode,
          note: result.note,
          dueAt: result.dueAt,
          entryAt: result.entryAt,
        ),
      );
      if (!mounted) return;
      RatnexSnack.success(
        context,
        isPayment
            ? 'Collected ${RatnexFormat.money(result.amount)}'
            : 'Added ${RatnexFormat.money(result.amount)} to the khata',
      );
    } catch (e) {
      if (mounted) RatnexSnack.error(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remind(UdhaarAccount account) async {
    final message = WhatsAppService.udhaarReminder(
      shopName: _shop?.shopName ?? 'our shop',
      customerName: widget.name,
      outstanding: account.outstanding,
      daysOverdue: account.daysOverdue,
      upiId: _shop?.upiId,
    );
    final ok = await WhatsAppService.send(widget.phone, message);
    if (!mounted) return;
    if (!ok) {
      await WhatsAppService.copy(message);
      if (mounted) {
        RatnexSnack.show(
          context,
          'WhatsApp not available — reminder copied to clipboard',
        );
      }
    }
  }

  Future<void> _deleteEntry(LedgerEntry entry) async {
    Haptics.warning();
    try {
      await _ledger.deleteEntry(widget.phoneId, entry);
      if (!mounted) return;
      RatnexSnack.undoable(
        context,
        message: '${LedgerEntryType.label(entry.type)} removed',
        onUndo: () async {
          await _ledger.addEntry(
            customerName: widget.name,
            phone: widget.phone,
            entry: entry,
          );
        },
      );
    } catch (e) {
      if (mounted) RatnexSnack.error(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UdhaarAccount?>(
      stream: _ledger.watchAccount(widget.phoneId),
      builder: (context, accountSnap) {
        return StreamBuilder<List<LedgerEntry>>(
          stream: _ledger.watchEntries(widget.phoneId),
          builder: (context, entrySnap) {
            final account = accountSnap.data;
            final entries = entrySnap.data ?? const <LedgerEntry>[];
            final outstanding = account?.outstanding ?? 0;
            final settled = outstanding <= 0.5;

            return RatnexPageScaffold(
              title: widget.name.isEmpty ? 'Khata' : widget.name,
              subtitle: widget.phone,
              showBack: true,
              trailing: (account != null && !settled)
                  ? IconButton(
                      tooltip: 'Send reminder',
                      onPressed: () => _remind(account),
                      icon: const Icon(
                        Icons.chat_outlined,
                        color: Color(0xFF25D366),
                        size: 21,
                      ),
                    )
                  : null,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: settled
                          ? RatnexColors.up.withValues(alpha: 0.09)
                          : (account?.isOverdue ?? false)
                              ? RatnexColors.down.withValues(alpha: 0.09)
                              : RatnexColors.goldSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: settled
                            ? RatnexColors.up.withValues(alpha: 0.25)
                            : (account?.isOverdue ?? false)
                                ? RatnexColors.down.withValues(alpha: 0.25)
                                : RatnexColors.gold.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settled ? 'ALL SETTLED' : 'OUTSTANDING',
                          style: RatnexTheme.label(
                            size: 10.5,
                            weight: FontWeight.w700,
                          ).copyWith(letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          RatnexFormat.money(outstanding),
                          style: RatnexTheme.money(size: 34),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          settled
                              ? 'Nothing pending from ${widget.name}.'
                              : (account?.isOverdue ?? false)
                                  ? 'Due since ${RatnexFormat.date(account!.oldestDueAt)} · ${account.daysOverdue} days overdue'
                                  : account?.oldestDueAt == null
                                      ? 'No due date set'
                                      : 'Due on ${RatnexFormat.date(account!.oldestDueAt)}',
                          style: RatnexTheme.label(size: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _openEntrySheet(isPayment: true),
                          icon: const Icon(Icons.south_west, size: 17),
                          label: const Text('Collect'),
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
                          onPressed: _busy
                              ? null
                              : () => _openEntrySheet(isPayment: false),
                          icon: const Icon(Icons.north_east, size: 17),
                          label: const Text('Add udhaar'),
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
                          label: 'Total given',
                          value:
                              RatnexFormat.compact(account?.totalCredit ?? 0),
                          icon: Icons.north_east,
                          accent: RatnexColors.warn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RatnexStatTile(
                          label: 'Collected',
                          value: RatnexFormat.compact(account?.totalPaid ?? 0),
                          icon: Icons.south_west,
                          accent: RatnexColors.up,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RatnexStatTile(
                          label: 'Written off',
                          value:
                              RatnexFormat.compact(account?.writtenOff ?? 0),
                          icon: Icons.remove_circle_outline,
                          accent: RatnexColors.down,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const RatnexSectionLabel(text: 'ENTRIES'),
                  const SizedBox(height: 10),
                  if (!entrySnap.hasData)
                    const RatnexListSkeleton(rows: 3)
                  else if (entries.isEmpty)
                    RatnexEmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'Khata is empty',
                      message:
                          'Add udhaar when goods go out on credit, and record every payment you collect against it.',
                      actionLabel: 'Add udhaar',
                      onAction: () => _openEntrySheet(isPayment: false),
                    )
                  else
                    ...entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EntryTile(
                          entry: e,
                          onDelete: () => _deleteEntry(e),
                        ),
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
  final LedgerEntry entry;
  final VoidCallback onDelete;

  const _EntryTile({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isPayment = entry.type == LedgerEntryType.payment;
    final isWriteOff = entry.type == LedgerEntryType.writeOff;
    final color = isPayment
        ? RatnexColors.up
        : isWriteOff
            ? RatnexColors.down
            : RatnexColors.warn;

    return RatnexCard(
      padding: const EdgeInsets.all(12),
      onLongPress: onDelete,
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
              isPayment
                  ? Icons.south_west
                  : isWriteOff
                      ? Icons.remove_circle_outline
                      : Icons.north_east,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      LedgerEntryType.label(entry.type),
                      style: RatnexTheme.label(
                        size: 13,
                        weight: FontWeight.w700,
                        color: RatnexColors.ink,
                      ),
                    ),
                    if (entry.mode != null) ...[
                      const SizedBox(width: 6),
                      RatnexBadge(
                        label: entry.mode!.toUpperCase(),
                        color: RatnexColors.muted,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    RatnexFormat.date(entry.entryAt ?? entry.createdAt),
                    if (entry.sourceId != null) entry.sourceId!,
                    if (entry.note != null && entry.note!.isNotEmpty)
                      entry.note!,
                  ].join(' · '),
                  maxLines: 2,
                  style: RatnexTheme.label(size: 11),
                ),
                if (entry.isOverdue)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: RatnexBadge(
                      label: 'Due ${RatnexFormat.date(entry.dueAt)}',
                      color: RatnexColors.down,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${isPayment || isWriteOff ? '−' : '+'}${RatnexFormat.money(entry.amount)}',
            style: RatnexTheme.money(size: 14, color: color),
          ),
        ],
      ),
    );
  }
}

class _EntryDraft {
  final String type;
  final double amount;
  final String? mode;
  final String? note;
  final DateTime? dueAt;
  final DateTime entryAt;

  const _EntryDraft({
    required this.type,
    required this.amount,
    this.mode,
    this.note,
    this.dueAt,
    required this.entryAt,
  });
}

class _EntrySheet extends StatefulWidget {
  final bool isPayment;
  final String customerName;
  final int defaultDueDays;

  const _EntrySheet({
    required this.isPayment,
    required this.customerName,
    required this.defaultDueDays,
  });

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  String _mode = 'cash';
  String _type = LedgerEntryType.credit;
  DateTime _entryAt = DateTime.now();
  late DateTime _dueAt =
      DateTime.now().add(Duration(days: widget.defaultDueDays));

  static const _modes = ['cash', 'upi', 'card', 'bank', 'cheque'];

  @override
  void initState() {
    super.initState();
    _type = widget.isPayment
        ? LedgerEntryType.payment
        : LedgerEntryType.credit;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = parseAmount(_amount.text);
    if (amount <= 0) {
      RatnexSnack.error(context, 'Enter an amount first');
      return;
    }
    Navigator.of(context).pop(
      _EntryDraft(
        type: _type,
        amount: amount,
        mode: _type == LedgerEntryType.payment ? _mode : null,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        dueAt: _type == LedgerEntryType.credit ? _dueAt : null,
        entryAt: _entryAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
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
                widget.isPayment
                    ? 'Collect from ${widget.customerName}'
                    : 'Add udhaar for ${widget.customerName}',
                style: RatnexTheme.brand(size: 21),
              ),
              const SizedBox(height: 16),
              CalcTextField(
                controller: _amount,
                label: 'Amount',
                prefix: '₹ ',
                autofocus: true,
                hint: 'You can type 5000+250',
              ),
              const SizedBox(height: 14),
              if (widget.isPayment) ...[
                Text(
                  'PAID BY',
                  style: RatnexTheme.label(size: 10.5, weight: FontWeight.w700)
                      .copyWith(letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _modes.map((m) {
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
                _DateRow(
                  label: 'Due date',
                  value: _dueAt,
                  onPick: (d) => setState(() => _dueAt = d),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 1095)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(
                          () => _type = _type == LedgerEntryType.writeOff
                              ? LedgerEntryType.credit
                              : LedgerEntryType.writeOff,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _type == LedgerEntryType.writeOff
                              ? RatnexColors.down
                              : RatnexColors.muted,
                          side: BorderSide(
                            color: _type == LedgerEntryType.writeOff
                                ? RatnexColors.down
                                : RatnexColors.hairline,
                          ),
                        ),
                        child: Text(
                          _type == LedgerEntryType.writeOff
                              ? 'Writing off as bad debt'
                              : 'Write off instead',
                          style: RatnexTheme.label(
                            size: 12,
                            weight: FontWeight.w600,
                            color: _type == LedgerEntryType.writeOff
                                ? RatnexColors.down
                                : RatnexColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _DateRow(
                label: 'Entry date',
                value: _entryAt,
                onPick: (d) => setState(() => _entryAt = d),
                firstDate: DateTime.now().subtract(const Duration(days: 1825)),
                lastDate: DateTime.now(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                style: RatnexTheme.label(size: 13, color: RatnexColors.ink),
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  labelStyle: RatnexTheme.label(size: 12.5),
                  filled: true,
                  fillColor: RatnexColors.panel,
                  isDense: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: RatnexColors.hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: RatnexColors.gold),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.isPayment
                      ? RatnexColors.up
                      : RatnexColors.ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  widget.isPayment ? 'Record payment' : 'Add to khata',
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
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onPick;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: RatnexColors.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: RatnexColors.hairline),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: RatnexColors.muted,
            ),
            const SizedBox(width: 10),
            Text(label, style: RatnexTheme.label(size: 12.5)),
            const Spacer(),
            Text(
              RatnexFormat.date(value),
              style: RatnexTheme.label(
                size: 13,
                weight: FontWeight.w700,
                color: RatnexColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
