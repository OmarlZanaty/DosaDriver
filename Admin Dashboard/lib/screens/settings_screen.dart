import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  final String search;
  const SettingsScreen({super.key, required this.search});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _saving = false;

  // ---------- Existing (from your screenshots) ----------
  // Surge
  final _surgeEnabledCtrl = ValueNotifier<bool>(false);
  final _surgeMultiplierCtrl = TextEditingController();

  // Cancellation
  final _beforeAcceptFeeCtrl = TextEditingController();
  final _afterAcceptFeeCtrl = TextEditingController();
  final _afterArrivalFeeCtrl = TextEditingController();
  final _cancellationCtrl = TextEditingController();
  final _freeCancelSecondsCtrl = TextEditingController();
  final _maxDailyUserCancelsCtrl = TextEditingController();

  // Pricing economic/premium/scooter
  final _ecoBaseFareCtrl = TextEditingController();
  final _ecoPerKmCtrl = TextEditingController();
  final _ecoPerMinCtrl = TextEditingController();
  final _ecoMinFareCtrl = TextEditingController();

  final _preBaseFareCtrl = TextEditingController();
  final _prePerKmCtrl = TextEditingController();
  final _prePerMinCtrl = TextEditingController();
  final _preMinFareCtrl = TextEditingController();

  final _scoBaseFareCtrl = TextEditingController();
  final _scoPerKmCtrl = TextEditingController();
  final _scoPerMinCtrl = TextEditingController();
  final _scoMinFareCtrl = TextEditingController();

  // ---------- New full control sections ----------
  // Payouts / Commission
  final _commissionPercentCtrl = TextEditingController();
  final _minWithdrawalCtrl = TextEditingController();
  final _withdrawalFeeCtrl = TextEditingController();
  final _autoPayoutCtrl = ValueNotifier<bool>(false);
  final _payoutScheduleCtrl = TextEditingController(); // daily/weekly/manual

  // Ride rules / matching
  final _searchRadiusKmCtrl = TextEditingController();
  final _maxRadiusKmCtrl = TextEditingController();
  final _driverResponseTimeoutSecCtrl = TextEditingController();
  final _maxDriversToNotifyCtrl = TextEditingController();
  final _reassignDelaySecCtrl = TextEditingController();
  final _maxActiveTripsPerCaptainCtrl = TextEditingController();
  final _allowCashCtrl = ValueNotifier<bool>(true);
  final _allowCardCtrl = ValueNotifier<bool>(false);
  final _allowWalletCtrl = ValueNotifier<bool>(true);

  // Captains onboarding
  final _autoApproveCaptainsCtrl = ValueNotifier<bool>(false);
  final _requireNationalIdCtrl = ValueNotifier<bool>(true);
  final _requireLicenseCtrl = ValueNotifier<bool>(true);
  final _requireVehiclePhotoCtrl = ValueNotifier<bool>(true);
  final _minRatingToAcceptCtrl = TextEditingController();
  final _minTripsBeforeCashoutCtrl = TextEditingController();
  final _defaultCaptainStatusCtrl = TextEditingController(); // pending_review/approved

  // App flags / maintenance
  final _maintenanceModeCtrl = ValueNotifier<bool>(false);
  final _disableNewSignupsCtrl = ValueNotifier<bool>(false);
  final _disableRideRequestsCtrl = ValueNotifier<bool>(false);
  final _disableWithdrawalsCtrl = ValueNotifier<bool>(false);
  final _minAndroidVersionCtrl = TextEditingController();
  final _forceUpdateMessageArCtrl = TextEditingController();
  final _bannerEnabledCtrl = ValueNotifier<bool>(false);
  final _bannerTextArCtrl = TextEditingController();

  // Support
  final _supportWhatsappCtrl = TextEditingController();
  final _supportPhoneCtrl = TextEditingController();
  final _supportEmailCtrl = TextEditingController();
  final _termsUrlCtrl = TextEditingController();
  final _privacyUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _surgeMultiplierCtrl.dispose();
    _beforeAcceptFeeCtrl.dispose();
    _afterAcceptFeeCtrl.dispose();
    _afterArrivalFeeCtrl.dispose();
    _cancellationCtrl.dispose();
    _freeCancelSecondsCtrl.dispose();
    _maxDailyUserCancelsCtrl.dispose();

    _ecoBaseFareCtrl.dispose();
    _ecoPerKmCtrl.dispose();
    _ecoPerMinCtrl.dispose();
    _ecoMinFareCtrl.dispose();

    _preBaseFareCtrl.dispose();
    _prePerKmCtrl.dispose();
    _prePerMinCtrl.dispose();
    _preMinFareCtrl.dispose();

    _scoBaseFareCtrl.dispose();
    _scoPerKmCtrl.dispose();
    _scoPerMinCtrl.dispose();
    _scoMinFareCtrl.dispose();

    _commissionPercentCtrl.dispose();
    _minWithdrawalCtrl.dispose();
    _withdrawalFeeCtrl.dispose();
    _payoutScheduleCtrl.dispose();

    _searchRadiusKmCtrl.dispose();
    _maxRadiusKmCtrl.dispose();
    _driverResponseTimeoutSecCtrl.dispose();
    _maxDriversToNotifyCtrl.dispose();
    _reassignDelaySecCtrl.dispose();
    _maxActiveTripsPerCaptainCtrl.dispose();

    _minRatingToAcceptCtrl.dispose();
    _minTripsBeforeCashoutCtrl.dispose();
    _defaultCaptainStatusCtrl.dispose();

    _minAndroidVersionCtrl.dispose();
    _forceUpdateMessageArCtrl.dispose();
    _bannerTextArCtrl.dispose();

    _supportWhatsappCtrl.dispose();
    _supportPhoneCtrl.dispose();
    _supportEmailCtrl.dispose();
    _termsUrlCtrl.dispose();
    _privacyUrlCtrl.dispose();

    _surgeEnabledCtrl.dispose();
    _autoPayoutCtrl.dispose();
    _allowCashCtrl.dispose();
    _allowCardCtrl.dispose();
    _allowWalletCtrl.dispose();
    _autoApproveCaptainsCtrl.dispose();
    _requireNationalIdCtrl.dispose();
    _requireLicenseCtrl.dispose();
    _requireVehiclePhotoCtrl.dispose();
    _maintenanceModeCtrl.dispose();
    _disableNewSignupsCtrl.dispose();
    _disableRideRequestsCtrl.dispose();
    _disableWithdrawalsCtrl.dispose();
    _bannerEnabledCtrl.dispose();

    super.dispose();
  }

  // ---------------- Utils ----------------
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textDirection: TextDirection.rtl)),
    );
  }

  bool _matchSection(String title, List<String> keywords) {
    final q = widget.search.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = (title + ' ' + keywords.join(' ')).toLowerCase();
    return hay.contains(q);
  }

  double _toDouble(TextEditingController c, {double fallback = 0}) {
    final v = double.tryParse(c.text.trim());
    return v ?? fallback;
  }

  int _toInt(TextEditingController c, {int fallback = 0}) {
    final v = int.tryParse(c.text.trim());
    return v ?? fallback;
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: const OutlineInputBorder(),
  );

  // ---------------- Load from Firestore ----------------
  Future<void> _loadAll() async {
    setState(() => _loading = true);

    // Existing
    final surgeSnap = await _db.doc('app_config/surge').get();
    final cancelSnap = await _db.doc('settings/cancellation').get();
    final ecoSnap = await _db.doc('pricing/economic').get();
    final preSnap = await _db.doc('pricing/premium').get();
    final scoSnap = await _db.doc('pricing/scooter').get();

    // New
    final payoutsSnap = await _db.doc('settings/payouts').get();
    final ridesSnap = await _db.doc('settings/rides').get();
    final captainsSnap = await _db.doc('settings/captains').get();
    final flagsSnap = await _db.doc('app_config/flags').get();
    final supportSnap = await _db.doc('settings/support').get();

    final surge = surgeSnap.data() ?? {};
    final cancel = cancelSnap.data() ?? {};
    final eco = ecoSnap.data() ?? {};
    final pre = preSnap.data() ?? {};
    final sco = scoSnap.data() ?? {};

    final payouts = payoutsSnap.data() ?? {};
    final rides = ridesSnap.data() ?? {};
    final captains = captainsSnap.data() ?? {};
    final flags = flagsSnap.data() ?? {};
    final support = supportSnap.data() ?? {};

    // Surge
    _surgeEnabledCtrl.value = (surge['enabled'] ?? false) == true;
    _surgeMultiplierCtrl.text = '${(surge['multiplier'] ?? 1)}';

    // Cancellation
    _beforeAcceptFeeCtrl.text = '${(cancel['beforeAcceptFee'] ?? 0)}';
    _afterAcceptFeeCtrl.text = '${(cancel['afterAcceptFee'] ?? 0)}';
    _afterArrivalFeeCtrl.text = '${(cancel['afterArrivalFee'] ?? 0)}';
    _cancellationCtrl.text = '${(cancel['cancellation'] ?? 0)}';
    _freeCancelSecondsCtrl.text = '${(cancel['freeCancelSeconds'] ?? 0)}';
    _maxDailyUserCancelsCtrl.text = '${(cancel['maxDailyCancellations'] ?? 0)}';

    // Pricing
    _ecoBaseFareCtrl.text = '${(eco['baseFare'] ?? 0)}';
    _ecoPerKmCtrl.text = '${(eco['perKm'] ?? 0)}';
    _ecoPerMinCtrl.text = '${(eco['perMin'] ?? 0)}';
    _ecoMinFareCtrl.text = '${(eco['minFare'] ?? 0)}';

    _preBaseFareCtrl.text = '${(pre['baseFare'] ?? 0)}';
    _prePerKmCtrl.text = '${(pre['perKm'] ?? 0)}';
    _prePerMinCtrl.text = '${(pre['perMin'] ?? 0)}';
    _preMinFareCtrl.text = '${(pre['minFare'] ?? 0)}';

    _scoBaseFareCtrl.text = '${(sco['baseFare'] ?? 0)}';
    _scoPerKmCtrl.text = '${(sco['perKm'] ?? 0)}';
    _scoPerMinCtrl.text = '${(sco['perMin'] ?? 0)}';
    _scoMinFareCtrl.text = '${(sco['minFare'] ?? 0)}';

    // Payouts
    _commissionPercentCtrl.text = '${(payouts['commissionPercent'] ?? 0)}';
    _minWithdrawalCtrl.text = '${(payouts['minWithdrawal'] ?? 0)}';
    _withdrawalFeeCtrl.text = '${(payouts['withdrawalFee'] ?? 0)}';
    _autoPayoutCtrl.value = (payouts['autoPayoutEnabled'] ?? false) == true;
    _payoutScheduleCtrl.text = '${(payouts['payoutSchedule'] ?? 'manual')}';

    // Rides
    _searchRadiusKmCtrl.text = '${(rides['searchRadiusKm'] ?? 3)}';
    _maxRadiusKmCtrl.text = '${(rides['maxRadiusKm'] ?? 10)}';
    _driverResponseTimeoutSecCtrl.text = '${(rides['driverResponseTimeoutSec'] ?? 25)}';
    _maxDriversToNotifyCtrl.text = '${(rides['maxDriversToNotify'] ?? 5)}';
    _reassignDelaySecCtrl.text = '${(rides['reassignDelaySec'] ?? 5)}';
    _maxActiveTripsPerCaptainCtrl.text = '${(rides['maxActiveTripsPerCaptain'] ?? 1)}';
    _allowCashCtrl.value = (rides['allowCash'] ?? true) == true;
    _allowCardCtrl.value = (rides['allowCard'] ?? false) == true;
    _allowWalletCtrl.value = (rides['allowWallet'] ?? true) == true;

    // Captains
    _autoApproveCaptainsCtrl.value = (captains['autoApprove'] ?? false) == true;
    _requireNationalIdCtrl.value = (captains['requireNationalId'] ?? true) == true;
    _requireLicenseCtrl.value = (captains['requireLicense'] ?? true) == true;
    _requireVehiclePhotoCtrl.value = (captains['requireVehiclePhoto'] ?? true) == true;
    _minRatingToAcceptCtrl.text = '${(captains['minRatingToAcceptTrips'] ?? 0)}';
    _minTripsBeforeCashoutCtrl.text = '${(captains['minTripsBeforeCashout'] ?? 0)}';
    _defaultCaptainStatusCtrl.text = '${(captains['defaultStatus'] ?? 'pending_review')}';

    // Flags
    _maintenanceModeCtrl.value = (flags['maintenanceMode'] ?? false) == true;
    _disableNewSignupsCtrl.value = (flags['disableNewSignups'] ?? false) == true;
    _disableRideRequestsCtrl.value = (flags['disableRideRequests'] ?? false) == true;
    _disableWithdrawalsCtrl.value = (flags['disableWithdrawals'] ?? false) == true;
    _minAndroidVersionCtrl.text = '${(flags['forceUpdateMinVersionAndroid'] ?? 0)}';
    _forceUpdateMessageArCtrl.text = '${(flags['forceUpdateMessageAr'] ?? '')}';
    _bannerEnabledCtrl.value = (flags['showBanner'] ?? false) == true;
    _bannerTextArCtrl.text = '${(flags['bannerTextAr'] ?? '')}';

    // Support
    _supportWhatsappCtrl.text = '${(support['whatsapp'] ?? '')}';
    _supportPhoneCtrl.text = '${(support['phone'] ?? '')}';
    _supportEmailCtrl.text = '${(support['email'] ?? '')}';
    _termsUrlCtrl.text = '${(support['termsUrl'] ?? '')}';
    _privacyUrlCtrl.text = '${(support['privacyUrl'] ?? '')}';

    setState(() => _loading = false);
  }

  // ---------------- Save helpers ----------------
  Future<void> _saveDoc(String path, Map<String, dynamic> data, {String? okMsg}) async {
    setState(() => _saving = true);
    try {
      await _db.doc(path).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _toast(okMsg ?? 'تم الحفظ ✅');
    } catch (e) {
      _toast('خطأ أثناء الحفظ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSurge() => _saveDoc(
    'app_config/surge',
    {
      'enabled': _surgeEnabledCtrl.value,
      'multiplier': _toDouble(_surgeMultiplierCtrl, fallback: 1),
    },
    okMsg: 'تم حفظ إعدادات الـ Surge ✅',
  );

  Future<void> _saveCancellation() => _saveDoc(
    'settings/cancellation',
    {
      'beforeAcceptFee': _toDouble(_beforeAcceptFeeCtrl),
      'afterAcceptFee': _toDouble(_afterAcceptFeeCtrl),
      'afterArrivalFee': _toDouble(_afterArrivalFeeCtrl),
      'cancellation': _toDouble(_cancellationCtrl),
      'freeCancelSeconds': _toInt(_freeCancelSecondsCtrl),
      'maxDailyCancellations': _toInt(_maxDailyUserCancelsCtrl),
    },
    okMsg: 'تم حفظ سياسة الإلغاء ✅',
  );

  Future<void> _savePricing(String type, TextEditingController base, TextEditingController km,
      TextEditingController min, TextEditingController minFare) {
    return _saveDoc(
      'pricing/$type',
      {
        'baseFare': _toDouble(base),
        'perKm': _toDouble(km),
        'perMin': _toDouble(min),
        'minFare': _toDouble(minFare),
      },
      okMsg: 'تم حفظ التسعير ($type) ✅',
    );
  }

  Future<void> _savePayouts() => _saveDoc(
    'settings/payouts',
    {
      'commissionPercent': _toDouble(_commissionPercentCtrl),
      'minWithdrawal': _toDouble(_minWithdrawalCtrl),
      'withdrawalFee': _toDouble(_withdrawalFeeCtrl),
      'autoPayoutEnabled': _autoPayoutCtrl.value,
      'payoutSchedule': _payoutScheduleCtrl.text.trim().isEmpty
          ? 'manual'
          : _payoutScheduleCtrl.text.trim(),
    },
    okMsg: 'تم حفظ إعدادات الأرباح/السحب ✅',
  );

  Future<void> _saveRides() => _saveDoc(
    'settings/rides',
    {
      'searchRadiusKm': _toDouble(_searchRadiusKmCtrl, fallback: 3),
      'maxRadiusKm': _toDouble(_maxRadiusKmCtrl, fallback: 10),
      'driverResponseTimeoutSec': _toInt(_driverResponseTimeoutSecCtrl, fallback: 25),
      'maxDriversToNotify': _toInt(_maxDriversToNotifyCtrl, fallback: 5),
      'reassignDelaySec': _toInt(_reassignDelaySecCtrl, fallback: 5),
      'maxActiveTripsPerCaptain': _toInt(_maxActiveTripsPerCaptainCtrl, fallback: 1),
      'allowCash': _allowCashCtrl.value,
      'allowCard': _allowCardCtrl.value,
      'allowWallet': _allowWalletCtrl.value,
    },
    okMsg: 'تم حفظ إعدادات الرحلات ✅',
  );

  Future<void> _saveCaptains() => _saveDoc(
    'settings/captains',
    {
      'autoApprove': _autoApproveCaptainsCtrl.value,
      'requireNationalId': _requireNationalIdCtrl.value,
      'requireLicense': _requireLicenseCtrl.value,
      'requireVehiclePhoto': _requireVehiclePhotoCtrl.value,
      'minRatingToAcceptTrips': _toDouble(_minRatingToAcceptCtrl),
      'minTripsBeforeCashout': _toInt(_minTripsBeforeCashoutCtrl),
      'defaultStatus': _defaultCaptainStatusCtrl.text.trim().isEmpty
          ? 'pending_review'
          : _defaultCaptainStatusCtrl.text.trim(),
    },
    okMsg: 'تم حفظ إعدادات السائقين ✅',
  );

  Future<void> _saveFlags() => _saveDoc(
    'app_config/flags',
    {
      'maintenanceMode': _maintenanceModeCtrl.value,
      'disableNewSignups': _disableNewSignupsCtrl.value,
      'disableRideRequests': _disableRideRequestsCtrl.value,
      'disableWithdrawals': _disableWithdrawalsCtrl.value,
      'forceUpdateMinVersionAndroid': _toInt(_minAndroidVersionCtrl),
      'forceUpdateMessageAr': _forceUpdateMessageArCtrl.text.trim(),
      'showBanner': _bannerEnabledCtrl.value,
      'bannerTextAr': _bannerTextArCtrl.text.trim(),
    },
    okMsg: 'تم حفظ إعدادات التطبيق العامة ✅',
  );

  Future<void> _saveSupport() => _saveDoc(
    'settings/support',
    {
      'whatsapp': _supportWhatsappCtrl.text.trim(),
      'phone': _supportPhoneCtrl.text.trim(),
      'email': _supportEmailCtrl.text.trim(),
      'termsUrl': _termsUrlCtrl.text.trim(),
      'privacyUrl': _privacyUrlCtrl.text.trim(),
    },
    okMsg: 'تم حفظ إعدادات الدعم ✅',
  );

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _topBar(),

              // Surge
              if (_matchSection('إعدادات الـ Surge', ['سيرج', 'زيادة', 'surge', 'multiplier']))
                _card(
                  title: 'إعدادات الـ Surge',
                  subtitle: 'app_config/surge',
                  child: Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _surgeEnabledCtrl,
                        builder: (_, v, __) => SwitchListTile(
                          value: v,
                          onChanged: (x) => _surgeEnabledCtrl.value = x,
                          title: const Text('تفعيل الـ Surge'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _numField('المضاعف (Multiplier)', _surgeMultiplierCtrl, hint: 'مثال: 1.5'),
                      const SizedBox(height: 12),
                      _saveRow(onSave: _saveSurge),
                    ],
                  ),
                ),

              // Cancellation
              if (_matchSection('سياسة الإلغاء', ['إلغاء', 'cancellation', 'fees', 'penalty']))
                _card(
                  title: 'سياسة الإلغاء والغرامات',
                  subtitle: 'settings/cancellation',
                  child: Column(
                    children: [
                      _numField('رسوم الإلغاء قبل قبول الكابتن', _beforeAcceptFeeCtrl),
                      const SizedBox(height: 10),
                      _numField('رسوم الإلغاء بعد قبول الكابتن', _afterAcceptFeeCtrl),
                      const SizedBox(height: 10),
                      _numField('رسوم الإلغاء بعد وصول الكابتن', _afterArrivalFeeCtrl),
                      const SizedBox(height: 10),
                      _numField('قيمة/سياسة الإلغاء (عام)', _cancellationCtrl),
                      const SizedBox(height: 10),
                      _intField('مدة الإلغاء المجاني (بالثواني)', _freeCancelSecondsCtrl, hint: 'مثال: 30'),
                      const SizedBox(height: 10),
                      _intField('أقصى عدد إلغاءات يوميًا للمستخدم', _maxDailyUserCancelsCtrl, hint: 'مثال: 3'),
                      const SizedBox(height: 12),
                      _saveRow(onSave: _saveCancellation),
                    ],
                  ),
                ),

              // Pricing sections
              if (_matchSection('التسعير - اقتصادي', ['pricing', 'economic', 'اقتصادي']))
                _pricingCard(
                  title: 'التسعير - اقتصادي',
                  subtitle: 'pricing/economic',
                  base: _ecoBaseFareCtrl,
                  km: _ecoPerKmCtrl,
                  min: _ecoPerMinCtrl,
                  minFare: _ecoMinFareCtrl,
                  onSave: () => _savePricing('economic', _ecoBaseFareCtrl, _ecoPerKmCtrl, _ecoPerMinCtrl, _ecoMinFareCtrl),
                ),

              if (_matchSection('التسعير - بريميوم', ['pricing', 'premium', 'بريميوم']))
                _pricingCard(
                  title: 'التسعير - بريميوم',
                  subtitle: 'pricing/premium',
                  base: _preBaseFareCtrl,
                  km: _prePerKmCtrl,
                  min: _prePerMinCtrl,
                  minFare: _preMinFareCtrl,
                  onSave: () => _savePricing('premium', _preBaseFareCtrl, _prePerKmCtrl, _prePerMinCtrl, _preMinFareCtrl),
                ),

              if (_matchSection('التسعير - سكوتر', ['pricing', 'scooter', 'سكوتر']))
                _pricingCard(
                  title: 'التسعير - سكوتر',
                  subtitle: 'pricing/scooter',
                  base: _scoBaseFareCtrl,
                  km: _scoPerKmCtrl,
                  min: _scoPerMinCtrl,
                  minFare: _scoMinFareCtrl,
                  onSave: () => _savePricing('scooter', _scoBaseFareCtrl, _scoPerKmCtrl, _scoPerMinCtrl, _scoMinFareCtrl),
                ),

              // Payouts
              if (_matchSection('الأرباح والسحب', ['payout', 'commission', 'سحب', 'عمولة']))
                _card(
                  title: 'الأرباح والسحب والعمولة',
                  subtitle: 'settings/payouts',
                  child: Column(
                    children: [
                      _numField('نسبة العمولة (%)', _commissionPercentCtrl, hint: 'مثال: 15'),
                      const SizedBox(height: 10),
                      _numField('الحد الأدنى للسحب', _minWithdrawalCtrl, hint: 'مثال: 200'),
                      const SizedBox(height: 10),
                      _numField('رسوم السحب', _withdrawalFeeCtrl, hint: 'مثال: 10'),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<bool>(
                        valueListenable: _autoPayoutCtrl,
                        builder: (_, v, __) => SwitchListTile(
                          value: v,
                          onChanged: (x) => _autoPayoutCtrl.value = x,
                          title: const Text('تفعيل الصرف التلقائي'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _payoutScheduleCtrl,
                        decoration: _dec('جدولة الصرف', hint: 'daily / weekly / manual'),
                      ),
                      const SizedBox(height: 12),
                      _saveRow(onSave: _savePayouts),
                    ],
                  ),
                ),

              // Rides rules
              if (_matchSection('إعدادات الرحلات', ['rides', 'matching', 'dispatch', 'رحلات']))
                _card(
                  title: 'إعدادات الرحلات والتوزيع',
                  subtitle: 'settings/rides',
                  child: Column(
                    children: [
                      _numField('نطاق البحث الأساسي (كم)', _searchRadiusKmCtrl, hint: 'مثال: 3'),
                      const SizedBox(height: 10),
                      _numField('أقصى نطاق بحث (كم)', _maxRadiusKmCtrl, hint: 'مثال: 10'),
                      const SizedBox(height: 10),
                      _intField('مهلة رد السائق (ثانية)', _driverResponseTimeoutSecCtrl, hint: 'مثال: 25'),
                      const SizedBox(height: 10),
                      _intField('أقصى عدد سائقين يتم إشعارهم', _maxDriversToNotifyCtrl, hint: 'مثال: 5'),
                      const SizedBox(height: 10),
                      _intField('تأخير إعادة الإسناد (ثانية)', _reassignDelaySecCtrl, hint: 'مثال: 5'),
                      const SizedBox(height: 10),
                      _intField('أقصى رحلات نشطة للكابتن', _maxActiveTripsPerCaptainCtrl, hint: 'مثال: 1'),
                      const Divider(height: 24),
                      ValueListenableBuilder<bool>(
                        valueListenable: _allowCashCtrl,
                        builder: (_, v, __) => SwitchListTile(
                          value: v,
                          onChanged: (x) => _allowCashCtrl.value = x,
                          title: const Text('السماح بالدفع كاش'),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _allowCardCtrl,
                        builder: (_, v, __) => SwitchListTile(
                          value: v,
                          onChanged: (x) => _allowCardCtrl.value = x,
                          title: const Text('السماح بالدفع بالبطاقة'),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _allowWalletCtrl,
                        builder: (_, v, __) => SwitchListTile(
                          value: v,
                          onChanged: (x) => _allowWalletCtrl.value = x,
                          title: const Text('السماح بالدفع بالمحفظة'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _saveRow(onSave: _saveRides),
                    ],
                  ),
                ),

              // Captains
              if (_matchSection('إعدادات السائقين', ['captain', 'driver', 'سائق', 'كابتن']))
                _card(
                  title: 'إعدادات السائقين/الكباتن',
                  subtitle: 'settings/captains',
                  child: Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _autoApproveCaptainsCtrl,
                        builder: (_, v, __) => SwitchListTile(
                          value: v,
                          onChanged: (x) => _autoApproveCaptainsCtrl.value = x,
                          title: const Text('الموافقة التلقائية على السائقين'),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _requireNationalIdCtrl,
                        builder: (_, v, __) => SwitchListTile(
                          value: v,
                          onChanged: (x) => _requireNationalIdCtrl.value = x,
                          title: const Text('طلب بطاقة الرقم القومي'),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _requireLicenseCtrl,
                        builder: (_, v, __) => SwitchListTile(
                          value: v,
                          onChanged: (x) => _requireLicenseCtrl.value = x,
                          title: const Text('طلب رخصة القيادة'),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _requireVehiclePhotoCtrl,
                        builder: (_, v, __) => SwitchListTile(
                          value: v,
                          onChanged: (x) => _requireVehiclePhotoCtrl.value = x,
                          title: const Text('طلب صورة المركبة'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _numField('أقل تقييم لقبول الرحلات', _minRatingToAcceptCtrl, hint: 'مثال: 4.2'),
                      const SizedBox(height: 10),
                      _intField('أقل عدد رحلات قبل السحب', _minTripsBeforeCashoutCtrl, hint: 'مثال: 10'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _defaultCaptainStatusCtrl,
                        decoration: _dec('الحالة الافتراضية', hint: 'pending_review / approved'),
                      ),
                      const SizedBox(height: 12),
                      _saveRow(onSave: _saveCaptains),
                    ],
                  ),
                ),

              // App flags
              if (_matchSection('إعدادات عامة', ['flags', 'maintenance', 'تحديث', 'صيانة', 'banner']))
                _card(
                  title: 'إعدادات عامة وتحكم كامل',
                  subtitle: 'app_config/flags',
                  child: Column(
                    children: [
                      _dangerSwitch(
                        title: 'وضع الصيانة (إيقاف أجزاء من التطبيق)',
                        notifier: _maintenanceModeCtrl,
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _disableNewSignupsCtrl,
                        builder: (_, v, __) => SwitchListTile(
                          value: v,
                          onChanged: (x) => _disableNewSignupsCtrl.value = x,
                          title: const Text('إيقاف التسجيل الجديد'),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _disableRideRequestsCtrl,
                        builder: (_, v, __) => SwitchListTile(
                          value: v,
                          onChanged: (x) => _disableRideRequestsCtrl.value = x,
                          title: const Text('إيقاف طلبات الرحلات'),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _disableWithdrawalsCtrl,
                        builder: (_, v, __) => SwitchListTile(
                          value: v,
                          onChanged: (x) => _disableWithdrawalsCtrl.value = x,
                          title: const Text('إيقاف السحب للكباتن'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _intField('إجبار تحديث - أقل نسخة أندرويد', _minAndroidVersionCtrl, hint: 'مثال: 12'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _forceUpdateMessageArCtrl,
                        decoration: _dec('رسالة إجبار التحديث (عربي)', hint: 'من فضلك حدث التطبيق للاستمرار'),
                        maxLines: 2,
                      ),
                      const Divider(height: 24),
                      ValueListenableBuilder<bool>(
                        valueListenable: _bannerEnabledCtrl,
                        builder: (_, v, __) => SwitchListTile(
                          value: v,
                          onChanged: (x) => _bannerEnabledCtrl.value = x,
                          title: const Text('إظهار بانر داخل التطبيق'),
                        ),
                      ),
                      TextField(
                        controller: _bannerTextArCtrl,
                        decoration: _dec('نص البانر (عربي)', hint: 'خصم 20% اليوم...'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _saveRow(onSave: _saveFlags),
                    ],
                  ),
                ),

              // Support
              if (_matchSection('الدعم', ['support', 'واتساب', 'phone', 'email', 'privacy', 'terms']))
                _card(
                  title: 'إعدادات الدعم والتواصل',
                  subtitle: 'settings/support',
                  child: Column(
                    children: [
                      TextField(
                        controller: _supportWhatsappCtrl,
                        decoration: _dec('واتساب الدعم', hint: '+2010xxxxxxx'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _supportPhoneCtrl,
                        decoration: _dec('هاتف الدعم', hint: '+2010xxxxxxx'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _supportEmailCtrl,
                        decoration: _dec('بريد الدعم', hint: 'support@domain.com'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _termsUrlCtrl,
                        decoration: _dec('رابط الشروط', hint: 'https://...'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _privacyUrlCtrl,
                        decoration: _dec('رابط الخصوصية', hint: 'https://...'),
                      ),
                      const SizedBox(height: 12),
                      _saveRow(onSave: _saveSupport),
                    ],
                  ),
                ),

              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _loadAll,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة تحميل من Firestore'),
              ),
              const SizedBox(height: 60),
            ],
          ),

          if (_saving)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.05),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'لوحة التحكم - الإعدادات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              widget.search.trim().isEmpty ? 'بدون بحث' : 'بحث: "${widget.search}"',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required String subtitle, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _saveRow({required VoidCallback onSave}) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _saving ? null : onSave,
          icon: const Icon(Icons.save),
          label: const Text('حفظ'),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'سيتم تطبيق الإعدادات مباشرة داخل Firestore',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _numField(String label, TextEditingController controller, {String? hint}) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _dec(label, hint: hint),
    );
  }

  Widget _intField(String label, TextEditingController controller, {String? hint}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: _dec(label, hint: hint),
    );
  }

  Widget _pricingCard({
    required String title,
    required String subtitle,
    required TextEditingController base,
    required TextEditingController km,
    required TextEditingController min,
    required TextEditingController minFare,
    required VoidCallback onSave,
  }) {
    return _card(
      title: title,
      subtitle: subtitle,
      child: Column(
        children: [
          _numField('الحد الأدنى للرحلة (Min Fare)', minFare, hint: 'مثال: 20'),
          const SizedBox(height: 10),
          _numField('سعر البداية (Base Fare)', base, hint: 'مثال: 15'),
          const SizedBox(height: 10),
          _numField('سعر لكل كم (Per Km)', km, hint: 'مثال: 6'),
          const SizedBox(height: 10),
          _numField('سعر لكل دقيقة (Per Min)', min, hint: 'مثال: 1.2'),
          const SizedBox(height: 12),
          _saveRow(onSave: onSave),
        ],
      ),
    );
  }

  Widget _dangerSwitch({required String title, required ValueNotifier<bool> notifier}) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (_, v, __) => SwitchListTile(
        value: v,
        onChanged: (x) async {
          if (x == true) {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('تأكيد', textDirection: TextDirection.rtl),
                content: const Text(
                  'تفعيل هذا الخيار قد يعطل استخدام التطبيق للمستخدمين. هل أنت متأكد؟',
                  textDirection: TextDirection.rtl,
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('نعم')),
                ],
              ),
            );
            if (ok != true) return;
          }
          notifier.value = x;
        },
        title: Text(title, style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}
