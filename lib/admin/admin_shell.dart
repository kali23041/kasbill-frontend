import 'package:flutter/material.dart';

import 'admin_theme.dart';
import 'components/admin_bottom_navbar.dart';
import 'pages/admin_home_page.dart';
import 'pages/admin_settings_page.dart';
import 'pages/admin_users_page.dart';
import 'services/admin_users_service.dart';

/// Dark admin console. Only open when Firestore role == Admin.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  bool _checking = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _guard();
  }

  Future<void> _guard() async {
    final ok = await AdminUsersService().currentUserIsAdmin();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin access required')),
      );
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _allowed = true;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.dark,
      child: Scaffold(
        backgroundColor: AdminColors.bg,
        body: _checking || !_allowed
            ? const Center(
                child: CircularProgressIndicator(color: AdminColors.gold),
              )
            : IndexedStack(
                index: _index,
                children: const [
                  AdminHomePage(),
                  AdminUsersPage(),
                  AdminSettingsPage(),
                ],
              ),
        bottomNavigationBar: _allowed
            ? AdminBottomNavbar(
                selectedIndex: _index,
                onItemTapped: (i) => setState(() => _index = i),
              )
            : null,
      ),
    );
  }
}
