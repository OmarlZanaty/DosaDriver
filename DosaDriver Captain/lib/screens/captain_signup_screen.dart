import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class CaptainSignupScreen extends StatefulWidget {
  const CaptainSignupScreen({super.key});

  @override
  State<CaptainSignupScreen> createState() => _CaptainSignupScreenState();
}

class _CaptainSignupScreenState extends State<CaptainSignupScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _referral = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _referral.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final confirm = _confirm.text;
    final referral = _referral.text.trim();

    if (name.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty) {
      setState(() => _error = 'من فضلك املأ جميع الحقول المطلوبة');
      return;
    }

    if (password != confirm) {
      setState(() => _error = 'كلمة المرور وتأكيد كلمة المرور غير متطابقين');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Resolve referral before creating account
      String? agencyId;
      String? agencyName;

      if (referral.isNotEmpty) {
        final agencySnap = await FirebaseFirestore.instance
            .collection('agencies')
            .where('referralCode', isEqualTo: referral)
            .limit(1)
            .get();

        if (agencySnap.docs.isNotEmpty) {
          final agencyDoc = agencySnap.docs.first;
          agencyId = agencyDoc.id;
          agencyName = agencyDoc['name'];
        }
      }

      // Use AuthService for consistent phone-to-email auth
      await AuthService().registerCaptain(
        phone: phone,
        password: password,
        name: name,
        extraData: {
          'email': email,
          'agencyId': agencyId,
          'agencyName': agencyName,
          'referralCode': referral,
          'profileCompleted': true,
          'approved': false,
          'documentsUploaded': false,
        },
      );

      // ✅ Update agency driver count
      if (agencyId != null) {
        await FirebaseFirestore.instance
            .collection('agencies')
            .doc(agencyId)
            .update({
              'totalDrivers': FieldValue.increment(1),
            });
      }

      if (!mounted) return;

      // سيتم التحويل تلقائيًا عن طريق CaptainStatusGate
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'فشل إنشاء الحساب');
    } catch (_) {
      setState(() => _error = 'فشل إنشاء الحساب');
    } finally {
      if (mounted) setState(() => _loading = false);
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE53935), // red
              Color(0xFFC62828), // darker red
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ===== BIG LOGO + WHITE RING =====
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white, // white ring
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) {
                                return const Icon(
                                  Icons.local_taxi,
                                  size: 100,
                                  color: Color(0xFFE53935),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ===== TITLE =====
                    Text(
                      'إنشاء حساب كابتن',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.97),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ===== FORM CARD =====
                    Card(
                      elevation: 10,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _name,
                                decoration: const InputDecoration(
                                  labelText: 'الاسم بالكامل',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'رقم الهاتف',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'البريد الإلكتروني',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextField(
                                controller: _password,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'كلمة المرور',
                                  prefixIcon: Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextField(
                                controller: _confirm,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'تأكيد كلمة المرور',
                                  prefixIcon: Icon(Icons.lock_reset_outlined),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextField(
                                controller: _referral,
                                decoration: const InputDecoration(
                                  labelText: 'كود الإحالة (اختياري)',
                                  prefixIcon: Icon(Icons.card_giftcard_outlined),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),

                              if (_error != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),

                              ElevatedButton(
                                onPressed: _loading ? null : _signup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53935),
                                  foregroundColor: Colors.white,
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _loading
                                      ? 'جاري إنشاء الحساب...'
                                      : 'إنشاء حساب',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ===== FOOTER =====
                    Text(
                      'DosaDriver Captain',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
