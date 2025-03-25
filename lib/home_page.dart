import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'components/navbar.dart';
import 'pages/dashboard_page.dart';
import 'pages/inventory_page.dart';
import 'pages/billing_page.dart';
import 'pages/customers_page.dart';
import 'pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // List of pages to display based on navigation bar selection
    final List<Widget> pages = [
      const DashboardPage(),
      const InventoryPage(),
      const BillingPage(),
      const CustomersPage(),
      const SettingsPage(),
    ];
    
    return Scaffold(
      body: SafeArea(
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: Navbar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
} 