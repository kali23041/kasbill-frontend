import 'package:flutter/material.dart';

class SidePanel extends StatelessWidget {
  const SidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Content Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store Location Section
                    _buildSection(
                      title: 'Our Store',
                      icon: Icons.store_outlined,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 20,
                              color: const Color(0xFF1E40AF),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Active Store in Pandharpur',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Our Team Section
                    _buildSection(
                      title: 'Our Team',
                      icon: Icons.people_outline,
                      child: Column(
                        children: [
                          _buildTeamMember(
                            name: 'Shiva Bhutade',
                            position: 'CEO',
                            phone: '+91 98765 43210',
                          ),
                          const SizedBox(height: 16),
                          _buildTeamMember(
                            name: 'Kartik Sabale',
                            position: 'Partner',
                            phone: '+91 98765 43211',
                          ),
                          const SizedBox(height: 16),
                          _buildTeamMember(
                            name: 'Tejas Khairnar',
                            position: 'Partner',
                            phone: '+91 98765 43212',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    '© 2024 Scraply. All rights reserved.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialIcon(Icons.facebook, const Color(0xFF1877F2)),
                      const SizedBox(width: 16),
                      _buildSocialIcon(Icons.phone, const Color(0xFF25D366)),
                      const SizedBox(width: 16),
                      _buildSocialIcon(Icons.email, const Color(0xFFEA4335)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: const Color(0xFF1E40AF),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildTeamMember({
    required String name,
    required String position,
    required String phone,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Profile Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    name.split(' ').map((e) => e[0]).join(''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      position,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.phone,
                size: 14,
                color: const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                phone,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        icon,
        size: 18,
        color: color,
      ),
    );
  }
}
