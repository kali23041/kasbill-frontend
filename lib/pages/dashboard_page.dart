import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard/analytics_section.dart';
import 'dashboard/quick_actions_section.dart';
import 'dashboard/recent_sales_section.dart';
import 'dashboard/low_stock_section.dart';
import 'dashboard/upcoming_orders_section.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This should only be called when the app starts, not on every tab switch
    if (!_hasShownDialog) {
      _checkRatesUpdate();
      _hasShownDialog = true;
    }
  }
  
  bool _hasShownDialog = false;
  
  // Replace initState with didChangeDependencies to ensure context is ready
  @override
  void initState() {
    super.initState();
    // Remove the postFrameCallback to avoid showing on every tab change
  }
  
  Future<void> _checkRatesUpdate() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) return;
    
    try {
      // Get all metals to check if they exist
      final metalsSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.email)
          .collection('metals')
          .get();
      
      // Only show the dialog if there are metals in the system
      if (metalsSnapshot.docs.isNotEmpty && mounted) {
        _showUpdateRatesDialog();
      }
    } catch (e) {
      // Silently fail - no need to bother user with errors here
    }
  }
  
  void _showUpdateRatesDialog() {
    // Use shared preferences to check if we already showed dialog today
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.update, color: Colors.amber.shade800, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Update Metal Rates',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade300),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Would you like to update today\'s metal rates?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'This will automatically update all product prices based on current metal rates.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Later',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/rates');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String userName = currentUser?.displayName ?? 'Jewelry Manager';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with greeting and logout button
          Container(
            margin: const EdgeInsets.only(bottom: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kasbill By Kartik Sabale',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.grey),
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error signing out: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          
          // Summary Cards - replaced with AnalyticsSection
          AnalyticsSection(currencyFormat: currencyFormat),
          
          // Quick Actions - replaced with QuickActionsSection
          const QuickActionsSection(),
          
          // Recent Sales Section - replaced with RecentSalesSection
          RecentSalesSection(currencyFormat: currencyFormat),
          
          // Low Stock Alert - replaced with LowStockSection
          const LowStockSection(),
          
          // Upcoming Orders - replaced with UpcomingOrdersSection
          // const UpcomingOrdersSection(),
        ],
      ),
    );
  }
} 