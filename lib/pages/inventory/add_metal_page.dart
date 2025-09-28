import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../member/premium_upgrade_popup.dart';
import '../settings/upgrade_to_premium_page.dart';

class AddMetalPage extends StatefulWidget {
  const AddMetalPage({super.key});

  @override
  State<AddMetalPage> createState() => _AddMetalPageState();
}

class _AddMetalPageState extends State<AddMetalPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _rateController = TextEditingController();
  String _selectedCarat = '24K';
  final List<String> _caratOptions = ['18K', '22K', '24K'];
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isEditing = false;
  String? _editingMetalId;
  
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  
  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _skuController.dispose();
    _rateController.dispose();
    super.dispose();
  }
  
  Future<bool> _canCreateMetal() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.email == null) return false;
    
    try {
      final userDoc = await _firestore
              .collection('users')
              .doc(currentUser.email)
          .get();
          
      final userData = userDoc.data() as Map<String, dynamic>?;
      final membershipType = userData?['membership'] ?? 'free';
      
      if (membershipType.toLowerCase() != 'free') {
        return true;
      }
      
      final metalsSnapshot = await _firestore
            .collection('users')
            .doc(currentUser.email)
            .collection('metals')
          .get();
      
      return metalsSnapshot.docs.length < 3;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking membership: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }
  
  void _showUpgradePopup() {
    showDialog(
      context: context,
      builder: (context) => PremiumUpgradePopup(
        title: 'Metal Limit Reached',
        description: 'Free members can only create up to 3 metals. Upgrade to premium for unlimited metals.',
        onUpgrade: () {
          Navigator.of(context).pop();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UpgradeToPremiumPage()),
          );
        },
      ),
    );
  }
  
  void _showAddMetalSheet({String? metalId, Map<String, dynamic>? metalData}) async {
    if (metalId != null && metalData != null) {
      _showMetalForm(metalId: metalId, metalData: metalData);
      return;
    }
    
    final canCreate = await _canCreateMetal();
    if (!canCreate) {
      _showUpgradePopup();
      return;
    }
    
    _showMetalForm();
  }
  
  void _showMetalForm({String? metalId, Map<String, dynamic>? metalData}) {
    _nameController.clear();
    _skuController.clear();
    _rateController.clear();
    _selectedCarat = '24K';
    _errorMessage = null;
    
    if (metalId != null && metalData != null) {
      _isEditing = true;
      _editingMetalId = metalId;
      _nameController.text = metalData['name'] ?? '';
      _skuController.text = metalData['sku'] ?? '';
      _rateController.text = metalData['rate']?.toString() ?? '';
      _selectedCarat = metalData['carat'] ?? '24K';
    } else {
      _isEditing = false;
      _editingMetalId = null;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isEditing ? 'Edit Metal' : 'Add New Metal',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_outlined),
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      margin: const EdgeInsets.only(bottom: 8.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFFDC2626),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Form
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Metal Name
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Metal Name',
                                hintText: 'Enter metal name (e.g., Gold, Silver)',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(Icons.style_outlined, color: Color(0xFF64748B), size: 20),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter metal name';
                                }
                                return null;
                              },
                              readOnly: _isEditing, // Can't change name when editing
                            ),
                            const SizedBox(height: 16),
                            
                            // SKU
                            TextFormField(
                              controller: _skuController,
                              decoration: InputDecoration(
                                labelText: 'SKU',
                                hintText: 'Enter stock keeping unit',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(Icons.qr_code, color: Colors.blue.shade400),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter SKU';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Carat Selection
                            DropdownButtonFormField<String>(
                              value: _selectedCarat,
                              decoration: InputDecoration(
                                labelText: 'Carat',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(Icons.star, color: Colors.blue.shade400),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
                                ),
                              ),
                              items: _caratOptions.map((carat) {
                                return DropdownMenuItem<String>(
                                  value: carat,
                                  child: Text(carat),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedCarat = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Rate
                            TextFormField(
                              controller: _rateController,
                              decoration: InputDecoration(
                                labelText: 'Rate (per gram)',
                                hintText: 'Enter rate per gram',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(Icons.currency_rupee, color: Colors.blue.shade400),
                                prefixText: '₹ ',
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
                                ),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter rate';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                                if (double.parse(value) <= 0) {
                                  return 'Rate must be greater than zero';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: _isLoading ? null : () => _saveMetal(setState),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditing ? 'Update Metal' : 'Add Metal',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Future<void> _saveMetal(StateSetter bottomSheetSetState) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    bottomSheetSetState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        final String metalName = _nameController.text.trim();
        final double rate = double.parse(_rateController.text.trim());
        
        if (_isEditing && _editingMetalId != null) {
          // Update existing metal
          await _firestore
              .collection('users')
              .doc(currentUser.email)
              .collection('metals')
              .doc(_editingMetalId)
              .update({
                'name': metalName,
                'sku': _skuController.text.trim(),
                'carat': _selectedCarat,
                'rate': rate,
                'updatedAt': FieldValue.serverTimestamp(),
              });
        } else {
          // Check if metal with this name already exists
          final docRef = _firestore
              .collection('users')
              .doc(currentUser.email)
              .collection('metals')
              .doc(metalName);
              
          final doc = await docRef.get();
          if (doc.exists) {
            bottomSheetSetState(() {
              _errorMessage = 'A metal with this name already exists';
              _isLoading = false;
            });
            return;
          }
          
          // Add new metal
          await docRef.set({
            'name': metalName,
            'sku': _skuController.text.trim(),
            'carat': _selectedCarat,
            'rate': rate,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        
        // Reset form and close bottom sheet
        if (mounted) {
          Navigator.pop(context);
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing ? 'Metal updated successfully' : 'Metal added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      bottomSheetSetState(() {
        _errorMessage = 'Failed to save metal: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _deleteMetal(String metalId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Delete Metal',
              style: TextStyle(color: Colors.red.shade800),
            ),
            content: const Text(
              'Are you sure you want to delete this metal? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        
        if (confirmed != true) {
          return;
        }
        
        // Delete the metal
        await _firestore
            .collection('users')
            .doc(currentUser.email)
            .collection('metals')
            .doc(metalId)
            .delete();
            
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Metal deleted successfully'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete metal: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Metals',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_outlined),
                      onPressed: () => _showAddMetalSheet(),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF475569),
                        padding: const EdgeInsets.all(8.0),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Info card about metals
              Container(
                padding: const EdgeInsets.all(8.0),
                margin: const EdgeInsets.only(bottom: 8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: const Icon(
                        Icons.monetization_on_outlined,
                        color: Color(0xFF0EA5E9),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Precious Metals',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Manage your inventory of metals with current rates',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Search Bar
              Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search metals...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_outlined, color: Color(0xFF64748B), size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_outlined, size: 20),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              
              // Metals list section title
              currentUser != null && currentUser.email != null
                ? StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(currentUser.email)
                        .collection('metals')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final hasMetals = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                      
                      return hasMetals 
                        ? Text(
                            'Your Metals',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          )
                        : const SizedBox.shrink();
                    },
                  )
                : const SizedBox.shrink(),
              const SizedBox(height: 16),
              
              // Metals list
              Expanded(
                child: currentUser != null && currentUser.email != null
                  ? StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('users')
                          .doc(currentUser.email)
                          .collection('metals')
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading metals: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.monetization_on_outlined,
                                  size: 80,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No metals yet',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the + button to add your first metal',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        // Filter metals based on search query
                        final allMetals = snapshot.data!.docs;
                        final filteredMetals = _searchQuery.isEmpty
                            ? allMetals
                            : allMetals.where((doc) {
                                final metal = doc.data() as Map<String, dynamic>;
                                final name = metal['name']?.toString().toLowerCase() ?? '';
                                final sku = metal['sku']?.toString().toLowerCase() ?? '';
                                final carat = metal['carat']?.toString().toLowerCase() ?? '';
                                
                                return name.contains(_searchQuery) || 
                                       sku.contains(_searchQuery) ||
                                       carat.contains(_searchQuery);
                              }).toList();
                        
                        if (filteredMetals.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 70,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No matching metals',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try a different search term',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: filteredMetals.length,
                          itemBuilder: (context, index) {
                            final metal = filteredMetals[index].data() as Map<String, dynamic>;
                            final metalId = filteredMetals[index].id;
                            final double rate = (metal['rate'] as num?)?.toDouble() ?? 0.0;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    // Metal icon/avatar
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F9FF),
                                        borderRadius: BorderRadius.circular(6.0),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.style_outlined,
                                          size: 20,
                                          color: Color(0xFF0EA5E9),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Metal details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                metal['name'] ?? 'Unnamed Metal',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: Color(0xFF374151),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF0F9FF),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  metal['carat'] ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF0EA5E9),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'SKU: ${metal['sku'] ?? 'N/A'}',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Rate: ${currencyFormat.format(rate)}/g',
                                            style: const TextStyle(
                                              color: Color(0xFF059669),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Action buttons
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          color: const Color(0xFF1E40AF),
                                          onPressed: () {
                                            _showAddMetalSheet(
                                              metalId: metalId,
                                              metalData: metal,
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outlined, size: 18),
                                          color: const Color(0xFFDC2626),
                                          onPressed: () => _deleteMetal(metalId),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : const Center(
                      child: Text('You need to be logged in to view metals'),
                    ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMetalSheet(),
        backgroundColor: const Color(0xFF1E40AF),
        child: const Icon(Icons.add_outlined),
      ),
    );
  }
} 