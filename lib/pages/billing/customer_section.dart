import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerSection extends StatelessWidget {
  final Map<String, dynamic>? selectedCustomer;
  final VoidCallback onSelectCustomer;

  const CustomerSection({
    Key? key,
    required this.selectedCustomer,
    required this.onSelectCustomer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outlined,
                      color: Color(0xFF1E40AF),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Customer Information',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                icon: Icon(
                  selectedCustomer != null ? Icons.edit_outlined : Icons.add_outlined,
                  size: 16,
                  color: const Color(0xFF1E40AF),
                ),
                label: Text(
                  selectedCustomer != null ? 'Change' : 'Add',
                  style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: onSelectCustomer,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF).withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          if (selectedCustomer != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedCustomer!['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      selectedCustomer!['phone'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        selectedCustomer!['address'],
                        style: const TextStyle(
                          fontSize: 13, 
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 20, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  const Text(
                    'No customer selected',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Customer selection dialog
class CustomerSelectionDialog extends StatelessWidget {
  final Function(Map<String, dynamic>) onCustomerSelected;

  const CustomerSelectionDialog({
    Key? key,
    required this.onCustomerSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final TextEditingController _searchController = TextEditingController();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Customer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_outlined, color: Color(0xFF64748B), size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search customers',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: const Icon(Icons.search_outlined, color: Color(0xFF64748B), size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 8),
              
              // Customer list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(_auth.currentUser?.email)
                      .collection('customers')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E40AF),
                          strokeWidth: 2,
                        ),
                      );
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading customers: ${snapshot.error}',
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                      );
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No customers found',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      );
                    }
                    
                    // Filter customers based on search
                    final query = _searchController.text.toLowerCase();
                    final filteredDocs = snapshot.data!.docs.where((doc) {
                      final customer = doc.data() as Map<String, dynamic>;
                      final name = customer['name']?.toString().toLowerCase() ?? '';
                      final phone = customer['phone']?.toString().toLowerCase() ?? '';
                      return name.contains(query) || phone.contains(query);
                    }).toList();
                    
                    return filteredDocs.isEmpty
                        ? Center(
                            child: Text(
                              'No customers matching "${_searchController.text}"',
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final customer = doc.data() as Map<String, dynamic>;
                              final customerId = doc.id;
                              
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF1E40AF).withOpacity(0.1),
                                  child: Text(
                                    customer['name'][0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF1E40AF),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  customer['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                subtitle: Text(
                                  customer['phone'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                onTap: () {
                                  onCustomerSelected({
                                    'id': customerId,
                                    ...customer,
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
          );
        },
      ),
    );
  }
} 