import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  
  void _showAddCategoryDialog() {
    _toggleDial();
    // Show dialog to add category
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Category',
          style: TextStyle(color: Colors.amber.shade800),
        ),
        content: const Text('Category dialog will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showAddMetalDialog() {
    _toggleDial();
    // Show dialog to add metal
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Metal',
          style: TextStyle(color: Colors.amber.shade800),
        ),
        content: const Text('Metal dialog will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showAddGemstoneDialog() {
    _toggleDial();
    // Show dialog to add gemstone
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Gemstone',
          style: TextStyle(color: Colors.amber.shade800),
        ),
        content: const Text('Gemstone dialog will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showAddProductDialog() {
    _toggleDial();
    // Show dialog to add product
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Product',
          style: TextStyle(color: Colors.amber.shade800),
        ),
        content: const Text('Product dialog will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
          
          // Overlay that darkens only the page content
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Positioned.fill(
                child: IgnorePointer(
                  ignoring: _animation.value == 0,
                  child: GestureDetector(
                    onTap: _toggleDial,
                    child: Container(
                      color: Colors.black.withOpacity(0.5 * _animation.value),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // Add Category FAB with Label
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -225 * _animation.value),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Label
                    AnimatedOpacity(
                      opacity: _animation.value,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
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
                    ),
                    // Button
                    Transform.scale(
                      scale: _animation.value,
                      child: Opacity(
                        opacity: _animation.value,
                        child: FloatingActionButton.small(
                          heroTag: 'category',
                          onPressed: _showAddCategoryDialog,
                          backgroundColor: Colors.purple.shade500,
                          child: const Icon(Icons.category),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Add Metal FAB with Label
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -170 * _animation.value),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Label
                    AnimatedOpacity(
                      opacity: _animation.value,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
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
                    ),
                    // Button
                    Transform.scale(
                      scale: _animation.value,
                      child: Opacity(
                        opacity: _animation.value,
                        child: FloatingActionButton.small(
                          heroTag: 'metal',
                          onPressed: _showAddMetalDialog,
                          backgroundColor: Colors.blue.shade500,
                          child: const Icon(Icons.monitor_weight),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Add Gemstone FAB with Label
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -115 * _animation.value),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Label
                    AnimatedOpacity(
                      opacity: _animation.value,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
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
                    ),
                    // Button
                    Transform.scale(
                      scale: _animation.value,
                      child: Opacity(
                        opacity: _animation.value,
                        child: FloatingActionButton.small(
                          heroTag: 'gemstone',
                          onPressed: _showAddGemstoneDialog,
                          backgroundColor: Colors.teal.shade500,
                          child: const Icon(Icons.diamond),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Add Product FAB with Label
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -60 * _animation.value),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Label
                    AnimatedOpacity(
                      opacity: _animation.value,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
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
                    ),
                    // Button
                    Transform.scale(
                      scale: _animation.value,
                      child: Opacity(
                        opacity: _animation.value,
                        child: FloatingActionButton.small(
                          heroTag: 'product',
                          onPressed: _showAddProductDialog,
                          backgroundColor: Colors.green.shade500,
                          child: const Icon(Icons.add_shopping_cart),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Main FAB
          FloatingActionButton(
            onPressed: _toggleDial,
            backgroundColor: Colors.amber.shade700,
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _animation,
            ),
          ),
        ],
      ),
    );
  }
} 