import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  int _rating = 0;
  String _feedbackType = 'General';
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isSuccess = false;
  
  final List<String> _feedbackTypes = [
    'General',
    'Bug Report',
    'Feature Request',
    'UI/UX',
    'Performance',
    'Other'
  ];
  
  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
  
  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate() || _rating == 0) {
      if (_rating == 0) {
        setState(() {
          _errorMessage = 'Please select a rating';
        });
      }
      return;
    }
    
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _isSuccess = false;
    });
    
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception('You must be logged in to submit feedback');
      }
      
      await _firestore
          .collection('feedback')
          .add({
            'userId': currentUser.email,
            'rating': _rating,
            'feedbackType': _feedbackType,
            'feedback': _feedbackController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'pending',
          });
      
      setState(() {
        _isSuccess = true;
        _feedbackController.clear();
        _rating = 0;
        _feedbackType = 'General';
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit feedback: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Your Feedback',
              children: [
                Text(
                  'We value your feedback! Please let us know how we can improve your experience.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
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
                    Expanded(
                      child: Text(
                        'Thank you for your feedback! We appreciate your input.',
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            
            _buildSection(
              title: 'Rate Your Experience',
              children: [
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber.shade700,
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            _rating = index + 1;
                            _errorMessage = null;
                          });
                        },
                      );
                    }),
                  ),
                ),
                Center(
                  child: Text(
                    _rating > 0 ? '$_rating out of 5 stars' : 'Tap to rate',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildSection(
              title: 'Feedback Details',
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _feedbackType,
                        decoration: InputDecoration(
                          labelText: 'Feedback Type',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(Icons.category, color: Colors.amber.shade400),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.amber.shade500, width: 2),
                          ),
                        ),
                        items: _feedbackTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _feedbackType = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _feedbackController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Your Feedback',
                          hintText: 'Please share your thoughts...',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(bottom: 80),
                            child: Icon(Icons.feedback, color: Colors.amber.shade400),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.amber.shade500, width: 2),
                          ),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your feedback';
                          }
                          return null;
                        },
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
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit Feedback',
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
              children: children,
            ),
          ),
        ),
      ],
    );
  }
} 