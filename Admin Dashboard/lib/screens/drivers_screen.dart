import 'dart:async';
// dart:html removed — use url_launcher for cross-platform URL opening

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DriversScreen extends StatefulWidget {
  final String search;
  final String adminRole; // SUPER_ADMIN | FINANCE | SUPPORT

  const DriversScreen({
    super.key,
    required this.search,
    required this.adminRole,
  });

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final ScrollController _scroll = ScrollController();

  String _statusFilter = 'all'; // all | pending | approved | rejected
  String _onlineFilter = 'all'; // all | online | offline

  int _limit = 30;
  final int _pageStep = 30;

  // Cache for captains_live to avoid rebuilding streams too aggressively
  final Map<String, StreamSubscription> _liveSubs = {};
  final Map<String, Map<String, dynamic>> _liveCache = {};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        setState(() => _limit += _pageStep);
      }
    });
  }

  @override
  void dispose() {
    for (final s in _liveSubs.values) {
      s.cancel();
    }
    _liveSubs.clear();
    _liveCache.clear();
    _scroll.dispose();
    super.dispose();
  }

  bool get canApprove => widget.adminRole == "SUPER_ADMIN";
  bool get canDocs => widget.adminRole == "SUPER_ADMIN" || widget.adminRole == "SUPPORT";
  bool get canFinance => widget.adminRole == "SUPER_ADMIN" || widget.adminRole == "FINANCE";

  Query<Map<String, dynamic>> _query() {
    return FirebaseFirestore.instance
        .collection('drivers')
        .orderBy('createdAt', descending: true)
        .limit(_limit);
  }

  // ---------------- STATUS (Arabic) + HOT COLORS ----------------
  String _normalizedStatus(Map<String, dynamic> data) {
    if (data['approved'] == true) return 'approved';

    final s = (data['status'] ?? '').toString();
    if (s == 'pending_review' || s == 'pending') return 'pending';
    if (s == 'rejected' || s == 'blocked') return 'rejected';
    return 'pending';
  }

  String _statusAr(String status) {
    switch (status) {
      case 'approved':
        return 'مُعتمد';
      case 'rejected':
        return 'موقوف';
      default:
        return 'قيد المراجعة';
    }
  }

  Color _statusSolid(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF22C55E); // hot green
      case 'rejected':
        return const Color(0xFFFB2C36); // hot red
      default:
        return const Color(0xFFFF7A18); // hot orange
    }
  }

  List<Color> _statusGradient(String status) {
    switch (status) {
      case 'approved':
        return const [Color(0xFF00E5FF), Color(0xFF22C55E)];
      case 'rejected':
        return const [Color(0xFFFF2E93), Color(0xFFFB2C36)];
      default:
        return const [Color(0xFFFFD400), Color(0xFFFF7A18)];
    }
  }

  Future<void> _setCaptainType(String uid, String type) async {
    await FirebaseFirestore.instance.collection('drivers').doc(uid).update({
      "captainType": type,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  String _onlineAr(bool isOnline) => isOnline ? 'أونلاين' : 'أوفلاين';

  // ---------------- FILTERS ----------------
  bool _matchesSearch(Map<String, dynamic> data) {
    final q = widget.search.trim().toLowerCase();
    if (q.isEmpty) return true;

    final name = (data['name'] ?? '').toString().toLowerCase();
    final phone = (data['phone'] ?? '').toString().toLowerCase();
    final carNumber = (data['carNumber'] ?? '').toString().toLowerCase();
    return name.contains(q) || phone.contains(q) || carNumber.contains(q);
  }

  bool _matchesFilters({
    required Map<String, dynamic> driver,
    required bool isOnline,
  }) {
    final status = _normalizedStatus(driver);

    if (_statusFilter != 'all' && status != _statusFilter) return false;
    if (_onlineFilter == 'online' && !isOnline) return false;
    if (_onlineFilter == 'offline' && isOnline) return false;

    return true;
  }

  // ✅ subscribe once, cache result
  void _ensureLiveSubscription(String uid) {
    if (_liveSubs.containsKey(uid)) return;

    final sub = FirebaseFirestore.instance
        .collection('captains_live')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      _liveCache[uid] = (snap.data() ?? <String, dynamic>{});
      if (mounted) setState(() {});
    });

    _liveSubs[uid] = sub;
  }

  // ---------------- UPDATES ----------------
  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم النسخ')),
    );
  }

  Future<void> _updateDriver(String uid, Map<String, dynamic> patch, {String? successMsg}) async {
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).update({
        ...patch,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      if (successMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ فشل التنفيذ: $e')),
      );
    }
  }

  Future<void> _setDocumentsApproved(String uid, bool value) async {
    await _updateDriver(uid, {
      'documentsUploaded': value,
      if (value) 'documentsApprovedAt': FieldValue.serverTimestamp(),
    }, successMsg: value ? '✅ تم اعتماد المستندات' : '✅ تم إلغاء اعتماد المستندات');
  }

  Future<void> _setApproved(String uid, bool value) async {
    await _updateDriver(uid, {
      'approved': value,
      'status': value ? 'approved' : 'pending_review',
      if (value) 'approvedAt': FieldValue.serverTimestamp(),
    }, successMsg: value ? '✅ تم اعتماد السائق' : '✅ تم تحويل السائق لقيد المراجعة');
  }

  // ---------------- URL FIX (important) ----------------
  /// Your failing URL:
  /// https://firebasestorage.googleapis.com/v0/b/dosadriver.firebasestorage.app/o/...
  ///
  /// In many Firebase projects, the real bucket is:
  /// dosadriver.appspot.com
  ///
  /// So we auto-try a fallback:
  /// /b/dosadriver.appspot.com/
  List<String> _urlCandidates(String url) {
    final clean = url.trim();

    // Basic normalize: prevent spaces issues
    final safe = clean.replaceAll(' ', '%20');

    final List<String> out = [safe];

    // Fallback: firebasestorage.app -> appspot.com
    if (safe.contains('/b/dosadriver.firebasestorage.app/')) {
      out.add(
        safe.replaceFirst('/b/dosadriver.firebasestorage.app/', '/b/dosadriver.appspot.com/'),
      );
    }

    // If user stored the full host somewhere weird, keep only once (no duplicates)
    return out.toSet().toList();
  }

  void _openInNewTab(String url) {
    try {
      // html.window.open removed — use url_launcher for cross-platform support
    } catch (_) {}
  }

  // ---------------- DOCUMENTS ----------------
  Map<String, String> _collectDocUrls(Map<String, dynamic> driver) {
    final docsMap = (driver['documents'] is Map<String, dynamic>)
        ? (driver['documents'] as Map<String, dynamic>)
        : <String, dynamic>{};

    final Map<String, String> out = {};

    void add(String key, String label) {
      final v = docsMap[key];
      if (v == null) return;
      final s = v.toString().trim();
      if (s.isEmpty) return;
      out[label] = s;
    }

    // Your keys
    add('profileImage', 'الصورة الشخصية');
    add('nationalIdFront', 'البطاقة (أمام)');
    add('nationalIdBack', 'البطاقة (خلف)');
    add('driverLicense', 'رخصة القيادة');
    add('carLicense', 'رخصة السيارة');
    add('carFront', 'السيارة (أمام)');
    add('carBack', 'السيارة (خلف)');

    return out;
  }

  void _openImageViewer({required String title, required String url}) {
    final candidates = _urlCandidates(url);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 980,
          height: 680,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 10),

              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: const Color(0xFF0B1220),
                    child: InteractiveViewer(
                      minScale: 0.6,
                      maxScale: 6,
                      child: Center(
                        child: _MultiTryNetworkImage(
                          urls: candidates,
                          fit: BoxFit.contain,
                          onOpenBrowser: () => _openInNewTab(candidates.first),
                          onCopy: () => _copy(candidates.first),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _copy(candidates.first),
                    icon: const Icon(Icons.copy),
                    label: const Text('نسخ الرابط'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _openInNewTab(candidates.first),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('فتح في المتصفح'),
                  ),
                  const Spacer(),
                  const Text(
                    'التكبير: عجلة الماوس / لمس',
                    style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _openDocumentsGrid(Map<String, dynamic> driver) {
    final urls = _collectDocUrls(driver);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 1050,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'مستندات السائق',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              if (urls.isEmpty)
                const Expanded(child: Center(child: Text('لا توجد مستندات', style: TextStyle(fontWeight: FontWeight.w900))))
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final cross = w >= 980 ? 4 : (w >= 720 ? 3 : 2);

                      return GridView.builder(
                        itemCount: urls.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.05,
                        ),
                        itemBuilder: (context, i) {
                          final title = urls.keys.elementAt(i);
                          final url = urls.values.elementAt(i).trim();
                          final candidates = _urlCandidates(url);

                          return InkWell(
                            onTap: () => _openImageViewer(title: title, url: url),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x2A000000), blurRadius: 26, offset: Offset(0, 16)),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _MultiTryNetworkImage(
                                        urls: candidates,
                                        fit: BoxFit.cover,
                                        onOpenBrowser: () => _openInNewTab(candidates.first),
                                        onCopy: () => _copy(candidates.first),
                                        compactError: true,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF8FAFC),
                                        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                          const Icon(Icons.open_in_full, size: 18),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- CHIPS ----------------
  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color hot,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? LinearGradient(colors: [hot, hot.withOpacity(.70)]) : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? hot.withOpacity(.35) : const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 12)),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF0B1220),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  int _crossAxisCountSmart(double w) {
    if (w >= 1500) return 5;
    if (w >= 1220) return 4;
    if (w >= 980) return 3;
    if (w >= 700) return 2;
    return 1;
  }

  double _cardAspectRatioSmart(int cross) {
    if (cross == 1) return 0.75;
    if (cross == 2) return 0.72;
    if (cross == 3) return 0.70;
    return 0.68;
  }

  String captainTypeAr(String type) {
    switch (type) {
      case "ECONOMIC":
        return "اقتصادي";
      case "PREMIUM":
        return "مميز";
      case "FAIR_VALUE":
        return "سعر عادل";
      case "SCOOTER":
        return "سكوتر";
      default:
        return "اقتصادي";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _chip(label: 'الكل', selected: _statusFilter == 'all', onTap: () => setState(() => _statusFilter = 'all'), hot: const Color(0xFF0B1220)),
              _chip(label: 'قيد المراجعة', selected: _statusFilter == 'pending', onTap: () => setState(() => _statusFilter = 'pending'), hot: const Color(0xFFFF7A18)),
              _chip(label: 'مُعتمد', selected: _statusFilter == 'approved', onTap: () => setState(() => _statusFilter = 'approved'), hot: const Color(0xFF22C55E)),
              _chip(label: 'موقوف', selected: _statusFilter == 'rejected', onTap: () => setState(() => _statusFilter = 'rejected'), hot: const Color(0xFFFB2C36)),
              const SizedBox(width: 12),
              _chip(label: 'كل الحالات', selected: _onlineFilter == 'all', onTap: () => setState(() => _onlineFilter = 'all'), hot: const Color(0xFF0B1220)),
              _chip(label: 'أونلاين', selected: _onlineFilter == 'online', onTap: () => setState(() => _onlineFilter = 'online'), hot: const Color(0xFF22C55E)),
              _chip(label: 'أوفلاين', selected: _onlineFilter == 'offline', onTap: () => setState(() => _onlineFilter = 'offline'), hot: const Color(0xFF64748B)),
            ],
          ),

          const SizedBox(height: 14),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query().snapshots(),
              builder: (context, snap) {

                if (snap.hasError) {
                  return Center(
                      child: SelectableText(
                          'Firestore Error:\n${snap.error}',
                          textDirection: TextDirection.ltr));
                }

                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                      child: Text(
                        'لا يوجد سائقين حالياً',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ));
                }

                final List<_DriverItem> items = [];

                for (final d in docs) {
                  final driver = d.data();
                  final uid = d.id;

                  _ensureLiveSubscription(uid);

                  final live = _liveCache[uid] ?? const <String, dynamic>{};
                  final isOnline = (live['isOnline'] ?? false) == true;

                  if (!_matchesSearch(driver)) continue;
                  if (!_matchesFilters(driver: driver, isOnline: isOnline)) continue;

                  items.add(_DriverItem(uid: uid, driver: driver, live: live));
                }

                return LayoutBuilder(
                  builder: (context, c) {

                    final cross = _crossAxisCountSmart(c.maxWidth);
                    final ratio = _cardAspectRatioSmart(cross);

                    return GridView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.only(bottom: 28),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: ratio,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {

                        final item = items[index];

                        final uid = item.uid;
                        final driver = item.driver;
                        final live = item.live;

                        final isOnline = (live['isOnline'] ?? false) == true;
                        final captainType = driver['captainType'] ?? 'ECONOMIC';

                        final name = (driver['name'] ?? 'بدون اسم').toString();
                        final phone = (driver['phone'] ?? '').toString();
                        final carType = (driver['carType'] ?? '').toString();
                        final carNumber = (driver['carNumber'] ?? '').toString();
                        final carColor = (driver['carColor'] ?? '').toString();

                        final status = _normalizedStatus(driver);
                        final statusSolid = _statusSolid(status);
                        final grad = _statusGradient(status);

                        final docsUploaded = (driver['documentsUploaded'] ?? false) == true;
                        final approved = (driver['approved'] ?? false) == true;

                        final dueToCompany = driver['dueToCompany'] ?? 0;
                        final earningsTotal = driver['earningsTotal'] ?? 0;

                        final docsMap = (driver['documents'] is Map<String, dynamic>)
                            ? (driver['documents'] as Map<String, dynamic>)
                            : <String, dynamic>{};

                        final photoUrl =
                        (docsMap['profileImage'] ?? driver['photoUrl'])?.toString();

                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [
                                grad[0].withOpacity(.30),
                                grad[1].withOpacity(.12)
                              ],
                            ),
                            border: Border.all(color: Colors.white.withOpacity(.70)),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x2A000000),
                                  blurRadius: 28,
                                  offset: Offset(0, 18)),
                            ],
                          ),

                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Padding(
                              padding: const EdgeInsets.all(14),

                              child: SingleChildScrollView(
                                child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  /// DRIVER HEADER
                                  Row(
                                    children: [

                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.white,
                                        backgroundImage:
                                        (photoUrl != null && photoUrl.trim().isNotEmpty)
                                            ? NetworkImage(photoUrl.trim())
                                            : null,
                                        child: (photoUrl == null || photoUrl.trim().isEmpty)
                                            ? Text(
                                          name.isNotEmpty
                                              ? name.characters.first
                                              : 'س',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w900),
                                        )
                                            : null,
                                      ),

                                      const SizedBox(width: 10),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [

                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0B1220),
                                              ),
                                            ),

                                            const SizedBox(height: 4),

                                            Row(
                                              children: [

                                                Expanded(
                                                  child: Text(
                                                    phone.isEmpty ? '—' : phone,
                                                    maxLines: 1,
                                                    overflow:
                                                    TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Color(0xFF0F172A),
                                                      fontWeight:
                                                      FontWeight.w800,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 6),

                                                InkWell(
                                                  onTap: phone.isEmpty
                                                      ? null
                                                      : () => _copy(phone),
                                                  child: const Icon(Icons.copy,
                                                      size: 18),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  /// ONLINE
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: isOnline
                                              ? const Color(0xFF22C55E)
                                              : const Color(0xFF94A3B8),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_onlineAr(isOnline)),
                                      const Spacer(),
                                      Text(carType.isEmpty ? '—' : carType),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  /// FINANCE
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                            child:
                                            Text('الأرباح: $earningsTotal')),
                                        Expanded(
                                            child:
                                            Text('مديونية: $dueToCompany')),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  /// DOCUMENTS + CAPTAIN TYPE
                                  Column(
                                    children: [

                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _openDocumentsGrid(driver),
                                        icon: const Icon(Icons.folder_open),
                                        label: const Text('عرض المستندات'),
                                      ),

                                      const SizedBox(height: 10),

                                      Row(
                                        children: [

                                          const Text(
                                            "نوع الكابتن:",
                                            style: TextStyle(
                                                fontWeight: FontWeight.w900),
                                          ),

                                          const SizedBox(width: 10),

                                          DropdownButton<String>(
                                            value: captainType,
                                            underline: const SizedBox(),

                                            items: const [

                                              DropdownMenuItem(
                                                  value: "ECONOMIC",
                                                  child: Text("اقتصادي")),

                                              DropdownMenuItem(
                                                  value: "PREMIUM",
                                                  child: Text("مميز")),

                                              DropdownMenuItem(
                                                  value: "FAIR_VALUE",
                                                  child: Text("سعر عادل")),

                                              DropdownMenuItem(
                                                  value: "SCOOTER",
                                                  child: Text("سكوتر")),
                                            ],

                                            onChanged: (value) {
                                              if (value != null) {
                                                _setCaptainType(uid, value);
                                              }
                                            },
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 8),

                                      _ToggleRow(
                                        title: 'الموافقة على المستندات',
                                        value: docsUploaded,
                                        enabled: canDocs,
                                        onChanged: (v) =>
                                            _setDocumentsApproved(uid, v),
                                      ),

                                      const SizedBox(height: 8),

                                      _ToggleRow(
                                        title: 'الموافقة على السائق',
                                        value: approved,
                                        enabled: canApprove,
                                        onChanged: (v) => _setApproved(uid, v),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  Row(
                                    children: [

                                      _MiniAction(
                                          label: 'نسخ UID',
                                          icon: Icons.copy,
                                          onTap: () => _copy(uid)),

                                      const SizedBox(width: 10),

                                      _MiniAction(
                                          label: 'نسخ الهاتف',
                                          icon: Icons.phone,
                                          onTap: phone.isEmpty
                                              ? null
                                              : () => _copy(phone)),

                                      const Spacer(),

                                      if (canFinance)
                                        const _MiniTag(
                                            label: 'المالية',
                                            icon: Icons.paid),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ) );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverItem {
  final String uid;
  final Map<String, dynamic> driver;
  final Map<String, dynamic> live;

  _DriverItem({required this.uid, required this.driver, required this.live});
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 12)),
        ],
      ),
      child: Text(
        'تحميل المزيد…',
        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: enabled ? const Color(0xFF0B1220) : const Color(0xFF94A3B8),
                fontSize: 13,
              ),
            ),
          ),
          Transform.scale(
            scale: 1.05,
            child: Checkbox(
              value: value,
              onChanged: enabled ? (v) => onChanged(v ?? false) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _MiniAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFF1F5F9) : Colors.white.withOpacity(.94),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(color: Color(0x16000000), blurRadius: 18, offset: Offset(0, 12)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: disabled ? const Color(0xFF94A3B8) : const Color(0xFF0B1220)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: disabled ? const Color(0xFF94A3B8) : const Color(0xFF0B1220),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MiniTag({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0B1220), Color(0xFF111827)]),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22000000)),
        boxShadow: const [
          BoxShadow(color: Color(0x24000000), blurRadius: 18, offset: Offset(0, 12)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)),
        ],
      ),
    );
  }
}

/// ✅ Tries multiple URLs (original + fallback appspot)
class _MultiTryNetworkImage extends StatefulWidget {
  final List<String> urls;
  final BoxFit fit;
  final VoidCallback onOpenBrowser;
  final VoidCallback onCopy;
  final bool compactError;

  const _MultiTryNetworkImage({
    required this.urls,
    required this.fit,
    required this.onOpenBrowser,
    required this.onCopy,
    this.compactError = false,
  });

  @override
  State<_MultiTryNetworkImage> createState() => _MultiTryNetworkImageState();
}

class _MultiTryNetworkImageState extends State<_MultiTryNetworkImage> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final url = widget.urls[_i];

    return Image.network(
      url,
      fit: widget.fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
      errorBuilder: (_, __, ___) {
        // try next candidate
        if (_i < widget.urls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _i += 1);
          });
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        // final fail UI
        if (widget.compactError) {
          return Container(
            color: const Color(0xFFF1F5F9),
            child: Center(
              child: Icon(Icons.broken_image, color: Colors.grey.shade700),
            ),
          );
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, color: Colors.white, size: 42),
            const SizedBox(height: 10),
            const Text('فشل تحميل الصورة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: widget.onOpenBrowser,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('فتح في المتصفح'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onCopy,
                  icon: const Icon(Icons.copy),
                  label: const Text('نسخ الرابط'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}