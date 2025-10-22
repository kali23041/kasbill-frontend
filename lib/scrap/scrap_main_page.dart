import 'package:flutter/material.dart';
import 'ecommerce_home_page.dart';
import 'pages/favorites_page.dart';
import 'pages/settings_page_scrap.dart';
import 'pages/profile_page.dart';
import 'components/bottom_navbar.dart';

class ScrapMainPage extends StatefulWidget {
  const ScrapMainPage({super.key});

  @override
  State<ScrapMainPage> createState() => _ScrapMainPageState();
}

class _ScrapMainPageState extends State<ScrapMainPage> {
  int _selectedIndex = 0;

  // List of pages - using separate widget classes for each page
  final List<Widget> _pages = [
    const EcommerceHomePageContent(), // Home page content only
    const FavoritesPage(),
    const SettingsPageScrap(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavbar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
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

