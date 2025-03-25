import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard/analytics_section.dart';
import 'dashboard/quick_actions_section.dart';
import 'dashboard/recent_sales_section.dart';
import 'dashboard/low_stock_section.dart';
import 'dashboard/upcoming_orders_section.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

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