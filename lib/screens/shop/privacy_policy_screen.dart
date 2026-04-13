import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Your privacy is important to us.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF154834)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Papyrus ("we", "us", or "our") operates this business management application. This document informs you of our policies regarding the collection, use, and disclosure of personal data when you use our Service.',
          ),
          const SizedBox(height: 24),
          _buildSection('1. Data Collection', 'We collect information only necessary to provide business management services, such as shop information, employee names, and transaction records. All data is stored securely using Supabase.'),
          _buildSection('2. Data Usage', 'Your data is used solely for operating your shop and internal business analytics. We do not sell your data to third parties.'),
          _buildSection('3. Security', 'The security of your data is important to us, but remember that no method of transmission over the Internet, or method of electronic storage is 100% secure. We use industry-standard encryption and protocols.'),
          _buildSection('4. Compliance', 'We comply with data protection regulations regarding your business information.'),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'Last Updated: April 2026',
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
