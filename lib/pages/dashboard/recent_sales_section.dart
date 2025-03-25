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
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Sales',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BillsListPage()),
                  );
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
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
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No sales recorded yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
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
                      const SizedBox(height: 12),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                customerName.substring(0, 1),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  itemName,
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
} 