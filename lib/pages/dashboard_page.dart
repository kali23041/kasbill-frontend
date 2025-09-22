import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard/analytics_section.dart';
import 'dashboard/quick_actions_section.dart';
import 'dashboard/recent_sales_section.dart';
import 'dashboard/low_stock_section.dart';
import 'dashboard/upcoming_orders_section.dart';
import 'rates_page.dart';
import '../utils/update_checker.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with AutomaticKeepAliveClientMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Static flag to track across all instances of dashboard
  static bool _hasShownDialogThisSession = false;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    // Check for app updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdates(context);
      
      // Only check for rates update if we haven't shown the dialog yet
      if (!_hasShownDialogThisSession) {
        _checkRatesUpdate();
      }
    });
  }
  
  Future<void> _checkRatesUpdate() async {
    // Skip if dialog already shown this app session
    if (_hasShownDialogThisSession) return;
    
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
      if (metalsSnapshot.docs.isNotEmpty && mounted && !_hasShownDialogThisSession) {
        _hasShownDialogThisSession = true; // Set flag before showing dialog
        _showUpdateRatesDialog();
      }
    } catch (e) {
      // Silently fail - no need to bother user with errors here
    }
  }
  
  void _showUpdateRatesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.update_outlined, color: Color(0xFF1E40AF), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: const Text(
                    'Update Metal Rates',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Color(0xFFE2E8F0)),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Would you like to update today\'s metal rates?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will automatically update all product prices based on current metal rates.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
            ),
            child: const Text('Later', style: TextStyle(fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const RatesPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Update Now', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String userName = currentUser?.displayName ?? 'Jewelry Manager';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with greeting and logout button
            Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kasbill By Kartik Sabale',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_outlined, color: Color(0xFF64748B), size: 20),
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error signing out: $e'),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
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
      ),
    );
  }
} 