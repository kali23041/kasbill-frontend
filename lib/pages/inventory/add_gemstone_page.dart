import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../member/premium_upgrade_popup.dart';
import '../settings/upgrade_to_premium_page.dart';

class AddGemstonePage extends StatefulWidget {
  const AddGemstonePage({super.key});

  @override
  State<AddGemstonePage> createState() => _AddGemstonePageState();
}

class _AddGemstonePageState extends State<AddGemstonePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _rateController = TextEditingController();
  final _weightController = TextEditingController();
  String _selectedType = 'Diamond';
  final List<String> _gemstoneTypes = ['Diamond', 'Ruby', 'Emerald', 'Sapphire', 'Pearl', 'Other'];
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isEditing = false;
  String? _editingGemstoneId;
  
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  
  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _skuController.dispose();
    _rateController.dispose();
    _weightController.dispose();
    super.dispose();
  }
  
  Future<bool> _canCreateGemstone() async {
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
      
      final gemstonesSnapshot = await _firestore
            .collection('users')
            .doc(currentUser.email)
            .collection('gemstones')
          .get();
      
      return gemstonesSnapshot.docs.length < 3;
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
        title: 'Gemstone Limit Reached',
        description: 'Free members can only create up to 3 gemstones. Upgrade to premium for unlimited gemstones.',
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
  
  void _showAddGemstoneSheet({String? gemstoneId, Map<String, dynamic>? gemstoneData}) async {
    if (gemstoneId != null && gemstoneData != null) {
      _showGemstoneForm(gemstoneId: gemstoneId, gemstoneData: gemstoneData);
      return;
    }
    
    final canCreate = await _canCreateGemstone();
    if (!canCreate) {
      _showUpgradePopup();
      return;
    }
    
    _showGemstoneForm();
  }
  
  void _showGemstoneForm({String? gemstoneId, Map<String, dynamic>? gemstoneData}) {
    _nameController.clear();
    _skuController.clear();
    _rateController.clear();
    _weightController.clear();
    _selectedType = 'Diamond';
    _errorMessage = null;
    
    if (gemstoneId != null && gemstoneData != null) {
      _isEditing = true;
      _editingGemstoneId = gemstoneId;
      _nameController.text = gemstoneData['name'] ?? '';
      _skuController.text = gemstoneData['sku'] ?? '';
      _rateController.text = gemstoneData['rate']?.toString() ?? '';
      _weightController.text = gemstoneData['weight']?.toString() ?? '';
      _selectedType = gemstoneData['type'] ?? 'Diamond';
    } else {
      _isEditing = false;
      _editingGemstoneId = null;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
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
                        _isEditing ? 'Edit Gemstone' : 'Add New Gemstone',
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
                            // Gemstone Name
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Gemstone Name',
                                hintText: 'Enter gemstone name',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(Icons.diamond_outlined, color: Color(0xFF64748B), size: 20),
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
                                  return 'Please enter gemstone name';
                                }
                                return null;
                              },
                              readOnly: _isEditing,
                            ),
                            const SizedBox(height: 12),
                            
                            // SKU
                            TextFormField(
                              controller: _skuController,
                              decoration: InputDecoration(
                                labelText: 'SKU',
                                hintText: 'Enter stock keeping unit',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(Icons.qr_code_outlined, color: Color(0xFF64748B), size: 20),
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
                                  return 'Please enter SKU';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            
                            // Gemstone Type
                            DropdownButtonFormField<String>(
                              value: _selectedType,
                              decoration: InputDecoration(
                                labelText: 'Gemstone Type',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF64748B), size: 20),
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
                              items: _gemstoneTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedType = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            
                            // Weight
                            TextFormField(
                              controller: _weightController,
                              decoration: InputDecoration(
                                labelText: 'Weight (carats)',
                                hintText: 'Enter weight in carats',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(Icons.line_weight_outlined, color: Color(0xFF64748B), size: 20),
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
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter weight';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                                if (double.parse(value) <= 0) {
                                  return 'Weight must be greater than zero';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            
                            // Rate
                            TextFormField(
                              controller: _rateController,
                              decoration: InputDecoration(
                                labelText: 'Rate (per carat)',
                                hintText: 'Enter rate per carat',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(Icons.currency_rupee_outlined, color: Color(0xFF64748B), size: 20),
                                prefixText: '₹ ',
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
                      onPressed: _isLoading ? null : () => _saveGemstone(setState),
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
                              _isEditing ? 'Update Gemstone' : 'Add Gemstone',
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
  
  Future<void> _saveGemstone(StateSetter bottomSheetSetState) async {
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
        final String gemstoneName = _nameController.text.trim();
        final double rate = double.parse(_rateController.text.trim());
        final double weight = double.parse(_weightController.text.trim());
        
        if (_isEditing && _editingGemstoneId != null) {
          // Update existing gemstone
          await _firestore
              .collection('users')
              .doc(currentUser.email)
              .collection('gemstones')
              .doc(_editingGemstoneId)
              .update({
                'name': gemstoneName,
                'sku': _skuController.text.trim(),
                'type': _selectedType,
                'weight': weight,
                'rate': rate,
                'updatedAt': FieldValue.serverTimestamp(),
              });
        } else {
          // Check if gemstone with this name already exists
          final docRef = _firestore
              .collection('users')
              .doc(currentUser.email)
              .collection('gemstones')
              .doc(gemstoneName);
              
          final doc = await docRef.get();
          if (doc.exists) {
            bottomSheetSetState(() {
              _errorMessage = 'A gemstone with this name already exists';
              _isLoading = false;
            });
            return;
          }
          
          // Add new gemstone
          await docRef.set({
            'name': gemstoneName,
            'sku': _skuController.text.trim(),
            'type': _selectedType,
            'weight': weight,
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
              content: Text(_isEditing ? 'Gemstone updated successfully' : 'Gemstone added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      bottomSheetSetState(() {
        _errorMessage = 'Failed to save gemstone: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _deleteGemstone(String gemstoneId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Delete Gemstone',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
            content: const Text(
              'Are you sure you want to delete this gemstone? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        
        if (confirmed != true) {
          return;
        }
        
        // Delete the gemstone
        await _firestore
            .collection('users')
            .doc(currentUser.email)
            .collection('gemstones')
            .doc(gemstoneId)
            .delete();
            
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gemstone deleted successfully'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete gemstone: ${e.toString()}'),
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
                      'Gemstones',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_outlined),
                      onPressed: () => _showAddGemstoneSheet(),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF475569),
                        padding: const EdgeInsets.all(8.0),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Info card about gemstones
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
                        Icons.diamond_outlined,
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
                            'Precious Gemstones',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Manage your inventory of precious gemstones',
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
                    hintText: 'Search gemstones...',
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
              
              // Gemstones list section title
              currentUser != null && currentUser.email != null
                ? StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(currentUser.email)
                        .collection('gemstones')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final hasGemstones = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                      
                      return hasGemstones 
                        ? const Text(
                            'Your Gemstones',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          )
                        : const SizedBox.shrink();
                    },
                  )
                : const SizedBox.shrink(),
              const SizedBox(height: 8),
              
              // Gemstones list
              Expanded(
                child: currentUser != null && currentUser.email != null
                  ? StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('users')
                          .doc(currentUser.email)
                          .collection('gemstones')
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading gemstones: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.diamond_outlined,
                                  size: 80,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No gemstones yet',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap the + button to add your first gemstone',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        // Filter gemstones based on search query
                        final allGemstones = snapshot.data!.docs;
                        final filteredGemstones = _searchQuery.isEmpty
                            ? allGemstones
                            : allGemstones.where((doc) {
                                final gemstone = doc.data() as Map<String, dynamic>;
                                final name = gemstone['name']?.toString().toLowerCase() ?? '';
                                final sku = gemstone['sku']?.toString().toLowerCase() ?? '';
                                final type = gemstone['type']?.toString().toLowerCase() ?? '';
                                
                                return name.contains(_searchQuery) || 
                                       sku.contains(_searchQuery) ||
                                       type.contains(_searchQuery);
                              }).toList();
                        
                        if (filteredGemstones.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.search_off,
                                  size: 70,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No matching gemstones',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Try a different search term',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: filteredGemstones.length,
                          itemBuilder: (context, index) {
                            final gemstone = filteredGemstones[index].data() as Map<String, dynamic>;
                            final gemstoneId = filteredGemstones[index].id;
                            final double rate = (gemstone['rate'] as num?)?.toDouble() ?? 0.0;
                            final double weight = (gemstone['weight'] as num?)?.toDouble() ?? 0.0;
                            
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
                                    // Gemstone icon/avatar
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F9FF),
                                        borderRadius: BorderRadius.circular(6.0),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.diamond_outlined,
                                          size: 20,
                                          color: Color(0xFF0EA5E9),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Gemstone details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                gemstone['name'] ?? 'Unnamed Gemstone',
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
                                                  gemstone['type'] ?? '',
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
                                            'SKU: ${gemstone['sku'] ?? 'N/A'}',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                'Weight: ${weight.toStringAsFixed(2)} ct',
                                                style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Rate: ${currencyFormat.format(rate)}/ct',
                                                style: const TextStyle(
                                                  color: Color(0xFF059669),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
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
                                            _showAddGemstoneSheet(
                                              gemstoneId: gemstoneId,
                                              gemstoneData: gemstone,
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outlined, size: 18),
                                          color: const Color(0xFFDC2626),
                                          onPressed: () => _deleteGemstone(gemstoneId),
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
                      child: Text('You need to be logged in to view gemstones'),
                    ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGemstoneSheet(),
        backgroundColor: const Color(0xFF1E40AF),
        child: const Icon(Icons.add_outlined),
      ),
    );
  }
} 
