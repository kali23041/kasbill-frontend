import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inventory/add_category_page.dart';
import 'inventory/add_metal_page.dart';
import 'inventory/add_gemstone_page.dart';
import 'inventory/add_product_page.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isDialOpen = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _toggleDial() {
    setState(() {
      _isDialOpen = !_isDialOpen;
      if (_isDialOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }
  
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
                  const Text(
                    'Inventory',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Placeholder content (to be replaced with actual inventory items)
                  Expanded(
                    child: Center(
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
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Dark overlay when menu is open
          if (_isDialOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isDialOpen = false;
                  });
                },
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Only show these when the menu is open
          if (_isDialOpen) ...[
            // Category button
            Padding(
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
            
            // Metal button
            Padding(
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
            
            // Gemstone button
            Padding(
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
            
            // Product button
            Padding(
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
          ],
          
          // Main FAB - toggle button
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _isDialOpen = !_isDialOpen;
              });
            },
            backgroundColor: Colors.amber.shade700,
            child: Icon(
              _isDialOpen ? Icons.close : Icons.add,
            ),
          ),
        ],
      ),
    );
  }
} 