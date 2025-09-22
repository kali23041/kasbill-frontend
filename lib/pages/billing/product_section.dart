import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class ProductSection extends StatelessWidget {
  final List<Map<String, dynamic>> billItems;
  final VoidCallback onAddProduct;
  final Function(int) onRemoveItem;
  final Function(int, int) onChangeQuantity;
  final NumberFormat currencyFormat;

  const ProductSection({
    Key? key,
    required this.billItems,
    required this.onAddProduct,
    required this.onRemoveItem,
    required this.onChangeQuantity,
    required this.currencyFormat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Row(
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Product Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 16),
                label: const Text('Add Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: onAddProduct,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                  foregroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Items list
          if (billItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 32,
                    color: const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No items added yet',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Click "Add Product" to add items to the bill',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: billItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = billItems[index];
                return BillItemCard(
                  item: item,
                  currencyFormat: currencyFormat,
                  onRemove: () => onRemoveItem(index),
                  onDecreaseQuantity: () => onChangeQuantity(index, item['quantity'] - 1),
                  onIncreaseQuantity: () => onChangeQuantity(index, item['quantity'] + 1),
                );
              },
            ),
        ],
      ),
    );
  }
}

class BillItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final NumberFormat currencyFormat;
  final VoidCallback onRemove;
  final VoidCallback onDecreaseQuantity;
  final VoidCallback onIncreaseQuantity;

  const BillItemCard({
    Key? key,
    required this.item,
    required this.currencyFormat,
    required this.onRemove,
    required this.onDecreaseQuantity,
    required this.onIncreaseQuantity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outlined,
                  color: Color(0xFFDC2626),
                  size: 18,
                ),
                onPressed: onRemove,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${item['category']} • ${item['metal']}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${item['weight']}g',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E40AF),
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
                currencyFormat.format(item['unitPrice']),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981),
                  fontSize: 13,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    color: const Color(0xFF64748B),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: onDecreaseQuantity,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${item['quantity']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    color: const Color(0xFF64748B),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: onIncreaseQuantity,
                  ),
                ],
              ),
              Text(
                currencyFormat.format(item['totalPrice']),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProductSelectionDialog extends StatelessWidget {
  final Function(Map<String, dynamic>) onProductSelected;
  final NumberFormat currencyFormat;

  const ProductSelectionDialog({
    Key? key,
    required this.onProductSelected,
    required this.currencyFormat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final TextEditingController searchController = TextEditingController();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: StatefulBuilder(
        builder: (context, setState) {
          String searchQuery = '';
          
          return Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_outlined, color: Color(0xFF64748B), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products by name, category, or metal',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: const Icon(Icons.search_outlined, color: Color(0xFF64748B), size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_outlined, color: Color(0xFF64748B), size: 18),
                            onPressed: () {
                              searchController.clear();
                              setState(() {
                                searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              
              // Product list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(_auth.currentUser?.email)
                      .collection('products')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E40AF),
                          strokeWidth: 2,
                        ),
                      );
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading products: ${snapshot.error}',
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                      );
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No products found',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      );
                    }
                    
                    // Filter products based on search query
                    var filteredDocs = snapshot.data!.docs;
                    if (searchQuery.isNotEmpty) {
                      filteredDocs = filteredDocs.where((doc) {
                        final product = doc.data() as Map<String, dynamic>;
                        final name = product['name']?.toString().toLowerCase() ?? '';
                        final category = product['category']?['name']?.toString().toLowerCase() ?? '';
                        final metal = product['metal']?['name']?.toString().toLowerCase() ?? '';
                        
                        return name.contains(searchQuery) || 
                               category.contains(searchQuery) ||
                               metal.contains(searchQuery);
                      }).toList();
                    }
                    
                    return filteredDocs.isEmpty
                        ? Center(
                            child: Text(
                              'No products match "${searchController.text}"',
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final product = doc.data() as Map<String, dynamic>;
                              final productId = doc.id;
                              
                              // Prepare product data
                              final fullProduct = {
                                'id': productId,
                                ...product,
                              };
                              
                              final price = (product['unitPrice'] as num?)?.toDouble() ?? 0.0;
                              final metalName = product['metal']?['name'] ?? 'N/A';
                              final metalCarat = product['metal']?['carat'] ?? '';
                              final categoryName = product['category']?['name'] ?? 'N/A';
                              final imagesList = product['images'] as List<dynamic>? ?? [];
                              
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      image: imagesList.isNotEmpty
                                          ? DecorationImage(
                                              image: MemoryImage(
                                                base64Decode(imagesList.first.toString()),
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                      color: const Color(0xFFF1F5F9),
                                    ),
                                    child: imagesList.isEmpty
                                        ? const Icon(Icons.image_not_supported_outlined, color: Color(0xFF94A3B8), size: 20)
                                        : null,
                                  ),
                                  title: Text(
                                    product['name'] ?? 'Unnamed Product',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Category: $categoryName',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                      Text(
                                        'Metal: $metalName $metalCarat',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        currencyFormat.format(price),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF10B981),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.add_outlined, size: 12, color: Color(0xFF10B981)),
                                            const SizedBox(width: 2),
                                            const Text(
                                              'Add',
                                              style: TextStyle(
                                                color: Color(0xFF10B981),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    onProductSelected(fullProduct);
                                    Navigator.pop(context);
                                  },
                                  isThreeLine: true,
                                ),
                              );
                            },
                          );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 