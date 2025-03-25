import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inventory/add_category_page.dart';
import 'inventory/add_metal_page.dart';
import 'inventory/add_gemstone_page.dart';
import 'inventory/add_product_page.dart';
import 'dart:convert';
import 'dart:ui';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isDialOpen = false;
  bool _isSelectionMode = false;
  Set<String> _selectedProducts = {};
  
  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _isSelectionMode
                        ? Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _isSelectionMode = false;
                                    _selectedProducts.clear();
                                  });
                                },
                              ),
                              Text(
                                '${_selectedProducts.length} Selected',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Inventory',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      if (_isSelectionMode)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: _selectedProducts.isNotEmpty
                            ? _deleteSelectedProducts
                            : null,
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.select_all),
                          onPressed: () {
                            setState(() {
                              _isSelectionMode = true;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Product listing section
                  Expanded(
                    child: currentUser != null && currentUser.email != null
                      ? StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('users')
                              .doc(currentUser.email)
                              .collection('products')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error loading products: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              );
                            }
                            
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 80,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No inventory items yet',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap the + button to start adding items',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            
                            final products = snapshot.data!.docs;
                            
                            return GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final product = products[index].data() as Map<String, dynamic>;
                                final productId = products[index].id;
                                
                                final String name = product['name'] ?? 'Unnamed Product';
                                final String category = product['category']?['name'] ?? '';
                                final String metal = product['metal']?['name'] ?? '';
                                final double price = (product['unitPrice'] as num?)?.toDouble() ?? 0.0;
                                final List<dynamic> images = product['images'] ?? [];
                                
                                return InkWell(
                                  onTap: () {
                                    if (_isSelectionMode) {
                                      setState(() {
                                        if (_selectedProducts.contains(productId)) {
                                          _selectedProducts.remove(productId);
                                          if (_selectedProducts.isEmpty) {
                                            _isSelectionMode = false;
                                          }
                                        } else {
                                          _selectedProducts.add(productId);
                                        }
                                      });
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AddProductPage(
                                            editProductId: productId,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  onLongPress: () {
                                    if (!_isSelectionMode) {
                                      setState(() {
                                        _isSelectionMode = true;
                                        _selectedProducts.add(productId);
                                      });
                                    }
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: _isSelectionMode && _selectedProducts.contains(productId)
                                            ? Border.all(color: Colors.blue, width: 2)
                                            : null,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.withOpacity(0.1),
                                              blurRadius: 10,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Product image
                                            Expanded(
                                              flex: 3,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: const BorderRadius.only(
                                                    topLeft: Radius.circular(12),
                                                    topRight: Radius.circular(12),
                                                  ),
                                                  image: images.isNotEmpty
                                                    ? DecorationImage(
                                                        image: MemoryImage(
                                                          base64Decode(images.first.toString()),
                                                        ),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : null,
                                                  color: Colors.grey.shade100,
                                                ),
                                                child: images.isEmpty
                                                  ? Center(
                                                      child: Icon(
                                                        Icons.image_not_supported_outlined,
                                                        color: Colors.grey.shade400,
                                                        size: 36,
                                                      ),
                                                    )
                                                  : null,
                                              ),
                                            ),
                                            
                                            // Product details
                                            Expanded(
                                              flex: 2,
                                              child: Padding(
                                                padding: const EdgeInsets.all(10.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    // Product name - truncated if too long
                                                    Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    
                                                    // Category & Metal info
                                                    Text(
                                                      '$category · $metal',
                                                      style: TextStyle(
                                                        color: Colors.grey.shade600,
                                                        fontSize: 12,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    
                                                    // Price
                                                    Text(
                                                      '₹${price.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.green.shade700,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_isSelectionMode)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: _selectedProducts.contains(productId)
                                                ? Colors.blue
                                                : Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.blue,
                                                width: 2,
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(2.0),
                                              child: Icon(
                                                Icons.check,
                                                size: 16,
                                                color: _selectedProducts.contains(productId)
                                                  ? Colors.white
                                                  : Colors.transparent,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        )
                      : const Center(
                          child: Text('Please log in to view your inventory'),
                        ),
                  ),
                ],
              ),
            ),
          ),
          
          // Dark overlay when menu is open
          AnimatedOpacity(
            opacity: _isDialOpen ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: _isDialOpen 
              ? Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDialOpen = false;
                      });
                    },
                    child: Container(
                      color: Colors.black,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Category button
          AnimatedSlide(
            offset: _isDialOpen ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 250),
            child: AnimatedOpacity(
              opacity: _isDialOpen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade500,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Add Category',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    FloatingActionButton.small(
                      heroTag: 'category',
                      onPressed: () {
                        setState(() {
                          _isDialOpen = false;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddCategoryPage()),
                        );
                      },
                      backgroundColor: Colors.purple.shade500,
                      child: const Icon(Icons.category),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Metal button
          AnimatedSlide(
            offset: _isDialOpen ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 250),
            child: AnimatedOpacity(
              opacity: _isDialOpen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade500,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Add Metal',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    FloatingActionButton.small(
                      heroTag: 'metal',
                      onPressed: () {
                        setState(() {
                          _isDialOpen = false;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddMetalPage()),
                        );
                      },
                      backgroundColor: Colors.blue.shade500,
                      child: const Icon(Icons.monitor_weight),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Gemstone button
          AnimatedSlide(
            offset: _isDialOpen ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 250),
            child: AnimatedOpacity(
              opacity: _isDialOpen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade500,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Add Gemstone',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    FloatingActionButton.small(
                      heroTag: 'gemstone',
                      onPressed: () {
                        setState(() {
                          _isDialOpen = false;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddGemstonePage()),
                        );
                      },
                      backgroundColor: Colors.teal.shade500,
                      child: const Icon(Icons.diamond),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Product button
          AnimatedSlide(
            offset: _isDialOpen ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 250),
            child: AnimatedOpacity(
              opacity: _isDialOpen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade500,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Add Product',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    FloatingActionButton.small(
                      heroTag: 'product',
                      onPressed: () {
                        setState(() {
                          _isDialOpen = false;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddProductPage()),
                        );
                      },
                      backgroundColor: Colors.green.shade500,
                      child: const Icon(Icons.add_shopping_cart),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Main FAB - toggle button
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _isDialOpen = !_isDialOpen;
              });
            },
            backgroundColor: Colors.amber.shade700,
            child: AnimatedRotation(
              turns: _isDialOpen ? 0.125 : 0, // 45 degrees rotation
              duration: const Duration(milliseconds: 250),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedProducts() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Delete ${_selectedProducts.length} Products',
              style: TextStyle(color: Colors.red.shade800),
            ),
            content: const Text(
              'Are you sure you want to delete the selected products? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          // Delete all selected products
          await Future.wait(
            _selectedProducts.map((productId) => 
              _firestore
                .collection('users')
                .doc(currentUser.email)
                .collection('products')
                .doc(productId)
                .delete()
            ),
          );

          setState(() {
            _isSelectionMode = false;
            _selectedProducts.clear();
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selected products deleted successfully'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete products: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 