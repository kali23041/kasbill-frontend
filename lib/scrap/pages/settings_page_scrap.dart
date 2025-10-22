import 'package:flutter/material.dart';

class SettingsPageScrap extends StatelessWidget {
  const SettingsPageScrap({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Upper white section with header
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Menu button
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.menu,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                      // Brand name
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                      // Notification button
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 4),
        
        // Main content area
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
                bottom: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  
                  // Account Section
                  const Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingItem(Icons.person_outline, 'Profile Settings', () {}),
                  _buildSettingItem(Icons.lock_outline, 'Privacy & Security', () {}),
                  _buildSettingItem(Icons.notifications_outlined, 'Notifications', () {}),
                  
                  const SizedBox(height: 24),
                  
                  // App Section
                  const Text(
                    'Application',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingItem(Icons.language_outlined, 'Language', () {}),
                  _buildSettingItem(Icons.dark_mode_outlined, 'Dark Mode', () {}),
                  _buildSettingItem(Icons.info_outline, 'About', () {}),
                  
                  const SizedBox(height: 24),
                  
                  // Support Section
                  const Text(
                    'Support',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingItem(Icons.help_outline, 'Help Center', () {}),
                  _buildSettingItem(Icons.privacy_tip_outlined, 'Terms & Policies', () {}),
                  _buildSettingItem(Icons.logout, 'Logout', () {}, isDestructive: true),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDestructive ? const Color(0xFFFEF2F2) : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDestructive ? const Color(0xFFDC2626) : Colors.black,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDestructive ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDestructive ? const Color(0xFFDC2626) : const Color(0xFF999999),
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}

