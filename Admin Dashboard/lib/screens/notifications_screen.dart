import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/lang_controller.dart';
import '../ui/tokens/app_colors.dart';

/// Admin: Push Notifications Center
/// Allows sending FCM push notifications to:
///   - All clients
///   - All captains
///   - All users
///   - A specific user (by phone or UID)
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _userCtrl = TextEditingController();

  String _target = 'all_clients'; // all_clients | all_captains | all_users | specific_user
  bool _sending = false;
  String? _resultMessage;
  bool _resultOk = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  Future<Options> _authOptions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');
    final token = await user.getIdToken(true);
    return Options(headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _resultMessage = null;
    });

    try {
      final opt = await _authOptions();
      final body = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'target': _target,
      };

      if (_target == 'specific_user') {
        final userRef = _userCtrl.text.trim();
        if (userRef.isEmpty) throw Exception('يجب تحديد المستخدم');
        // Numeric → phone, else → uid
        if (RegExp(r'^\d+$').hasMatch(userRef)) {
          body['phone'] = userRef;
        } else {
          body['uid'] = userRef;
        }
      }

      await ApiClient.dio.post(
        ApiConfig.api('/admin/notifications/send'),
        data: body,
        options: opt,
      );

      setState(() {
        _resultOk = true;
        _resultMessage =
            LangController.instance.isArabic
                ? 'تم إرسال الإشعار بنجاح ✓'
                : 'Notification sent successfully ✓';
        _titleCtrl.clear();
        _bodyCtrl.clear();
        _userCtrl.clear();
      });
    } catch (e) {
      setState(() {
        _resultOk = false;
        _resultMessage = e.toString();
      });
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LangController.instance;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page title
              Text(
                lang.t('notifications'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Form card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Target Audience ─────────────────────────────────────
                      _SectionTitle(
                          lang.isArabic
                              ? 'الجمهور المستهدف'
                              : 'Target Audience'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _TargetChip(
                            label: lang.t('all_clients'),
                            icon: Icons.person_outline,
                            value: 'all_clients',
                            selected: _target == 'all_clients',
                            onTap: () =>
                                setState(() => _target = 'all_clients'),
                          ),
                          _TargetChip(
                            label: lang.t('all_captains'),
                            icon: Icons.directions_car_outlined,
                            value: 'all_captains',
                            selected: _target == 'all_captains',
                            onTap: () =>
                                setState(() => _target = 'all_captains'),
                          ),
                          _TargetChip(
                            label: lang.t('all_users'),
                            icon: Icons.people_outline,
                            value: 'all_users',
                            selected: _target == 'all_users',
                            onTap: () =>
                                setState(() => _target = 'all_users'),
                          ),
                          _TargetChip(
                            label: lang.t('specific_user'),
                            icon: Icons.person_search_outlined,
                            value: 'specific_user',
                            selected: _target == 'specific_user',
                            onTap: () =>
                                setState(() => _target = 'specific_user'),
                          ),
                        ],
                      ),

                      // Specific user input
                      if (_target == 'specific_user') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _userCtrl,
                          style: GoogleFonts.cairo(),
                          decoration: InputDecoration(
                            labelText: lang.isArabic
                                ? 'رقم الهاتف أو معرف المستخدم'
                                : 'Phone number or UID',
                            prefixIcon: const Icon(Icons.person_pin_outlined),
                          ),
                          validator: (v) {
                            if (_target == 'specific_user' &&
                                (v == null || v.trim().isEmpty)) {
                              return lang.isArabic
                                  ? 'مطلوب'
                                  : 'Required';
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),

                      // ── Message ─────────────────────────────────────────────
                      _SectionTitle(
                          lang.isArabic ? 'محتوى الإشعار' : 'Message'),
                      const SizedBox(height: 12),

                      // Title
                      TextFormField(
                        controller: _titleCtrl,
                        style: GoogleFonts.cairo(),
                        decoration: InputDecoration(
                          labelText: lang.t('notif_title'),
                          prefixIcon:
                              const Icon(Icons.title_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return lang.isArabic
                                ? 'العنوان مطلوب'
                                : 'Title is required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // Body
                      TextFormField(
                        controller: _bodyCtrl,
                        style: GoogleFonts.cairo(),
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: lang.t('notif_body'),
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 60),
                            child: Icon(Icons.message_outlined),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return lang.isArabic
                                ? 'نص الإشعار مطلوب'
                                : 'Body is required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // ── Preview card ──────────────────────────────────────
                      _NotifPreview(
                        title: _titleCtrl.text,
                        body: _bodyCtrl.text,
                      ),

                      const SizedBox(height: 24),

                      // ── Result banner ────────────────────────────────────
                      if (_resultMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _resultOk
                                ? AppColors.successSoft
                                : AppColors.dangerSoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _resultOk
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _resultOk
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                color: _resultOk
                                    ? AppColors.success
                                    : AppColors.danger,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _resultMessage!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _resultOk
                                        ? AppColors.success
                                        : AppColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Send button ──────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(
                            lang.t('send'),
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _TargetChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.bgApp,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifPreview extends StatelessWidget {
  final String title;
  final String body;

  const _NotifPreview({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty && body.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgApp,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_outlined,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? '...' : title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
