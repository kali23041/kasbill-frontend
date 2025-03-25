import 'package:flutter/material.dart';

class AddMetalPage extends StatelessWidget {
  const AddMetalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Metal'),
        backgroundColor: Colors.blue.shade500,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Metal form will be implemented here'),
      ),
    );
  }
} 