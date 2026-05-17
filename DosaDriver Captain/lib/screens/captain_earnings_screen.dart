import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import 'captain_home_screen.dart';
import 'captain_profile_screen.dart';
import 'captain_trips_screen.dart';

/// Captain Earnings Dashboard Screen
class CaptainEarningsScreen extends StatefulWidget {
  const CaptainEarningsScreen({super.key});

  @override
  State<CaptainEarningsScreen> createState() => _CaptainEarningsScreenState();
}

class _CaptainEarningsScreenState extends State<CaptainEarningsScreen> {
  // ================= DATA =================
  double _walletBalance = 0.0;
  double _pendingCommission = 0.0;
  double _totalGross = 0.0;
  double _weeklyEarnings = 0.0;

  int _totalTrips = 0;

  int _currentIndex = 1; // Earnings tab

  String _timeOnline = '0h 0m';
  String _totalDistance = '0 km';

  List<double> _dailyEarnings = List.filled(7, 0.0);
  final List<String> _days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  /// 🔥 Load real earnings from Firestore
  Future<void> _loadEarnings() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final firestore = FirebaseFirestore.instance;

      // =========================
      // DRIVER WALLET (SOURCE OF TRUTH)
      // =========================
      final walletDoc =
      await firestore.collection('driver_wallet').doc(uid).get();

      if (walletDoc.exists) {
        final data = walletDoc.data()!;

        _walletBalance =
            (data['availableBalance'] as num?)?.toDouble() ?? 0.0;

        _pendingCommission =
            (data['pendingCommission'] as num?)?.toDouble() ?? 0.0;

        _totalGross =
            (data['totalGross'] as num?)?.toDouble() ?? 0.0;

        _totalTrips =
            (data['totalTrips'] as num?)?.toInt() ?? 0;
      }

      // =========================
      // WEEKLY NET EARNINGS (CHART)
      // =========================
      final now = DateTime.now();
      final startOfWeek = now.subtract(
        Duration(days: now.weekday % 7),
      );


      final earningsSnap = await firestore
          .collection('driver_earnings')
          .where('driverId', isEqualTo: uid)
          .where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek),
      )
          .get();

      _weeklyEarnings = 0.0;
      _dailyEarnings = List.filled(7, 0.0);

      for (final doc in earningsSnap.docs) {
        final data = doc.data();

        final netAmount =
            (data['netAmount'] as num?)?.toDouble() ?? 0.0;

        final createdAt =
        (data['createdAt'] as Timestamp).toDate();

        final dayIndex = createdAt.weekday % 7;

        _weeklyEarnings += netAmount;
        _dailyEarnings[dayIndex] += netAmount;
      }
    } catch (e) {
      debugPrint('❌ Earnings load error: $e');
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,

      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const ShowLoading()
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildWeeklyEarningsCard(),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 16),
                  _buildEarningsBreakdown(),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.mediumGray,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == _currentIndex) return;

          Widget target;

          switch (index) {
            case 0:
              target = const CaptainHomeScreen();
              break;
            case 1:
              return; // already on earnings
            case 2:
              target = const CaptainTripsScreen();
              break;
            case 3:
              target = const CaptainProfileScreen();
              break;
            default:
              return;
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => target),
          );
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }


  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children:  [
              Expanded(
                child: Text(AppStrings.earnings(context))

              ),
              Icon(Icons.help_outline, color: AppColors.white),
            ],
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available Balance',
                          style: AppTextStyles.caption),
                      const SizedBox(height: 4),
                      Text(
                        'EG ${_walletBalance.toStringAsFixed(2)}',
                        style: AppTextStyles.priceLarge,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child:  Text(
                    AppStrings.withdraw(context),
                    style: const TextStyle(color: AppColors.white),
                    ),

                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyEarningsCard() {
    final max = _dailyEarnings.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'EG ${_weeklyEarnings.toStringAsFixed(2)}',


            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final value = _dailyEarnings[i];
                final height = max == 0 ? 0.0 : (value / max) * 100;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 32,
                      height: height,
                      decoration: BoxDecoration(
                        color: AppColors.mapRoute,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_days[i], style: AppTextStyles.caption),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.directions_car,
            label: AppStrings.totalTrips(context),
            value: _totalTrips.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.access_time,
            label: AppStrings.timeOnline(context),
            value: _timeOnline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.speed,
            label: AppStrings.timeOnline(context),
            value: _totalDistance,
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.earningsBreakdown(context),
            style: AppTextStyles.headline3,
          ),
          const SizedBox(height: 16),

          _BreakdownRow(
            label: AppStrings.totalGross(context),
            value: 'EG ${_totalGross.toStringAsFixed(2)}',
          ),
          const Divider(),

          _BreakdownRow(
            label: AppStrings.companyCommission(context),
            value: '- EG ${_pendingCommission.toStringAsFixed(2)}',
            valueColor: Colors.red,
          ),
          const Divider(),

          _BreakdownRow(
            label: AppStrings.availableBalance(context),
            value: 'EG ${_walletBalance.toStringAsFixed(2)}',
            valueColor: Colors.green,
          ),
        ],
      ),
    );
  }
}

// ================= WIDGETS =================

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.mediumGray),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.headline3),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _BreakdownRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyLarge),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.black,
          ),
        ),
      ],
    );
  }
}

class ShowLoading extends StatelessWidget {
  const ShowLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}
