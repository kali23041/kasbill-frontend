import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ecommerce_home_page.dart';
import 'pages/favorites_page.dart';
import 'pages/settings_page_scrap.dart';
import 'pages/profile_page.dart';
import 'components/bottom_navbar.dart';
import '../auth/login_page.dart';

class ScrapMainPage extends StatefulWidget {
  const ScrapMainPage({super.key});

  @override
  State<ScrapMainPage> createState() => _ScrapMainPageState();
}

class _ScrapMainPageState extends State<ScrapMainPage> {
  int _selectedIndex = 0;
  User? _currentUser;

  // List of pages - using separate widget classes for each page with state preservation
  // Initialize in initState to ensure proper state management
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const EcommerceHomePageContent(), // Home page content only
      const FavoritesPageContent(), // Wrapped with state preservation
      const SettingsPageScrapContent(), // Wrapped with state preservation
      const ProfilePageContent(), // Wrapped with state preservation
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
            child: BottomNavbar(
              selectedIndex: _selectedIndex,
              onItemTapped: _onItemTapped,
            ),
          ),
        );
  }
}

// Extract the content part of EcommerceHomePage
class EcommerceHomePageContent extends StatefulWidget {
  const EcommerceHomePageContent({super.key});

  @override
  State<EcommerceHomePageContent> createState() => _EcommerceHomePageContentState();
}

class _EcommerceHomePageContentState extends State<EcommerceHomePageContent> with AutomaticKeepAliveClientMixin {
  // Keep state alive when switching tabs
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    // Return the EcommerceHomePage without Scaffold and bottomNavigationBar
    return const EcommerceHomePage(showNavbar: false);
  }
}

// Wrapper for FavoritesPage with state preservation
class FavoritesPageContent extends StatefulWidget {
  const FavoritesPageContent({super.key});

  @override
  State<FavoritesPageContent> createState() => _FavoritesPageContentState();
}

class _FavoritesPageContentState extends State<FavoritesPageContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const FavoritesPage();
  }
}

// Wrapper for SettingsPageScrap with state preservation
class SettingsPageScrapContent extends StatefulWidget {
  const SettingsPageScrapContent({super.key});

  @override
  State<SettingsPageScrapContent> createState() => _SettingsPageScrapContentState();
}

class _SettingsPageScrapContentState extends State<SettingsPageScrapContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SettingsPageScrap();
  }
}

// Wrapper for ProfilePage with state preservation
class ProfilePageContent extends StatefulWidget {
  const ProfilePageContent({super.key});

  @override
  State<ProfilePageContent> createState() => _ProfilePageContentState();
}

class _ProfilePageContentState extends State<ProfilePageContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const ProfilePage();
  }
}

