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
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: Color(0xFF8B5CF6),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Bill Summary',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Subtotal
          _buildSummaryRow(
            'Subtotal',
            currencyFormat.format(subtotal),
          ),
          const SizedBox(height: 6),
          
          // Discount
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Discount',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 32,
                      margin: const EdgeInsets.only(right: 6),
                      child: TextField(
                        controller: discountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E40AF),
                              width: 2,
                            ),
                          ),
                          suffixText: '%',
                          suffixStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '- ${currencyFormat.format((discount / 100) * subtotal)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          
          // Tax
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Tax (GST)',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 32,
                      margin: const EdgeInsets.only(right: 6),
                      child: TextField(
                        controller: taxController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E40AF),
                              width: 2,
                            ),
                          ),
                          suffixText: '%',
                          suffixStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        currencyFormat.format((tax / 100) * (subtotal - (discount / 100) * subtotal)),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          
          // Making Charge
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Additional Charges',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: additionalChargesController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(
                        color: Color(0xFF1E40AF),
                        width: 2,
                      ),
                    ),
                    prefixText: '₹',
                    prefixStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),
          
          // Total amount
          Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text(
                  'Total Amount',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Text(
                    currencyFormat.format(total),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Payment method
          const Text(
            'Payment Method',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: paymentMethods.map((method) {
              final isSelected = paymentMethod == method;
              return ChoiceChip(
                label: Text(
                  method,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF1E40AF).withOpacity(0.1),
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  color: isSelected
                      ? const Color(0xFF1E40AF)
                      : const Color(0xFF64748B),
                ),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF1E40AF)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                onSelected: (selected) {
                  if (selected) {
                    onPaymentMethodChanged(method);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          
          // Notes
          TextField(
            controller: notesController,
            maxLines: 3,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              labelStyle: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
              hintText: 'Add any additional notes or comments',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
} 