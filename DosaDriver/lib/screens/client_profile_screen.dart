import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/language_controller.dart';
import '../services/auth_service.dart';
import '../widgets/custom_widgets.dart';
import 'client_signin_screen.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final _authService = ClientAuthService();
  bool _editMode = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ClientSignInScreen()),
        (r) => false,
      );
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await _authService.updateProfile(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      setState(() => _editMode = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ البيانات بنجاح ✓'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (!_editMode)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => setState(() => _editMode = true),
            ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('يرجى تسجيل الدخول'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};
                final name  = data['name']  ?? '';
                final phone = data['phone'] ?? '';
                final email = data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';

                // Pre-fill edit fields
                if (_editMode && _nameCtrl.text.isEmpty) {
                  _nameCtrl.text  = name;
                  _phoneCtrl.text = phone;
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // ─── Header ───
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 48,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '؟',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              name.isEmpty ? 'المستخدم' : name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ─── Stats ───
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('rides')
                              .where('riderFirebaseUid', isEqualTo: uid)
                              .snapshots(),
                          builder: (ctx, rideSnap) {
                            final rides = rideSnap.data?.docs ?? [];
                            final completed = rides.where((d) {
                              final st = ((d.data() as Map)['status'] ?? '').toString().toUpperCase();
                              return st == 'COMPLETED';
                            }).length;
                            final totalSpent = rides.fold<double>(0, (sum, d) {
                              final data = d.data() as Map<String, dynamic>;
                              final st = (data['status'] ?? '').toString().toUpperCase();
                              if (st != 'COMPLETED') return sum;
                              return sum + (data['price'] ?? data['finalFare'] ?? 0).toDouble();
                            });

                            return Row(
                              children: [
                                _StatCard(label: 'الرحلات', value: '$completed'),
                                const SizedBox(width: 12),
                                _StatCard(label: 'المنفق', value: '${totalSpent.toStringAsFixed(0)} جنيه'),
                                const SizedBox(width: 12),
                                _StatCard(label: 'الإجمالي', value: '${rides.length}'),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ─── Edit Form ───
                      if (_editMode)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('تعديل البيانات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 16),
                              _inputField(_nameCtrl, 'الاسم الكامل', Icons.person_outline),
                              const SizedBox(height: 12),
                              _inputField(_phoneCtrl, 'رقم الهاتف', Icons.phone_outlined, type: TextInputType.phone),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => setState(() { _editMode = false; _nameCtrl.clear(); _phoneCtrl.clear(); }),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.divider),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      child: const Text('إلغاء', style: TextStyle(color: AppColors.mediumGray)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _saving ? null : _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      child: _saving
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      if (!_editMode) ...[
                        // ─── Info tiles ───
                        _InfoTile(icon: Icons.person_outline, label: 'الاسم', value: name.isEmpty ? 'غير محدد' : name),
                        _InfoTile(icon: Icons.phone_outlined, label: 'الهاتف', value: phone.isEmpty ? 'غير محدد' : phone),
                        _InfoTile(icon: Icons.email_outlined, label: 'البريد', value: email),

                        const SizedBox(height: 8),

                        // ─── Settings tiles ───
                        _SettingsTile(
                          icon: Icons.language,
                          label: 'اللغة / Language',
                          trailing: ListenableBuilder(
                            listenable: LanguageController.instance,
                            builder: (_, __) => Text(
                              LanguageController.instance.isArabic ? 'العربية' : 'English',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                            ),
                          ),
                          onTap: () => LanguageController.instance.toggleLanguage(),
                        ),

                        _SettingsTile(
                          icon: Icons.info_outline,
                          label: 'عن التطبيق',
                          onTap: () => showAboutDialog(
                            context: context,
                            applicationName: 'DosaDriver Client',
                            applicationVersion: '1.0.0',
                            applicationLegalese: '© 2025 DosaDriver',
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ─── Logout ───
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout, color: AppColors.error),
                            label: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 15)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _inputField(TextEditingController c, String label, IconData icon, {TextInputType? type}) {
    return TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.mediumGray),
        filled: true, fillColor: AppColors.lightGray,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
        ),
        child: Column(children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mediumGray)),
        ]),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.mediumGray)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkGray)),
        ]),
      ]),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.label, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.mediumGray),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
