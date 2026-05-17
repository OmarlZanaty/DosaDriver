import 'package:flutter/material.dart';

class AppStrings {
  static bool _isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  // Auth
  static String welcomeClient(BuildContext context) =>
      _isArabic(context) ? 'مرحباً بك' : 'Welcome';
  static String signIn(BuildContext context) =>
      _isArabic(context) ? 'تسجيل الدخول' : 'Sign In';
  static String signUp(BuildContext context) =>
      _isArabic(context) ? 'إنشاء حساب' : 'Sign Up';
  static String email(BuildContext context) =>
      _isArabic(context) ? 'البريد الإلكتروني' : 'Email';
  static String password(BuildContext context) =>
      _isArabic(context) ? 'كلمة المرور' : 'Password';
  static String confirmPassword(BuildContext context) =>
      _isArabic(context) ? 'تأكيد كلمة المرور' : 'Confirm Password';
  static String fullName(BuildContext context) =>
      _isArabic(context) ? 'الاسم الكامل' : 'Full Name';
  static String phone(BuildContext context) =>
      _isArabic(context) ? 'رقم الهاتف' : 'Phone Number';
  static String noAccount(BuildContext context) =>
      _isArabic(context) ? 'ليس لديك حساب؟' : "Don't have an account?";
  static String haveAccount(BuildContext context) =>
      _isArabic(context) ? 'لديك حساب بالفعل؟' : 'Already have an account?';

  // Home
  static String whereToGo(BuildContext context) =>
      _isArabic(context) ? 'إلى أين تريد الذهاب؟' : 'Where do you want to go?';
  static String searchDestination(BuildContext context) =>
      _isArabic(context) ? 'ابحث عن وجهتك...' : 'Search destination...';
  static String bookRide(BuildContext context) =>
      _isArabic(context) ? 'احجز رحلة' : 'Book Ride';
  static String myRides(BuildContext context) =>
      _isArabic(context) ? 'رحلاتي' : 'My Rides';
  static String profile(BuildContext context) =>
      _isArabic(context) ? 'الملف الشخصي' : 'Profile';

  // Ride Booking
  static String pickup(BuildContext context) =>
      _isArabic(context) ? 'نقطة الانطلاق' : 'Pickup';
  static String destination(BuildContext context) =>
      _isArabic(context) ? 'الوجهة' : 'Destination';
  static String rideType(BuildContext context) =>
      _isArabic(context) ? 'نوع الرحلة' : 'Ride Type';
  static String estimatedFare(BuildContext context) =>
      _isArabic(context) ? 'السعر التقديري' : 'Estimated Fare';
  static String confirmBooking(BuildContext context) =>
      _isArabic(context) ? 'تأكيد الحجز' : 'Confirm Booking';
  static String searchingCaptain(BuildContext context) =>
      _isArabic(context) ? 'جارٍ البحث عن كابتن...' : 'Searching for captain...';
  static String captainFound(BuildContext context) =>
      _isArabic(context) ? 'تم العثور على كابتن!' : 'Captain Found!';
  static String captainOnWay(BuildContext context) =>
      _isArabic(context) ? 'الكابتن في الطريق إليك' : 'Captain is on the way';
  static String captainArrived(BuildContext context) =>
      _isArabic(context) ? 'الكابتن وصل إلى موقعك' : 'Captain has arrived';
  static String tripInProgress(BuildContext context) =>
      _isArabic(context) ? 'الرحلة جارية' : 'Trip in progress';
  static String tripCompleted(BuildContext context) =>
      _isArabic(context) ? 'اكتملت الرحلة' : 'Trip Completed';
  static String cancelRide(BuildContext context) =>
      _isArabic(context) ? 'إلغاء الرحلة' : 'Cancel Ride';
  static String cancelRideConfirm(BuildContext context) =>
      _isArabic(context) ? 'هل أنت متأكد من إلغاء الرحلة؟' : 'Are you sure you want to cancel?';
  static String yes(BuildContext context) =>
      _isArabic(context) ? 'نعم' : 'Yes';
  static String no(BuildContext context) =>
      _isArabic(context) ? 'لا' : 'No';

  // Ride Types
  static String fairValue(BuildContext context) =>
      _isArabic(context) ? 'قيمة عادلة' : 'Fair Value';
  static String premium(BuildContext context) =>
      _isArabic(context) ? 'بريميوم' : 'Premium';
  static String economic(BuildContext context) =>
      _isArabic(context) ? 'اقتصادي' : 'Economic';
  static String scooter(BuildContext context) =>
      _isArabic(context) ? 'سكوتر' : 'Scooter';

  // Status
  static String gettingLocation(BuildContext context) =>
      _isArabic(context) ? 'جارٍ تحديد موقعك...' : 'Getting your location...';
  static String useCurrentLocation(BuildContext context) =>
      _isArabic(context) ? 'استخدام موقعي الحالي' : 'Use current location';

  // Trips
  static String myTrips(BuildContext context) =>
      _isArabic(context) ? 'رحلاتي' : 'My Trips';
  static String noTrips(BuildContext context) =>
      _isArabic(context) ? 'لا توجد رحلات بعد' : 'No trips yet';
  static String tripHistory(BuildContext context) =>
      _isArabic(context) ? 'سجل الرحلات' : 'Trip History';

  // Profile
  static String editProfile(BuildContext context) =>
      _isArabic(context) ? 'تعديل الملف الشخصي' : 'Edit Profile';
  static String logout(BuildContext context) =>
      _isArabic(context) ? 'تسجيل الخروج' : 'Logout';
  static String language(BuildContext context) =>
      _isArabic(context) ? 'اللغة' : 'Language';
  static String about(BuildContext context) =>
      _isArabic(context) ? 'عن التطبيق' : 'About';

  // Common
  static String loading(BuildContext context) =>
      _isArabic(context) ? 'جارٍ التحميل...' : 'Loading...';
  static String error(BuildContext context) =>
      _isArabic(context) ? 'حدث خطأ' : 'An error occurred';
  static String retry(BuildContext context) =>
      _isArabic(context) ? 'إعادة المحاولة' : 'Retry';
  static String ok(BuildContext context) =>
      _isArabic(context) ? 'حسناً' : 'OK';
  static String backToHome(BuildContext context) =>
      _isArabic(context) ? 'العودة للرئيسية' : 'Back to Home';
  static String egp(BuildContext context) =>
      _isArabic(context) ? 'جنيه' : 'EGP';
  static String km(BuildContext context) =>
      _isArabic(context) ? 'كم' : 'km';
  static String min(BuildContext context) =>
      _isArabic(context) ? 'دقيقة' : 'min';
  static String rateYourTrip(BuildContext context) =>
      _isArabic(context) ? 'قيّم رحلتك' : 'Rate Your Trip';
  static String howWasYourRide(BuildContext context) =>
      _isArabic(context) ? 'كيف كانت رحلتك؟' : 'How was your ride?';
  static String submitRating(BuildContext context) =>
      _isArabic(context) ? 'إرسال التقييم' : 'Submit Rating';
}
