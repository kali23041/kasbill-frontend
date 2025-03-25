import 'package:flutter/material.dart';

class AddCategoryPage extends StatelessWidget {
  const AddCategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Category'),
        backgroundColor: Colors.purple.shade500,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Category form will be implemented here'),
      ),
    );
  }
} 