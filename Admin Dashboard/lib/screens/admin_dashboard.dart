import 'package:flutter/material.dart';

import 'overview_screen.dart';
import 'rides_screen.dart';
import 'drivers_screen.dart';
import 'approvals_screen.dart';
import 'support_screen.dart';
import 'finance_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import '../core/session_store.dart';
import '../core/perm_keys.dart';
import '../features/dashboard_users/dashboard_users_screen.dart';
import 'admin_login_screen.dart';
import '../core/session_store.dart';
import '../features/agencies/agencies_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _index = 0;
  bool _railExpanded = true;

  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionStore.current;
    final canManageAdmins =
        session?.role == 'SUPER_ADMIN';

    debugPrint('ADMIN ROLE = ${SessionStore.current?.role} | perms = ${SessionStore.current?.permissions}');

    final pages = <Widget>[
      OverviewScreen(search: _search.text),
      RidesScreen(search: _search.text),
      DriversScreen(
        search: _search.text,
        adminRole: SessionStore.current?.role ?? "SUPER_ADMIN",
      ),      ApprovalsScreen(search: _search.text),
      SupportScreen(search: _search.text),
      FinanceScreen(search: _search.text),
      NotificationsScreen(search: _search.text),
      SettingsScreen(search: _search.text),
      if (canManageAdmins)
        const DashboardUsersScreen(),
      AgenciesScreen(search: _search.text),
    ];

    final titles = <String>[
      'نظرة عامة',
      'الرحلات',
      'السائقون',
      'طلبات الاعتماد',
      'الدعم الفني',
      'الإدارة المالية',
      'الإشعارات',
      'الإعدادات',
      if (canManageAdmins)
        'مديرو لوحة التحكم',
      'الوكلاء',
    ];



    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Row(
        children: [
          // SIDEBAR
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _railExpanded ? 260 : 88,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF111827), Color(0xFF1F2937)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      if (_railExpanded)
                        const Expanded(
                          child: Text(
                            'لوحة تحكم دوسا درايفر',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      IconButton(
                        onPressed: () => setState(() => _railExpanded = !_railExpanded),
                        icon: Icon(
                          _railExpanded ? Icons.close : Icons.menu,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 24),

                /// 🔹 Navigation
                Expanded(
                  child: NavigationRail(
                    backgroundColor: Colors.transparent,
                    extended: _railExpanded,
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    selectedIconTheme: const IconThemeData(color: Colors.white),
                    unselectedIconTheme: const IconThemeData(color: Color(0xFF9CA3AF)),
                    selectedLabelTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w600,
                    ),
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: Text('نظرة عامة'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.local_taxi_outlined),
                        selectedIcon: Icon(Icons.local_taxi),
                        label: Text('الرحلات'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.groups_outlined),
                        selectedIcon: Icon(Icons.groups),
                        label: Text('السائقون'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.verified_user_outlined),
                        selectedIcon: Icon(Icons.verified_user),
                        label: Text('طلبات الكابتن'),

                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.support_agent_outlined),
                        selectedIcon: Icon(Icons.support_agent),
                        label: Text('الدعم الفني'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: Icon(Icons.account_balance_wallet),
                        label: Text('الإدارة المالية'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.notifications_outlined),
                        selectedIcon: Icon(Icons.notifications),
                        label: Text('الإشعارات'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('الإعدادات'),
                      ),

                      if (canManageAdmins)
                        const NavigationRailDestination(
                          icon: Icon(Icons.admin_panel_settings_outlined),
                          selectedIcon: Icon(Icons.admin_panel_settings),
                          label: Text('مديرو اللوحة'),
                        ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.business_outlined),
                        selectedIcon: Icon(Icons.business),
                        label: Text('الوكلاء'),
                      ),
                    ],
                  ),
                ),

                /// 🔻 LOGOUT BUTTON
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: _railExpanded
                        ? const Text('تسجيل الخروج')
                        : const SizedBox(),
                    onPressed: () {
                      SessionStore.clear(); // 🔐 clear session
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const AdminLoginScreen(),
                        ),
                            (route) => false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // MAIN AREA
          Expanded(
            child: Column(
              children: [
                // HEADER
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        titles[_index],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Row(
                        children: const [
                          SizedBox(
                            width: 8,
                            height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'مباشر',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            suffixIcon: const Icon(Icons.search),
                            hintText: 'بحث...',
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('الإشعارات'),
                              content: const Text('لا توجد إشعارات جديدة حالياً.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('حسناً'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: Stack(
                          children: const [
                            Icon(Icons.notifications_none, size: 28),
                            Positioned(
                              right: 1,
                              top: 2,
                              child: CircleAvatar(radius: 5, backgroundColor: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // CONTENT
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: pages[_index],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
