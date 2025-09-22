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
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
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
                                icon: const Icon(Icons.close_outlined, color: Color(0xFF64748B), size: 20),
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Inventory',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                          ),
                      if (_isSelectionMode)
                        IconButton(
                          icon: const Icon(Icons.delete_outlined, color: Color(0xFFDC2626), size: 20),
                          onPressed: _selectedProducts.isNotEmpty
                            ? _deleteSelectedProducts
                            : null,
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.select_all_outlined, color: Color(0xFF64748B), size: 20),
                          onPressed: () {
                            setState(() {
                              _isSelectionMode = true;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
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
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 64,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No inventory items yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Tap the + button to start adding items',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF94A3B8),
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
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
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
                                          borderRadius: BorderRadius.circular(8),
                                          border: _isSelectionMode && _selectedProducts.contains(productId)
                                            ? Border.all(color: const Color(0xFF1E40AF), width: 2)
                                            : Border.all(color: const Color(0xFFE2E8F0)),
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
                                                    topLeft: Radius.circular(8),
                                                    topRight: Radius.circular(8),
                                                  ),
                                                  image: images.isNotEmpty
                                                    ? DecorationImage(
                                                        image: MemoryImage(
                                                          base64Decode(images.first.toString()),
                                                        ),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : null,
                                                  color: const Color(0xFFF1F5F9),
                                                ),
                                                child: images.isEmpty
                                                  ? Center(
                                                      child: Icon(
                                                        Icons.image_not_supported_outlined,
                                                        color: const Color(0xFF94A3B8),
                                                        size: 28,
                                                      ),
                                                    )
                                                  : null,
                                              ),
                                            ),
                                            
                                            // Product details
                                            Expanded(
                                              flex: 2,
                                              child: Padding(
                                                padding: const EdgeInsets.all(6.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    // Product name - truncated if too long
                                                    Text(
                                                      name,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 13,
                                                        color: Color(0xFF1E293B),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    
                                                    // Category & Metal info
                                                    Text(
                                                      '$category · $metal',
                                                      style: const TextStyle(
                                                        color: Color(0xFF64748B),
                                                        fontSize: 11,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    
                                                    // Price
                                                    Text(
                                                      '₹${price.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF10B981),
                                                        fontSize: 14,
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
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: _selectedProducts.contains(productId)
                                                ? const Color(0xFF1E40AF)
                                                : Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF1E40AF),
                                                width: 2,
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(2.0),
                                              child: Icon(
                                                Icons.check,
                                                size: 14,
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E40AF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Add Category',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                      backgroundColor: const Color(0xFF1E40AF),
                      child: const Icon(Icons.category_outlined, size: 18),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Add Metal',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                      backgroundColor: const Color(0xFF10B981),
                      child: const Icon(Icons.monitor_weight_outlined, size: 18),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Add Gemstone',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                      backgroundColor: const Color(0xFFF59E0B),
                      child: const Icon(Icons.diamond_outlined, size: 18),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Add Product',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                      backgroundColor: const Color(0xFF8B5CF6),
                      child: const Icon(Icons.add_shopping_cart_outlined, size: 18),
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
            backgroundColor: const Color(0xFF1E40AF),
            child: AnimatedRotation(
              turns: _isDialOpen ? 0.125 : 0, // 45 degrees rotation
              duration: const Duration(milliseconds: 250),
              child: const Icon(Icons.add, color: Colors.white),
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
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            title: Text(
              'Delete ${_selectedProducts.length} Products',
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: const Text(
              'Are you sure you want to delete the selected products? This action cannot be undone.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 13)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                ),
                child: const Text('Delete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete products: ${e.toString()}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }
} 