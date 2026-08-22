import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_profile_service.dart';
import '../services/shop_rates_service.dart';
import '../services/shop_schemes_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/calc_text_field.dart';
import '../widgets/ratnex_ui.dart';
import 'create_scheme_page.dart';
import 'scheme_member_page.dart';

class SchemeDetailPage extends StatefulWidget {
  final String schemeId;

  const SchemeDetailPage({super.key, required this.schemeId});

  @override
  State<SchemeDetailPage> createState() => _SchemeDetailPageState();
}

class _SchemeDetailPageState extends State<SchemeDetailPage> {
  final _service = ShopSchemesService();
  final _rates = ShopRatesService();
  final _profile = ShopProfileService();
  final _search = TextEditingController();

  String _query = '';
  String _filter = 'all';
  ShopProfile? _shop;

  @override
  void initState() {
    super.initState();
    _profile.watchProfile().first.then((p) {
      if (mounted) setState(() => _shop = p);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _enroll(SavingsScheme scheme) async {
    final draft = await showModalBottomSheet<_MemberDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EnrollSheet(),
    );
    if (draft == null || !mounted) return;
    try {
      await _service.enrollMember(
        scheme: scheme,
        name: draft.name,
        phone: draft.phone,
        address: draft.address,
        nomineeName: draft.nominee,
      );
      if (mounted) RatnexSnack.success(context, '${draft.name} enrolled');
    } catch (e) {
      if (mounted) RatnexSnack.error(context, '$e');
    }
  }

  Future<void> _collect(SavingsScheme scheme, SchemeMember member) async {
    final metals = await _rates.watchMetals().first;
    if (!mounted) return;

    // Default to the shop's own rate for the scheme's metal, at the highest
    // karat on file — that is what a member buying grams would be charged.
    final candidates = metals
        .where((m) => m.metalType == scheme.metalType)
        .toList()
      ..sort((a, b) => (b.karat ?? 0).compareTo(a.karat ?? 0));
    final defaultRate =
        candidates.isEmpty ? 0.0 : candidates.first.shopRatePerGram;

    final draft = await showModalBottomSheet<_InstallmentDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InstallmentSheet(
        scheme: scheme,
        member: member,
        defaultRate: defaultRate,
        rateOptions: candidates,
      ),
    );
    if (draft == null || !mounted) return;

    try {
      await _service.payInstallment(
        scheme: scheme,
        member: member,
        amount: draft.amount,
        mode: draft.mode,
        ratePerGram: draft.ratePerGram,
        note: draft.note,
      );
      if (!mounted) return;
      RatnexSnack.success(
        context,
        'Installment ${member.paidCount + 1} recorded',
      );
    } catch (e) {
      if (mounted) RatnexSnack.error(context, '$e');
    }
  }

  Future<void> _remind(SavingsScheme scheme, SchemeMember member) async {
    final message = WhatsAppService.schemeInstallmentReminder(
      shopName: _shop?.shopName ?? 'our shop',
      customerName: member.name,
      schemeName: scheme.name,
      amount: scheme.monthlyAmount,
      monthNumber: member.paidCount + 1,
    );
    final ok = await WhatsAppService.send(member.phone, message);
    if (!mounted) return;
    if (!ok) {
      await WhatsAppService.copy(message);
      if (mounted) RatnexSnack.show(context, 'Reminder copied to clipboard');
    }
  }

  Future<void> _closeScheme(SavingsScheme scheme) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Close ${scheme.name}?', style: RatnexTheme.brand(size: 19)),
        content: Text(
          'No new members can join after this. Existing members keep their installments and can still be paid out.',
          style: RatnexTheme.label(size: 13, color: RatnexColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: RatnexTheme.label(size: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Close scheme',
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
    if (ok != true || !mounted) return;
    await _service.closeScheme(scheme.id);
    if (mounted) RatnexSnack.success(context, 'Scheme closed');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SavingsScheme?>(
      stream: _service.watchScheme(widget.schemeId),
      builder: (context, schemeSnap) {
        final scheme = schemeSnap.data;
        if (scheme == null) {
          return RatnexPageScaffold(
            title: 'Scheme',
            subtitle: schemeSnap.hasData ? 'Not found' : 'Loading…',
            showBack: true,
            body: schemeSnap.hasData
                ? RatnexEmptyState(
                    icon: Icons.help_outline,
                    title: 'Scheme not found',
                    message: 'It may have been deleted from another device.',
                  )
                : const RatnexListSkeleton(rows: 3),
          );
        }

        return StreamBuilder<List<SchemeMember>>(
          stream: _service.watchMembers(scheme.id),
          builder: (context, memberSnap) {
            final all = memberSnap.data ?? const <SchemeMember>[];
            final due = all.where((m) => m.isDue).toList();
            final matured = all
                .where((m) => m.status == 'matured' || m.status == 'redeemed')
                .toList();

            var visible = switch (_filter) {
              'due' => due,
              'matured' => matured,
              _ => all,
            };
            final q = _query.trim().toLowerCase();
            if (q.isNotEmpty) {
              final digits = q.replaceAll(RegExp(r'\D'), '');
              visible = visible
                  .where((m) =>
                      m.name.toLowerCase().contains(q) ||
                      m.memberNo.toLowerCase().contains(q) ||
                      (digits.isNotEmpty && m.phone.contains(digits)))
                  .toList();
            }

            final grams = all.fold<double>(0, (s, m) => s + m.gramsAccrued);

            return RatnexPageScaffold(
              title: scheme.name,
              subtitle:
                  '${scheme.planLabel} · ${RatnexFormat.money(scheme.monthlyAmount)} a month',
              showBack: true,
              trailing: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: RatnexColors.ink),
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateSchemePage(existing: scheme),
                        ),
                      );
                    case 'close':
                      _closeScheme(scheme);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit scheme')),
                  if (scheme.isActive)
                    const PopupMenuItem(
                      value: 'close',
                      child: Text('Close scheme'),
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
                          label: 'Collected',
                          value: RatnexFormat.compact(scheme.collected),
                          caption: '${all.length} members',
                          icon: Icons.savings_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RatnexStatTile(
                          label: 'Grams held',
                          value: grams == 0
                              ? '—'
                              : RatnexFormat.grams(grams),
                          caption: SchemeAccrual.label(scheme.accrual),
                          icon: Icons.scale_outlined,
                          accent: RatnexColors.gold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RatnexStatTile(
                          label: 'Due now',
                          value: '${due.length}',
                          caption: due.isEmpty ? 'All on track' : 'Chase these',
                          icon: Icons.notifications_active_outlined,
                          accent: due.isEmpty
                              ? RatnexColors.up
                              : RatnexColors.down,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (scheme.isActive)
                    FilledButton.icon(
                      onPressed: () => _enroll(scheme),
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: const Text('Enroll a member'),
                      style: FilledButton.styleFrom(
                        backgroundColor: RatnexColors.ink,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  const SizedBox(height: 14),
                  RatnexSearchField(
                    hint: 'Search member name, number or phone',
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 10),
                  RatnexFilterChips(
                    selected: _filter,
                    options: [
                      (value: 'all', label: 'All', count: all.length),
                      (value: 'due', label: 'Due', count: due.length),
                      (
                        value: 'matured',
                        label: 'Matured',
                        count: matured.length
                      ),
                    ],
                    onSelected: (v) => setState(() => _filter = v),
                  ),
                  const SizedBox(height: 14),
                  if (!memberSnap.hasData)
                    const RatnexListSkeleton(rows: 3)
                  else if (all.isEmpty)
                    RatnexEmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No members yet',
                      message:
                          'Enroll your first customer and start collecting installments.',
                      actionLabel: 'Enroll a member',
                      onAction: () => _enroll(scheme),
                    )
                  else if (visible.isEmpty)
                    RatnexEmptyState(
                      icon: Icons.search_off,
                      title: 'No members match',
                      message: 'Try a different name, number or filter.',
                    )
                  else
                    ...visible.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MemberCard(
                          scheme: scheme,
                          member: m,
                          onCollect: () => _collect(scheme, m),
                          onRemind: () => _remind(scheme, m),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SchemeMemberPage(
                                schemeId: scheme.id,
                                memberId: m.id,
                              ),
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
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  final SavingsScheme scheme;
  final SchemeMember member;
  final VoidCallback onCollect;
  final VoidCallback onRemind;
  final VoidCallback onTap;

  const _MemberCard({
    required this.scheme,
    required this.member,
    required this.onCollect,
    required this.onRemind,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        (member.paidCount / scheme.durationMonths).clamp(0.0, 1.0);
    final statusColor = switch (member.status) {
      'redeemed' => RatnexColors.muted,
      'matured' => RatnexColors.up,
      'cancelled' => RatnexColors.down,
      _ => member.isDue ? RatnexColors.down : RatnexColors.info,
    };

    return RatnexCard(
      onTap: onTap,
      borderColor:
          member.isDue ? RatnexColors.down.withValues(alpha: 0.3) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RatnexAvatar(name: member.name, size: 40),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
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
                      '${member.memberNo} · ${member.phone}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RatnexTheme.label(size: 11),
                    ),
                  ],
                ),
              ),
              RatnexBadge(
                label: member.isDue
                    ? '${member.daysOverdue}d late'
                    : switch (member.status) {
                        'redeemed' => 'Redeemed',
                        'matured' => 'Matured',
                        'cancelled' => 'Cancelled',
                        _ => 'On track',
                      },
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: RatnexColors.hairline,
              valueColor: AlwaysStoppedAnimation(
                member.isDue ? RatnexColors.down : RatnexColors.gold,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${member.paidCount} of ${scheme.durationMonths} paid · ${RatnexFormat.money(member.paidAmount)}'
                  '${member.gramsAccrued > 0 ? ' · ${RatnexFormat.grams(member.gramsAccrued)}' : ''}',
                  style: RatnexTheme.label(size: 11.5),
                ),
              ),
              if (member.isActive) ...[
                IconButton(
                  tooltip: 'Remind',
                  onPressed: onRemind,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.chat_outlined,
                    size: 18,
                    color: Color(0xFF25D366),
                  ),
                ),
                FilledButton(
                  onPressed: onCollect,
                  style: FilledButton.styleFrom(
                    backgroundColor: RatnexColors.ink,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(
                    'Collect',
                    style: RatnexTheme.label(
                      size: 12,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberDraft {
  final String name;
  final String phone;
  final String? address;
  final String? nominee;

  const _MemberDraft({
    required this.name,
    required this.phone,
    this.address,
    this.nominee,
  });
}

class _EnrollSheet extends StatefulWidget {
  const _EnrollSheet();

  @override
  State<_EnrollSheet> createState() => _EnrollSheetState();
}

class _EnrollSheetState extends State<_EnrollSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _nominee = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _nominee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Enroll a member',
      children: [
        _sheetField(_name, 'Full name', capitalize: true),
        const SizedBox(height: 12),
        _sheetField(_phone, 'Phone', keyboard: TextInputType.phone),
        const SizedBox(height: 12),
        _sheetField(_address, 'Address (optional)'),
        const SizedBox(height: 12),
        _sheetField(_nominee, 'Nominee (optional)', capitalize: true),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
              RatnexSnack.error(context, 'Name and phone are required');
              return;
            }
            Navigator.of(context).pop(
              _MemberDraft(
                name: _name.text.trim(),
                phone: _phone.text.trim(),
                address:
                    _address.text.trim().isEmpty ? null : _address.text.trim(),
                nominee:
                    _nominee.text.trim().isEmpty ? null : _nominee.text.trim(),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: RatnexColors.ink,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text(
            'Enroll',
            style: RatnexTheme.label(
              size: 13.5,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstallmentDraft {
  final double amount;
  final String mode;
  final double? ratePerGram;
  final String? note;

  const _InstallmentDraft({
    required this.amount,
    required this.mode,
    this.ratePerGram,
    this.note,
  });
}

class _InstallmentSheet extends StatefulWidget {
  final SavingsScheme scheme;
  final SchemeMember member;
  final double defaultRate;
  final List<ShopMetalRate> rateOptions;

  const _InstallmentSheet({
    required this.scheme,
    required this.member,
    required this.defaultRate,
    required this.rateOptions,
  });

  @override
  State<_InstallmentSheet> createState() => _InstallmentSheetState();
}

class _InstallmentSheetState extends State<_InstallmentSheet> {
  late final _amount = TextEditingController(
    text: widget.scheme.monthlyAmount.toStringAsFixed(0),
  );
  late final _rate = TextEditingController(
    text: widget.defaultRate > 0 ? widget.defaultRate.toStringAsFixed(0) : '',
  );
  final _note = TextEditingController();
  String _mode = 'cash';

  static const _modes = ['cash', 'upi', 'card', 'bank'];

  bool get _tracksGrams => widget.scheme.accrual == SchemeAccrual.grams;

  double get _grams {
    final rate = parseAmount(_rate.text);
    if (rate <= 0) return 0;
    return parseAmount(_amount.text) / rate;
  }

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title:
          'Installment ${widget.member.paidCount + 1} of ${widget.scheme.durationMonths}',
      subtitle: widget.member.name,
      children: [
        CalcTextField(
          controller: _amount,
          label: 'Amount',
          prefix: '₹ ',
          allowDecimal: false,
          enabled: widget.scheme.allowCustomAmount ||
              widget.member.paidCount == 0 ||
              true,
          onChanged: (_) => setState(() {}),
        ),
        if (_tracksGrams) ...[
          const SizedBox(height: 12),
          CalcTextField(
            controller: _rate,
            label: "Today's rate",
            prefix: '₹ ',
            suffix: '/g',
            allowDecimal: false,
            onChanged: (_) => setState(() {}),
          ),
          if (widget.rateOptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.rateOptions.take(4).map((r) {
                return ActionChip(
                  label: Text(
                    '${r.label} · ${RatnexFormat.money(r.shopRatePerGram)}',
                    style: RatnexTheme.label(size: 11, weight: FontWeight.w600),
                  ),
                  onPressed: () => setState(
                    () => _rate.text = r.shopRatePerGram.toStringAsFixed(0),
                  ),
                  backgroundColor: RatnexColors.panel,
                  side: BorderSide(color: RatnexColors.hairline),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          RatnexNotice(
            message: _grams > 0
                ? 'This installment buys ${RatnexFormat.grams(_grams)} at the rate above. Total after this: ${RatnexFormat.grams(widget.member.gramsAccrued + _grams)}.'
                : 'Enter a rate to convert this installment into grams.',
            color: RatnexColors.gold,
            icon: Icons.scale_outlined,
          ),
        ],
        const SizedBox(height: 14),
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
        const SizedBox(height: 12),
        _sheetField(_note, 'Note (optional)'),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () {
            final amount = parseAmount(_amount.text);
            if (amount <= 0) {
              RatnexSnack.error(context, 'Enter an amount');
              return;
            }
            Navigator.of(context).pop(
              _InstallmentDraft(
                amount: amount,
                mode: _mode,
                ratePerGram: _tracksGrams ? parseAmount(_rate.text) : null,
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: RatnexColors.up,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text(
            'Record installment',
            style: RatnexTheme.label(
              size: 13.5,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SheetShell({
    required this.title,
    this.subtitle,
    required this.children,
  });

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
              Text(title, style: RatnexTheme.brand(size: 21)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: RatnexTheme.label(size: 12.5)),
              ],
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

Widget _sheetField(
  TextEditingController controller,
  String label, {
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
      labelStyle: RatnexTheme.label(size: 12.5),
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
    ),
  );
}
