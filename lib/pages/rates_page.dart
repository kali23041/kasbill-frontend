import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RatesPage extends StatefulWidget {
  const RatesPage({super.key});

  @override
  State<RatesPage> createState() => _RatesPageState();
}

class _RatesPageState extends State<RatesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _updateRate(String metalId, double currentRate) async {
    final TextEditingController rateController = TextEditingController(text: currentRate.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Update Rate',
          style: TextStyle(
            color: Colors.amber.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: rateController,
              decoration: InputDecoration(
                labelText: 'Rate (per gram)',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.amber.shade500, width: 2),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            Text(
              'This will update the metal rate and all products using this metal.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final String newRateText = rateController.text.trim();
              final double? newRate = double.tryParse(newRateText);
              
              if (newRate == null || newRate <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid rate'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              final String? userEmail = _auth.currentUser?.email;
              if (userEmail != null) {
                try {
                  // Close the dialog
                  Navigator.of(context).pop();
                  _showProgressDialog('Updating rates...');
                  
                  // Create batch for faster updates
                  final batch = _firestore.batch();
                  
                  // 1. Update metal rate
                  final metalRef = _firestore
                    .collection('users')
                    .doc(userEmail)
                    .collection('metals')
                    .doc(metalId);
                    
                  batch.update(metalRef, {
                    'rate': newRate,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  
                  // 2. Get all products with this metal
                  final productsSnapshot = await _firestore
                    .collection('users')
                    .doc(userEmail)
                    .collection('products')
                    .where('metal.id', isEqualTo: metalId)
                    .get();
                  
                  // 3. Update each product price in the batch
                  int updatedProductsCount = 0;
                  for (final doc in productsSnapshot.docs) {
                    final product = doc.data();
                    final weight = (product['weight'] as num).toDouble();
                    final makingCharge = (product['makingCharge'] as num).toDouble();
                    final otherCharges = (product['otherCharges'] as num).toDouble();
                    final discount = (product['discount'] as num).toDouble();
                    final quantity = (product['quantity'] as num).toInt();
                    
                    // Calculate new prices
                    double metalCost = weight * newRate;
                    double makingCost = (makingCharge * metalCost) / 100;
                    double totalBeforeDiscount = metalCost + makingCost + otherCharges;
                    double discountAmount = (discount * totalBeforeDiscount) / 100;
                    double singleItemPrice = totalBeforeDiscount - discountAmount;
                    double totalPrice = singleItemPrice * quantity;
                    
                    // Add update to batch
                    final productRef = _firestore
                      .collection('users')
                      .doc(userEmail)
                      .collection('products')
                      .doc(doc.id);
                      
                    batch.update(productRef, {
                      'metal.rate': newRate,
                      'unitPrice': singleItemPrice,
                      'totalPrice': totalPrice,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    
                    updatedProductsCount++;
                  }
                  
                  // Commit all updates in a single batch
                  await batch.commit();
                  
                  // Dismiss progress dialog
                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Rate updated successfully. Updated $updatedProductsCount products.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  // Dismiss progress dialog
                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update rate: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
  
  void _showProgressDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.amber.shade700),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateAllProductRates() async {
    final String? userEmail = _auth.currentUser?.email;
    if (userEmail == null) return;
    
    try {
      _showProgressDialog('Updating all products...');
      
      // Get all metals
      final metalsSnapshot = await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('metals')
          .get();
      
      int totalUpdatedProducts = 0;
      
      // Create a batch for faster updates
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;
      
      // For each metal, update all related products
      for (final metalDoc in metalsSnapshot.docs) {
        final metal = metalDoc.data();
        final metalId = metalDoc.id;
        final metalRate = (metal['rate'] as num).toDouble();
        
        // Get products for this metal
        final productsSnapshot = await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('products')
          .where('metal.id', isEqualTo: metalId)
          .get();
        
        // Update each product
        for (final productDoc in productsSnapshot.docs) {
          final product = productDoc.data();
          final weight = (product['weight'] as num).toDouble();
          final makingCharge = (product['makingCharge'] as num).toDouble();
          final otherCharges = (product['otherCharges'] as num).toDouble();
          final discount = (product['discount'] as num).toDouble();
          final quantity = (product['quantity'] as num).toInt();
          
          // Calculate new prices
          double metalCost = weight * metalRate;
          double makingCost = (makingCharge * metalCost) / 100;
          double totalBeforeDiscount = metalCost + makingCost + otherCharges;
          double discountAmount = (discount * totalBeforeDiscount) / 100;
          double singleItemPrice = totalBeforeDiscount - discountAmount;
          double totalPrice = singleItemPrice * quantity;
          
          // Add update to batch
          final productRef = _firestore
            .collection('users')
            .doc(userEmail)
            .collection('products')
            .doc(productDoc.id);
            
          batch.update(productRef, {
            'metal.rate': metalRate,
            'unitPrice': singleItemPrice,
            'totalPrice': totalPrice,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          batchCount++;
          totalUpdatedProducts++;
          
          // Firestore allows max 500 operations in a batch
          if (batchCount >= 450) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
      }
      
      // Commit any remaining updates in the batch
      if (batchCount > 0) {
        await batch.commit();
      }
      
      // Dismiss progress dialog
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated prices for $totalUpdatedProducts products'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Dismiss progress dialog
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product rates: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? userEmail = _auth.currentUser?.email;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Metal Rates',
          style: TextStyle(
            color: Colors.amber.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.amber.shade800),
        actions: [
          TextButton.icon(
            onPressed: _updateAllProductRates,
            icon: Icon(Icons.update, color: Colors.amber.shade800),
            label: Text(
              'Update All Products',
              style: TextStyle(color: Colors.amber.shade800),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 80.0, 16.0, 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search metals...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.amber.shade500, width: 2),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          // Info card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.monetization_on,
                      color: Colors.amber.shade800,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Metal Rates',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap on any metal to update its current rate per gram',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Metals list
          Expanded(
            child: userEmail != null
                ? StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(userEmail)
                        .collection('metals')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.monetization_on_outlined,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No metals found',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add metals from the inventory section',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      // Filter metals based on search query
                      final filteredDocs = _searchQuery.isEmpty
                          ? snapshot.data!.docs
                          : snapshot.data!.docs.where((doc) {
                              final metal = doc.data() as Map<String, dynamic>;
                              final name = metal['name']?.toString().toLowerCase() ?? '';
                              final carat = metal['carat']?.toString().toLowerCase() ?? '';
                              
                              return name.contains(_searchQuery) || carat.contains(_searchQuery);
                            }).toList();
                      
                      if (filteredDocs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 70,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No matching metals',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final metal = doc.data() as Map<String, dynamic>;
                          final metalId = doc.id;
                          final rate = (metal['rate'] as num?)?.toDouble() ?? 0.0;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
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
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _updateRate(metalId, rate),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.monetization_on,
                                            size: 30,
                                            color: Colors.amber.shade800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  metal['name'] ?? 'Unknown Metal',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    metal['carat'] ?? '',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.amber.shade800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Current Rate',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                Text(
                                                  '${currencyFormat.format(rate)}/g',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        color: Colors.amber.shade800,
                                        onPressed: () => _updateRate(metalId, rate),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )
                : const Center(
                    child: Text('Please log in to view metal rates'),
                  ),
          ),
        ],
      ),
    );
  }
} 