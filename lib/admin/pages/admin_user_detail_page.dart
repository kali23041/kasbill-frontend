import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../admin_theme.dart';
import '../services/admin_users_service.dart';

class AdminUserDetailPage extends StatefulWidget {
  final String email;

  const AdminUserDetailPage({super.key, required this.email});

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage> {
  final _service = AdminUsersService();
  bool _loading = true;
  bool _saving = false;
  AdminUser? _user;

  String _role = 'Shop';
  String _plan = 'free';
  String _billing = 'free';
  String _status = 'expired';
  DateTime? _expiresOn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final u = await _service.getUser(widget.email);
      if (!mounted) return;
      if (u == null) {
        setState(() {
          _loading = false;
          _user = null;
        });
        return;
      }
      setState(() {
        _user = u;
        _role = u.role == 'Admin' ? 'Admin' : 'Shop';
        _plan = u.plan;
        _billing = u.planBilling ?? 'free';
        _status = u.planStatus ?? 'expired';
        _expiresOn = u.planExpiresOn;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Load failed: $e');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.updateRole(email: widget.email, role: _role);
      await _service.updateUserPlan(
        email: widget.email,
        plan: _plan,
        planBilling: _billing,
        planStatus: _status,
        planExpiresOn: _expiresOn,
        planStartedOn: _user?.planStartedOn ?? DateTime.now(),
      );
      await _load();
      if (!mounted) return;
      _toast('Saved');
    } catch (e) {
      if (!mounted) return;
      _toast('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _quick(Future<void> Function() action, String okMsg) async {
    setState(() => _saving = true);
    try {
      await action();
      await _load();
      if (!mounted) return;
      _toast(okMsg);
    } catch (e) {
      if (!mounted) return;
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresOn ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: AdminTheme.dark,
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _expiresOn = DateTime(picked.year, picked.month, picked.day, 23, 59);
      });
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.dark,
      child: Scaffold(
        backgroundColor: AdminColors.bg,
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AdminColors.gold),
                )
              : _user == null
                  ? Center(
                      child: Text(
                        'User not found',
                        style: AdminTheme.label(size: 14),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back),
                                color: AdminColors.ink,
                              ),
                              Expanded(
                                child: Text(
                                  'Edit user',
                                  style: AdminTheme.brand(size: 22),
                                ),
                              ),
                              TextButton(
                                onPressed: _saving ? null : _save,
                                child: Text(
                                  _saving ? 'Saving…' : 'Save',
                                  style: AdminTheme.label(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: AdminColors.gold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            children: [
                              Text(
                                _user!.displayName,
                                style: AdminTheme.label(
                                  size: 18,
                                  weight: FontWeight.w700,
                                  color: AdminColors.ink,
                                ),
                              ),
                              Text(
                                _user!.email,
                                style: AdminTheme.label(size: 13),
                              ),
                              const SizedBox(height: 18),
                              _section(
                                'Role',
                                DropdownButtonFormField<String>(
                                  initialValue: _role,
                                  dropdownColor: AdminColors.panelElevated,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Shop',
                                      child: Text('Shop'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Admin',
                                      child: Text('Admin'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _role = v);
                                  },
                                  decoration: _dec(),
                                  style: AdminTheme.label(
                                    size: 14,
                                    color: AdminColors.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _section(
                                'Plan',
                                DropdownButtonFormField<String>(
                                  initialValue: _plan,
                                  dropdownColor: AdminColors.panelElevated,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'free',
                                      child: Text('free'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'premium',
                                      child: Text('premium'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _plan = v);
                                  },
                                  decoration: _dec(),
                                  style: AdminTheme.label(
                                    size: 14,
                                    color: AdminColors.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _section(
                                'Billing',
                                DropdownButtonFormField<String>(
                                  initialValue: _billing,
                                  dropdownColor: AdminColors.panelElevated,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'free',
                                      child: Text('free'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'monthly',
                                      child: Text('monthly'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'yearly',
                                      child: Text('yearly'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _billing = v);
                                    }
                                  },
                                  decoration: _dec(),
                                  style: AdminTheme.label(
                                    size: 14,
                                    color: AdminColors.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _section(
                                'Status',
                                DropdownButtonFormField<String>(
                                  initialValue: _status,
                                  dropdownColor: AdminColors.panelElevated,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'trial',
                                      child: Text('trial'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'active',
                                      child: Text('active'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'expired',
                                      child: Text('expired'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _status = v);
                                  },
                                  decoration: _dec(),
                                  style: AdminTheme.label(
                                    size: 14,
                                    color: AdminColors.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _section(
                                'Expires on',
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    _expiresOn == null
                                        ? 'Not set'
                                        : DateFormat('d MMM yyyy')
                                            .format(_expiresOn!),
                                    style: AdminTheme.label(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: AdminColors.ink,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.calendar_today,
                                    color: AdminColors.gold,
                                    size: 18,
                                  ),
                                  onTap: _pickExpiry,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Quick actions',
                                style: AdminTheme.label(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: AdminColors.ink,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _quickBtn(
                                '+7 days trial',
                                () => _quick(
                                  () =>
                                      _service.grantTrial7Days(widget.email),
                                  'Trial granted',
                                ),
                              ),
                              const SizedBox(height: 8),
                              _quickBtn(
                                'Activate monthly (30 days)',
                                () => _quick(
                                  () => _service
                                      .activateMonthly30(widget.email),
                                  'Monthly activated',
                                ),
                              ),
                              const SizedBox(height: 8),
                              _quickBtn(
                                'Activate yearly (365 days)',
                                () => _quick(
                                  () => _service
                                      .activateYearly365(widget.email),
                                  'Yearly activated',
                                ),
                              ),
                              const SizedBox(height: 8),
                              _quickBtn(
                                'Mark expired',
                                () => _quick(
                                  () => _service.markExpired(widget.email),
                                  'Marked expired',
                                ),
                                danger: true,
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

  Widget _section(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AdminColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AdminTheme.label(size: 11)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  InputDecoration _dec() => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AdminColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.hairline),
        ),
      );

  Widget _quickBtn(String label, VoidCallback onTap, {bool danger = false}) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: _saving ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: danger ? AdminColors.down : AdminColors.gold,
          side: BorderSide(
            color: danger ? AdminColors.down : AdminColors.hairline,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
