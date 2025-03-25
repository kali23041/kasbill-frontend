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
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isEditing ? 'Edit Metal' : 'Add New Metal',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900),
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
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(Icons.style, color: Colors.blue.shade400),
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
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: Colors.blue.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : () => _saveMetal(setState),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isEditing ? 'Update Metal' : 'Add Metal',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Metals',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddMetalSheet(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Info card about metals
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.monetization_on,
                        color: Colors.blue.shade800,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Precious Metals',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Manage your inventory of metals with current rates',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Search Bar
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search metals...',
                    prefixIcon: Icon(Icons.search, color: Colors.blue.shade300),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
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
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 2,
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    // Metal icon/avatar
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.style,
                                          size: 28,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
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
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  metal['carat'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'SKU: ${metal['sku'] ?? 'N/A'}',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Rate: ${currencyFormat.format(rate)}/g',
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Action buttons
                                    Column(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          color: Colors.blue.shade600,
                                          onPressed: () {
                                            _showAddMetalSheet(
                                              metalId: metalId,
                                              metalData: metal,
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          color: Colors.red.shade600,
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
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }
} 