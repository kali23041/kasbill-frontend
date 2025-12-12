import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_home_page.dart';
import 'pages/admin_items_page.dart';
import 'pages/admin_settings_page.dart';
import 'pages/admin_profile_page.dart';
import 'components/admin_bottom_navbar.dart';
import '../auth/login_page.dart';

class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  int _selectedIndex = 0;
  User? _currentUser;

  // List of pages - using separate widget classes for each page with state preservation
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const AdminHomePageContent(), // Home page content only
      const AdminItemsPageContent(), // Items page with state preservation
      const AdminSettingsPageContent(), // Settings page with state preservation
      const AdminProfilePageContent(), // Profile page with state preservation
    ];
    
    // Check initial auth state
    _currentUser = FirebaseAuth.instance.currentUser;
    
    // Listen to auth changes only for logout detection
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null && mounted) {
        // User logged out, redirect to login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      } else {
        // Update current user without rebuilding
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      }
    });
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If user is null, show loading (will redirect in listener)
    if (_currentUser == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }
    
    // User is authenticated, show the main page
    return Scaffold(
      backgroundColor: Colors.black,
      body: RepaintBoundary(
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: RepaintBoundary(
        child: AdminBottomNavbar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }
}

// Wrapper for AdminHomePage with state preservation
class AdminHomePageContent extends StatefulWidget {
  const AdminHomePageContent({super.key});

  @override
  State<AdminHomePageContent> createState() => _AdminHomePageContentState();
}

class _AdminHomePageContentState extends State<AdminHomePageContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const AdminHomePage();
  }
}

// Wrapper for AdminItemsPage with state preservation
class AdminItemsPageContent extends StatefulWidget {
  const AdminItemsPageContent({super.key});

  @override
  State<AdminItemsPageContent> createState() => _AdminItemsPageContentState();
}

class _AdminItemsPageContentState extends State<AdminItemsPageContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const AdminItemsPage();
  }
}

// Wrapper for AdminSettingsPage with state preservation
class AdminSettingsPageContent extends StatefulWidget {
  const AdminSettingsPageContent({super.key});

  @override
  State<AdminSettingsPageContent> createState() => _AdminSettingsPageContentState();
}

class _AdminSettingsPageContentState extends State<AdminSettingsPageContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const AdminSettingsPage();
  }
}

// Wrapper for AdminProfilePage with state preservation
class AdminProfilePageContent extends StatefulWidget {
  const AdminProfilePageContent({super.key});

  @override
  State<AdminProfilePageContent> createState() => _AdminProfilePageContentState();
}

class _AdminProfilePageContentState extends State<AdminProfilePageContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const AdminProfilePage();
  }
}
