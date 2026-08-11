import 'package:flutter/material.dart';

import '../admin_theme.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text('Settings', style: AdminTheme.brand(size: 32)),
          const SizedBox(height: 4),
          Text(
            'Admin console',
            style: AdminTheme.label(size: 13),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminColors.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About',
                  style: AdminTheme.label(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AdminColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ratnex Admin manages shop roles and subscription expiry. '
                  'Shop apps read planStatus and planExpiresOn from Firestore.',
                  style: AdminTheme.label(size: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.logout),
              label: const Text('Exit admin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.gold,
                foregroundColor: AdminColors.bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
