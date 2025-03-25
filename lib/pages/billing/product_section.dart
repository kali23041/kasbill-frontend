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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Product Items',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Add Product'),
              onPressed: onAddProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Items list
        if (billItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'No items added yet',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Click "Add Product" to add items to the bill',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
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
            separatorBuilder: (context, index) => const SizedBox(height: 8),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
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
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade400,
                  size: 20,
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
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${item['weight']}g',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currencyFormat.format(item['unitPrice']),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.grey.shade700,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: onDecreaseQuantity,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${item['quantity']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: Colors.grey.shade700,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: onIncreaseQuantity,
                  ),
                ],
              ),
              Text(
                currencyFormat.format(item['totalPrice']),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
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
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
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
                    Text(
                      'Add Products',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
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
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setState(() {
                                searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
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
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error loading products: ${snapshot.error}'),
                      );
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('No products found'),
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
                            child: Text('No products match "${searchController.text}"'),
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
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: ListTile(
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: imagesList.isNotEmpty
                                          ? DecorationImage(
                                              image: MemoryImage(
                                                base64Decode(imagesList.first.toString()),
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                      color: Colors.grey.shade200,
                                    ),
                                    child: imagesList.isEmpty
                                        ? Icon(Icons.image_not_supported, color: Colors.grey.shade400)
                                        : null,
                                  ),
                                  title: Text(
                                    product['name'] ?? 'Unnamed Product',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Category: $categoryName'),
                                      Text('Metal: $metalName $metalCarat'),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        currencyFormat.format(price),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add, size: 14, color: Colors.green.shade700),
                                            const SizedBox(width: 2),
                                            Text(
                                              'Add',
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
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