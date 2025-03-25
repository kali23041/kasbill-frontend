import 'package:flutter/material.dart';
import '../components/bottom_navbar.dart';
import '../components/navbar.dart';
import 'home/home_page.dart';
import 'billing/billing_page.dart';
import 'inventory/inventory_page.dart';
import 'customers/customers_page.dart';
import 'more/more_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const HomePage(),
    const BillingPage(),
    const InventoryPage(),
    const CustomersPage(),
    const MorePage(),
  ];
  
  final List<String> _titles = [
    'Dashboard',
    'Billing',
    'Inventory',
    'Customers',
    'More Options',
  ];

  void _onNavItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Navbar(
          title: _titles[_currentIndex],
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                child: IconButton(
                  icon: Icon(
                    Icons.account_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    // User profile action
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: BottomNavbar(
        currentIndex: _currentIndex,
        onTap: _onNavItemTapped,
      ),
    );
  }
} 