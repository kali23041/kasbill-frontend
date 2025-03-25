import 'package:flutter/material.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildProfileSection(context),
          const SizedBox(height: 24),
          _buildSectionTitle('Account'),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            [
              _buildMenuItem(
                context,
                Icons.receipt_long,
                'Your Orders',
                'View your order history',
                Colors.blue,
              ),
              _buildMenuItem(
                context,
                Icons.person_outline,
                'Profile',
                'Edit your profile details',
                Colors.purple,
              ),
              _buildMenuItem(
                context,
                Icons.notifications_outlined,
                'Notifications',
                'Manage your notifications',
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Business'),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            [
              _buildMenuItem(
                context,
                Icons.bar_chart,
                'Reports',
                'View sales and inventory reports',
                Colors.green,
              ),
              _buildMenuItem(
                context,
                Icons.category_outlined,
                'Categories',
                'Manage jewelry categories',
                Colors.amber,
              ),
              _buildMenuItem(
                context,
                Icons.people_outline,
                'Staff',
                'Manage your staff members',
                Colors.indigo,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Preferences'),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            [
              _buildMenuItem(
                context,
                Icons.settings_outlined,
                'Settings',
                'Configure application settings',
                Colors.grey.shade700,
              ),
              _buildMenuItem(
                context,
                Icons.help_outline,
                'Help & Support',
                'Get help with using the application',
                Colors.teal,
              ),
              _buildMenuItem(
                context,
                Icons.info_outline,
                'About',
                'App version and information',
                Colors.deepPurple,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildLogoutButton(context),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin User',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'admin@jewelry.com',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.edit,
                color: Colors.white,
              ),
              onPressed: () {
                // Edit profile action
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
  ) {
    return InkWell(
      onTap: () {
        // Handle menu item tap
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.logout),
        title: const Text(
          'Logout',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.pushReplacementNamed(context, '/login');
        },
      ),
    );
  }
} 