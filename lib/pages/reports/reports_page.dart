import 'package:flutter/material.dart';
import '../../components/navbar.dart';
import '../../components/app_drawer.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Navbar(
          title: 'Reports',
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                // Export report action
              },
            ),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text(
          'Reports Page Content',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
} 