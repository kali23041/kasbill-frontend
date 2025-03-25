import 'package:flutter/material.dart';

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language Settings'),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.language,
              size: 80,
              color: Colors.amber.shade700,
            ),
            const SizedBox(height: 24),
            const Text(
              'Coming Soon!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Language options will be available in the next update. Stay tuned!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 