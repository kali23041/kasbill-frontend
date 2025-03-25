import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class AddProductPage extends StatefulWidget {
  final String? editProductId;
  
  const AddProductPage({super.key, this.editProductId});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skuController = TextEditingController();
  final _weightController = TextEditingController();
  final _makingChargeController = TextEditingController();
  final _otherChargesController = TextEditingController();
  final _discountController = TextEditingController();
  final _quantityController = TextEditingController();
  
  // Selected items
  String? _selectedCategoryId;
  Map<String, dynamic>? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedMetalId;
  Map<String, dynamic>? _selectedMetal;
  
  // Calculate values
  double _weight = 0.0;
  double _metalRate = 0.0;
  double _makingCharge = 0.0;
  double _otherCharges = 0.0;
  double _discount = 0.0;
  double _totalPrice = 0.0;
  int _quantity = 1;
  
  // Flag for pricing section expanded
  bool _isPricingExpanded = false;
  
  // For image upload (will be expanded later)
  List<String> _productImages = [];
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isEditing = false;
  String? _editingProductId;
  
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;
  
  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';
    
    // Add listeners for automatic price calculation
    _weightController.addListener(_calculatePrice);
    _makingChargeController.addListener(_calculatePrice);
    _otherChargesController.addListener(_calculatePrice);
    _discountController.addListener(_calculatePrice);
    _quantityController.addListener(_calculatePrice);
    
    // Load product data if editing an existing product
    if (widget.editProductId != null) {
      _loadProductData();
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _productNameController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _weightController.dispose();
    _makingChargeController.dispose();
    _otherChargesController.dispose();
    _discountController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
  
  void _calculatePrice() {
    setState(() {
      // Parse input values with safety checks
      _weight = double.tryParse(_weightController.text) ?? 0.0;
      _makingCharge = double.tryParse(_makingChargeController.text) ?? 0.0;
      _otherCharges = double.tryParse(_otherChargesController.text) ?? 0.0;
      _discount = double.tryParse(_discountController.text) ?? 0.0;
      _quantity = int.tryParse(_quantityController.text) ?? 1;
      
      // Get metal rate from selected metal
      if (_selectedMetal != null) {
        _metalRate = (_selectedMetal!['rate'] as num?)?.toDouble() ?? 0.0;
      }
      
      // Calculate the price
      double metalCost = _weight * _metalRate;
      double makingCost = (_makingCharge * metalCost) / 100; // Making charge as percentage of metal cost
      double totalBeforeDiscount = metalCost + makingCost + _otherCharges;
      double discountAmount = (_discount * totalBeforeDiscount) / 100;
      double singleItemPrice = totalBeforeDiscount - discountAmount;
      
      // Total price accounting for quantity
      _totalPrice = singleItemPrice * _quantity;
    });
  }
  
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Check if category and metal are selected
    if (_selectedCategoryId == null) {
      setState(() {
        _errorMessage = 'Please select a category';
      });
      return;
    }
    
    if (_selectedMetalId == null) {
      setState(() {
        _errorMessage = 'Please select a metal';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        final String productName = _productNameController.text.trim();
        
        // Prepare product data
        final Map<String, dynamic> productData = {
          'name': productName,
          'description': _descriptionController.text.trim(),
          'sku': _skuController.text.trim(),
          'category': {
            'id': _selectedCategoryId,
            'name': _selectedCategory?['name'] ?? '',
          },
          'subcategory': _selectedSubcategory,
          'metal': {
            'id': _selectedMetalId,
            'name': _selectedMetal?['name'] ?? '',
            'carat': _selectedMetal?['carat'] ?? '',
            'rate': _metalRate,
          },
          'weight': _weight,
          'makingCharge': _makingCharge,
          'otherCharges': _otherCharges,
          'discount': _discount,
          'quantity': _quantity,
          'unitPrice': _totalPrice / _quantity,
          'totalPrice': _totalPrice,
          'images': _productImages,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        if (_isEditing && _editingProductId != null) {
          // Update existing product
          await _firestore
              .collection('users')
              .doc(currentUser.email)
              .collection('products')
              .doc(_editingProductId)
              .update(productData);
        } else {
          // Check if product with this name already exists
          final docRef = _firestore
              .collection('users')
              .doc(currentUser.email)
              .collection('products')
              .doc(productName);
              
          final doc = await docRef.get();
          if (doc.exists) {
            setState(() {
              _errorMessage = 'A product with this name already exists';
              _isLoading = false;
            });
            return;
          }
          
          // Add new product
          await docRef.set(productData);
        }
        
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing ? 'Product updated successfully' : 'Product added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Clear form after successful save
          _resetForm();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save product: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _resetForm() {
    setState(() {
      _productNameController.clear();
      _descriptionController.clear();
      _skuController.clear();
      _weightController.clear();
      _makingChargeController.clear();
      _otherChargesController.clear();
      _discountController.clear();
      _quantityController.text = '1';
      
      _selectedCategoryId = null;
      _selectedCategory = null;
      _selectedSubcategory = null;
      _selectedMetalId = null;
      _selectedMetal = null;
      
      _weight = 0.0;
      _totalPrice = 0.0;
      _productImages = [];
      
      _isEditing = false;
      _editingProductId = null;
      _errorMessage = null;
    });
  }
  
  Future<void> _deleteProduct(String productId) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Delete Product',
              style: TextStyle(color: Colors.red.shade800),
            ),
            content: const Text(
              'Are you sure you want to delete this product? This action cannot be undone.',
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
        
        // Delete the product
        await _firestore
            .collection('users')
            .doc(currentUser.email)
            .collection('products')
            .doc(productId)
            .delete();
            
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted successfully'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete product: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _editProduct(String productId, Map<String, dynamic> productData) {
    setState(() {
      _isEditing = true;
      _editingProductId = productId;
      
      // Populate form with existing data
      _productNameController.text = productData['name'] ?? '';
      _descriptionController.text = productData['description'] ?? '';
      _skuController.text = productData['sku'] ?? '';
      _weightController.text = (productData['weight'] ?? 0.0).toString();
      _makingChargeController.text = (productData['makingCharge'] ?? 0.0).toString();
      _otherChargesController.text = (productData['otherCharges'] ?? 0.0).toString();
      _discountController.text = (productData['discount'] ?? 0.0).toString();
      _quantityController.text = (productData['quantity'] ?? 1).toString();
      
      // Set selected values
      _selectedCategoryId = productData['category']?['id'];
      _selectedCategory = {
        'name': productData['category']?['name'] ?? '',
      };
      
      _selectedSubcategory = productData['subcategory'];
      
      _selectedMetalId = productData['metal']?['id'];
      _selectedMetal = {
        'name': productData['metal']?['name'] ?? '',
        'carat': productData['metal']?['carat'] ?? '',
        'rate': productData['metal']?['rate'] ?? 0.0,
      };
      
      _metalRate = (_selectedMetal?['rate'] as num?)?.toDouble() ?? 0.0;
      _productImages = List<String>.from(productData['images'] ?? []);
      
      // Calculate price with the populated data
      _calculatePrice();
    });
    
    // Scroll to top of the form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 300),
      );
    });
  }

  Future<void> _loadProductData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        final doc = await _firestore
            .collection('users')
            .doc(currentUser.email)
            .collection('products')
            .doc(widget.editProductId)
            .get();
            
        if (doc.exists) {
          final productData = doc.data() as Map<String, dynamic>;
          _editProduct(widget.editProductId!, productData);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load product: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 16.0, 
                right: 16.0, 
                top: 16.0, 
                bottom: 80.0, // Add padding at bottom for the button
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Products',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _resetForm,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          foregroundColor: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Product Form directly instead of tabs
                  currentUser != null && currentUser.email != null
                    ? _buildAddProductForm(currentUser)
                    : const Center(
                        child: Text('You need to be logged in to manage products'),
                      ),
                ],
              ),
            ),
            
            // Sticky Save Button at the bottom
            Positioned(
              bottom: 0,
              left: 0, 
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: Colors.green.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading ? null : _saveProduct,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isEditing ? 'Update Product' : 'Add Product',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Product Form Builder - modify to remove Save button at bottom
  Widget _buildAddProductForm(User currentUser) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _isEditing ? Icons.edit : Icons.add_box,
                  color: Colors.green.shade800,
                ),
                const SizedBox(width: 10),
                Text(
                  _isEditing ? 'Edit Product' : 'Add New Product',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Error message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade800,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),
                ],
              ),
            ),
          
          // Images Section - moved to start of form and simplified
          Text(
            'Product Image',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          
          // Simplified image picker
          Row(
            children: [
              if (_productImages.isNotEmpty)
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: MemoryImage(
                          base64Decode(_productImages.first),
                        ),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.image,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _isUploadingImage ? null : _pickImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: _isUploadingImage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Select Image'),
                  ),
                  if (_productImages.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _productImages.clear();
                        });
                      },
                      icon: Icon(Icons.delete, color: Colors.red.shade600, size: 18),
                      label: Text(
                        'Remove',
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Basic Info Section
          Text(
            'Basic Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          
          // Product Name
          TextFormField(
            controller: _productNameController,
            decoration: InputDecoration(
              labelText: 'Product Name',
              hintText: 'Enter product name',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.label, color: Colors.green.shade400),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade500, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter product name';
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
              hintText: 'Enter product SKU',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.qr_code, color: Colors.green.shade400),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade500, width: 2),
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
          
          // Description
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Enter product description',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.description, color: Colors.green.shade400),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade500, width: 2),
              ),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          
          // Category Section
          Text(
            'Category & Metal',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          
          // Category Dropdown
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(currentUser.email)
                .collection('categories')
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              // Handle loading state
              if (snapshot.connectionState == ConnectionState.waiting) {
                return DropdownButtonFormField<String>(
                  items: const [],
                  onChanged: null,
                  decoration: InputDecoration(
                    labelText: 'Category (Loading...)',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.category, color: Colors.green.shade400),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                );
              }
              
              // Handle error state
              if (snapshot.hasError) {
                return DropdownButtonFormField<String>(
                  items: const [],
                  onChanged: null,
                  decoration: InputDecoration(
                    labelText: 'Category (Error loading)',
                    filled: true,
                    fillColor: Colors.red.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.error, color: Colors.red),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                );
              }
              
              // No categories available
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please add categories first from the Categories page'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  child: DropdownButtonFormField<String>(
                    items: const [],
                    onChanged: null,
                    decoration: InputDecoration(
                      labelText: 'No categories available',
                      filled: true,
                      fillColor: Colors.orange.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.category, color: Colors.orange),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.orange.shade200),
                      ),
                      suffixIcon: Icon(Icons.add_circle, color: Colors.orange),
                    ),
                  ),
                );
              }
              
              // Build category dropdown items
              final categories = snapshot.data!.docs;
              final dropdownItems = categories.map((doc) {
                final category = doc.data() as Map<String, dynamic>;
                final categoryId = doc.id;
                final categoryName = category['name'] ?? 'Unnamed';
                
                return DropdownMenuItem<String>(
                  value: categoryId,
                  child: Text(categoryName),
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      _selectedSubcategory = null; // Reset subcategory when category changes
                    });
                  },
                );
              }).toList();
              
              return DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                items: dropdownItems,
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Select Category',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.category, color: Colors.green.shade400),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green.shade500, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
                isExpanded: true,
              );
            },
          ),
          const SizedBox(height: 16),
          
          // Subcategory Dropdown (depends on selected category)
          if (_selectedCategory != null && 
              _selectedCategory!['subcategories'] != null && 
              (_selectedCategory!['subcategories'] as List).isNotEmpty)
            DropdownButtonFormField<String>(
              value: _selectedSubcategory,
              items: (_selectedCategory!['subcategories'] as List).map((subcategory) {
                return DropdownMenuItem<String>(
                  value: subcategory.toString(),
                  child: Text(subcategory.toString()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSubcategory = value;
                });
              },
              decoration: InputDecoration(
                labelText: 'Select Subcategory (Optional)',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.subdirectory_arrow_right, color: Colors.green.shade400),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green.shade500, width: 2),
                ),
              ),
              isExpanded: true,
            ),
          
          if (_selectedCategory != null && 
              (_selectedCategory!['subcategories'] == null || 
              (_selectedCategory!['subcategories'] as List).isEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'No subcategories available for this category',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            
          const SizedBox(height: 16),
          
          // Metal Dropdown
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(currentUser.email)
                .collection('metals')
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              // Handle loading state
              if (snapshot.connectionState == ConnectionState.waiting) {
                return DropdownButtonFormField<String>(
                  items: const [],
                  onChanged: null,
                  decoration: InputDecoration(
                    labelText: 'Metal (Loading...)',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.style, color: Colors.green.shade400),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                );
              }
              
              // Handle error state
              if (snapshot.hasError) {
                return DropdownButtonFormField<String>(
                  items: const [],
                  onChanged: null,
                  decoration: InputDecoration(
                    labelText: 'Metal (Error loading)',
                    filled: true,
                    fillColor: Colors.red.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.error, color: Colors.red),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                );
              }
              
              // No metals available
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please add metals first from the Metals page'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  child: DropdownButtonFormField<String>(
                    items: const [],
                    onChanged: null,
                    decoration: InputDecoration(
                      labelText: 'No metals available',
                      filled: true,
                      fillColor: Colors.orange.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.style, color: Colors.orange),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.orange.shade200),
                      ),
                      suffixIcon: Icon(Icons.add_circle, color: Colors.orange),
                    ),
                  ),
                );
              }
              
              // Build metal dropdown items
              final metals = snapshot.data!.docs;
              final dropdownItems = metals.map((doc) {
                final metal = doc.data() as Map<String, dynamic>;
                final metalId = doc.id;
                final metalName = metal['name'] ?? 'Unnamed';
                final carat = metal['carat'] ?? '';
                final rate = (metal['rate'] as num?)?.toDouble() ?? 0.0;
                final formattedRate = currencyFormat.format(rate);
                
                return DropdownMenuItem<String>(
                  value: metalId,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(metalName),
                      Text(
                        '$carat - $formattedRate/g',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      _selectedMetalId = metalId;
                      _selectedMetal = metal;
                    });
                  },
                );
              }).toList();
              
              return DropdownButtonFormField<String>(
                value: _selectedMetalId,
                items: dropdownItems,
                onChanged: (value) {
                  setState(() {
                    _selectedMetalId = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Select Metal',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.style, color: Colors.green.shade400),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green.shade500, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a metal';
                  }
                  return null;
                },
                isExpanded: true,
              );
            },
          ),
          const SizedBox(height: 16),
          
          // Weight Input
          TextFormField(
            controller: _weightController,
            decoration: InputDecoration(
              labelText: 'Weight (grams)',
              hintText: 'Enter weight in grams',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.line_weight, color: Colors.green.shade400),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade500, width: 2),
              ),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter weight';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Making Charge Input
          TextFormField(
            controller: _makingChargeController,
            decoration: InputDecoration(
              labelText: 'Making Charge (%)',
              hintText: 'Enter making charge percentage',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.percent, color: Colors.green.shade400),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade500, width: 2),
              ),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter making charge';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Other Charges Input
          TextFormField(
            controller: _otherChargesController,
            decoration: InputDecoration(
              labelText: 'Other Charges',
              hintText: 'Enter other charges',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.attach_money, color: Colors.green.shade400),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade500, width: 2),
              ),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter other charges';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Discount Input
          TextFormField(
            controller: _discountController,
            decoration: InputDecoration(
              labelText: 'Discount (%)',
              hintText: 'Enter discount percentage',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.discount, color: Colors.green.shade400),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade500, width: 2),
              ),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter discount';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Quantity Input
          TextFormField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: 'Quantity',
              hintText: 'Enter quantity',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.list, color: Colors.green.shade400),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade500, width: 2),
              ),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter quantity';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // Total Price
          Text(
            'Total Price: ${currencyFormat.format(_totalPrice)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 16),
          
          // Add this section after the Weight & Quantity section, before Pricing
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  // Add a different image picker method using File IO
  Future<void> _pickImage() async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      // Show a simple dialog to choose camera or gallery
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text('Select Image Source'),
            children: <Widget>[
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, ImageSource.camera),
                child: const Text('Camera'),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, ImageSource.gallery),
                child: const Text('Gallery'),
              ),
            ],
          );
        },
      );

      if (source == null) {
        setState(() {
          _isUploadingImage = false;
        });
        return;
      }

      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        final List<int> imageBytes = await imageFile.readAsBytes();
        final String base64Image = base64Encode(imageBytes);
        
        setState(() {
          _productImages.add(base64Image);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }
} 