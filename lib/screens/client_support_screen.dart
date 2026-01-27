import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class ClientSupportScreen extends StatefulWidget {
  const ClientSupportScreen({super.key});

  @override
  State<ClientSupportScreen> createState() => _ClientSupportScreenState();
}

class _ClientSupportScreenState extends State<ClientSupportScreen> {
  final _messageController = TextEditingController();
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text('Help & Support', style: AppTextStyles.headline2),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Quick Help Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        'How can we help?',
                        style: AppTextStyles.headline3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We\'re here to help! Browse our FAQs or contact our support team.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.darkGray,
                    ),
                  ),
                ],
              ),
            ),

            // Contact Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Us',
                    style: AppTextStyles.headline3,
                  ),
                  const SizedBox(height: 12),
                  _buildContactOption(
                    Icons.phone,
                    'Call Support',
                    '+20 100 123 4567',
                    () => _launchPhone('+201001234567'),
                  ),
                  const SizedBox(height: 12),
                  _buildContactOption(
                    Icons.email,
                    'Email Support',
                    'support@dosadriver.com',
                    () => _launchEmail(),
                  ),
                  const SizedBox(height: 12),
                  _buildContactOption(
                    Icons.chat,
                    'Live Chat',
                    'Chat with our team',
                    () => _showLiveChat(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // FAQs Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Frequently Asked Questions',
                    style: AppTextStyles.headline3,
                  ),
                  const SizedBox(height: 12),
                  _buildFAQItem(
                    'How do I book a ride?',
                    'Open the app, enter your destination, select a ride type, and confirm. A driver will be assigned shortly.',
                  ),
                  const SizedBox(height: 8),
                  _buildFAQItem(
                    'What payment methods are accepted?',
                    'We accept cash, credit cards, debit cards, and mobile wallets (Vodafone Cash, Orange Money).',
                  ),
                  const SizedBox(height: 8),
                  _buildFAQItem(
                    'Can I cancel a ride?',
                    'Yes, you can cancel a ride before the driver arrives. A small cancellation fee may apply.',
                  ),
                  const SizedBox(height: 8),
                  _buildFAQItem(
                    'How do I report a safety issue?',
                    'Use the emergency button during your ride or contact support immediately after the ride.',
                  ),
                  const SizedBox(height: 8),
                  _buildFAQItem(
                    'What if I left something in the car?',
                    'Contact the driver through the app or reach out to support with your ride details.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Send Message Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send us a Message',
                    style: AppTextStyles.headline3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Describe your issue or question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Send Message',
                        style: AppTextStyles.headline3.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Safety Tips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Safety Tips',
                    style: AppTextStyles.headline3,
                  ),
                  const SizedBox(height: 12),
                  _buildSafetyTip(
                    '✓',
                    'Always verify the driver\'s name and vehicle details',
                  ),
                  const SizedBox(height: 8),
                  _buildSafetyTip(
                    '✓',
                    'Share your ride details with a trusted contact',
                  ),
                  const SizedBox(height: 8),
                  _buildSafetyTip(
                    '✓',
                    'Keep your belongings secure during the ride',
                  ),
                  const SizedBox(height: 8),
                  _buildSafetyTip(
                    '✓',
                    'Rate your driver honestly to help the community',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.darkGray,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.divider),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ExpansionTile(
        title: Text(question, style: AppTextStyles.bodyMedium),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              answer,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.darkGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyTip(String icon, String tip) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 20, color: AppColors.success),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            tip,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.darkGray,
            ),
          ),
        ),
      ],
    );
  }

  void _launchPhone(String phone) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling $phone')),
    );
  }

  void _launchEmail() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening email client...')),
    );
  }

  void _showLiveChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Live Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Connecting to support agent...'),
            const SizedBox(height: 16),
            Text(
              'Average wait time: 2 minutes',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.darkGray,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Message sent! We\'ll reply soon.')),
    );

    _messageController.clear();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
