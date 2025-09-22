import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../inventory/add_product_page.dart';

class LowStockSection extends StatelessWidget {
  final int lowStockThreshold;
  
  const LowStockSection({
    super.key,
    this.lowStockThreshold = 5,  // Default threshold for low stock
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
          .where('quantity', isLessThanOrEqualTo: lowStockThreshold)
          .orderBy('quantity')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            height: 80,
            child: Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF1E40AF),
                strokeWidth: 2,
              ),
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: const Text(
                    'All products have sufficient stock',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_outlined, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Low Stock Alert',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddProductPage()),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text(
                      'Add Stock',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              
              Column(
                children: snapshot.data!.docs.map((doc) {
                  final product = doc.data() as Map<String, dynamic>;
                  final productName = product['name'] ?? 'Unnamed Product';
                  final quantity = product['quantity'] ?? 0;
                  
                  return Column(
                    children: [
                      _buildLowStockItem(
                        productName, 
                        '$quantity item${quantity == 1 ? '' : 's'} left'
                      ),
                      if (doc != snapshot.data!.docs.last) const Divider(),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // Low stock item row
  Widget _buildLowStockItem(String name, String count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            count,
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
} 