import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/localization/localization_helper.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;

    _nameController.text = _user!.displayName ?? '';
    _emailController.text = _user!.email ?? '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();

      final data = doc.data();
      final phone = (data?['phone'] ?? '').toString().trim();

      if (mounted) {
        setState(() {
          _phoneController.text = phone;
        });
      } else {
        _phoneController.text = phone;
      }
    } catch (_) {
      // fallback (phone auth only)
      _phoneController.text = _user!.phoneNumber ?? '';
    }
  }


  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      if (_user != null) {
        await _user!.updateDisplayName(_nameController.text.trim());
        await _user!.reload();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('profile_updated')),
            ),
          );
        }

        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        _user?.displayName ?? context.tr('profile_user');
    final email =
        _user?.email ?? context.tr('profile_no_email');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.tr('profile_title'),
          style: AppTextStyles.headline2,
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ================= PROFILE HEADER =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.1),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        displayName.substring(0, 1).toUpperCase(),
                        style: AppTextStyles.headline1.copyWith(
                          color: AppColors.primary,
                          fontSize: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(displayName, style: AppTextStyles.headline2),
                  const SizedBox(height: 8),
                  Text(
                    email,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.darkGray,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ================= PROFILE FORM =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Name
                  Text(
                    context.tr('profile_full_name'),
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    enabled: _isEditing,
                    decoration: InputDecoration(
                      hintText: context.tr('profile_enter_name'),
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor:
                      _isEditing ? Colors.white : AppColors.background,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Email
                  Text(
                    context.tr('profile_email'),
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: context.tr('profile_email_hint'),
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Phone
                  Text(
                    context.tr('profile_phone'),
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: context.tr('profile_phone_hint'),
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ================= ACTION BUTTONS =================
                  if (_isEditing)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                setState(() => _isEditing = false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.divider,
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              context.tr('profile_cancel'),
                              style: AppTextStyles.headline3.copyWith(
                                color: AppColors.darkGray,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                            _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                valueColor:
                                AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                                : Text(
                              context.tr('profile_save'),
                              style:
                              AppTextStyles.headline3.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.headline2.copyWith(
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.darkGray,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
