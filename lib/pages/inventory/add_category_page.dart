import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../member/premium_upgrade_popup.dart';
import '../settings/upgrade_to_premium_page.dart';

class AddCategoryPage extends StatefulWidget {
  const AddCategoryPage({super.key});

  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final _formKey = GlobalKey<FormState>();
  final _categoryNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<TextEditingController> _subCategoryControllers = [];
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isEditing = false;
  String? _editingCategoryId;
  
  // Add search controller
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _categoryNameController.dispose();
    _descriptionController.dispose();
    for (var controller in _subCategoryControllers) {
      controller.dispose();
    }
    _searchController.dispose(); // Dispose search controller
    super.dispose();
  }
  
  void _addSubCategoryField() {
    setState(() {
      _subCategoryControllers.add(TextEditingController());
    });
  }
  
  void _removeSubCategoryField(int index) {
    if (index < _subCategoryControllers.length) {
      setState(() {
        _subCategoryControllers[index].dispose();
        _subCategoryControllers.removeAt(index);
      });
    }
  }
  
  Future<bool> _canCreateCategory() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.email == null) return false;
    
    try {
      // Check membership status
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.email)
          .get();
          
      final userData = userDoc.data() as Map<String, dynamic>?;
      final membershipType = userData?['membership'] ?? 'free';
      
      // If premium, no limit
      if (membershipType.toLowerCase() != 'free') {
        return true;
      }
      
      // Count existing categories for free users
      final categoriesSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.email)
          .collection('categories')
          .get();
      
      // Free users can have max 3 categories
      return categoriesSnapshot.docs.length < 3;
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
        title: 'Category Limit Reached',
        description: 'Free members can only create up to 3 categories. Upgrade to premium for unlimited categories.',
        onUpgrade: () {
          Navigator.of(context).pop();
          // Navigate to the upgrade page
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UpgradeToPremiumPage()),
          );
        },
      ),
    );
  }
  
  void _showAddCategorySheet({String? categoryId, Map<String, dynamic>? categoryData}) async {
    // If editing existing category, show the form right away
    if (categoryId != null && categoryData != null) {
      _showCategoryForm(categoryId: categoryId, categoryData: categoryData);
      return;
    }
    
    // Otherwise, check if user can create more categories
    final canCreate = await _canCreateCategory();
    if (!canCreate) {
      _showUpgradePopup();
      return;
    }
    
    // If they can, show the form
    _showCategoryForm();
  }
  
  void _showCategoryForm({String? categoryId, Map<String, dynamic>? categoryData}) {
    // Reset form
    _categoryNameController.clear();
    _descriptionController.clear();
    for (var controller in _subCategoryControllers) {
      controller.dispose();
    }
    _subCategoryControllers.clear();
    _errorMessage = null;
    
    // If editing, populate form with existing data
    if (categoryId != null && categoryData != null) {
      _isEditing = true;
      _editingCategoryId = categoryId;
      _categoryNameController.text = categoryData['name'] ?? '';
      _descriptionController.text = categoryData['description'] ?? '';
      
      // Add controllers for subcategories
      final subcategories = categoryData['subcategories'] as List<dynamic>?;
      if (subcategories != null) {
        for (var subcategory in subcategories) {
          final controller = TextEditingController(text: subcategory.toString());
          _subCategoryControllers.add(controller);
        }
      }
    } else {
      _isEditing = false;
      _editingCategoryId = null;
      // Add one empty subcategory field by default
      _addSubCategoryField();
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
                        _isEditing ? 'Edit Category' : 'Add New Category',
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
                            // Category Name
                            TextFormField(
                              controller: _categoryNameController,
                              decoration: InputDecoration(
                                labelText: 'Category Name',
                                hintText: 'Enter category name',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(Icons.category),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.purple.shade500, width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter category name';
                                }
                                return null;
                              },
                              readOnly: _isEditing, // Can't change name when editing
                            ),
                            const SizedBox(height: 16),
                            
                            // Description
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Description (Optional)',
                                hintText: 'Enter category description',
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(Icons.description),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.purple.shade500, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Subcategories section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subcategories',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle, color: Colors.purple.shade500),
                                  onPressed: () {
                                    setState(() {
                                      _addSubCategoryField();
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Subcategory fields
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _subCategoryControllers.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _subCategoryControllers[index],
                                          decoration: InputDecoration(
                                            labelText: 'Subcategory ${index + 1}',
                                            hintText: 'Enter subcategory name',
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            prefixIcon: const Icon(Icons.subdirectory_arrow_right),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade200),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.purple.shade500, width: 2),
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _removeSubCategoryField(index);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
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
                      onPressed: _isLoading ? null : _saveCategory,
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
                              _isEditing ? 'Update Category' : 'Add Category',
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
  
  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        final String categoryName = _categoryNameController.text.trim();
        
        // Prepare subcategories list
        final List<String> subcategories = [];
        for (var controller in _subCategoryControllers) {
          final subcategory = controller.text.trim();
          if (subcategory.isNotEmpty) {
            subcategories.add(subcategory);
          }
        }
        
        if (_isEditing && _editingCategoryId != null) {
          // Update existing category
          await _firestore
              .collection('users')
              .doc(currentUser.email)
              .collection('categories')
              .doc(_editingCategoryId)
              .update({
                'name': categoryName,
                'description': _descriptionController.text.trim(),
                'subcategories': subcategories,
                'updatedAt': FieldValue.serverTimestamp(),
              });
        } else {
          // Check if category with this name already exists
          final docRef = _firestore
              .collection('users')
              .doc(currentUser.email)
              .collection('categories')
              .doc(categoryName);
              
          final doc = await docRef.get();
          if (doc.exists) {
            setState(() {
              _errorMessage = 'A category with this name already exists';
              _isLoading = false;
            });
            return;
          }
          
          // Add new category
          await docRef.set({
            'name': categoryName,
            'description': _descriptionController.text.trim(),
            'subcategories': subcategories,
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
              content: Text(_isEditing ? 'Category updated successfully' : 'Category added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save category: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _deleteCategory(String categoryId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Delete Category',
              style: TextStyle(color: Colors.red.shade800),
            ),
            content: const Text(
              'Are you sure you want to delete this category? This action cannot be undone.',
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
        
        // Delete the category
        await _firestore
            .collection('users')
            .doc(currentUser.email)
            .collection('categories')
            .doc(categoryId)
            .delete();
            
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category deleted successfully'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete category: ${e.toString()}'),
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
                      'Categories',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_outlined),
                      onPressed: () => _showAddCategorySheet(),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF475569),
                        padding: const EdgeInsets.all(8.0),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Info card about categories
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
                        Icons.category_outlined,
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
                            'Jewelry Categories',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Organize your inventory with categories and subcategories',
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
                    hintText: 'Search categories...',
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
              
              // Category list section title
              currentUser != null && currentUser.email != null
                ? StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(currentUser.email)
                        .collection('categories')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final hasCategories = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                      
                      return hasCategories 
                        ? Text(
                            'Your Categories',
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
              
              // Categories list
              Expanded(
                child: currentUser != null && currentUser.email != null
                  ? StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('users')
                          .doc(currentUser.email)
                          .collection('categories')
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading categories: ${snapshot.error}',
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
                                  Icons.category_outlined,
                                  size: 80,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No categories yet',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the + button to add your first category',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        // Filter categories based on search query
                        final allCategories = snapshot.data!.docs;
                        final filteredCategories = _searchQuery.isEmpty
                            ? allCategories
                            : allCategories.where((doc) {
                                final category = doc.data() as Map<String, dynamic>;
                                final name = category['name']?.toString().toLowerCase() ?? '';
                                final description = category['description']?.toString().toLowerCase() ?? '';
                                
                                // Search in subcategories too
                                bool matchesSubcategory = false;
                                final subcategories = category['subcategories'] as List<dynamic>?;
                                if (subcategories != null) {
                                  for (var sub in subcategories) {
                                    if (sub.toString().toLowerCase().contains(_searchQuery)) {
                                      matchesSubcategory = true;
                                      break;
                                    }
                                  }
                                }
                                
                                return name.contains(_searchQuery) || 
                                       description.contains(_searchQuery) ||
                                       matchesSubcategory;
                              }).toList();
                        
                        if (filteredCategories.isEmpty) {
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
                                  'No matching categories',
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
                          itemCount: filteredCategories.length,
                          itemBuilder: (context, index) {
                            final category = filteredCategories[index].data() as Map<String, dynamic>;
                            final categoryId = filteredCategories[index].id;
                            final subcategories = category['subcategories'] as List<dynamic>?;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent,
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF1E40AF),
                                  ),
                                ),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  childrenPadding: EdgeInsets.zero,
                                  title: Text(
                                    category['name'] ?? 'Unnamed Category',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (category['description'] != null && category['description'].isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            category['description'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      if (subcategories != null && subcategories.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            '${subcategories.length} subcategories',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.purple.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F9FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.category_outlined,
                                      color: Color(0xFF0EA5E9),
                                      size: 16,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        color: const Color(0xFF1E40AF),
                                        onPressed: () {
                                          _showAddCategorySheet(
                                            categoryId: categoryId,
                                            categoryData: category,
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outlined, size: 18),
                                        color: const Color(0xFFDC2626),
                                        onPressed: () => _deleteCategory(categoryId),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(8),
                                          bottomRight: Radius.circular(8),
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (subcategories != null && subcategories.isNotEmpty) ...[
                                            Text(
                                              'Subcategories',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: subcategories.map((subcategory) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: Colors.purple.shade200,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    subcategory.toString(),
                                                    style: TextStyle(
                                                      color: Colors.purple.shade800,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ] else
                                            const Text(
                                              'No subcategories defined',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                        ],
                                      ),
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
                      child: Text('You need to be logged in to view categories'),
                    ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategorySheet(),
        backgroundColor: const Color(0xFF1E40AF),
        child: const Icon(Icons.add_outlined),
      ),
    );
  }
} 
