import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  
  @override
  void dispose() {
    _categoryNameController.dispose();
    _descriptionController.dispose();
    for (var controller in _subCategoryControllers) {
      controller.dispose();
    }
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
  
  void _showAddCategorySheet({String? categoryId, Map<String, dynamic>? categoryData}) {
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
                        _isEditing ? 'Edit Category' : 'Add New Category',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800,
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
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: Colors.purple.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _saveCategory,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isEditing ? 'Update Category' : 'Add Category',
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
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: Colors.purple.shade500,
        foregroundColor: Colors.white,
      ),
      body: currentUser != null && currentUser.email != null
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
                
                final categories = snapshot.data!.docs;
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index].data() as Map<String, dynamic>;
                    final categoryId = categories[index].id;
                    final subcategories = category['subcategories'] as List<dynamic>?;
                    
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
                      child: ExpansionTile(
                        title: Text(
                          category['name'] ?? 'Unnamed Category',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          category['description'] ?? 'No description',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.shade100,
                          child: Icon(
                            Icons.category,
                            color: Colors.purple.shade800,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                _showAddCategorySheet(
                                  categoryId: categoryId,
                                  categoryData: category,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteCategory(categoryId),
                            ),
                          ],
                        ),
                        children: [
                          if (subcategories != null && subcategories.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Subcategories:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
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
                                          color: Colors.purple.shade50,
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
                                ],
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No subcategories'),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            )
          : const Center(
              child: Text('You need to be logged in to view categories'),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategorySheet(),
        backgroundColor: Colors.purple.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }
} 