import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math';
import 'billing/customer_section.dart';
import 'billing/product_section.dart';
import 'billing/bill_summary_section.dart';
import 'billing/bill_header_section.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Controllers
  final _searchProductController = TextEditingController();
  final _discountController = TextEditingController();
  final _taxController = TextEditingController();
  final _additionalChargesController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Selected customer
  Map<String, dynamic>? _selectedCustomer;
  
  // Bill items
  List<Map<String, dynamic>> _billItems = [];
  
  // Bill calculations
  double _subtotal = 0.0;
  double _discount = 0.0;
  double _tax = 0.0;
  double _additionalCharges = 0.0;
  double _total = 0.0;
  
  // Payment information
  String _paymentMethod = 'Cash';
  List<String> _paymentMethods = ['Cash', 'Card', 'UPI', 'Bank Transfer'];
  
  // Status flags
  bool _isProcessing = false;
  String? _errorMessage;
  
  // Formatting
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  
  @override
  void initState() {
    super.initState();
    _taxController.text = '3'; // Default GST
    _discountController.text = '0';
    _additionalChargesController.text = '0';
    
    // Add listeners for calculations
    _discountController.addListener(_calculateBill);
    _taxController.addListener(_calculateBill);
    _additionalChargesController.addListener(_calculateBill);
  }
  
  @override
  void dispose() {
    _searchProductController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _additionalChargesController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  // Generate a random invoice number
  String _generateInvoiceNumber() {
    final random = Random();
    int number = random.nextInt(900000) + 100000; // Generate 6-digit number
    return 'INV$number';
  }
  
  // Calculate totals for the bill
  void _calculateBill() {
    setState(() {
      // Calculate subtotal from bill items
      _subtotal = _billItems.fold(0, (sum, item) => sum + (item['totalPrice'] as double));
      
      // Parse other inputs with fallbacks
      _discount = double.tryParse(_discountController.text) ?? 0.0;
      _tax = double.tryParse(_taxController.text) ?? 0.0;
      _additionalCharges = double.tryParse(_additionalChargesController.text) ?? 0.0;
      
      // Calculate total
      double discountAmount = (_discount / 100) * _subtotal;
      double afterDiscount = _subtotal - discountAmount;
      double taxAmount = (_tax / 100) * afterDiscount;
      
      _total = afterDiscount + taxAmount + _additionalCharges;
    });
  }
  
  // Add a product to the bill
  void _addProductToBill(Map<String, dynamic> product, [int quantity = 1]) {
    // Check if product already exists in the bill
    int existingIndex = _billItems.indexWhere((item) => item['productId'] == product['id']);
    
    setState(() {
      if (existingIndex >= 0) {
        // Increment quantity if product already exists
        _billItems[existingIndex]['quantity'] += quantity;
        _billItems[existingIndex]['totalPrice'] = 
            _billItems[existingIndex]['unitPrice'] * _billItems[existingIndex]['quantity'];
      } else {
        // Add new product to bill
        _billItems.add({
          'productId': product['id'],
          'name': product['name'],
          'category': product['category']['name'],
          'metal': '${product['metal']['name']} ${product['metal']['carat']}',
          'weight': product['weight'],
          'unitPrice': product['unitPrice'],
          'quantity': quantity,
          'totalPrice': product['unitPrice'] * quantity,
          'productData': product,
        });
      }
      
      // Recalculate bill totals
      _calculateBill();
    });
  }
  
  // Remove an item from the bill
  void _removeItemFromBill(int index) {
    setState(() {
      _billItems.removeAt(index);
      _calculateBill();
    });
  }
  
  // Change item quantity
  void _changeItemQuantity(int index, int newQuantity) {
    if (newQuantity < 1) return;
    
    setState(() {
      _billItems[index]['quantity'] = newQuantity;
      _billItems[index]['totalPrice'] = _billItems[index]['unitPrice'] * newQuantity;
      _calculateBill();
    });
  }
  
  // Search and select customer
  void _showCustomerSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomerSelectionDialog(
        onCustomerSelected: (customer) {
          setState(() {
            _selectedCustomer = customer;
          });
        },
      ),
    );
  }
  
  // Search and add products
  void _showProductSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductSelectionDialog(
        onProductSelected: (product) {
          _addProductToBill(product);
        },
        currencyFormat: currencyFormat,
      ),
    );
  }
  
  // Confirm and save the bill
  Future<void> _saveBill() async {
    if (_billItems.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one product to the bill';
      });
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != null) {
        final String invoiceNumber = _generateInvoiceNumber();
        final DateTime now = DateTime.now();
        
        // Prepare bill data
        final Map<String, dynamic> billData = {
          'invoiceNumber': invoiceNumber,
          'date': now,
          'customer': _selectedCustomer != null 
              ? {
                  'id': _selectedCustomer!['id'],
                  'name': _selectedCustomer!['name'],
                  'phone': _selectedCustomer!['phone'],
                  'address': _selectedCustomer!['address'],
                }
              : null,
          'items': _billItems.map((item) {
            return {
              'productId': item['productId'],
              'name': item['name'],
              'category': item['category'],
              'metal': item['metal'],
              'weight': item['weight'],
              'unitPrice': item['unitPrice'],
              'quantity': item['quantity'],
              'totalPrice': item['totalPrice'],
            };
          }).toList(),
          'subtotal': _subtotal,
          'discountPercentage': _discount,
          'discountAmount': (_discount / 100) * _subtotal,
          'taxPercentage': _tax,
          'taxAmount': (_tax / 100) * (_subtotal - (_discount / 100) * _subtotal),
          'additionalCharges': _additionalCharges,
          'total': _total,
          'paymentMethod': _paymentMethod,
          'notes': _notesController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        // Save bill to Firestore
        await _firestore
            .collection('users')
            .doc(currentUser.email)
            .collection('bills')
            .doc(invoiceNumber)
            .set(billData);
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bill #$invoiceNumber saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Clear form for new bill
          _resetForm();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save bill: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  // Reset the form for a new bill
  void _resetForm() {
    setState(() {
      _billItems = [];
      _selectedCustomer = null;
      _discountController.text = '0';
      _taxController.text = '3';
      _additionalChargesController.text = '0';
      _notesController.text = '';
      _paymentMethod = 'Cash';
      _subtotal = 0.0;
      _discount = 0.0;
      _tax = 3.0;
      _additionalCharges = 0.0;
      _total = 0.0;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    
    return Scaffold(
      body: currentUser != null && currentUser.email != null
          ? SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Create Bill',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset'),
                              onPressed: _resetForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade100,
                                foregroundColor: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Main content - make it scrollable
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 80),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Error message (if any)
                                if (_errorMessage != null)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade300),
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
                                
                                // Basic info card
                                Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Invoice header
                                        BillHeaderSection(
                                          invoiceNumber: _generateInvoiceNumber(),
                                          date: DateTime.now(),
                                          dateFormat: dateFormat,
                                        ),
                                        const Divider(height: 24),
                                        
                                        // Customer selection
                                        CustomerSection(
                                          selectedCustomer: _selectedCustomer,
                                          onSelectCustomer: _showCustomerSelectionSheet,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                // Product items section
                                Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: ProductSection(
                                      billItems: _billItems,
                                      onAddProduct: _showProductSelectionSheet,
                                      onRemoveItem: _removeItemFromBill,
                                      onChangeQuantity: _changeItemQuantity, 
                                      currencyFormat: currencyFormat,
                                    ),
                                  ),
                                ),
                                
                                // Bill summary section
                                Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: BillSummarySection(
                                      subtotal: _subtotal,
                                      discountController: _discountController,
                                      taxController: _taxController,
                                      additionalChargesController: _additionalChargesController,
                                      notesController: _notesController,
                                      discount: _discount,
                                      tax: _tax,
                                      additionalCharges: _additionalCharges,
                                      total: _total,
                                      paymentMethod: _paymentMethod,
                                      paymentMethods: _paymentMethods,
                                      onPaymentMethodChanged: (method) {
                                        setState(() {
                                          _paymentMethod = method;
                                        });
                                      },
                                      currencyFormat: currencyFormat,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Fixed position save button
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveBill,
                          child: const Text(
                            'Save Bill',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const Center(
              child: Text('You need to be logged in to create bills'),
            ),
    );
  }
} 