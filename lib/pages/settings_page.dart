import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page.dart';

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
    
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
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
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.grey),
                      onPressed: _signOut,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // User Profile Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade700, Colors.amber.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.shade200.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // User avatar
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: currentUser?.photoURL != null
                              ? NetworkImage(currentUser!.photoURL!)
                              : null,
                          child: currentUser?.photoURL == null
                              ? Text(
                                  _userData?['displayName']?.substring(0, 1).toUpperCase() ?? 'U',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade800,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        
                        // User name
                        Text(
                          _userData?['displayName'] ?? 'User',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // User email
                        Text(
                          _userData?['email'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Membership badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: _userData?['membership'] == 'premium'
                                ? Colors.purple.shade800
                                : Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _userData?['membership'] == 'premium'
                                    ? Icons.workspace_premium
                                    : Icons.card_membership,
                                color: _userData?['membership'] == 'premium'
                                    ? Colors.amber
                                    : Colors.amber.shade800,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _userData?['membership'] == 'premium'
                                    ? 'Premium Member'
                                    : 'Free Member',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _userData?['membership'] == 'premium'
                                      ? Colors.white
                                      : Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
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
                        // Navigate to premium page
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      onTap: () {
                        // Show change password dialog
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // App Settings Section
                _buildSettingSection(
                  title: 'App Settings',
                  children: [
                    _buildSettingItem(
                      icon: Icons.language,
                      title: 'Language',
                      subtitle: 'English',
                      onTap: () {
                        // Show language options
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      onTap: () {
                        // Navigate to notification settings
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.color_lens_outlined,
                      title: 'Theme',
                      subtitle: 'Light',
                      onTap: () {
                        // Show theme options
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Help & Support Section
                _buildSettingSection(
                  title: 'Help & Support',
                  children: [
                    _buildSettingItem(
                      icon: Icons.help_outline,
                      title: 'Help Center',
                      onTap: () {
                        // Navigate to help center
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.info_outline,
                      title: 'About',
                      onTap: () {
                        // Show about dialog
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.feedback_outlined,
                      title: 'Feedback',
                      onTap: () {
                        // Show feedback form
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // App Version
                Center(
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
  }
  
  Widget _buildSettingSection({required String title, required List<Widget> children}) {
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                  if (subtitle != null) 
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
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
} 