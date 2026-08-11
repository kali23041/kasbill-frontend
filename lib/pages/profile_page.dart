import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../admin/admin_shell.dart';
import '../admin/services/admin_users_service.dart';
import '../auth/auth_helpers.dart';
import '../auth/signin_page.dart';
import '../components/ratnex_page_scaffold.dart';
import '../pages/categories_page.dart';
import '../pages/edit_shop_details_page.dart';
import '../pages/gst_page.dart';
import '../pages/metals_diamonds_page.dart';
import '../pages/plans_page.dart';
import '../services/shop_plan_service.dart';
import '../services/shop_profile_service.dart';
import '../services/stock_image_helper.dart';
import '../theme/ratnex_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Sign out',
          style: RatnexTheme.label(
            size: 18,
            weight: FontWeight.w700,
            color: RatnexColors.ink,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of Ratnex?',
          style: RatnexTheme.label(size: 13, color: RatnexColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: RatnexTheme.label(size: 13, color: RatnexColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sign out',
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

    if (shouldLogout != true || !mounted) return;

    setState(() => _isLoggingOut = true);

    try {
      await AuthHelpers.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SigninPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign out failed: $e'),
          backgroundColor: RatnexColors.down,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('d MMM yyyy').format(DateTime.now());
    final user = FirebaseAuth.instance.currentUser;
    final fallbackName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : 'Shop account';
    final email = user?.email ?? '—';
    final profileService = ShopProfileService();

    return StreamBuilder<ShopProfile>(
      stream: profileService.watchProfile(),
      builder: (context, snap) {
        final profile = snap.data ?? const ShopProfile();
        final name = profile.shopName?.trim().isNotEmpty == true
            ? profile.shopName!.trim()
            : fallbackName;
        final pct = profile.completionPercent.round();
        final logoBytes = StockImageHelper.decodeBase64(profile.logoBase64);

        return RatnexPageScaffold(
          title: 'Profile',
          subtitle: 'Shop account  ·  $today',
          trailing: RatnexHeaderChip(
            label: pct >= 100 ? 'Complete' : '$pct%',
            color: pct >= 100 ? RatnexColors.up : RatnexColors.gold,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RatnexPanel(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: RatnexColors.goldSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: logoBytes != null
                            ? Image.memory(logoBytes, fit: BoxFit.cover)
                            : user?.photoURL != null
                                ? Image.network(
                                    user!.photoURL!,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.storefront_outlined,
                                    color: RatnexColors.gold,
                                    size: 28,
                                  ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: RatnexTheme.label(
                                size: 16,
                                weight: FontWeight.w700,
                                color: RatnexColors.ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(email, style: RatnexTheme.label(size: 12)),
                            const SizedBox(height: 2),
                            Text(
                              profile.shopType != null
                                  ? 'Role · Shop · ${profile.shopType}'
                                  : 'Role · Shop',
                              style: RatnexTheme.label(size: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RatnexPanel(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditShopDetailsPage(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Shop profile',
                                style: RatnexTheme.label(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: RatnexColors.ink,
                                ),
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: RatnexTheme.money(
                                size: 16,
                                color: pct >= 100
                                    ? RatnexColors.up
                                    : RatnexColors.gold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: profile.totalCount == 0
                                ? 0
                                : profile.completedCount / profile.totalCount,
                            minHeight: 8,
                            backgroundColor: RatnexColors.hairline,
                            color: pct >= 100
                                ? RatnexColors.up
                                : RatnexColors.gold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          pct >= 100
                              ? 'Profile complete'
                              : '${profile.completedCount}/${profile.totalCount} details · Tap to complete',
                          style: RatnexTheme.label(size: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const RatnexSectionLabel(text: 'Account'),
              const SizedBox(height: 8),
              RatnexPanel(
                child: Column(
                  children: [
                    StreamBuilder<ShopPlan>(
                      stream: ShopPlanService().watchPlan(),
                      builder: (context, planSnap) {
                        final plan = planSnap.data ?? ShopPlan.free;
                        return _ProfileRow(
                          icon: Icons.workspace_premium_outlined,
                          title: 'Plans',
                          subtitle: plan.priceLabel,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PlansPage(),
                              ),
                            );
                          },
                          onLongPress: () => _debugGrantAdmin(context),
                        );
                      },
                    ),
                    // Shows when Firestore role is Admin (case-insensitive),
                    // or email is in AdminConfig.allowlistEmails.
                    // First Admin: Firebase Console → users/{email} → role: "Admin"
                    // or (debug) long-press Plans → Grant myself Admin.
                    StreamBuilder<bool>(
                      stream: AdminUsersService().watchCurrentUserIsAdmin(),
                      builder: (context, roleSnap) {
                        if (roleSnap.data != true) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          children: [
                            const Divider(
                              height: 1,
                              indent: 12,
                              endIndent: 12,
                              color: RatnexColors.hairline,
                            ),
                            _ProfileRow(
                              icon: Icons.admin_panel_settings_outlined,
                              title: 'Admin',
                              subtitle: 'Subscriptions & users',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AdminShell(),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    const Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                      color: RatnexColors.hairline,
                    ),
                    _ProfileRow(
                      icon: Icons.diamond_outlined,
                      title: 'Metals & Diamonds',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MetalsDiamondsPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                      color: RatnexColors.hairline,
                    ),
                    _ProfileRow(
                      icon: Icons.category_outlined,
                      title: 'Categories',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CategoriesPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                      color: RatnexColors.hairline,
                    ),
                    _ProfileRow(
                      icon: Icons.receipt_long_outlined,
                      title: 'GST',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const GstPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                      color: RatnexColors.hairline,
                    ),
                    _ProfileRow(
                      icon: Icons.storefront_outlined,
                      title: 'Edit shop details',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EditShopDetailsPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                      color: RatnexColors.hairline,
                    ),
                    _ProfileRow(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      onTap: () => _soon(context, 'Notifications'),
                    ),
                    const Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                      color: RatnexColors.hairline,
                    ),
                    _ProfileRow(
                      icon: Icons.lock_outline,
                      title: 'Privacy & security',
                      onTap: () => _soon(context, 'Privacy & security'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const RatnexSectionLabel(text: 'App'),
              const SizedBox(height: 8),
              RatnexPanel(
                child: Column(
                  children: [
                    _ProfileRow(
                      icon: Icons.info_outline,
                      title: 'About Ratnex',
                      onTap: () => _showAbout(context),
                    ),
                    const Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                      color: RatnexColors.hairline,
                    ),
                    _ProfileRow(
                      icon: Icons.help_outline,
                      title: 'Help & support',
                      onTap: () => _soon(context, 'Help & support'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Opacity(
                opacity: _isLoggingOut ? 0.6 : 1,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoggingOut ? null : _handleLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RatnexColors.down,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          RatnexColors.down.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(
                      _isLoggingOut ? 'Signing out…' : 'Logout',
                      style: RatnexTheme.label(
                        size: 14,
                        weight: FontWeight.w700,
                        color: Colors.white,
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

  void _soon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon')),
    );
  }

  Future<void> _debugGrantAdmin(BuildContext context) async {
    if (!kDebugMode) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grant Admin?'),
        content: const Text(
          'Sets your Firestore role to Admin so the Admin menu appears. '
          'Debug builds only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Grant'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await AdminUsersService().grantCurrentUserAdmin();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role set to Admin — open Profile again')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not grant Admin: $e')),
      );
    }
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'About Ratnex',
          style: RatnexTheme.label(
            size: 18,
            weight: FontWeight.w700,
            color: RatnexColors.ink,
          ),
        ),
        content: Text(
          'Ratnex is jewellery billing software for shops.\n\nVersion 1.0.7',
          style: RatnexTheme.label(size: 13, color: RatnexColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: RatnexTheme.label(
                size: 13,
                weight: FontWeight.w700,
                color: RatnexColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ProfileRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: RatnexColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RatnexTheme.label(
                      size: 13,
                      weight: FontWeight.w600,
                      color: RatnexColors.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: RatnexTheme.label(size: 11)),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: RatnexColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
