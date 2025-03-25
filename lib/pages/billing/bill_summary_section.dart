import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BillSummarySection extends StatelessWidget {
  final double subtotal;
  final TextEditingController discountController;
  final TextEditingController taxController;
  final TextEditingController additionalChargesController;
  final TextEditingController notesController;
  final double discount;
  final double tax;
  final double additionalCharges;
  final double total;
  final String paymentMethod;
  final List<String> paymentMethods;
  final Function(String) onPaymentMethodChanged;
  final NumberFormat currencyFormat;

  const BillSummarySection({
    Key? key,
    required this.subtotal,
    required this.discountController,
    required this.taxController,
    required this.additionalChargesController,
    required this.notesController,
    required this.discount,
    required this.tax,
    required this.additionalCharges,
    required this.total,
    required this.paymentMethod,
    required this.paymentMethods,
    required this.onPaymentMethodChanged,
    required this.currencyFormat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                color: Colors.purple.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Bill Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Subtotal
          _buildSummaryRow(
            'Subtotal',
            currencyFormat.format(subtotal),
          ),
          const SizedBox(height: 12),
          
          // Discount
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Discount',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      child: TextField(
                        controller: discountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          suffixText: '%',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '- ${currencyFormat.format((discount / 100) * subtotal)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Tax
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Tax (GST)',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      child: TextField(
                        controller: taxController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          suffixText: '%',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        currencyFormat.format((tax / 100) * (subtotal - (discount / 100) * subtotal)),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Making Charge
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Additional Charges',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: additionalChargesController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    prefixText: '₹',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // Total amount
          Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text(
                  'Total Amount',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    currencyFormat.format(total),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Payment method
          const Text(
            'Payment Method',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: paymentMethods.map((method) {
              final isSelected = paymentMethod == method;
              return ChoiceChip(
                label: Text(method),
                selected: isSelected,
                selectedColor: Colors.amber.shade100,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.amber.shade900
                      : Colors.grey.shade700,
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                onSelected: (selected) {
                  if (selected) {
                    onPaymentMethodChanged(method);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Notes
          TextField(
            controller: notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              hintText: 'Add any additional notes or comments',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
} 