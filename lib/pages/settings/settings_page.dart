import 'package:flutter/material.dart';
import '../../components/navbar.dart';
import '../../components/app_drawer.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Navbar(
          title: 'Settings',
          actions: [],
        ),
      ),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text(
          'Settings Page Content',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
} 