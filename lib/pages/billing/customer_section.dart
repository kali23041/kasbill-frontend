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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Customer Information',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            TextButton.icon(
              icon: Icon(
                selectedCustomer != null ? Icons.edit : Icons.add,
                size: 18,
              ),
              label: Text(selectedCustomer != null ? 'Change' : 'Add Customer'),
              onPressed: onSelectCustomer,
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        if (selectedCustomer != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedCustomer!['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      selectedCustomer!['phone'],
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        selectedCustomer!['address'],
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                const Text('No customer selected'),
              ],
            ),
          ),
      ],
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
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
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
              
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search customers',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                            child: Text('No customers matching "${_searchController.text}"'),
                          )
                        : ListView.builder(
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final customer = doc.data() as Map<String, dynamic>;
                              final customerId = doc.id;
                              
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.amber.shade100,
                                  child: Text(
                                    customer['name'][0].toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.amber.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(customer['name']),
                                subtitle: Text(customer['phone']),
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