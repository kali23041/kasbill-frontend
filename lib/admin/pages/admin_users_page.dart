import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../admin_theme.dart';
import '../services/admin_users_service.dart';
import 'admin_user_detail_page.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _search = TextEditingController();
  final _service = AdminUsersService();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AdminUser> _filter(List<AdminUser> all) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (u) =>
              u.email.contains(q) ||
              u.displayName.toLowerCase().contains(q) ||
              u.role.toLowerCase().contains(q) ||
              (u.planStatus ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  Color _statusColor(AdminUser u) {
    if (u.isAdmin) return AdminColors.gold;
    if (u.isExpiredLive) return AdminColors.down;
    if (u.planStatus == 'trial') return AdminColors.gold;
    if (u.planStatus == 'active') return AdminColors.up;
    return AdminColors.muted;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Users', style: AdminTheme.brand(size: 32)),
                const SizedBox(height: 4),
                Text(
                  'Manage roles & subscriptions',
                  style: AdminTheme.label(size: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: AdminTheme.label(size: 14, color: AdminColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Search email, name, status…',
                    hintStyle: AdminTheme.label(size: 13),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AdminColors.muted,
                    ),
                    filled: true,
                    fillColor: AdminColors.panel,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AdminColors.hairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AdminColors.hairline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AdminColors.gold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<AdminUser>>(
              stream: _service.watchAllUsers(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snap.error}',
                      style: AdminTheme.label(color: AdminColors.down),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AdminColors.gold),
                  );
                }
                final list = _filter(snap.data!);
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'No users match',
                      style: AdminTheme.label(size: 14),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final u = list[index];
                    final expiry = u.planExpiresOn != null
                        ? DateFormat('d MMM yyyy').format(u.planExpiresOn!)
                        : '—';
                    return Material(
                      color: AdminColors.panel,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminUserDetailPage(email: u.email),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminColors.hairline),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AdminColors.chip,
                                child: Text(
                                  u.displayName.isNotEmpty
                                      ? u.displayName[0].toUpperCase()
                                      : '?',
                                  style: AdminTheme.label(
                                    size: 15,
                                    weight: FontWeight.w700,
                                    color: AdminColors.gold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AdminTheme.label(
                                        size: 14,
                                        weight: FontWeight.w700,
                                        color: AdminColors.ink,
                                      ),
                                    ),
                                    Text(
                                      u.email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AdminTheme.label(size: 11),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Expires $expiry',
                                      style: AdminTheme.label(size: 10),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(u)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      u.isAdmin ? 'Admin' : u.statusLabel,
                                      style: AdminTheme.label(
                                        size: 10,
                                        weight: FontWeight.w700,
                                        color: _statusColor(u),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    u.role,
                                    style: AdminTheme.label(size: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
