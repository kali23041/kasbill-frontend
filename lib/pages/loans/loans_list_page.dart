import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class LoansListPage extends StatefulWidget {
  const LoansListPage({super.key});

  @override
  State<LoansListPage> createState() => _LoansListPageState();
}

class _LoansListPageState extends State<LoansListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final dateFormat = DateFormat('dd MMM yyyy');
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  String _statusFilter = 'All';
  final List<String> _statusOptions = ['All', 'Active', 'Closed', 'Overdue'];
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Calculate interest until today
  double calculateInterest(Map<String, dynamic> loan) {
    final double principal = loan['loanAmount'] ?? 0.0;
    final double interestRate = loan['interestRate'] ?? 0.0;
    
    DateTime startDate;
    if (loan['startDate'] is Timestamp) {
      startDate = (loan['startDate'] as Timestamp).toDate();
    } else {
      startDate = DateTime.now();
    }
    
    final DateTime now = DateTime.now();
    final int daysDifference = now.difference(startDate).inDays;
    
    // Daily interest calculation
    final double dailyInterestRate = interestRate / 100 / 30; // Monthly rate divided by 30 days
    final double interestAmount = principal * dailyInterestRate * daysDifference;
    
    return interestAmount;
  }
  
  // Calculate total amount to be paid (principal + interest)
  double calculateTotalAmount(Map<String, dynamic> loan) {
    final double principal = loan['loanAmount'] ?? 0.0;
    final double interestAmount = calculateInterest(loan);
    return principal + interestAmount;
  }

  @override
  Widget build(BuildContext context) {
    final String? userEmail = _auth.currentUser?.email;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'All Loans',
          style: TextStyle(
            color: Colors.amber.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.amber.shade800),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 80.0, 16.0, 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by customer name or item',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.amber.shade500, width: 2),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusOptions.map((status) {
                  final isSelected = _statusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      selectedColor: Colors.amber.shade100,
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.amber.shade800
                            : Colors.grey.shade800,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _statusFilter = status;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // List of loans
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(userEmail)
                  .collection('loans')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading loans: ${snapshot.error}'),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.monetization_on_outlined,
                          size: 64,
                          color: Colors.amber.shade200,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No loans found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first loan by clicking the "New Loan" button',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                // Apply filters and search
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final loan = doc.data() as Map<String, dynamic>;
                  
                  // Apply status filter
                  if (_statusFilter != 'All') {
                    final String loanStatus = loan['status'] ?? '';
                    if (loanStatus.toLowerCase() != _statusFilter.toLowerCase()) {
                      return false;
                    }
                  }
                  
                  // Apply search query
                  if (_searchQuery.isNotEmpty) {
                    final String customerName = loan['customerName']?.toString().toLowerCase() ?? '';
                    final String itemName = loan['item']?['name']?.toString().toLowerCase() ?? '';
                    final String itemDescription = loan['item']?['description']?.toString().toLowerCase() ?? '';
                    
                    return customerName.contains(_searchQuery) || 
                           itemName.contains(_searchQuery) ||
                           itemDescription.contains(_searchQuery);
                  }
                  
                  return true;
                }).toList();
                
                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'No loans match your filters',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final loan = doc.data() as Map<String, dynamic>;
                    final loanId = doc.id;
                    
                    // Get loan details
                    final customerName = loan['customerName'] ?? 'Unknown Customer';
                    final loanAmount = (loan['loanAmount'] as num?)?.toDouble() ?? 0.0;
                    final interestRate = (loan['interestRate'] as num?)?.toDouble() ?? 0.0;
                    final itemName = loan['item']?['name'] ?? 'Unknown Item';
                    
                    // Get dates
                    DateTime startDate;
                    if (loan['startDate'] is Timestamp) {
                      startDate = (loan['startDate'] as Timestamp).toDate();
                    } else {
                      startDate = DateTime.now();
                    }
                    
                    DateTime endDate;
                    if (loan['endDate'] is Timestamp) {
                      endDate = (loan['endDate'] as Timestamp).toDate();
                    } else {
                      endDate = DateTime.now().add(const Duration(days: 30));
                    }
                    
                    // Calculate interest and total amount
                    final interestAmount = calculateInterest(loan);
                    final totalAmount = calculateTotalAmount(loan);
                    
                    // Determine loan status
                    final String status = loan['status'] ?? 'active';
                    Color statusColor;
                    
                    switch (status.toLowerCase()) {
                      case 'active':
                        statusColor = Colors.green;
                        break;
                      case 'closed':
                        statusColor = Colors.blue;
                        break;
                      case 'overdue':
                        statusColor = Colors.red;
                        break;
                      default:
                        statusColor = Colors.grey;
                    }
                    
                    // Check if there's an image
                    final List<dynamic> images = loan['item']?['images'] ?? [];
                    final bool hasImage = images.isNotEmpty;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
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
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () {
                            // Show loan details
                            _showLoanDetails(loan, loanId);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Item image or placeholder
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.grey.shade200,
                                        image: hasImage
                                            ? DecorationImage(
                                                image: MemoryImage(
                                                  base64Decode(images.first.toString()),
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: hasImage
                                          ? null
                                          : Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey.shade400,
                                            ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Customer and loan details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  customerName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  status.toUpperCase(),
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            itemName,
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today, 
                                                size: 14, 
                                                color: Colors.grey.shade600
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                
                                // Loan amounts
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildAmountColumn(
                                      'Principal', 
                                      currencyFormat.format(loanAmount),
                                      Icons.attach_money,
                                      Colors.amber.shade700,
                                    ),
                                    _buildAmountColumn(
                                      'Interest (${interestRate.toStringAsFixed(1)}%)', 
                                      currencyFormat.format(interestAmount),
                                      Icons.trending_up,
                                      Colors.green.shade700,
                                    ),
                                    _buildAmountColumn(
                                      'Total', 
                                      currencyFormat.format(totalAmount),
                                      Icons.account_balance_wallet,
                                      Colors.purple.shade700,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
      
      // Floating action button to add a new loan
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Loan'),
        backgroundColor: Colors.amber.shade700,
      ),
    );
  }
  
  Widget _buildAmountColumn(String label, String amount, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }
  
  void _showLoanDetails(Map<String, dynamic> loan, String loanId) {
    // Show bottom sheet with loan details
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Loan Details',
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
                const Divider(height: 24),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailSection(
                          title: 'Customer Information',
                          children: [
                            _buildDetailRow('Name', loan['customerName'] ?? 'N/A'),
                            _buildDetailRow('Phone', loan['customerPhone'] ?? 'N/A'),
                            _buildDetailRow('Address', loan['customerAddress'] ?? 'N/A'),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildDetailSection(
                          title: 'Loan Information',
                          children: [
                            _buildDetailRow('Principal Amount', currencyFormat.format(loan['loanAmount'] ?? 0)),
                            _buildDetailRow('Interest Rate', '${(loan['interestRate'] ?? 0).toString()}%'),
                            _buildDetailRow('Duration', '${loan['durationDays'] ?? 0} days'),
                            
                            // Get dates
                            _buildDetailRow('Start Date', dateFormat.format(
                              loan['startDate'] is Timestamp 
                                ? (loan['startDate'] as Timestamp).toDate() 
                                : DateTime.now()
                            )),
                            _buildDetailRow('End Date', dateFormat.format(
                              loan['endDate'] is Timestamp 
                                ? (loan['endDate'] as Timestamp).toDate() 
                                : DateTime.now().add(const Duration(days: 30))
                            )),
                            
                            _buildDetailRow('Status', (loan['status'] ?? 'active').toUpperCase()),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildDetailSection(
                          title: 'Item Information',
                          children: [
                            _buildDetailRow('Name', loan['item']?['name'] ?? 'N/A'),
                            _buildDetailRow('Description', loan['item']?['description'] ?? 'N/A'),
                            _buildDetailRow('Weight', '${loan['item']?['weight'] ?? 'N/A'} g'),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Item images
                        Text(
                          'Item Images',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        SizedBox(
                          height: 120,
                          child: _buildItemImages(loan['item']?['images'] ?? []),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Calculations
                        _buildDetailSection(
                          title: 'Financial Details',
                          children: [
                            _buildDetailRow('Principal Amount', currencyFormat.format(loan['loanAmount'] ?? 0)),
                            _buildDetailRow('Interest Until Today', currencyFormat.format(calculateInterest(loan))),
                            const Divider(),
                            _buildDetailRow('Total Amount Due', currencyFormat.format(calculateTotalAmount(loan)), 
                              valueStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Actions
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Close Loan button (if active)
                    if ((loan['status'] ?? 'active').toLowerCase() == 'active')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Close Loan'),
                        onPressed: () => _updateLoanStatus(loanId, 'closed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    
                    // Mark as Overdue button (if active)
                    if ((loan['status'] ?? 'active').toLowerCase() == 'active')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.warning),
                        label: const Text('Mark Overdue'),
                        onPressed: () => _updateLoanStatus(loanId, 'overdue'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    
                    // Reactivate button (if closed or overdue)
                    if ((loan['status'] ?? 'active').toLowerCase() != 'active')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reactivate'),
                        onPressed: () => _updateLoanStatus(loanId, 'active'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildItemImages(List<dynamic> images) {
    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No images available',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: images.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(right: 8),
          width: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: MemoryImage(
                base64Decode(images[index].toString()),
              ),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDetailSection({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade800,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _updateLoanStatus(String loanId, String status) async {
    try {
      final String? userEmail = _auth.currentUser?.email;
      if (userEmail == null) return;
      
      await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('loans')
          .doc(loanId)
          .update({'status': status});
      
      Navigator.pop(context); // Close the details sheet
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loan status updated to $status'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update loan status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 