import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminItemsPage extends StatefulWidget {
  const AdminItemsPage({super.key});

  @override
  State<AdminItemsPage> createState() => _AdminItemsPageState();
}

class _AdminItemsPageState extends State<AdminItemsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _selectedItems = {};
  bool _isSelectionMode = false;
  bool _isLoading = false;

  // Get today's date in YYYY-MM-DD format
  String get _todayDate => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Upper white section with header
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Cancel/Back button (when in selection mode)
                      _isSelectionMode
                          ? GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isSelectionMode = false;
                                  _selectedItems.clear();
                                });
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.black,
                                  size: 18,
                                ),
                              ),
                            )
                          : Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.menu,
                                color: Colors.black,
                                size: 18,
                              ),
                            ),
                      // Brand name
                      Text(
                        _isSelectionMode
                            ? '${_selectedItems.length} selected'
                            : 'All Items',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                      // Action buttons
                      Row(
                        children: [
                          if (_isSelectionMode && _selectedItems.isNotEmpty)
                            GestureDetector(
                              onTap: _deleteSelectedItems,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: _showCreateItemDialog,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.black,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Daily Update Button
                if (!_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _showDailyUpdateDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.update, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Daily Update Price',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (!_isSelectionMode) const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 4),
        
        // Main content area
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
                bottom: Radius.circular(20),
              ),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('items').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
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
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Color(0xFF999999),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No items yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF999999),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _showCreateItemDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Create First Item'),
                        ),
                      ],
                    ),
                  );
                }

                final items = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final itemDoc = items[index];
                    final itemName = itemDoc.id;
                    final itemData = itemDoc.data() as Map<String, dynamic>;
                    final isSelected = _selectedItems.contains(itemName);

                    return _buildItemCard(
                      itemName: itemName,
                      itemData: itemData,
                      isSelected: isSelected,
                      onTap: () => _handleItemTap(itemName),
                      onLongPress: () => _handleItemLongPress(itemName),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard({
    required String itemName,
    required Map<String, dynamic> itemData,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.black.withOpacity(0.1)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Colors.black, width: 2)
              : null,
        ),
        child: Row(
          children: [
            // Selection checkbox
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Colors.black : const Color(0xFF999999),
                  size: 24,
                ),
              ),
            // Item Name
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Sell: ₹${itemData['sellPrice']?.toStringAsFixed(2) ?? '0.00'}/kg',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Buy: ₹${itemData['buyPrice']?.toStringAsFixed(2) ?? '0.00'}/kg',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Today's price indicator
            Expanded(
              flex: 2,
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore
                    .collection('items')
                    .doc(itemName)
                    .collection('dailyRates')
                    .doc(_todayDate)
                    .snapshots(),
                builder: (context, rateSnapshot) {
                  if (rateSnapshot.hasData && rateSnapshot.data!.exists) {
                    final rateData = rateSnapshot.data!.data() as Map<String, dynamic>;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${rateData['sellPrice']?.toStringAsFixed(2) ?? '0.00'}/kg',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'No price',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleItemTap(String itemName) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedItems.contains(itemName)) {
          _selectedItems.remove(itemName);
        } else {
          _selectedItems.add(itemName);
        }
        if (_selectedItems.isEmpty) {
          _isSelectionMode = false;
        }
      });
    } else {
      _showAddTodayPriceDialog(itemName);
    }
  }

  void _handleItemLongPress(String itemName) {
    setState(() {
      _isSelectionMode = true;
      _selectedItems.add(itemName);
    });
  }

  void _showCreateItemDialog() {
    final nameController = TextEditingController();
    final sellPriceController = TextEditingController();
    final buyPriceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Create New Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sellPriceController,
              decoration: const InputDecoration(
                labelText: 'Sell Price (₹/kg)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: buyPriceController,
              decoration: const InputDecoration(
                labelText: 'Buy Price (₹/kg)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final sellPrice = double.tryParse(sellPriceController.text) ?? 0.0;
              final buyPrice = double.tryParse(buyPriceController.text) ?? 0.0;

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item name is required')),
                );
                return;
              }

              try {
                await _firestore.collection('items').doc(name).set({
                  'sellPrice': sellPrice,
                  'buyPrice': buyPrice,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item created successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddTodayPriceDialog(String itemName) {
    final sellPriceController = TextEditingController();
    final buyPriceController = TextEditingController();

    // Get current today's price if exists
    _firestore
        .collection('items')
        .doc(itemName)
        .collection('dailyRates')
        .doc(_todayDate)
        .get()
        .then((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        sellPriceController.text = data['sellPrice']?.toString() ?? '';
        buyPriceController.text = data['buyPrice']?.toString() ?? '';
      }
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Update Price - $itemName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sellPriceController,
              decoration: const InputDecoration(
                labelText: 'Sell Price (₹/kg)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: buyPriceController,
              decoration: const InputDecoration(
                labelText: 'Buy Price (₹/kg)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final sellPrice = double.tryParse(sellPriceController.text) ?? 0.0;
              final buyPrice = double.tryParse(buyPriceController.text) ?? 0.0;

              try {
                await _firestore
                    .collection('items')
                    .doc(itemName)
                    .collection('dailyRates')
                    .doc(_todayDate)
                    .set({
                  'sellPrice': sellPrice,
                  'buyPrice': buyPrice,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Price updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDailyUpdateDialog() async {
    // Get all items
    final itemsSnapshot = await _firestore.collection('items').get();
    
    if (itemsSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to update')),
      );
      return;
    }

    final sellPriceControllers = <String, TextEditingController>{};
    final buyPriceControllers = <String, TextEditingController>{};

    // Initialize controllers with today's prices
    for (var doc in itemsSnapshot.docs) {
      final itemName = doc.id;
      sellPriceControllers[itemName] = TextEditingController();
      buyPriceControllers[itemName] = TextEditingController();

      final todayRateDoc = await _firestore
          .collection('items')
          .doc(itemName)
          .collection('dailyRates')
          .doc(_todayDate)
          .get();

      if (todayRateDoc.exists) {
        final data = todayRateDoc.data() as Map<String, dynamic>;
        sellPriceControllers[itemName]!.text = data['sellPrice']?.toString() ?? '';
        buyPriceControllers[itemName]!.text = data['buyPrice']?.toString() ?? '';
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Daily Update All Prices'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: itemsSnapshot.docs.length,
            itemBuilder: (context, index) {
              final itemName = itemsSnapshot.docs[index].id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sellPriceControllers[itemName],
                            decoration: const InputDecoration(
                              labelText: 'Sell (₹/kg)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: buyPriceControllers[itemName],
                            decoration: const InputDecoration(
                              labelText: 'Buy (₹/kg)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });

              try {
                final batch = _firestore.batch();
                
                for (var doc in itemsSnapshot.docs) {
                  final itemName = doc.id;
                  final sellPrice = double.tryParse(sellPriceControllers[itemName]!.text) ?? 0.0;
                  final buyPrice = double.tryParse(buyPriceControllers[itemName]!.text) ?? 0.0;

                  final rateRef = _firestore
                      .collection('items')
                      .doc(itemName)
                      .collection('dailyRates')
                      .doc(_todayDate);

                  batch.set(rateRef, {
                    'sellPrice': sellPrice,
                    'buyPrice': buyPrice,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }

                await batch.commit();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All prices updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Update All'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedItems.isEmpty) return;

    final selectedCount = _selectedItems.length;
    final selectedItemsCopy = Set<String>.from(_selectedItems);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Items'),
        content: Text(
          'Are you sure you want to delete $selectedCount item(s)? This will also delete all daily rate history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = _firestore.batch();
        
        for (var itemName in selectedItemsCopy) {
          // Delete all daily rates subcollection
          final ratesSnapshot = await _firestore
              .collection('items')
              .doc(itemName)
              .collection('dailyRates')
              .get();

          for (var rateDoc in ratesSnapshot.docs) {
            batch.delete(rateDoc.reference);
          }

          // Delete the item document
          batch.delete(_firestore.collection('items').doc(itemName));
        }

        await batch.commit();

        if (mounted) {
          setState(() {
            _selectedItems.clear();
            _isSelectionMode = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$selectedCount item(s) deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
