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
            margin: const EdgeInsets.only(bottom: 24.0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade100.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            height: 100,
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.red.shade800,
              ),
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 24.0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade100.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All products have sufficient stock',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        
        return Container(
          margin: const EdgeInsets.only(bottom: 24.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade100.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'Low Stock Alert',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
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
                    child: Text(
                      'Add Stock',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            count,
            style: TextStyle(
              color: Colors.red.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
} 