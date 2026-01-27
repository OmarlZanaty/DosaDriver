import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'diagnostics_screen.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/localization/localization_helper.dart';

import 'client_phone_login_screen.dart';

class ClientSettingsScreen extends StatefulWidget {
  const ClientSettingsScreen({super.key});

  @override
  State<ClientSettingsScreen> createState() => _ClientSettingsScreenState();
}

class _ClientSettingsScreenState extends State<ClientSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _shareLocation = true;
  String _language = 'en';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          context.tr('settings'),
          style: AppTextStyles.headline2,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🔔 Notifications
            _buildSection(
              context.tr('notifications'),
              [
                _buildToggleTile(
                  context.tr('push_notifications'),
                  context.tr('push_notifications_desc'),
                  _notificationsEnabled,
                      (v) => setState(() => _notificationsEnabled = v),
                ),
                _buildToggleTile(
                  context.tr('sound'),
                  context.tr('sound_desc'),
                  _soundEnabled,
                      (v) => setState(() => _soundEnabled = v),
                ),
              ],
            ),

            // 🔒 Privacy & Safety
            _buildSection(
              context.tr('privacy_safety'),
              [
                _buildToggleTile(
                  context.tr('share_location'),
                  context.tr('share_location_desc'),
                  _shareLocation,
                      (v) => setState(() => _shareLocation = v),
                ),
                _buildTile(
                  Icons.shield,
                  context.tr('emergency_contacts'),
                  context.tr('emergency_contacts_desc'),
                  _showEmergencyContacts,
                ),
                _buildTile(
                  Icons.privacy_tip,
                  context.tr('privacy_policy'),
                  context.tr('privacy_policy_desc'),
                  _showPrivacyPolicy,
                ),
              ],
            ),

            // ⚙ App Settings
            _buildSection(
              context.tr('app_settings'),
              [
                //_buildLanguageTile(),
                _buildTile(
                  Icons.info,
                  context.tr('about_app'),
                  context.tr('app_version'),
                      () {},
                ),
                _buildTile(
                  Icons.bug_report,
                  'Diagnostics',
                  'Run quick system checks',
                      () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                    );
                  },
                ),

                _buildTile(
                  Icons.help,
                  context.tr('help_support'),
                  context.tr('help_support_desc'),
                  _showSupport,
                ),
              ],
            ),

            // 👤 Account
            _buildSection(
              context.tr('account'),
              [
                _buildTile(
                  Icons.logout,
                  context.tr('logout'),
                  context.tr('logout_desc'),
                  _showLogoutDialog,
                  textColor: Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: AppTextStyles.headline3.copyWith(
              color: AppColors.primary,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: List.generate(
              children.length,
                  (i) => Column(
                children: [
                  children[i],
                  if (i < children.length - 1)
                    const Divider(height: 1, indent: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleTile(
      String title,
      String subtitle,
      bool value,
      Function(bool) onChanged,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap, {
        Color textColor = AppColors.darkGray,
      }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(color: textColor),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.darkGray,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.divider,
      ),
      onTap: onTap,
    );
  }

/*  Widget _buildLanguageTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.language, color: AppColors.primary),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('language'),
                      style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('language_desc'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.darkGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
          *//*DropdownButton<String>(
            value: _language,
            underline: const SizedBox(),
            items: [
              DropdownMenuItem(
                value: 'en',
                child: Text(context.tr('english')),
              ),
              DropdownMenuItem(
                value: 'ar',
                child: Text(context.tr('arabic')),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _language = v);
              // 🔥 later we will connect this to LocaleController
            },
          ),*//*
        ],
      ),
    );
  }*/

  // ================= DIALOGS =================

  void _showEmergencyContacts() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('emergency_contacts')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text(context.tr('police')),
              subtitle: const Text('122'),
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text(context.tr('ambulance')),
              subtitle: const Text('123'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('close')),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('privacy_policy')),
        content: SingleChildScrollView(
          child: Text(
            context.tr('privacy_policy_text'),
            style: AppTextStyles.bodySmall,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('agree')),
          ),
        ],
      ),
    );
  }

  void _showSupport() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('help_support')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('contact_us'),
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 8),
            const Text('📧 support@dosadriver.com'),
            const Text('📞 +20 100 123 4567'),
            const SizedBox(height: 16),
            Text(context.tr('available_247')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('close')),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('logout')),
        content: Text(context.tr('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClientPhoneLoginScreen(),
                ),
              );
            },
            child: Text(
              context.tr('logout'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
