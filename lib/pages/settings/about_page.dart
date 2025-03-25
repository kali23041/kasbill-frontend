import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Kasbill Jewelery'),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'About Us',
              children: [
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.diamond,
                        size: 64,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Kasbill Jewelery',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'A complete solution for jewelry businesses to manage inventory, sales, and customer relationships.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildSection(
              title: 'Features',
              children: [
                _buildFeatureItem(
                  icon: Icons.inventory,
                  title: 'Inventory Management',
                  description: 'Keep track of your jewelry items, metals, and categories',
                ),
                const Divider(),
                _buildFeatureItem(
                  icon: Icons.point_of_sale,
                  title: 'Sales Management',
                  description: 'Create bills, track sales history, and manage customers',
                ),
                const Divider(),
                _buildFeatureItem(
                  icon: Icons.people,
                  title: 'Customer Management',
                  description: 'Maintain customer records and purchase history',
                ),
                const Divider(),
                _buildFeatureItem(
                  icon: Icons.analytics,
                  title: 'Analytics & Reporting',
                  description: 'Track sales performance and inventory value',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildSection(
              title: 'Developer',
              children: [
                _buildContactItem(
                  icon: Icons.person,
                  title: 'Kartik Sabale',
                  subtitle: 'Lead Developer',
                ),
                const Divider(),
                _buildContactItem(
                  icon: Icons.email,
                  title: 'Email',
                  subtitle: 'sabalekartikk77@gmail.com',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            Center(
              child: Text(
                '© 2023 Kasbill Jewelery. All rights reserved.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.amber.shade800,
              size: 22,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.amber.shade800,
              size: 22,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 