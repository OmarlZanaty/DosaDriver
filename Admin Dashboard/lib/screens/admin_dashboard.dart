import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/lang_controller.dart';
import '../core/session_store.dart';
import '../ui/tokens/app_colors.dart';
import 'admin_login_screen.dart';
import 'overview_screen.dart';
import 'rides_screen.dart';
import 'drivers_screen.dart';
import 'approvals_screen.dart';
import 'support_screen.dart';
import 'finance_screen.dart';
import 'settings_screen.dart';
import 'clients_screen.dart';
import 'notifications_screen.dart';
import 'pricing_screen.dart';
import 'reports_screen.dart';
import 'captain_intelligence_screen.dart';
import '../features/dashboard_users/dashboard_users_screen.dart';
import '../features/agencies/agencies_screen.dart';

// ── Navigation item model ─────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String labelKey;
  final String? permKey; // null = always visible

  const _NavItem(this.icon, this.labelKey, [this.permKey]);
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _index = 0;
  bool _sidebarExpanded = true;
  final TextEditingController _search = TextEditingController();
  final ScrollController _sidebarScroll = ScrollController();

  @override
  void dispose() {
    _search.dispose();
    _sidebarScroll.dispose();
    super.dispose();
  }

  bool get _isSuperAdmin =>
      (SessionStore.current?.role ?? '').trim().toUpperCase() == 'SUPER_ADMIN';

  // All nav sections — order matches _buildPages()
  List<_NavItem> get _navItems => [
    const _NavItem(Icons.dashboard_outlined, 'overview'),
    const _NavItem(Icons.local_taxi_outlined, 'rides'),
    const _NavItem(Icons.people_outline, 'clients'),
    const _NavItem(Icons.directions_car_outlined, 'captains'),
    const _NavItem(Icons.verified_user_outlined, 'approvals'),
    const _NavItem(Icons.account_balance_wallet_outlined, 'finance'),
    const _NavItem(Icons.price_change_outlined, 'pricing'),
    const _NavItem(Icons.notifications_outlined, 'notifications'),
    const _NavItem(Icons.bar_chart_outlined, 'reports'),
    const _NavItem(Icons.analytics_outlined, 'captain_intel'),
    const _NavItem(Icons.support_agent_outlined, 'support'),
    const _NavItem(Icons.settings_outlined, 'settings'),
    if (_isSuperAdmin)
      const _NavItem(Icons.admin_panel_settings_outlined, 'admins'),
    const _NavItem(Icons.business_outlined, 'agencies'),
  ];

  List<Widget> get _pages {
    final search = _search.text;
    return [
      OverviewScreen(search: search),
      RidesScreen(search: search),
      ClientsScreen(search: search),
      DriversScreen(
          search: search,
          adminRole: SessionStore.current?.role ?? 'SUPER_ADMIN'),
      ApprovalsScreen(search: search),
      FinanceScreen(search: search),
      const PricingScreen(),
      const NotificationsScreen(),
      const ReportsScreen(),
      const CaptainIntelligenceScreen(),
      SupportScreen(search: search),
      SettingsScreen(search: search),
      if (_isSuperAdmin) const DashboardUsersScreen(),
      AgenciesScreen(search: search),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LangController.instance,
      builder: (_, __) {
        final lang = LangController.instance;
        final pages = _pages;
        final items = _navItems;
        // Clamp index to valid range (in case page count changes with role)
        if (_index >= pages.length) _index = 0;

        return Scaffold(
          backgroundColor: AppColors.bgApp,
          body: Row(
            children: [
              // ── SIDEBAR ──────────────────────────────────────────────────
              _buildSidebar(items, lang),

              // ── MAIN CONTENT ─────────────────────────────────────────────
              Expanded(
                child: Column(
                  children: [
                    _buildHeader(items, lang),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.03),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOut,
                            )),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_index),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: pages[_index],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Sidebar ──────────────────────────────────────────────────────────────
  Widget _buildSidebar(List<_NavItem> items, LangController lang) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      width: _sidebarExpanded ? 248 : 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Logo + collapse toggle
          _buildSidebarHeader(),

          const Divider(height: 1),

          // Navigation items
          Expanded(
            child: Scrollbar(
              controller: _sidebarScroll,
              child: ListView(
                controller: _sidebarScroll,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                children: [
                  // Grouped: Main
                  if (_sidebarExpanded) _sectionLabel(lang.t('overview').toUpperCase()),
                  _navTile(items, 0, lang),
                  _navTile(items, 1, lang),
                  _navTile(items, 2, lang),
                  _navTile(items, 3, lang),
                  _navTile(items, 4, lang),

                  const SizedBox(height: 6),
                  if (_sidebarExpanded) _sectionLabel(lang.isArabic ? 'FINANCIALS' : 'FINANCIALS'),
                  _navTile(items, 5, lang),
                  _navTile(items, 6, lang),
                  _navTile(items, 7, lang),
                  _navTile(items, 8, lang),
                  _navTile(items, 9, lang),

                  const SizedBox(height: 6),
                  if (_sidebarExpanded) _sectionLabel('MANAGEMENT'),
                  _navTile(items, 10, lang),
                  _navTile(items, 11, lang),
                  if (items.length > 12) _navTile(items, 12, lang),
                  if (items.length > 13) _navTile(items, 13, lang),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Admin info + logout
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          // Logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.directions_car,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ),

          if (_sidebarExpanded) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'DosaDriver',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const Spacer(),

          // Collapse toggle
          InkWell(
            onTap: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                _sidebarExpanded
                    ? Icons.keyboard_double_arrow_left_rounded
                    : Icons.keyboard_double_arrow_right_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _navTile(List<_NavItem> items, int i, LangController lang) {
    if (i >= items.length) return const SizedBox.shrink();
    final item = items[i];
    final selected = _index == i;

    return Tooltip(
      message: _sidebarExpanded ? '' : lang.t(item.labelKey),
      preferBelow: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border(
                  left: BorderSide(
                    color: AppColors.primary,
                    width: 3,
                  ),
                )
              : null,
        ),
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: _sidebarExpanded ? 10 : 0,
            vertical: 0,
          ),
          leading: Icon(
            item.icon,
            size: 20,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          title: _sidebarExpanded
              ? Text(
                  lang.t(item.labelKey),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                )
              : null,
          onTap: () => setState(() => _index = i),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    final session = SessionStore.current;
    final role = session?.role ?? 'Admin';
    final lang = LangController.instance;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (_sidebarExpanded) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primarySoft,
                  child: const Icon(Icons.person, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w700, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        role,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: _sidebarExpanded
                  ? Text(lang.t('logout'),
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700))
                  : const SizedBox.shrink(),
              onPressed: () async {
                await SessionStore.clear();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                    (r) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(List<_NavItem> items, LangController lang) {
    final title = _index < items.length
        ? lang.t(items[_index].labelKey)
        : '';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Page title + live dot
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          _LiveDot(),

          const Spacer(),

          // Global search
          SizedBox(
            width: 300,
            height: 40,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.cairo(fontSize: 13),
              decoration: InputDecoration(
                hintText: lang.t('search_hint'),
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.bgApp,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Language toggle
          _LangToggle(),

          const SizedBox(width: 8),

          // Notifications bell
          _NotifBell(
            onTap: () => setState(() => _index = 7), // → Notifications page
          ),

          const SizedBox(width: 8),

          // Admin avatar
          _AdminAvatar(),
        ],
      ),
    );
  }
}

// ── Reusable header widgets ─────────────────────────────────────────────────

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                  AppColors.success,
                  AppColors.success.withValues(alpha: 0.4),
                  _anim.value),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            LangController.instance.t('live'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _LangToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lang = LangController.instance;
    return Tooltip(
      message: lang.isArabic ? 'Switch to English' : 'التبديل للعربية',
      child: InkWell(
        onTap: lang.toggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            lang.isArabic ? 'EN' : 'ع',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotifBell extends StatelessWidget {
  final VoidCallback onTap;
  const _NotifBell({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: LangController.instance.t('notifications'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined,
                  size: 22, color: AppColors.textSecondary),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: SessionStore.current?.role ?? 'Admin',
      child: CircleAvatar(
        radius: 17,
        backgroundColor: AppColors.primarySoft,
        child: const Icon(Icons.person, color: AppColors.primary, size: 18),
      ),
    );
  }
}
