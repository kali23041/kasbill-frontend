import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsSection extends StatelessWidget {
  final NumberFormat currencyFormat;
  
  const AnalyticsSection({
    super.key,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final String? userEmail = _auth.currentUser?.email;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(userEmail)
          .collection('products')
          .snapshots(),
      builder: (context, productSnapshot) {
        // Calculate inventory value from products
        double inventoryValue = 0.0;
        if (productSnapshot.hasData) {
          for (var doc in productSnapshot.data!.docs) {
            final product = doc.data() as Map<String, dynamic>;
            final price = (product['totalPrice'] as num?)?.toDouble() ?? 0.0;
            inventoryValue += price;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('users')
              .doc(userEmail)
              .collection('bills')
              .snapshots(),
          builder: (context, billsSnapshot) {
            // Calculate total sales from bills
            double totalSales = 0.0;
            int billCount = 0;
            
            if (billsSnapshot.hasData) {
              billCount = billsSnapshot.data!.docs.length;
              for (var doc in billsSnapshot.data!.docs) {
                final bill = doc.data() as Map<String, dynamic>;
                final total = (bill['total'] as num?)?.toDouble() ?? 0.0;
                totalSales += total;
              }
            }
            
            // Calculate percentage change (placeholder for now)
            String salesChange = billCount > 0 ? "+${billCount} bills" : "No sales yet";

            return Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  _buildSummaryCard(
                    context,
                    title: 'Total Sales',
                    value: currencyFormat.format(totalSales),
                    icon: Icons.trending_up_outlined,
                    color: const Color(0xFF10B981),
                    change: salesChange,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    context,
                    title: 'Inventory Value',
                    value: currencyFormat.format(inventoryValue),
                    icon: Icons.inventory_outlined,
                    color: const Color(0xFF1E40AF),
                    change: '${productSnapshot.hasData ? productSnapshot.data!.docs.length : 0} items',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Summary card (Sales, Inventory, etc.)
  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String change,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                change,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 