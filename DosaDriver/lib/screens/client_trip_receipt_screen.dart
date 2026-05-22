import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import 'client_rate_ride_screen.dart';

/// Full trip receipt — accessible from:
///   1) ClientRateRideScreen (after trip completion, "عرض الإيصال" button)
///   2) ClientTripsScreen (tap any completed trip card)
class ClientTripReceiptScreen extends StatelessWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  /// true → shows a back arrow (came from history list)
  final bool fromHistory;

  const ClientTripReceiptScreen({
    super.key,
    required this.rideId,
    required this.rideData,
    this.fromHistory = false,
  });

  // ─── helpers ────────────────────────────────────────────────
  double get _fare =>
      ((rideData['finalFare'] ??
              rideData['suggestedFare'] ??
              rideData['price'] ??
              0) as num)
          .toDouble();

  double get _distanceKm =>
      ((rideData['distanceKm'] ?? rideData['distance'] ?? 0) as num).toDouble();

  double get _durationMin =>
      ((rideData['durationMin'] ?? rideData['duration'] ?? 0) as num).toDouble();

  String get _pickupAddr =>
      (rideData['pickupAddr'] ?? rideData['pickup']?['addr'] ?? '—').toString();

  String get _dropAddr =>
      (rideData['dropAddr'] ?? rideData['drop']?['addr'] ?? '—').toString();

  String get _paymentMethod {
    final m = (rideData['paymentMethod'] ?? '').toString().toUpperCase();
    switch (m) {
      case 'CASH':
        return 'نقدي';
      case 'INSTAPAY':
        return 'InstaPay';
      case 'VODAFONE_CASH':
        return 'فودافون كاش';
      default:
        return m.isEmpty ? 'نقدي' : m;
    }
  }

  IconData get _paymentIcon {
    final m = (rideData['paymentMethod'] ?? '').toString().toUpperCase();
    switch (m) {
      case 'INSTAPAY':
      case 'VODAFONE_CASH':
        return Icons.mobile_friendly;
      default:
        return Icons.payments_outlined;
    }
  }

  String get _rideTypeLabel {
    switch ((rideData['type'] ?? rideData['rideType'] ?? '').toString().toUpperCase()) {
      case 'FAIR_VALUE':
        return '🚖 اقتصادي';
      case 'PREMIUM':
        return '🚘 بريميوم';
      case 'CUTE_CAR':
        return '🚙 كيوت كار';
      case 'SCOOTER':
        return '🛵 موتوسيكل';
      default:
        return 'رحلة';
    }
  }

  String get _captainName =>
      (rideData['captainName'] ?? '').toString();

  double get _captainRating =>
      ((rideData['captainRating'] ?? 0) as num).toDouble();

  String get _carModel => (rideData['carModel'] ?? '').toString();
  String get _plateNumber => (rideData['plateNumber'] ?? '').toString();

  String _formatDate(dynamic val) {
    if (val == null) return '';
    DateTime? dt;
    if (val is String) dt = DateTime.tryParse(val);
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $h:$m';
  }

  void _copyRideId(BuildContext context) {
    Clipboard.setData(ClipboardData(text: rideId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ رقم الرحلة'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatDate(rideData['createdAt'] ?? rideData['updatedAt']);

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'إيصال الرحلة',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: fromHistory,
        leading: fromHistory
            ? BackButton(color: Colors.white)
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'مشاركة الإيصال',
            onPressed: () => _shareReceipt(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Success Badge ──
            _buildSuccessBadge(),

            const SizedBox(height: 20),

            // ── Fare Card ──
            _buildFareCard(createdAt),

            const SizedBox(height: 14),

            // ── Route Card ──
            _buildRouteCard(),

            const SizedBox(height: 14),

            // ── Trip Stats ──
            _buildStatsRow(),

            const SizedBox(height: 14),

            // ── Captain Info ──
            if (_captainName.isNotEmpty) ...[
              _buildCaptainCard(),
              const SizedBox(height: 14),
            ],

            // ── Fare Breakdown ──
            _buildBreakdownCard(),

            const SizedBox(height: 14),

            // ── Ride ID ──
            _buildRideIdRow(context),

            const SizedBox(height: 24),

            // ── Rate Button (only when not from history) ──
            if (!fromHistory)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.star_rate_rounded, color: Colors.white),
                  label: const Text(
                    'قيّم الرحلة',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientRateRideScreen(
                          rideId: rideId,
                          rideData: rideData,
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  Widget _buildSuccessBadge() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: AppColors.successLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.success, size: 44),
        ),
        const SizedBox(height: 10),
        const Text(
          'رحلة مكتملة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.darkGray,
          ),
        ),
      ],
    );
  }

  Widget _buildFareCard(String createdAt) {
    return _Card(
      child: Column(
        children: [
          const Text('المبلغ الإجمالي',
              style: TextStyle(color: AppColors.mediumGray, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            '${_fare.toStringAsFixed(2)} جنيه',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_paymentIcon, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(_paymentMethod,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ],
            ),
          ),
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(createdAt,
                style: const TextStyle(
                    color: AppColors.mediumGray, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    return _Card(
      child: Column(
        children: [
          _RouteRow(
            icon: Icons.circle,
            iconColor: AppColors.success,
            label: 'من',
            value: _pickupAddr,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 9),
            child: SizedBox(
              height: 20,
              child: VerticalDivider(
                  color: AppColors.divider, thickness: 1.5, width: 20),
            ),
          ),
          _RouteRow(
            icon: Icons.location_on,
            iconColor: AppColors.primary,
            label: 'إلى',
            value: _dropAddr,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _StatPill(
          icon: Icons.straighten_rounded,
          label: 'المسافة',
          value: '${_distanceKm.toStringAsFixed(1)} كم',
          color: AppColors.secondary,
        ),
        const SizedBox(width: 10),
        _StatPill(
          icon: Icons.timer_outlined,
          label: 'المدة',
          value: '${_durationMin.toStringAsFixed(0)} د',
          color: AppColors.warning,
        ),
        const SizedBox(width: 10),
        _StatPill(
          icon: Icons.directions_car_outlined,
          label: 'النوع',
          value: _rideTypeLabel,
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildCaptainCard() {
    return _Card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primaryLight,
            child: const Icon(Icons.person, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _captainName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                if (_carModel.isNotEmpty || _plateNumber.isNotEmpty)
                  Text(
                    '${_carModel.isNotEmpty ? _carModel : ''}${_plateNumber.isNotEmpty ? ' · $_plateNumber' : ''}',
                    style: const TextStyle(
                        color: AppColors.mediumGray, fontSize: 13),
                  ),
              ],
            ),
          ),
          if (_captainRating > 0)
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 2),
                Text(
                  _captainRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard() {
    // Show whatever breakdown fields the backend provides
    final baseFare =
        (rideData['baseFare'] ?? rideData['basePrice'] ?? 0 as num).toDouble();
    final distanceFare =
        (rideData['distanceFare'] ?? rideData['distancePrice'] ?? 0 as num)
            .toDouble();
    final timeFare =
        (rideData['timeFare'] ?? rideData['timePrice'] ?? 0 as num).toDouble();
    final discount =
        (rideData['discount'] ?? 0 as num).toDouble();

    final hasBreakdown =
        baseFare > 0 || distanceFare > 0 || timeFare > 0 || discount > 0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تفاصيل السعر',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 10),
          if (hasBreakdown) ...[
            if (baseFare > 0)
              _BreakdownRow('سعر الأساس', '${baseFare.toStringAsFixed(2)} ج'),
            if (distanceFare > 0)
              _BreakdownRow(
                  'رسوم المسافة', '${distanceFare.toStringAsFixed(2)} ج'),
            if (timeFare > 0)
              _BreakdownRow(
                  'رسوم الوقت', '${timeFare.toStringAsFixed(2)} ج'),
            if (discount > 0)
              _BreakdownRow(
                  'خصم', '-${discount.toStringAsFixed(2)} ج',
                  valueColor: AppColors.success),
            const Divider(height: 16),
          ] else ...[
            if (_distanceKm > 0)
              _BreakdownRow('المسافة',
                  '${_distanceKm.toStringAsFixed(1)} كم'),
            if (_durationMin > 0)
              _BreakdownRow('الوقت',
                  '${_durationMin.toStringAsFixed(0)} دقيقة'),
            const Divider(height: 16),
          ],
          _BreakdownRow(
            'الإجمالي',
            '${_fare.toStringAsFixed(2)} ج',
            isBold: true,
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildRideIdRow(BuildContext context) {
    return GestureDetector(
      onTap: () => _copyRideId(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined,
                color: AppColors.mediumGray, size: 18),
            const SizedBox(width: 8),
            const Text('رقم الرحلة',
                style: TextStyle(
                    color: AppColors.mediumGray, fontSize: 13)),
            const Spacer(),
            Text(
              '#$rideId',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.darkGray),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.copy_all_outlined,
                size: 15, color: AppColors.mediumGray),
          ],
        ),
      ),
    );
  }

  void _shareReceipt(BuildContext context) {
    final text = '''
إيصال رحلة DosaDriver
──────────────────
المبلغ: ${_fare.toStringAsFixed(2)} جنيه
من: $_pickupAddr
إلى: $_dropAddr
المسافة: ${_distanceKm.toStringAsFixed(1)} كم
المدة: ${_durationMin.toStringAsFixed(0)} دقيقة
طريقة الدفع: $_paymentMethod
الكابتن: $_captainName
رقم الرحلة: #$rideId
──────────────────
شكراً لاستخدامك DosaDriver 🚖
''';
    Clipboard.setData(ClipboardData(text: text.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الإيصال إلى الحافظة')),
    );
  }
}

// ─── Shared small widgets ───────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.mediumGray,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatPill(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x10000000),
                blurRadius: 8,
                offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 12),
                textAlign: TextAlign.center),
            Text(label,
                style: const TextStyle(
                    color: AppColors.mediumGray, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _BreakdownRow(this.label, this.value,
      {this.isBold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: isBold ? AppColors.darkGray : AppColors.mediumGray,
                  fontWeight:
                      isBold ? FontWeight.w700 : FontWeight.normal,
                  fontSize: isBold ? 15 : 13)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? AppColors.darkGray,
                  fontWeight:
                      isBold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: isBold ? 15 : 13)),
        ],
      ),
    );
  }
}
