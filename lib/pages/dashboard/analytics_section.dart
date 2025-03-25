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
              margin: const EdgeInsets.only(bottom: 24.0),
              child: Row(
                children: [
                  _buildSummaryCard(
                    context,
                    title: 'Total Sales',
                    value: currencyFormat.format(totalSales),
                    icon: Icons.attach_money,
                    color: Colors.green,
                    change: salesChange,
                  ),
                  const SizedBox(width: 16),
                  _buildSummaryCard(
                    context,
                    title: 'Inventory Value',
                    value: currencyFormat.format(inventoryValue),
                    icon: Icons.diamond,
                    color: Colors.amber.shade800,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
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
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                change,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 