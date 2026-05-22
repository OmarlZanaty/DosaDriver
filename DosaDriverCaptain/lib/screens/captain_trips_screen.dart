import 'package:flutter/material.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/ride/ride_status.dart';
import '../services/backend_api.dart';
import '../services/captain_ride_api.dart';
import '../widgets/captain_drawer.dart';

class CaptainTripsScreen extends StatefulWidget {
  const CaptainTripsScreen({super.key});

  @override
  State<CaptainTripsScreen> createState() => _CaptainTripsScreenState();
}

class _CaptainTripsScreenState extends State<CaptainTripsScreen> {
  final _rideApi = CaptainRideApi(BackendApi());
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rides = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _rideApi.getHistory();
      final list = (res['rides'] as List?) ?? [];
      _rides = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatTripTime(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year} • '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Helper: converts a raw backend status string into the RideStatus enum.
  RideStatus _parseRideStatus(String raw) {
    final lower = raw.toLowerCase();
    return RideStatus.values.firstWhere(
          (s) => s.name.toLowerCase() == lower,
      orElse: () => RideStatus.canceled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      drawer: const CaptainDrawer(),
      appBar: AppBar(
        title: Text(AppStrings.myTrips(context)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        // Leading hamburger is automatically provided by Scaffold when drawer is set
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
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
          SizedBox(
            height: 200,
            child: Center(
              child: Text(
                AppStrings.noTrips(context),
                style: AppTextStyles.bodyMedium,
              ),
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
      itemBuilder: (context, index) {
        final data = _rides[index];
        final statusRaw = (data['status'] ?? 'UNKNOWN').toString();
        final st = _parseRideStatus(statusRaw);          // <-- fixed here
        final isCompleted = st == RideStatus.completed;
        final rawAmount = data['finalFare'] ?? data['suggestedFare'] ?? 0;
        final amount = rawAmount is num ? rawAmount.toDouble() : double.tryParse('$rawAmount') ?? 0;
        final pickup = (data['pickupAddr'] ?? AppStrings.pickup(context)).toString();
        final destination =
        (data['dropAddr'] ?? AppStrings.destination(context)).toString();
        final tripTime = _formatTripTime(data['updatedAt']?.toString());

        return GestureDetector(
          onTap: () => _showTripDetail(context, data),
          child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.cancel,
                    color: isCompleted ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCompleted
                            ? AppStrings.completed(context)
                            : AppStrings.cancelled(context),
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 2),
                      Text(tripTime, style: AppTextStyles.bodySmall),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'EG ${amount.toDouble().toStringAsFixed(2)}',
                    style: AppTextStyles.headline3,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.circle, size: 10, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pickup,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.circle, size: 10, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      destination,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        )); // GestureDetector + Container
      },
    );
  }

  void _showTripDetail(BuildContext context, Map<String, dynamic> data) {
    final statusRaw = (data['status'] ?? '').toString();
    final st = _parseRideStatus(statusRaw);
    final isCompleted = st == RideStatus.completed;
    final rawAmount = data['finalFare'] ?? data['suggestedFare'] ?? 0;
    final amount = rawAmount is num ? rawAmount.toDouble() : double.tryParse('$rawAmount') ?? 0;
    final pickup = (data['pickupAddr'] ?? '—').toString();
    final drop = (data['dropAddr'] ?? '—').toString();
    final clientName = (data['clientName'] ?? data['userName'] ?? '—').toString();
    final distanceKm = ((data['distanceKm'] ?? 0) as num).toDouble();
    final durationMin = ((data['durationMin'] ?? 0) as num).toDouble();
    final payMethod = (data['paymentMethod'] ?? 'CASH').toString().toUpperCase();
    final payLabel = payMethod == 'CASH' ? 'نقدي' : payMethod == 'INSTAPAY' ? 'InstaPay' : payMethod == 'VODAFONE_CASH' ? 'فودافون كاش' : payMethod;
    final tripTime = _formatTripTime(data['updatedAt']?.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.cancel,
                  color: isCompleted ? AppColors.success : AppColors.error,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  isCompleted ? 'رحلة مكتملة' : 'رحلة ملغاة',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                const Spacer(),
                Text(tripTime,
                  style: const TextStyle(color: AppColors.mediumGray, fontSize: 12)),
              ]),
              const SizedBox(height: 16),

              // Fare
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الأجرة', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('${amount.toStringAsFixed(2)} ج',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      )),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Route
              _DetailRow(icon: Icons.circle, iconColor: AppColors.success, label: 'من', value: pickup),
              const SizedBox(height: 8),
              _DetailRow(icon: Icons.location_on, iconColor: AppColors.primary, label: 'إلى', value: drop),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 6),

              // Stats grid
              Row(children: [
                _MiniStat('العميل', clientName, Icons.person_outline),
                const SizedBox(width: 10),
                _MiniStat('المسافة', '${distanceKm.toStringAsFixed(1)} كم', Icons.straighten_rounded),
                const SizedBox(width: 10),
                _MiniStat('المدة', '${durationMin.toStringAsFixed(0)} د', Icons.timer_outlined),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _MiniStat('الدفع', payLabel, Icons.payments_outlined),
                const SizedBox(width: 10),
                _MiniStat('الرحلة #', (data['id'] ?? '—').toString(), Icons.receipt_long_outlined),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: iconColor, size: 14),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.mediumGray, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        SizedBox(
          width: 280,
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ]),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MiniStat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.lightGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(label,
            style: const TextStyle(color: AppColors.mediumGray, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}