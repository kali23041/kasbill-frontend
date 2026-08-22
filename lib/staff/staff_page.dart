import 'package:flutter/material.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_staff_service.dart';
import '../theme/ratnex_theme.dart';
import '../utils/ratnex_format.dart';
import '../widgets/ratnex_ui.dart';

/// Staff accounts and what each of them may do.
class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  final _service = ShopStaffService();

  Future<void> _add() async {
    final draft = await showModalBottomSheet<StaffMember>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _StaffSheet(),
    );
    if (draft == null || !mounted) return;
    try {
      await _service.addStaff(
        email: draft.email,
        name: draft.name,
        role: draft.role,
        permissions: draft.permissions,
        phone: draft.phone,
      );
      if (mounted) RatnexSnack.success(context, '${draft.name} added');
    } catch (e) {
      if (mounted) {
        RatnexSnack.error(context, '$e'.replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _edit(StaffMember member) async {
    final updated = await showModalBottomSheet<StaffMember>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffSheet(existing: member),
    );
    if (updated == null || !mounted) return;
    await _service.updateStaff(updated);
    if (mounted) RatnexSnack.success(context, 'Saved');
  }

  Future<void> _remove(StaffMember member) async {
    await _service.removeStaff(member.id);
    if (!mounted) return;
    RatnexSnack.undoable(
      context,
      message: '${member.name} removed',
      onUndo: () => _service.addStaff(
        email: member.email,
        name: member.name,
        role: member.role,
        permissions: member.permissions,
        phone: member.phone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StaffMember>>(
      stream: _service.watchStaff(),
      builder: (context, snap) {
        final staff = snap.data ?? const <StaffMember>[];
        final loading = !snap.hasData && !snap.hasError;

        return RatnexPageScaffold(
          title: 'Staff',
          subtitle: staff.isEmpty
              ? 'Only you can use this shop account'
              : '${staff.where((s) => s.active).length} people have access',
          showBack: true,
          trailing: IconButton(
            tooltip: 'Add staff',
            onPressed: _add,
            icon: Icon(Icons.person_add_alt, color: RatnexColors.ink),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RatnexNotice(
                message:
                    'Staff sign in with their own Google account. A salesperson never sees profit, cost price or your reports.',
                color: RatnexColors.info,
                icon: Icons.shield_outlined,
              ),
              const SizedBox(height: 16),
              if (loading)
                const RatnexListSkeleton(rows: 2)
              else if (staff.isEmpty)
                RatnexEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No staff added',
                  message:
                      'Add your salespeople and manager so each of them bills under their own name — and so you can see who did what.',
                  actionLabel: 'Add staff',
                  onAction: _add,
                )
              else
                ...staff.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _StaffTile(
                      member: m,
                      onTap: () => _edit(m),
                      onToggle: () => _service.setActive(m.id, !m.active),
                      onRemove: () => _remove(m),
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

class _StaffTile extends StatelessWidget {
  final StaffMember member;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  const _StaffTile({
    required this.member,
    required this.onTap,
    required this.onToggle,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return RatnexCard(
      onTap: onTap,
      child: Row(
        children: [
          RatnexAvatar(name: member.name, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name.isEmpty ? member.email : member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RatnexTheme.label(
                          size: 14,
                          weight: FontWeight.w700,
                          color: RatnexColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    RatnexBadge(
                      label: StaffRole.label(member.role),
                      color: member.active
                          ? RatnexColors.gold
                          : RatnexColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  member.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RatnexTheme.label(size: 11.5),
                ),
                const SizedBox(height: 3),
                Text(
                  member.active
                      ? '${member.permissions.length} permissions · ${member.lastActiveAt == null ? 'never signed in' : 'active ${RatnexFormat.relativeDays(member.lastActiveAt)}'}'
                      : 'Access turned off',
                  style: RatnexTheme.label(
                    size: 11,
                    color: member.active
                        ? RatnexColors.muted
                        : RatnexColors.down,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 19, color: RatnexColors.muted),
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  onTap();
                case 'toggle':
                  onToggle();
                case 'remove':
                  onRemove();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit access')),
              PopupMenuItem(
                value: 'toggle',
                child: Text(member.active ? 'Turn off access' : 'Turn on access'),
              ),
              const PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffSheet extends StatefulWidget {
  final StaffMember? existing;

  const _StaffSheet({this.existing});

  @override
  State<_StaffSheet> createState() => _StaffSheetState();
}

class _StaffSheetState extends State<_StaffSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');

  late String _role = widget.existing?.role ?? StaffRole.salesperson;
  late Set<String> _permissions = {
    ...(widget.existing?.permissions ??
        StaffRole.defaultPermissions(StaffRole.salesperson)),
  };
  bool _customising = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _pickRole(String role) {
    setState(() {
      _role = role;
      _permissions = StaffRole.defaultPermissions(role);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
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
                _isEdit ? 'Edit access' : 'Add staff',
                style: RatnexTheme.brand(size: 21),
              ),
              const SizedBox(height: 16),
              _field(_name, 'Name', capitalize: true),
              const SizedBox(height: 12),
              _field(
                _email,
                'Google account email',
                keyboard: TextInputType.emailAddress,
                enabled: !_isEdit,
              ),
              const SizedBox(height: 12),
              _field(_phone, 'Phone (optional)',
                  keyboard: TextInputType.phone),
              const SizedBox(height: 18),
              Text(
                'ROLE',
                style: RatnexTheme.label(size: 10.5, weight: FontWeight.w700)
                    .copyWith(letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              ...StaffRole.all
                  .where((r) => r != StaffRole.owner)
                  .map((r) {
                final active = r == _role;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _pickRole(r),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: active
                            ? RatnexColors.goldSoft
                            : RatnexColors.panel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active
                              ? RatnexColors.gold
                              : RatnexColors.hairline,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            active
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: active
                                ? RatnexColors.gold
                                : RatnexColors.muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  StaffRole.label(r),
                                  style: RatnexTheme.label(
                                    size: 13.5,
                                    weight: FontWeight.w700,
                                    color: RatnexColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  StaffRole.description(r),
                                  style: RatnexTheme.label(size: 11.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() => _customising = !_customising),
                child: Row(
                  children: [
                    Icon(
                      _customising ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: RatnexColors.gold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Fine-tune permissions (${_permissions.length})',
                      style: RatnexTheme.label(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: RatnexColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
              if (_customising) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: Perm.all.map((p) {
                    final on = _permissions.contains(p);
                    return FilterChip(
                      label: Text(Perm.label(p)),
                      selected: on,
                      onSelected: (v) => setState(
                        () => v ? _permissions.add(p) : _permissions.remove(p),
                      ),
                      labelStyle: RatnexTheme.label(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: on ? Colors.white : RatnexColors.muted,
                      ),
                      selectedColor: RatnexColors.ink,
                      backgroundColor: RatnexColors.panel,
                      side: BorderSide(color: RatnexColors.hairline),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  if (_name.text.trim().isEmpty ||
                      _email.text.trim().isEmpty) {
                    RatnexSnack.error(context, 'Name and email are required');
                    return;
                  }
                  Navigator.of(context).pop(
                    StaffMember(
                      id: widget.existing?.id ?? _email.text.trim().toLowerCase(),
                      email: _email.text.trim().toLowerCase(),
                      name: _name.text.trim(),
                      role: _role,
                      permissions: _permissions,
                      active: widget.existing?.active ?? true,
                      phone: _phone.text.trim().isEmpty
                          ? null
                          : _phone.text.trim(),
                      addedAt: widget.existing?.addedAt,
                      lastActiveAt: widget.existing?.lastActiveAt,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: RatnexColors.ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  _isEdit ? 'Save access' : 'Add staff',
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
    TextInputType? keyboard,
    bool capitalize = false,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: RatnexColors.hairline),
        ),
        disabledBorder: OutlineInputBorder(
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
