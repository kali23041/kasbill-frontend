import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UpgradeToPremiumPage extends StatefulWidget {
  const UpgradeToPremiumPage({super.key});

  @override
  State<UpgradeToPremiumPage> createState() => _UpgradeToPremiumPageState();
}

class _UpgradeToPremiumPageState extends State<UpgradeToPremiumPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // Use the user's email as the document ID in the members collection
        await FirebaseFirestore.instance
            .collection('members')
            .doc(user.email)
            .set({
          'userId': user.uid,
          'userEmail': user.email,
          'userName': user.displayName ?? '',
          'phone': _phoneController.text,
          'message': _messageController.text,
          'requestDate': FieldValue.serverTimestamp(),
          'status': 'pending',
          'membershipType': 'premium',
          'requestAmount': 4999,
          'currency': 'INR',
          'isPriceNegotiable': true,
        });

        // Also update the user's document to reflect pending premium status
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .update({
          'premiumRequested': true,
          'premiumRequestDate': FieldValue.serverTimestamp(),
        });

        setState(() {
          _isSubmitted = true;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade to Premium'),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Header Section
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.workspace_premium,
                        size: 70,
                        color: Colors.amber.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Premium Membership',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Elevate your jewelry business',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Pricing Card
              Container(
                padding: const EdgeInsets.all(24),
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
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹4,999',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
                        ),
                        const Text(
                          '/year',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Price is negotiable',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.amber.shade700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'All Premium Features Included:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureRow('Unlimited inventory items'),
                    _buildFeatureRow('Unlimited customer records'),
                    _buildFeatureRow('Unlimited loan management'),
                    _buildFeatureRow('Advanced reporting tools'),
                    _buildFeatureRow('Metal rates updating'),
                    _buildFeatureRow('Bulk product price updates'),
                    _buildFeatureRow('Premium customer support'),
                    _buildFeatureRow('Customizable billing options'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Request Form
              _isSubmitted 
                ? _buildSuccessMessage()
                : _buildRequestForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green.shade600,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Apply for Premium',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Fill out the form below and our team will contact you within 2 working days.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: 'Enter your contact number',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.phone),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.amber.shade500, width: 2),
              ),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _messageController,
            decoration: InputDecoration(
              labelText: 'Message (Optional)',
              hintText: 'Any specific requirements or questions?',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.message),
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
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: Colors.amber.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSubmitting ? null : _submitRequest,
              child: _isSubmitting
                ? const CircularProgressIndicator(
                    color: Colors.white,
                  )
                : const Text(
                    'Submit Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle,
            size: 60,
            color: Colors.green.shade600,
          ),
          const SizedBox(height: 16),
          const Text(
            'Request Submitted!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Thank you for your interest in our Premium plan. Our team will contact you within 2 working days to discuss the details and process your upgrade.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Return to App',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 