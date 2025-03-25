import 'package:flutter/material.dart';

class AddGemstonePage extends StatelessWidget {
  const AddGemstonePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Gemstone'),
        backgroundColor: Colors.teal.shade500,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Gemstone form will be implemented here'),
      ),
    );
  }
} 