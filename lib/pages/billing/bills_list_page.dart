import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'bill_details_sheet.dart';

class BillsListPage extends StatefulWidget {
  const BillsListPage({Key? key}) : super(key: key);

  @override
  State<BillsListPage> createState() => _BillsListPageState();
}

class _BillsListPageState extends State<BillsListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  
  String _statusFilter = 'All';
  final List<String> _statusOptions = ['All', 'Paid', 'Pending', 'Cancelled'];
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  DateTime? _startDate;
  DateTime? _endDate;
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.amber.shade700,
            colorScheme: ColorScheme.light(
              primary: Colors.amber.shade700,
              onPrimary: Colors.white,
            ),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
  
  void _clearFilters() {
    setState(() {
      _statusFilter = 'All';
      _searchQuery = '';
      _searchController.clear();
      _startDate = null;
      _endDate = null;
    });
  }
  
  Stream<QuerySnapshot> _getBillsStream() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.email == null) {
      return const Stream.empty();
    }
    
    Query query = _firestore
        .collection('users')
        .doc(currentUser.email)
        .collection('bills')
        .orderBy('createdAt', descending: true);
    
    // Apply status filter
    if (_statusFilter != 'All') {
      query = query.where('status', isEqualTo: _statusFilter);
    }
    
    // Apply date range filter
    if (_startDate != null) {
      final startOfDay = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      query = query.where('date', isGreaterThanOrEqualTo: startOfDay);
    }
    
    if (_endDate != null) {
      final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      query = query.where('date', isLessThanOrEqualTo: endOfDay);
    }
    
    return query.snapshots();
  }
  
  void _viewBillDetails(String invoiceId, Map<String, dynamic> billData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BillDetailsSheet(
        billData: billData,
        currencyFormat: currencyFormat,
        dateFormat: dateFormat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Filter Sales',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Status filter
                            const Text('Status'),
                            Wrap(
                              spacing: 8,
                              children: _statusOptions.map((status) {
                                return ChoiceChip(
                                  label: Text(status),
                                  selected: _statusFilter == status,
                                  onSelected: (selected) {
                                    if (selected) {
                                      this.setState(() {
                                        _statusFilter = status;
                                      });
                                      Navigator.pop(context);
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            
                            // Date range
                            const Text('Date Range'),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _startDate != null && _endDate != null
                                    ? '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}'
                                    : 'Select date range',
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () {
                                Navigator.pop(context);
                                _showDateRangePicker();
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Clear filters
                            ElevatedButton(
                              onPressed: () {
                                _clearFilters();
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade100,
                                foregroundColor: Colors.red.shade900,
                              ),
                              child: const Text('Clear Filters'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by invoice number or customer',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          // Active filters
          if (_statusFilter != 'All' || _startDate != null || _endDate != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Filters: '),
                    if (_statusFilter != 'All')
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(_statusFilter),
                          onDeleted: () {
                            setState(() {
                              _statusFilter = 'All';
                            });
                          },
                        ),
                      ),
                    if (_startDate != null && _endDate != null)
                      Chip(
                        label: Text(
                          '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM').format(_endDate!)}',
                        ),
                        onDeleted: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
          
          // Bills list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getBillsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No bills found',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_statusFilter != 'All' || _startDate != null || _endDate != null)
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text('Clear Filters'),
                          ),
                      ],
                    ),
                  );
                }
                
                // Filter bills based on search query
                final filteredDocs = _searchQuery.isEmpty
                    ? snapshot.data!.docs
                    : snapshot.data!.docs.where((doc) {
                        final bill = doc.data() as Map<String, dynamic>;
                        final invoiceNumber = bill['invoiceNumber']?.toString().toLowerCase() ?? '';
                        final customerName = bill['customer']?['name']?.toString().toLowerCase() ?? '';
                        final customerPhone = bill['customer']?['phone']?.toString().toLowerCase() ?? '';
                        
                        return invoiceNumber.contains(_searchQuery) ||
                               customerName.contains(_searchQuery) ||
                               customerPhone.contains(_searchQuery);
                      }).toList();
                
                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No matching bills found',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                          child: const Text('Clear Search'),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final billData = doc.data() as Map<String, dynamic>;
                    final invoiceNumber = billData['invoiceNumber'] ?? 'N/A';
                    
                    // Handle Timestamps
                    DateTime date;
                    if (billData['date'] is Timestamp) {
                      date = (billData['date'] as Timestamp).toDate();
                    } else {
                      date = DateTime.now();
                    }
                    
                    final customerName = billData['customer']?['name'] ?? 'Walk-in Customer';
                    final paymentMethod = billData['paymentMethod'] ?? 'N/A';
                    final total = (billData['total'] as num?)?.toDouble() ?? 0.0;
                    final itemCount = (billData['items'] as List<dynamic>?)?.length ?? 0;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(
                              invoiceNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                paymentMethod,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Date: ${dateFormat.format(date)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              'Customer: $customerName',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              'Items: $itemCount',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currencyFormat.format(total),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        onTap: () => _viewBillDetails(invoiceNumber, billData),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 