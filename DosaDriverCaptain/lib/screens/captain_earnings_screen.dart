import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/backend_api.dart';
import '../services/captain_ride_api.dart';
import '../widgets/captain_drawer.dart';

/// ملخص الأرباح — Full Arabic RTL earnings screen.
/// No bottom navigation bar; navigation is via the side drawer.
class CaptainEarningsScreen extends StatefulWidget {
  const CaptainEarningsScreen({super.key});

  @override
  State<CaptainEarningsScreen> createState() => _CaptainEarningsScreenState();
}

class _CaptainEarningsScreenState extends State<CaptainEarningsScreen>
    with SingleTickerProviderStateMixin {
  final _api = CaptainRideApi(BackendApi());
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TabController _tabCtrl;

  // ── Earnings summary ──────────────────────────────────────────────
  double _balance      = 0;
  double _pending      = 0;
  double _totalGross   = 0;
  double _weeklyTotal  = 0;
  int    _totalTrips   = 0;
  String _timeOnline   = '0 ساعة';
  List<double> _dailyEarnings = List.filled(7, 0.0);
  final List<String> _dayLabels = ['أحد', 'إثن', 'ثلا', 'أرب', 'خام', 'جمع', 'سبت'];

  // ── Payment history ───────────────────────────────────────────────
  List<Map<String, dynamic>> _history = [];
  bool _historyLoading = false;
  bool _hasMoreHistory = true;
  int  _historyPage = 1;

  // ── Loading / error ──────────────────────────────────────────────
  bool   _summaryLoading = true;
  String? _summaryError;

  // ── Withdraw ─────────────────────────────────────────────────────
  bool _withdrawRequesting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadSummary();
    _loadHistory();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────

  Future<void> _loadSummary() async {
    setState(() { _summaryLoading = true; _summaryError = null; });
    try {
      final res = await _api.getEarnings();
      _balance     = (res['availableBalance']  as num?)?.toDouble() ?? 0;
      _pending     = (res['pendingPayout']     as num?)?.toDouble() ?? 0;
      _totalGross  = (res['totalGross']        as num?)?.toDouble() ?? 0;
      _weeklyTotal = (res['weeklyEarnings']    as num?)?.toDouble() ?? 0;
      _totalTrips  = (res['totalTrips']        as num?)?.toInt()    ?? 0;
      final daily  = (res['dailyEarnings']     as List?) ?? [];
      _dailyEarnings = List.generate(7, (i) =>
          i < daily.length ? (daily[i] as num).toDouble() : 0.0);
    } catch (e) {
      _summaryError = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) setState(() => _summaryLoading = false);
    }
  }

  Future<void> _loadHistory({bool reset = false}) async {
    if (_historyLoading) return;
    if (!_hasMoreHistory && !reset) return;
    if (reset) {
      _history = []; _historyPage = 1; _hasMoreHistory = true;
    }
    setState(() => _historyLoading = true);
    try {
      final res  = await _api.getHistory(page: _historyPage, limit: 20);
      final list = (res['rides'] as List?) ?? [];
      final mapped = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _history.addAll(mapped);
        _historyPage++;
        _hasMoreHistory = mapped.length == 20;
      });
    } catch (_) {}
    finally { if (mounted) setState(() => _historyLoading = false); }
  }

  String _fmt(double v) => v.toStringAsFixed(2);
  String _fmt0(double v) => v.toStringAsFixed(0);

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  // ── Withdraw ─────────────────────────────────────────────────────
  Future<void> _requestWithdraw() async {
    setState(() => _withdrawRequesting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _withdrawRequesting = false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('طلب السحب'),
        content: const Text(
            'سيتم التواصل معك خلال 24 ساعة لإتمام عملية السحب.\n\nللاستفسار: support@dosadriver.com'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('حسناً', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const CaptainDrawer(),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _summaryLoading
                ? _buildSkeletons()
                : _summaryError != null
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF8C1D18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8, right: 8, bottom: 0,
      ),
      child: Column(
        children: [
          // Title row
          Row(children: [
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const Expanded(
              child: Text('الأرباح',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: () { _loadSummary(); _loadHistory(reset: true); },
            ),
          ]),
          // Balance card
          if (!_summaryLoading && _summaryError == null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12)],
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('الرصيد المتاح', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('${_fmt(_balance)} ج',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary)),
                    if (_pending > 0)
                      Text('قيد المراجعة: ${_fmt(_pending)} ج',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
                  ]),
                ),
                ElevatedButton.icon(
                  onPressed: _withdrawRequesting ? null : _requestWithdraw,
                  icon: _withdrawRequesting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.arrow_upward, size: 16),
                  label: const Text('سحب'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ]),
            ),
          // Tabs
          TabBar(
            controller: _tabCtrl,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'اليوم'),
              Tab(text: 'الأسبوع'),
              Tab(text: 'السجل'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Main content ─────────────────────────────────────────────────
  Widget _buildContent() {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildTodayTab(),
        _buildWeekTab(),
        _buildHistoryTab(),
      ],
    );
  }

  // ── ملخص اليوم ──────────────────────────────────────────────────
  Widget _buildTodayTab() {
    final today = _dailyEarnings.isNotEmpty ? _dailyEarnings.last : 0.0;
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Today's earning hero
          _EarningsHeroCard(amount: today, label: 'إجمالي أرباح اليوم'),
          const SizedBox(height: 14),
          // Stats row
          Row(children: [
            Expanded(child: _StatCard(icon: Icons.directions_car_outlined, label: 'إجمالي الرحلات', value: '$_totalTrips')),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(icon: Icons.payments_outlined,       label: 'إجمالي الإيرادات', value: '${_fmt0(_totalGross)} ج')),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(icon: Icons.remove_circle_outline,   label: 'خصومات الشركة', value: '${_fmt0(_pending)} ج', valueColor: Colors.red)),
          ]),
          const SizedBox(height: 14),
          // Breakdown card
          _SectionCard(
            title: 'تفاصيل الأرباح',
            child: Column(children: [
              _BreakdownRow(label: 'إجمالي الإيرادات الخام', value: '${_fmt(_totalGross)} ج'),
              _BreakdownRow(label: 'خصومات الشركة',           value: '- ${_fmt(_pending)} ج', valueColor: Colors.red),
              const Divider(height: 16),
              _BreakdownRow(label: 'الرصيد الصافي المتاح',    value: '${_fmt(_balance)} ج',   valueColor: Colors.green, bold: true),
            ]),
          ),
        ],
      ),
    );
  }

  // ── ملخص الأسبوع ────────────────────────────────────────────────
  Widget _buildWeekTab() {
    final maxVal = _dailyEarnings.fold<double>(0, math.max);
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EarningsHeroCard(amount: _weeklyTotal, label: 'إجمالي أرباح الأسبوع'),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'الأرباح اليومية',
            child: Column(children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (i) {
                    final v   = _dailyEarnings[i];
                    final pct = maxVal == 0 ? 0.0 : (v / maxVal);
                    final isToday = i == 6;
                    return _DayBar(
                      label: _dayLabels[i],
                      value: v,
                      pct: pct,
                      isToday: isToday,
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
            ]),
          ),
          const SizedBox(height: 14),
          // Day-by-day list
          _SectionCard(
            title: 'التفاصيل اليومية',
            child: Column(
              children: List.generate(7, (i) {
                final v = _dailyEarnings[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: i == 6 ? AppColors.primary.withOpacity(0.12) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text(_dayLabels[i],
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: i == 6 ? AppColors.primary : Colors.black54))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(i == 6 ? 'اليوم' : 'يوم ${i + 1}',
                        style: const TextStyle(fontSize: 13))),
                    Text('${_fmt0(v)} ج',
                        style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14,
                          color: v > 0 ? AppColors.earnings : Colors.grey,
                        )),
                  ]),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── سجل المدفوعات ────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    if (_history.isEmpty && _historyLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_history.isEmpty && !_historyLoading) {
      return RefreshIndicator(
        onRefresh: () => _loadHistory(reset: true),
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Center(child: Text('لا توجد رحلات مكتملة بعد', style: TextStyle(color: Colors.grey, fontSize: 15))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadHistory(reset: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length + (_hasMoreHistory ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          if (i == _history.length) {
            // Load more trigger
            if (!_historyLoading) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
            );
          }
          final ride = _history[i];
          return _RideHistoryCard(ride: ride, fmtDate: _formatDate);
        },
      ),
    );
  }

  // ── Skeletons ─────────────────────────────────────────────────────
  Widget _buildSkeletons() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(4, (_) => const _SkeletonCard()),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(_summaryError!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSummary,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _EarningsHeroCard extends StatelessWidget {
  final double amount;
  final String label;
  const _EarningsHeroCard({required this.amount, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 6),
        Text('${amount.toStringAsFixed(2)} ج',
            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.earnings)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _StatCard({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.primary.withOpacity(0.7), size: 22),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor ?? AppColors.darkGray)),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.darkGray)),
        ),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _BreakdownRow({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: bold ? AppColors.darkGray : Colors.grey)),
      Text(value, style: TextStyle(
          fontSize: 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: valueColor ?? AppColors.darkGray)),
    ]),
  );
}

class _DayBar extends StatelessWidget {
  final String label;
  final double value;
  final double pct;
  final bool isToday;
  const _DayBar({required this.label, required this.value, required this.pct, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        if (value > 0)
          Text('${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
        const SizedBox(height: 2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          height: math.max(pct * 120, 4),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: isToday ? AppColors.primary : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: isToday ? AppColors.primary : Colors.grey)),
      ]),
    );
  }
}

class _RideHistoryCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final String Function(String?) fmtDate;
  const _RideHistoryCard({required this.ride, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final status     = (ride['status'] ?? '').toString().toLowerCase();
    final isOk       = status == 'completed';
    final fare       = (ride['finalFare'] ?? ride['suggestedFare'] ?? ride['price'] ?? 0) as num;
    final pickup     = (ride['pickupAddr'] ?? ride['pickup']?['addr'] ?? '---').toString();
    final drop       = (ride['dropAddr']   ?? ride['drop']?['addr']   ?? '---').toString();
    final date       = fmtDate(ride['updatedAt']?.toString() ?? ride['createdAt']?.toString());
    final payMethod  = (ride['paymentMethod'] ?? 'CASH').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isOk ? Icons.check_circle : Icons.cancel,
              color: isOk ? AppColors.success : AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(isOk ? 'مكتملة' : 'ملغية',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                  color: isOk ? AppColors.success : AppColors.error))),
          Text('${fare.toStringAsFixed(2)} ج',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.earnings)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.circle, size: 9, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(pickup, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.location_on, size: 12, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(drop, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.access_time, size: 12, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Expanded(child: Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_payLabel(payMethod),
                style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }

  String _payLabel(String m) {
    switch (m.toUpperCase()) {
      case 'INSTAPAY': return 'InstaPay';
      case 'VODAFONE_CASH': return 'Vodafone Cash';
      default: return 'كاش';
    }
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 14, width: 120, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 10),
          Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 6),
          Container(height: 12, width: 180, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4))),
        ]),
      ),
    );
  }
}
