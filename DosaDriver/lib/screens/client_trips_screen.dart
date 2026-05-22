import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme/app_colors.dart';
import '../services/backend_api.dart';
import '../services/client_ride_api.dart';
import '../widgets/custom_widgets.dart';
import 'client_trip_receipt_screen.dart';
import 'client_help_screen.dart';

class ClientTripsScreen extends StatefulWidget {
  const ClientTripsScreen({super.key});

  @override
  State<ClientTripsScreen> createState() => _ClientTripsScreenState();
}

class _ClientTripsScreenState extends State<ClientTripsScreen> {
  final _rideApi = ClientRideApi(BackendApi());
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rides = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (mounted) setState(() { _loading = false; _rides = []; });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _rideApi.getHistory();
      final list = (res['rides'] as List?) ?? [];
      _rides = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return AppColors.success;
      case 'CANCELED':
      case 'CANCELLED':
        return AppColors.error;
      case 'STARTED':
        return AppColors.secondary;
      case 'ACCEPTED':
        return AppColors.warning;
      default:
        return AppColors.mediumGray;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return 'مكتملة';
      case 'CANCELED':
      case 'CANCELLED':
        return 'ملغاة';
      case 'STARTED':
        return 'جارية';
      case 'ACCEPTED':
        return 'مقبولة';
      case 'REQUESTED':
        return 'بانتظار';
      case 'ARRIVED':
        return 'وصل الكابتن';
      default:
        return status;
    }
  }

  String _rideTypeLabel(String? type) {
    switch ((type ?? '').toUpperCase()) {
      case 'FAIR_VALUE':
        return '🚖 قيمة عادلة';
      case 'PREMIUM':
        return '🏆 بريميوم';
      case 'CUTE_CAR':
        return '🚙 كيوت كار';
      case 'SCOOTER':
        return '🛵 سكوتر';
      default:
        return type ?? '';
    }
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return '';
    DateTime? dt;
    if (createdAt is String) {
      dt = DateTime.tryParse(createdAt);
    }
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'رحلاتي',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            tooltip: 'المساعدة',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientHelpScreen()),
            ),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('يرجى تسجيل الدخول'))
          : RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
              ],
            ),
          ),
        ],
      );
    }

    if (_rides.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 80, color: AppColors.divider),
                SizedBox(height: 16),
                const Text(
                  'لا توجد رحلات بعد',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mediumGray,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ابدأ رحلتك الأولى الآن!',
                  style: TextStyle(color: AppColors.mediumGray),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _rides.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final data = _rides[i];
        final status = (data['status'] ?? '').toString();
        final type = (data['type'] ?? data['rideType'] ?? '').toString();
        final price = data['finalFare'] ?? data['suggestedFare'] ?? data['price'] ?? 0;
        final pickupAddr = (data['pickupAddr'] ?? '').toString();
        final dropAddr = (data['dropAddr'] ?? '').toString();
        final dateStr = _formatDate(data['createdAt']);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientTripReceiptScreen(
                rideId: (data['id'] ?? data['rideId'] ?? '').toString(),
                rideData: data,
                fromHistory: true,
              ),
            ),
          ),
          child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatusChip(
                      label: _statusLabel(status),
                      color: _statusColor(status),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _RouteRow(
                  icon: Icons.circle,
                  iconColor: AppColors.success,
                  address: pickupAddr.isEmpty ? 'غير محدد' : pickupAddr,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(width: 1, height: 18, color: AppColors.divider),
                ),
                _RouteRow(
                  icon: Icons.location_on,
                  iconColor: AppColors.primary,
                  address: dropAddr.isEmpty ? 'غير محدد' : dropAddr,
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _rideTypeLabel(type),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGray,
                      ),
                    ),
                    Text(
                      '${(price is num ? price : double.tryParse('$price') ?? 0).toStringAsFixed(2)} جنيه',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )); // GestureDetector + Container
      },
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String address;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(fontSize: 13, color: AppColors.darkGray),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
