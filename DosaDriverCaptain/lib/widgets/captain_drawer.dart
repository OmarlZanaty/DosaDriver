import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_colors.dart';
import '../screens/captain_home_screen.dart';
import '../screens/captain_earnings_screen.dart';
import '../screens/captain_trips_screen.dart';
import '../screens/captain_profile_screen.dart';
import '../screens/captain_help_screen.dart';
import '../screens/splash_screen.dart';
import '../services/auth_service.dart';

/// Global persistent side drawer for the Captain App.
/// Add `drawer: const CaptainDrawer()` to any Scaffold.
class CaptainDrawer extends StatelessWidget {
  const CaptainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.80,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('drivers')
            .doc(uid)
            .snapshots(),
        builder: (ctx, snap) {
          final data =
              (snap.data?.data() as Map<String, dynamic>?) ?? {};
          final name    = data['name']?.toString() ?? 'الكابتن';
          final rating  = (data['rating'] as num?)?.toDouble() ?? 5.0;
          final phone   = data['phone']?.toString() ?? '';
          final photoUrl = data['documents']?['profileImage']?.toString()
              ?? data['photoUrl']?.toString();

          return Column(
            children: [
              _DrawerHeader(
                name: name,
                rating: rating,
                phone: phone,
                photoUrl: photoUrl,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    _NavTile(
                      icon: Icons.map_outlined,
                      label: 'الرئيسية',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const CaptainHomeScreen()),
                          (r) => false,
                        );
                      },
                    ),
                    _NavTile(
                      icon: Icons.history_outlined,
                      label: 'رحلاتي',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const CaptainTripsScreen()));
                      },
                    ),
                    _NavTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'الأرباح',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const CaptainEarningsScreen()));
                      },
                    ),
                    _NavTile(
                      icon: Icons.person_outline,
                      label: 'الإعدادات',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const CaptainProfileScreen()));
                      },
                    ),
                    _NavTile(
                      icon: Icons.help_outline,
                      label: 'المساعدة',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const CaptainHelpScreen()));
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 20),
                    ),
                    _NavTile(
                      icon: Icons.logout,
                      label: 'تسجيل الخروج',
                      color: Colors.red,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await AuthService().logout();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const SplashScreen()),
                            (r) => false,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                    top: 6),
                child: const Text(
                  'DosaDriver Captain v1.0',
                  style: TextStyle(color: Colors.black38, fontSize: 11),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────
class _DrawerHeader extends StatelessWidget {
  final String name;
  final double rating;
  final String phone;
  final String? photoUrl;

  const _DrawerHeader({
    required this.name,
    required this.rating,
    required this.phone,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF8C1D18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: Colors.white.withOpacity(0.25),
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl!) : null,
            onBackgroundImageError: photoUrl != null ? (_, __) {} : null,
            child: photoUrl == null
                ? const Icon(Icons.person, size: 38, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800),
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(phone,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < rating.round() ? Icons.star : Icons.star_border,
                  size: 16,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                rating.toStringAsFixed(1),
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.darkGray;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label,
          style: TextStyle(
              color: c, fontWeight: FontWeight.w600, fontSize: 15)),
      onTap: onTap,
      horizontalTitleGap: 6,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
    );
  }
}
