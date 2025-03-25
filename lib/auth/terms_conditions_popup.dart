import 'package:flutter/material.dart';

class TermsConditionsPopup extends StatelessWidget {
  const TermsConditionsPopup({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: Colors.amber.shade800,
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('1. Introduction'),
                  _buildParagraph(
                    'Welcome to our Jewelry Management Application. By using this application, you agree to be bound by the following terms and conditions. Please read them carefully before proceeding with registration.'
                  ),
                  
                  _buildSectionTitle('2. Account Registration'),
                  _buildParagraph(
                    'To use our application, you must register an account. You agree to provide accurate, current, and complete information during the registration process. You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.'
                  ),
                  
                  _buildSectionTitle('3. Data Privacy'),
                  _buildParagraph(
                    'We collect and process your personal information in accordance with our Privacy Policy. By using our application, you consent to the collection and use of your information as described in the Privacy Policy.'
                  ),
                  _buildParagraph(
                    'Your data is stored securely on Firebase servers. We implement appropriate security measures to protect your information from unauthorized access or disclosure.'
                  ),
                  
                  _buildSectionTitle('4. Free and Premium Features'),
                  _buildParagraph(
                    'The application offers both free and premium features. Free accounts have limitations on certain features, such as the number of metals, categories, and loans that can be created. Premium accounts provide unlimited access to these features.'
                  ),
                  _buildParagraph(
                    'Premium subscription purchases are processed through secure payment gateways. Subscription fees are non-refundable except as required by law.'
                  ),
                  
                  _buildSectionTitle('5. User Responsibilities'),
                  _buildParagraph(
                    'You agree to use the application only for lawful purposes and in accordance with these terms. You shall not use the application in any way that could damage, disable, overburden, or impair our services.'
                  ),
                  _buildParagraph(
                    'You are solely responsible for all data and information you input into the application, including customer details, inventory records, and financial transactions.'
                  ),
                  
                  _buildSectionTitle('6. Intellectual Property'),
                  _buildParagraph(
                    'All content, features, and functionality of the application, including but not limited to text, graphics, logos, and software, are owned by us and are protected by copyright, trademark, and other intellectual property laws.'
                  ),
                  
                  _buildSectionTitle('7. Limitation of Liability'),
                  _buildParagraph(
                    'To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to loss of profits, data, or use, arising out of or in connection with your use of the application.'
                  ),
                  
                  _buildSectionTitle('8. Termination'),
                  _buildParagraph(
                    'We reserve the right to suspend or terminate your access to the application at any time for any reason, including but not limited to a breach of these terms.'
                  ),
                  
                  _buildSectionTitle('9. Changes to Terms'),
                  _buildParagraph(
                    'We may revise these terms at any time by updating this page. Your continued use of the application following the posting of changes will constitute your acceptance of such changes.'
                  ),
                  
                  _buildSectionTitle('10. Governing Law'),
                  _buildParagraph(
                    'These terms shall be governed by and construed in accordance with the laws of the jurisdiction in which we operate, without regard to its conflict of law provisions.'
                  ),
                  
                  const SizedBox(height: 20),
                  Text(
                    'Last updated: August 2023',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Action button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('I Understand', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
    );
  }
} 