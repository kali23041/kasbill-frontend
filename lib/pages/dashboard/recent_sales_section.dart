import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../billing/bills_list_page.dart';
import '../billing/bill_details_sheet.dart';

class RecentSalesSection extends StatelessWidget {
  final NumberFormat currencyFormat;

  const RecentSalesSection({
    super.key,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final String? userEmail = _auth.currentUser?.email;
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Sales',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BillsListPage()),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1E40AF),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(userEmail)
                .collection('bills')
                .orderBy('date', descending: true)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 32,
                          color: const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No sales recorded yet',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final billData = doc.data() as Map<String, dynamic>;
                  
                  // Handle timestamp conversion
                  DateTime date;
                  if (billData['date'] is Timestamp) {
                    date = (billData['date'] as Timestamp).toDate();
                  } else {
                    date = DateTime.now();
                  }
                  
                  final customerName = billData['customer']?['name'] ?? 'Walk-in Customer';
                  final total = (billData['total'] as num?)?.toDouble() ?? 0.0;
                  
                  // Get first item or default text
                  String itemName = 'Unknown item';
                  if (billData['items'] != null && (billData['items'] as List).isNotEmpty) {
                    itemName = (billData['items'] as List).first['name'] ?? 'Unknown item';
                  }
                  
                  return Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => BillDetailsSheet(
                              billData: billData,
                              currencyFormat: currencyFormat,
                              dateFormat: dateFormat,
                            ),
                          );
                        },
                        child: _buildRecentSaleCard(
                          customerName: customerName,
                          itemName: itemName,
                          date: dateFormat.format(date),
                          amount: currencyFormat.format(total),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // Recent sale card
  Widget _buildRecentSaleCard({
    required String customerName,
    required String itemName,
    required String date,
    required String amount,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1E40AF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                customerName.substring(0, 1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  itemName,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
} 