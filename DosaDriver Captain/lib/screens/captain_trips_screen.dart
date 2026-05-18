import 'package:flutter/material.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/ride/ride_status.dart';
import '../services/backend_api.dart';
import '../services/captain_ride_api.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: Text(AppStrings.myTrips(context)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const ListView(
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
        final st = rideStatusFromAny(statusRaw);
        final isCompleted = st == RideStatus.completed;
        final rawAmount = data['finalFare'] ?? data['suggestedFare'] ?? 0;
        final amount = rawAmount is num ? rawAmount.toDouble() : double.tryParse('$rawAmount') ?? 0;
        final pickup = (data['pickupAddr'] ?? AppStrings.pickup(context)).toString();
        final destination =
            (data['dropAddr'] ?? AppStrings.destination(context)).toString();
        final tripTime = _formatTripTime(data['updatedAt']?.toString());

        return Container(
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
        );
      },
    );
  }
}
