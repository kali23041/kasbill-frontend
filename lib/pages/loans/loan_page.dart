import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'loans_list_page.dart';

class LoanPage extends StatefulWidget {
  const LoanPage({super.key});

  @override
  State<LoanPage> createState() => _LoanPageState();
}

class _LoanPageState extends State<LoanPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  
  // Form controllers
  final _loanAmountController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _durationController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemDescriptionController = TextEditingController();
  final _itemWeightController = TextEditingController();
  
  // Selected customer
  Map<String, dynamic>? _selectedCustomer;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  
  // Item images
  List<String> _itemImages = [];
  bool _isUploadingImage = false;
  
  // State
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;
  
  // Format for currency
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final dateFormat = DateFormat('dd MMM yyyy');
  
  @override
  void dispose() {
    _loanAmountController.dispose();
    _interestRateController.dispose();
    _durationController.dispose();
    _itemNameController.dispose();
    _itemDescriptionController.dispose();
    _itemWeightController.dispose();
    super.dispose();
  }
  
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        // Update end date based on duration
        _calculateEndDate();
      });
    }
  }
  
  void _calculateEndDate() {
    int days = int.tryParse(_durationController.text) ?? 30;
    setState(() {
      _endDate = _startDate.add(Duration(days: days));
    });
  }
  
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
          _itemImages.add(base64Image);
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
  
  Future<void> _showCustomerSelectionSheet() async {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final String? userEmail = _auth.currentUser?.email;
    
    if (userEmail == null) return;
    
    // Show bottom sheet to select customer
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Customer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(userEmail)
                      .collection('customers')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error loading customers: ${snapshot.error}'),
                      );
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('No customers found'),
                      );
                    }
                    
                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final customer = doc.data() as Map<String, dynamic>;
                        final customerId = doc.id;
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.amber.shade100,
                            child: Text(
                              customer['name']?[0]?.toUpperCase() ?? 'C',
                              style: TextStyle(
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(customer['name'] ?? 'Unknown'),
                          subtitle: Text(customer['phone'] ?? 'No phone'),
                          onTap: () {
                            setState(() {
                              _selectedCustomer = {
                                'id': customerId,
                                ...customer,
                              };
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedCustomer == null) {
      setState(() {
        _errorMessage = 'Please select a customer';
      });
      return;
    }
    
    if (_itemImages.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one image of the item';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception('You must be logged in to create a loan');
      }
      
      final loanData = {
        'customerId': _selectedCustomer!['id'],
        'customerName': _selectedCustomer!['name'],
        'customerPhone': _selectedCustomer!['phone'],
        'customerAddress': _selectedCustomer!['address'],
        'loanAmount': double.parse(_loanAmountController.text),
        'interestRate': double.parse(_interestRateController.text),
        'durationDays': int.parse(_durationController.text),
        'startDate': _startDate,
        'endDate': _endDate,
        'item': {
          'name': _itemNameController.text,
          'description': _itemDescriptionController.text,
          'weight': _itemWeightController.text,
          'images': _itemImages,
        },
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Generate a unique ID for the loan using customer name and timestamp
      final String loanId = '${_selectedCustomer!['name']}_${DateTime.now().millisecondsSinceEpoch}';
      
      await _firestore
          .collection('users')
          .doc(currentUser.email)
          .collection('loans')
          .doc(loanId)
          .set(loanData);
      
      setState(() {
        _isSuccess = true;
        // Reset form
        _selectedCustomer = null;
        _loanAmountController.clear();
        _interestRateController.clear();
        _durationController.clear();
        _itemNameController.clear();
        _itemDescriptionController.clear();
        _itemWeightController.clear();
        _itemImages.clear();
        _startDate = DateTime.now();
        _endDate = DateTime.now().add(const Duration(days: 30));
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loan created successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create loan: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          color: Colors.amber.shade800,
        ),
        title: const Text(''),
        actions: [
          TextButton.icon(
            icon: Icon(
              Icons.list_alt,
              size: 16,
              color: Colors.amber.shade700,
            ),
            label: Text(
              'View All Loans',
              style: TextStyle(color: Colors.amber.shade700, fontSize: 13),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoansListPage()),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.amber.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 60.0, 16.0, 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                
              if (_isSuccess)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Loan created successfully!',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Customer Selection
              _buildSection(
                title: 'Customer Information',
                children: [
                  if (_selectedCustomer != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCustomer!['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 16, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Text(
                              _selectedCustomer!['phone'],
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedCustomer!['address'],
                                style: TextStyle(
                                  fontSize: 15, 
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton.icon(
                            icon: Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.amber.shade700,
                            ),
                            label: Text(
                              'Change Customer',
                              style: TextStyle(color: Colors.amber.shade700),
                            ),
                            onPressed: _showCustomerSelectionSheet,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.amber.shade50,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Center(
                      child: TextButton.icon(
                        icon: Icon(
                          Icons.person_add,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                        label: Text(
                          'Select Customer',
                          style: TextStyle(color: Colors.amber.shade700),
                        ),
                        onPressed: _showCustomerSelectionSheet,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.amber.shade50,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Loan Details
              _buildSection(
                title: 'Loan Details',
                children: [
                  TextFormField(
                    controller: _loanAmountController,
                    decoration: InputDecoration(
                      labelText: 'Loan Amount',
                      hintText: 'Enter loan amount',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.money, color: Colors.amber.shade400),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.amber.shade500, width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter loan amount';
                      }
                      try {
                        double.parse(value);
                      } catch (e) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _interestRateController,
                          decoration: InputDecoration(
                            labelText: 'Interest Rate (%)',
                            hintText: 'Enter interest rate',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(Icons.percent, color: Colors.amber.shade400),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.amber.shade500, width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter interest rate';
                            }
                            try {
                              double.parse(value);
                            } catch (e) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          decoration: InputDecoration(
                            labelText: 'Duration (Days)',
                            hintText: 'Enter duration',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(Icons.calendar_today, color: Colors.amber.shade400),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.amber.shade500, width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter duration';
                            }
                            try {
                              int.parse(value);
                            } catch (e) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              _calculateEndDate();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Date picker
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectStartDate(context),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Start Date',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(Icons.date_range, color: Colors.amber.shade400),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Text(dateFormat.format(_startDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'End Date',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(Icons.event, color: Colors.amber.shade400),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Text(dateFormat.format(_endDate)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Item Details
              _buildSection(
                title: 'Item Details',
                children: [
                  TextFormField(
                    controller: _itemNameController,
                    decoration: InputDecoration(
                      labelText: 'Item Name',
                      hintText: 'Enter item name',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.shopping_bag, color: Colors.amber.shade400),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.amber.shade500, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter item name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _itemDescriptionController,
                    decoration: InputDecoration(
                      labelText: 'Item Description',
                      hintText: 'Enter item description',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.description, color: Colors.amber.shade400),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.amber.shade500, width: 2),
                      ),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter item description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _itemWeightController,
                    decoration: InputDecoration(
                      labelText: 'Weight (grams)',
                      hintText: 'Enter weight in grams',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.scale, color: Colors.amber.shade400),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.amber.shade500, width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter item weight';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Item Images
                  const Text(
                    'Item Images',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_itemImages.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.image,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No images added yet',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _itemImages.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: MemoryImage(
                                        base64Decode(_itemImages[index]),
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _itemImages.removeAt(index);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton.icon(
                            icon: Icon(
                              Icons.add_a_photo,
                              color: Colors.amber.shade700,
                            ),
                            label: Text(
                              'Add Image',
                              style: TextStyle(color: Colors.amber.shade700),
                            ),
                            onPressed: _isUploadingImage ? null : _pickImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade50,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveLoan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Loan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
} 