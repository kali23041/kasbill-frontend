import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../admin_theme.dart';
import '../services/admin_users_service.dart';
import 'admin_user_detail_page.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminUsersService();

    return StreamBuilder<List<AdminUser>>(
      stream: service.watchAllUsers(),
      builder: (context, snap) {
        final users = snap.data ?? const <AdminUser>[];
        final shops = users.where((u) => u.role != 'Admin').length;
        final trial =
            users.where((u) => u.planStatus == 'trial' && !u.isExpiredLive).length;
        final active =
            users.where((u) => u.planStatus == 'active' && !u.isExpiredLive).length;
        final expired = users.where((u) => u.isExpiredLive).length;
        final expiringToday = users.where((u) => u.isExpiringToday).toList();

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text('Admin', style: AdminTheme.brand(size: 32)),
              const SizedBox(height: 4),
              Text(
                'Subscriptions & shops',
                style: AdminTheme.label(size: 13),
              ),
              const SizedBox(height: 18),
              if (snap.hasError)
                _panel(
                  child: Text(
                    'Could not load users: ${snap.error}',
                    style: AdminTheme.label(color: AdminColors.down),
                  ),
                )
              else if (!snap.hasData)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: AdminColors.gold),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _CountCard(label: 'Shops', value: '$shops'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CountCard(
                        label: 'Trial',
                        value: '$trial',
                        accent: AdminColors.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _CountCard(
                        label: 'Active',
                        value: '$active',
                        accent: AdminColors.up,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CountCard(
                        label: 'Expired',
                        value: '$expired',
                        accent: AdminColors.down,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Text(
                      'Expiring today',
                      style: AdminTheme.label(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AdminColors.ink,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AdminColors.goldSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${expiringToday.length}',
                        style: AdminTheme.label(
                          size: 11,
                          weight: FontWeight.w700,
                          color: AdminColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (expiringToday.isEmpty)
                  _panel(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No subscriptions expire today.',
                        style: AdminTheme.label(size: 13),
                      ),
                    ),
                  )
                else
                  _panel(
                    child: Column(
                      children: [
                        for (var i = 0; i < expiringToday.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              color: AdminColors.hairline,
                            ),
                          _ExpiringRow(
                            user: expiringToday[i],
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AdminUserDetailPage(
                                    email: expiringToday[i].email,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AdminColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.hairline),
      ),
      child: child,
    );
  }
}

class _CountCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _CountCard({
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AdminColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AdminTheme.label(size: 11)),
          const SizedBox(height: 6),
          Text(
            value,
            style: AdminTheme.money(
              size: 26,
              color: accent ?? AdminColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiringRow extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onTap;

  const _ExpiringRow({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final expiry = user.planExpiresOn != null
        ? DateFormat('h:mm a').format(user.planExpiresOn!)
        : '—';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AdminColors.chip,
              child: Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?',
                style: AdminTheme.label(
                  size: 14,
                  weight: FontWeight.w700,
                  color: AdminColors.gold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminTheme.label(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AdminColors.ink,
                    ),
                  ),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminTheme.label(size: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  user.statusLabel,
                  style: AdminTheme.label(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AdminColors.gold,
                  ),
                ),
                Text(expiry, style: AdminTheme.label(size: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
