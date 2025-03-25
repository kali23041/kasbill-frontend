import 'package:flutter/material.dart';

class AddProductPage extends StatelessWidget {
  const AddProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Product'),
        backgroundColor: Colors.green.shade500,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Product form will be implemented here'),
      ),
    );
  }
} 