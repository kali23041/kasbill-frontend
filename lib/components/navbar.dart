import 'package:flutter/material.dart';

class Navbar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const Navbar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      actions: actions,
    );
  }
} 