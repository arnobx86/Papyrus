import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Welcome to Papyrus.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF154834)),
          ),
          const SizedBox(height: 16),
          const Text(
            'By using this application, you agree to comply with and be bound by the following terms and conditions of use.',
          ),
          const SizedBox(height: 24),
          _buildSection('1. Use of Service', 'Papyrus is a business management tool. You agree to use the service for lawful purposes only and in a way that does not infringe the rights of others.'),
          _buildSection('2. Account Responsibility', 'You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.'),
          _buildSection('3. Data Content', 'You retain all rights to the data you enter. However, you grant us permission to host and store this data on your behalf through our third-party provider, Supabase.'),
          _buildSection('4. Limitation of Liability', 'Papyrus is provided "as is" without any warranties. We shall not be liable for any financial losses or data corruption arising from the use of the app.'),
          _buildSection('5. Modifications', 'We reserve the right to modify these terms at any time. Continued use of the service constitutes acceptance of the new terms.'),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'Effective Date: April 2026',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(height: 1.5, color: Colors.black87)),
        ],
      ),
    );
  }
}
