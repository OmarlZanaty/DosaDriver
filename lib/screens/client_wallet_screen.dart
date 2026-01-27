import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class ClientWalletScreen extends StatefulWidget {
  const ClientWalletScreen({super.key});

  @override
  State<ClientWalletScreen> createState() => _ClientWalletScreenState();
}

class _ClientWalletScreenState extends State<ClientWalletScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  double _walletBalance = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    if (_user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _walletBalance = (doc.data()?['walletBalance'] ?? 0.0).toDouble();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading wallet: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addMoney(double amount) async {
    if (_user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'walletBalance': FieldValue.increment(amount),
      });

      _loadWalletBalance();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Added ${amount.toStringAsFixed(2)} EGP')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text('Wallet', style: AppTextStyles.headline2),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Wallet Balance Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wallet Balance',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_walletBalance.toStringAsFixed(2)} EGP',
                          style: AppTextStyles.headline1.copyWith(
                            color: Colors.white,
                            fontSize: 36,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Available for rides and services',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Add Money Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Add Money',
                          style: AppTextStyles.headline3,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildQuickAddButton('50', 50),
                            _buildQuickAddButton('100', 100),
                            _buildQuickAddButton('200', 200),
                            _buildQuickAddButton('500', 500),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment Methods Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Methods',
                          style: AppTextStyles.headline3,
                        ),
                        const SizedBox(height: 12),
                        _buildPaymentMethod(
                          'Credit Card',
                          '•••• •••• •••• 4242',
                          Icons.credit_card,
                        ),
                        const SizedBox(height: 12),
                        _buildPaymentMethod(
                          'Mobile Wallet',
                          'Vodafone Cash / Orange Money',
                          Icons.phone_android,
                        ),
                        const SizedBox(height: 12),
                        _buildPaymentMethod(
                          'Bank Transfer',
                          'Direct bank transfer',
                          Icons.account_balance,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Transaction History
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: AppTextStyles.headline3,
                        ),
                        const SizedBox(height: 12),
                        _buildTransactionItem(
                          'Ride to Downtown',
                          '-45.50 EGP',
                          '2 hours ago',
                          Icons.directions_car,
                          Colors.red,
                        ),
                        const SizedBox(height: 8),
                        _buildTransactionItem(
                          'Wallet Top-up',
                          '+200.00 EGP',
                          'Yesterday',
                          Icons.add_circle,
                          AppColors.success,
                        ),
                        const SizedBox(height: 8),
                        _buildTransactionItem(
                          'Ride to Airport',
                          '-120.00 EGP',
                          '3 days ago',
                          Icons.directions_car,
                          Colors.red,
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

  Widget _buildQuickAddButton(String amount, double value) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _addMoney(value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              Text(
                '+$amount',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'EGP',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.darkGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethod(String name, String details, IconData icon) {
    return Container(
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
                Text(name, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  details,
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
    );
  }

  Widget _buildTransactionItem(
    String title,
    String amount,
    String time,
    IconData icon,
    Color amountColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: amountColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: amountColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodySmall),
                Text(time, style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.darkGray,
                  fontSize: 11,
                )),
              ],
            ),
          ),
          Text(
            amount,
            style: AppTextStyles.bodyMedium.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
