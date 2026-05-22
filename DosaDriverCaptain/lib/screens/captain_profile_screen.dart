import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../screens/splash_screen.dart';
import 'diagnostics_screen.dart';
import '../services/driver_stats_service.dart';
import '../widgets/captain_drawer.dart';

class CaptainProfileScreen extends StatelessWidget {
  const CaptainProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      drawer: const CaptainDrawer(),
      backgroundColor: AppColors.lightGray,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('drivers')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final name = data['name'] ?? 'السائق';
          final phone = data['phone'] ?? '';
          final rating = (data['rating'] ?? 5.0).toDouble();
          final trips = data['totalTrips'] ?? 0;

          final carModel = data['carModel'] ?? '';
          final plateNumber = data['plateNumber'] ?? '';

          final profileImage = data['documents']?['profileImage'];

          return CustomScrollView(
            slivers: [

              /// ================= HEADER =================
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: AppColors.primary,
                leading: Builder(builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                )),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(name),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          Color(0xFF8C1D18),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        const SizedBox(height: 40),

                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white,
                          backgroundImage: profileImage != null
                              ? NetworkImage(profileImage)
                              : null,
                          onBackgroundImageError: profileImage != null
                              ? (_, __) {/* swallow: offline or 404 */}
                              : null,
                          child: profileImage == null
                              ? const Icon(Icons.person,
                              size: 42, color: AppColors.primary)
                              : null,
                        ),

                        const SizedBox(height: 10),

                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          phone,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              /// ================= BODY =================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [

                      /// ===== BASIC STATS =====
                      Row(
                        children: [
                          _StatCard(
                            icon: Icons.star,
                            label: "التقييم",
                            value: rating.toString(),
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            icon: Icons.route,
                            label: "إجمالي الرحلات",
                            value: trips.toString(),
                          ),
                          const SizedBox(width: 12),
                          const _StatCard(
                            icon: Icons.verified,
                            label: "الحالة",
                            value: "نشط",
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      /// ===== DRIVER DASHBOARD =====
                      DriverPerformanceDashboard(captainId: uid),

                      const SizedBox(height: 20),

                      /// ===== VEHICLE =====
                      _SectionCard(
                        title: "السيارة",
                        icon: Icons.directions_car,
                        children: [
                          _RowItem("الموديل", carModel),
                          _RowItem("رقم اللوحة", plateNumber),
                        ],
                      ),

                      const SizedBox(height: 16),

                      /// ===== DOCUMENTS =====
                      _SectionCard(
                        title: "المستندات",
                        icon: Icons.badge,
                        children: [

                          if (data['documents']?['profileImage'] != null)
                            _ImagePreview(
                              title: "الصورة الشخصية",
                              url: data['documents']['profileImage'],
                            ),

                          if (data['documents']?['license'] != null)
                            _ImagePreview(
                              title: "رخصة القيادة",
                              url: data['documents']['license'],
                            ),

                          if (data['documents']?['carRegistration'] != null)
                            _ImagePreview(
                              title: "رخصة السيارة",
                              url: data['documents']['carRegistration'],
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      /// ===== SETTINGS =====
                      _SectionCard(
                        title: "الإعدادات",
                        icon: Icons.settings,
                        children: [

                          ListTile(
                            leading: const Icon(Icons.bug_report),
                            title: const Text("تشخيص النظام"),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DiagnosticsScreen(),
                                ),
                              );
                            },
                          ),

                          ListTile(
                            leading: const Icon(Icons.logout, color: Colors.red),
                            title: const Text(
                              "تسجيل الخروج",
                              style: TextStyle(color: Colors.red),
                            ),
                            onTap: () async {

                              await FirebaseAuth.instance.signOut();

                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SplashScreen(),
                                  ),
                                      (_) => false,
                                );
                              }
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

////////////////////////////////////////////////////////////////
/// DRIVER PERFORMANCE DASHBOARD
////////////////////////////////////////////////////////////////

class DriverPerformanceDashboard extends StatelessWidget {

  final String captainId;

  const DriverPerformanceDashboard({super.key, required this.captainId});

  @override
  Widget build(BuildContext context) {

    return FutureBuilder(
      future: DriverStatsService.getDriverStats(captainId),
      builder: (context, snapshot) {

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          );
        }

        final stats = snapshot.data as Map<String, dynamic>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "لوحة أداء السائق",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              physics: const NeverScrollableScrollPhysics(),
              children: [

                _StatBox(
                  "إجمالي الأرباح",
                  "${stats['earnings'].toStringAsFixed(2)} ج",
                  Icons.attach_money,
                ),

                _StatBox(
                  "رحلات اليوم",
                  "${stats['todayTrips']}",
                  Icons.today,
                ),

                _StatBox(
                  "رحلات هذا الأسبوع",
                  "${stats['weekTrips']}",
                  Icons.date_range,
                ),

                _StatBox(
                  "نسبة القبول",
                  "${stats['acceptRate'].toStringAsFixed(1)} %",
                  Icons.check_circle,
                ),

                _StatBox(
                  "نسبة الإلغاء",
                  "${stats['cancelRate'].toStringAsFixed(1)} %",
                  Icons.cancel,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

////////////////////////////////////////////////////////////////
/// SMALL COMPONENTS
////////////////////////////////////////////////////////////////

class _StatBox extends StatelessWidget {

  final String title;
  final String value;
  final IconData icon;

  const _StatBox(this.title, this.value, this.icon);

  @override
  Widget build(BuildContext context) {

    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          Icon(icon, color: AppColors.primary),

          const SizedBox(height: 8),

          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(value, style: AppTextStyles.headline3),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [

          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.headline3),
            ],
          ),

          const Divider(),

          ...children,
        ],
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final String label;
  final String value;

  const _RowItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(value, style: AppTextStyles.bodyLarge),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final String title;
  final String url;

  const _ImagePreview({
    required this.title,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(title),
          const Spacer(),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: Image.network(url),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}