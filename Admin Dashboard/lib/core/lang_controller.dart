import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple AR ↔ EN language toggle.
/// Call [LangController.instance.toggle()] to switch languages.
/// Wrap your MaterialApp with [AnimatedBuilder] and listen to this notifier.
class LangController extends ChangeNotifier {
  LangController._();
  static final LangController instance = LangController._();

  Locale _locale = const Locale('ar');
  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';
  TextDirection get dir => isArabic ? TextDirection.rtl : TextDirection.ltr;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('admin_lang') ?? 'ar';
    _locale = Locale(lang);
    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    if (_locale.languageCode == langCode) return;
    _locale = Locale(langCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_lang', langCode);
    notifyListeners();
  }

  void toggle() {
    setLanguage(isArabic ? 'en' : 'ar');
  }

  /// Translate a key.  Falls back to the key itself if not found.
  String t(String key) => _translations[_locale.languageCode]?[key] ?? key;
}

/// All UI strings — add more as needed.
const Map<String, Map<String, String>> _translations = {
  'ar': {
    // Sidebar
    'overview': 'نظرة عامة',
    'rides': 'الرحلات',
    'clients': 'العملاء',
    'captains': 'الكباتن',
    'approvals': 'طلبات الاعتماد',
    'finance': 'الإدارة المالية',
    'pricing': 'إدارة التسعير',
    'notifications': 'الإشعارات',
    'reports': 'التقارير والتصدير',
    'support': 'الدعم الفني',
    'settings': 'الإعدادات',
    'admins': 'مديرو اللوحة',
    'agencies': 'الوكلاء',
    'captain_intel': 'ذكاء الكباتن',
    'ratings': 'التقييمات والمراجعات',
    'promotions': 'العروض والإحالات',
    'logout': 'تسجيل الخروج',
    // Header
    'search_hint': 'بحث بالاسم أو الهاتف أو رقم الرحلة...',
    'live': 'مباشر',
    // Overview
    'active_rides': 'الرحلات النشطة',
    'online_captains': 'الكباتن المتصلون',
    'today_revenue': 'إيراد اليوم',
    'today_trips': 'رحلات اليوم',
    'today_new_users': 'مستخدمون جدد',
    'today_new_captains': 'كباتن جدد',
    'cancel_rate': 'نسبة الإلغاء',
    'waiting_rides': 'في الانتظار',
    'online_now': 'أونلاين الآن',
    'revenue_chart': 'منحنى الإيرادات',
    'trip_volume': 'حجم الرحلات',
    'today': 'اليوم',
    'this_week': 'هذا الأسبوع',
    'this_month': 'هذا الشهر',
    'this_year': 'هذا العام',
    'completed': 'مكتملة',
    'cancelled': 'ملغاة',
    'requested': 'مطلوبة',
    // States
    'loading': 'جاري التحميل...',
    'error': 'حدث خطأ',
    'retry': 'إعادة المحاولة',
    'empty': 'لا توجد بيانات',
    'save': 'حفظ',
    'cancel': 'إلغاء',
    'confirm': 'تأكيد',
    'delete': 'حذف',
    'edit': 'تعديل',
    'view': 'عرض',
    'send': 'إرسال',
    'export': 'تصدير',
    'filter': 'تصفية',
    'all': 'الكل',
    // Finance
    'total_revenue': 'إجمالي الإيرادات',
    'total_commission': 'إجمالي العمولة',
    'captain_payouts': 'مدفوعات الكباتن',
    // Pricing
    'base_fare': 'الأجرة الأساسية',
    'per_km': 'سعر الكيلومتر',
    'per_min': 'سعر الدقيقة',
    'min_fare': 'الحد الأدنى للأجرة',
    'min_offer': 'أدنى عرض سعر للعميل',
    'max_offer': 'أقصى عرض سعر للعميل',
    'avg_price': 'متوسط السعر المرجعي',
    'commission_pct': 'نسبة العمولة (%)',
    // Clients
    'client_name': 'الاسم',
    'phone': 'الهاتف',
    'email': 'البريد الإلكتروني',
    'joined': 'تاريخ التسجيل',
    'total_trips': 'إجمالي الرحلات',
    'total_spent': 'إجمالي الإنفاق',
    'status': 'الحالة',
    'active': 'نشط',
    'blocked': 'محظور',
    'block': 'حظر',
    'unblock': 'رفع الحظر',
    // Notifications
    'notif_title': 'عنوان الإشعار',
    'notif_body': 'نص الإشعار',
    'target': 'الجمهور المستهدف',
    'all_clients': 'جميع العملاء',
    'all_captains': 'جميع الكباتن',
    'all_users': 'جميع المستخدمين',
    'specific_user': 'مستخدم محدد',
    // Reports
    'revenue_report': 'تقرير الإيرادات',
    'trips_report': 'تقرير الرحلات',
    'captain_performance': 'أداء الكباتن',
    'client_activity': 'نشاط العملاء',
    'cancellation_report': 'تقرير الإلغاء',
    'date_from': 'من تاريخ',
    'date_to': 'إلى تاريخ',
    'download_csv': 'تنزيل CSV',
    'download_excel': 'تنزيل Excel',
  },
  'en': {
    // Sidebar
    'overview': 'Overview',
    'rides': 'Rides',
    'clients': 'Clients',
    'captains': 'Captains',
    'approvals': 'Captain Approvals',
    'finance': 'Finance',
    'pricing': 'Pricing',
    'notifications': 'Notifications',
    'reports': 'Reports',
    'support': 'Support',
    'settings': 'Settings',
    'admins': 'Admin Users',
    'agencies': 'Agencies',
    'captain_intel': 'Captain Intelligence',
    'ratings': 'Ratings & Reviews',
    'promotions': 'Promotions & Referrals',
    'logout': 'Sign Out',
    // Header
    'search_hint': 'Search by name, phone, or ride ID...',
    'live': 'Live',
    // Overview
    'active_rides': 'Active Rides',
    'online_captains': 'Captains Online',
    'today_revenue': "Today's Revenue",
    'today_trips': "Today's Trips",
    'today_new_users': 'New Users Today',
    'today_new_captains': 'New Captains Today',
    'cancel_rate': 'Cancellation Rate',
    'waiting_rides': 'Waiting',
    'online_now': 'Online Now',
    'revenue_chart': 'Revenue Trend',
    'trip_volume': 'Trip Volume',
    'today': 'Today',
    'this_week': 'This Week',
    'this_month': 'This Month',
    'this_year': 'This Year',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    'requested': 'Requested',
    // States
    'loading': 'Loading...',
    'error': 'An error occurred',
    'retry': 'Retry',
    'empty': 'No data found',
    'save': 'Save',
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'delete': 'Delete',
    'edit': 'Edit',
    'view': 'View',
    'send': 'Send',
    'export': 'Export',
    'filter': 'Filter',
    'all': 'All',
    // Finance
    'total_revenue': 'Total Revenue',
    'total_commission': 'Total Commission',
    'captain_payouts': 'Captain Payouts',
    // Pricing
    'base_fare': 'Base Fare',
    'per_km': 'Per KM Rate',
    'per_min': 'Per Minute Rate',
    'min_fare': 'Minimum Fare',
    'min_offer': 'Min Client Offer',
    'max_offer': 'Max Client Offer',
    'avg_price': 'Average Reference Price',
    'commission_pct': 'Commission %',
    // Clients
    'client_name': 'Name',
    'phone': 'Phone',
    'email': 'Email',
    'joined': 'Joined',
    'total_trips': 'Total Trips',
    'total_spent': 'Total Spent',
    'status': 'Status',
    'active': 'Active',
    'blocked': 'Blocked',
    'block': 'Block',
    'unblock': 'Unblock',
    // Notifications
    'notif_title': 'Notification Title',
    'notif_body': 'Notification Body',
    'target': 'Target Audience',
    'all_clients': 'All Clients',
    'all_captains': 'All Captains',
    'all_users': 'All Users',
    'specific_user': 'Specific User',
    // Reports
    'revenue_report': 'Revenue Report',
    'trips_report': 'Trips Report',
    'captain_performance': 'Captain Performance',
    'client_activity': 'Client Activity',
    'cancellation_report': 'Cancellation Report',
    'date_from': 'From Date',
    'date_to': 'To Date',
    'download_csv': 'Download CSV',
    'download_excel': 'Download Excel',
  },
};
