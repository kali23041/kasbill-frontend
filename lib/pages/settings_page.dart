import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';
import 'rates_page.dart';
import 'settings/upgrade_to_premium_page.dart';
import 'settings/language_page.dart';
import 'settings/help_center_page.dart';
import 'settings/about_page.dart';
import 'settings/feedback_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(currentUser.email)
            .get();
            
        if (doc.exists) {
          setState(() {
            _userData = doc.data() as Map<String, dynamic>?;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1E40AF),
                strokeWidth: 2,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_outlined, color: Color(0xFF64748B), size: 20),
                      onPressed: _signOut,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // User Profile Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // User avatar
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          backgroundImage: currentUser?.photoURL != null
                              ? NetworkImage(currentUser!.photoURL!)
                              : null,
                          child: currentUser?.photoURL == null
                              ? Text(
                                  _userData?['displayName']?.substring(0, 1).toUpperCase() ?? 'U',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E40AF),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        
                        // User name
                        Text(
                          _userData?['displayName'] ?? 'User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        // User email
                        Text(
                          _userData?['email'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Membership badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _userData?['membership'] == 'premium'
                                ? const Color(0xFF8B5CF6)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _userData?['membership'] == 'premium'
                                    ? Icons.workspace_premium_outlined
                                    : Icons.card_membership_outlined,
                                color: _userData?['membership'] == 'premium'
                                    ? Colors.white
                                    : const Color(0xFF1E40AF),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _userData?['membership'] == 'premium'
                                    ? 'Premium Member'
                                    : 'Free Member',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  color: _userData?['membership'] == 'premium'
                                      ? Colors.white
                                      : const Color(0xFF1E40AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Account Settings Section
                _buildSettingSection(
                  title: 'Account Settings',
                  children: [
                    _buildSettingItem(
                      icon: Icons.person_outline,
                      title: 'Edit Profile',
                      onTap: () async {
                        // Navigate to edit profile page and refresh data if changes were made
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EditProfilePage()),
                        );
                        
                        // If profile was updated, reload user data
                        if (result == true) {
                          _loadUserData();
                        }
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.workspace_premium,
                      title: 'Upgrade to Premium',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const UpgradeToPremiumPage()),
                        );
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      onTap: () async {
                        // Check if user is logged in with email/password
                        User? currentUser = _auth.currentUser;
                        final List<String> providers = [];
                        
                        if (currentUser != null && currentUser.email != null) {
                          final providerData = await _auth.fetchSignInMethodsForEmail(currentUser.email!);
                          providers.addAll(providerData);
                        }
                        
                        // Only show change password page if user uses email/password auth
                        if (providers.contains('password')) {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ChangePasswordPage()),
                          );
                          
                          // If password was changed successfully, you might want to handle it
                          if (result == true) {
                            // Option: Show a success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password changed successfully')),
                            );
                          }
                        } else {
                          // Show a message that this option is not available for social logins
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('This option is only available for email/password accounts'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.attach_money,
                      title: 'Rates',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RatesPage()),
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // App Settings Section
                _buildSettingSection(
                  title: 'App Settings',
                  children: [
                    _buildSettingItem(
                      icon: Icons.language,
                      title: 'Language',
                      subtitle: 'English',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LanguagePage()),
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Help & Support Section
                _buildSettingSection(
                  title: 'Help & Support',
                  children: [
                    _buildSettingItem(
                      icon: Icons.help_outline,
                      title: 'Help Center',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HelpCenterPage()),
                        );
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.info_outline,
                      title: 'About',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AboutPage()),
                        );
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.feedback_outlined,
                      title: 'Feedback',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const FeedbackPage()),
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // App Version
                Center(
                  child: Text(
                    'Version 1.0.0',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }
  
  Widget _buildSettingSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E40AF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: const Color(0xFF1E40AF),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  if (subtitle != null) 
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_outlined,
              color: Color(0xFF94A3B8),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
} 