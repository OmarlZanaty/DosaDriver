import 'package:flutter/material.dart';

class AppStrings {

  // ================= HOME =================

  static String welcomeCaptain(BuildContext context) {
    return _isArabic(context) ? 'مرحباً أيها الكابتن' : 'Welcome, Captain';
  }

  static String readyForRides(BuildContext context) {
    return _isArabic(context) ? 'جاهز للرحلات' : 'Ready for rides';
  }

  static String goOnlineToStart(BuildContext context) {
    return _isArabic(context)
        ? 'انتقل إلى متصل لبدء العمل'
        : 'Go online to start';
  }

  // ================= MENU =================

  static String earnings(BuildContext context) {
    return _isArabic(context) ? 'الأرباح' : 'Earnings';
  }

  static String trips(BuildContext context) {
    return _isArabic(context) ? 'الرحلات' : 'Trips';
  }

  // ================= COMMON =================

  static bool _isArabic(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'ar';
  }

  // ================= EARNINGS =================


  static String availableBalance(BuildContext context) {
    return _isArabic(context) ? 'الرصيد المتاح' : 'Available Balance';
  }

  static String withdraw(BuildContext context) {
    return _isArabic(context) ? 'سحب' : 'WITHDRAW';
  }

  static String earningsBreakdown(BuildContext context) {
    return _isArabic(context)
        ? 'تفاصيل الأرباح'
        : 'Earnings Breakdown';
  }

  static String totalGross(BuildContext context) {
    return _isArabic(context)
        ? 'إجمالي الأرباح'
        : 'Total Gross Earnings';
  }

  static String companyCommission(BuildContext context) {
    return _isArabic(context)
        ? 'عمولة الشركة (25٪)'
        : 'Company Commission (25%)';
  }

  // ================= STATS =================

  static String totalTrips(BuildContext context) {
    return _isArabic(context) ? 'إجمالي الرحلات' : 'Total Trips';
  }

  static String timeOnline(BuildContext context) {
    return _isArabic(context) ? 'وقت الاتصال' : 'Time Online';
  }

  static String distance(BuildContext context) {
    return _isArabic(context) ? 'المسافة' : 'Distance';
  }

  // ================= RIDE MAP =================

  static String pickup(BuildContext context) =>
      _isArabic(context) ? 'نقطة الالتقاء' : 'Pickup';

  static String dropOff(BuildContext context) =>
      _isArabic(context) ? 'الوجهة' : 'Drop-off';

  static String you(BuildContext context) =>
      _isArabic(context) ? 'أنت' : 'You';

  static String client(BuildContext context) =>
      _isArabic(context) ? 'العميل' : 'Client';

  static String gettingLocation(BuildContext context) =>
      _isArabic(context) ? 'جارٍ تحديد موقعك...' : 'Getting your location...';

  static String loadingPickupAddress(BuildContext context) =>
      _isArabic(context) ? 'جارٍ تحميل عنوان الالتقاء...' : 'Loading pickup address...';

// ================= STATUS =================

  static String headingToPickup(BuildContext context) =>
      _isArabic(context) ? 'في الطريق إلى موقع الالتقاء' : 'Heading to Pickup';

  static String waitingForClient(BuildContext context) =>
      _isArabic(context) ? 'في انتظار العميل' : 'Waiting for Client';

  static String tripInProgress(BuildContext context) =>
      _isArabic(context) ? 'الرحلة جارية' : 'Trip in Progress';

  static String rideStatus(BuildContext context) =>
      _isArabic(context) ? 'حالة الرحلة' : 'Ride Status';

// ================= SUBTITLES =================

  static String navigateToPickup(BuildContext context) =>
      _isArabic(context) ? 'توجه إلى موقع الالتقاء' : 'Navigate to pickup location';

  static String clientNotified(BuildContext context) =>
      _isArabic(context) ? 'تم إخطار العميل' : 'Client has been notified';

  static String headingToDestination(BuildContext context) =>
      _isArabic(context) ? 'في الطريق إلى الوجهة' : 'Heading to destination';

// ================= ACTIONS =================

  static String arrived(BuildContext context) =>
      _isArabic(context) ? 'وصلت إلى الموقع' : "I've Arrived";

  static String startTrip(BuildContext context) =>
      _isArabic(context) ? 'بدء الرحلة' : 'Start Trip';

  static String completeTrip(BuildContext context) =>
      _isArabic(context) ? 'إنهاء الرحلة' : 'Complete Trip';

  static String cancelRide(BuildContext context) =>
      _isArabic(context) ? 'إلغاء الرحلة' : 'Cancel Ride';

// ================= DIALOG =================

  static String rideCompleted(BuildContext context) =>
      _isArabic(context) ? 'تم إنهاء الرحلة!' : 'Ride Completed!';

  static String rideCancelled(BuildContext context) =>
      _isArabic(context) ? 'تم إلغاء الرحلة' : 'Ride Cancelled';

  static String rideCompletedMsg(BuildContext context) =>
      _isArabic(context)
          ? 'أحسنت! تم إنهاء الرحلة بنجاح.'
          : 'Great job! The ride has been completed successfully.';

  static String rideCancelledMsg(BuildContext context) =>
      _isArabic(context)
          ? 'تم إلغاء هذه الرحلة.'
          : 'This ride has been cancelled.';

  static String backToHome(BuildContext context) =>
      _isArabic(context) ? 'العودة إلى الرئيسية' : 'Back to Home';

// ================= TRIPS =================

  static String myTrips(BuildContext context) {
    return _isArabic(context) ? 'رحلاتي' : 'My Trips';
  }

  static String noTrips(BuildContext context) {
    return _isArabic(context) ? 'لا توجد رحلات بعد' : 'No trips yet';
  }

  static String completed(BuildContext context) {
    return _isArabic(context) ? 'مكتملة' : 'Completed';
  }

  static String cancelled(BuildContext context) {
    return _isArabic(context) ? 'ملغاة' : 'Cancelled';
  }

  static String destination(BuildContext context) {
    return _isArabic(context) ? 'الوجهة' : 'Destination';
  }

  // ================= DOCUMENT UPLOAD =================

  static String uploadDocuments(BuildContext context) =>
      _isArabic(context) ? 'رفع المستندات' : 'Upload Documents';

  static String uploadAllDocuments(BuildContext context) =>
      _isArabic(context)
          ? 'يرجى رفع جميع المستندات'
          : 'Upload all documents';

  static String submitForReview(BuildContext context) =>
      _isArabic(context) ? 'إرسال للمراجعة' : 'Submit for Review';

  static String nationalId(BuildContext context) =>
      _isArabic(context) ? 'الهوية الوطنية' : 'National ID';

  static String driverLicense(BuildContext context) =>
      _isArabic(context) ? 'رخصة القيادة' : 'Driver License';

  static String carLicense(BuildContext context) =>
      _isArabic(context) ? 'رخصة السيارة' : 'Car License';

  static String carImage(BuildContext context) =>
      _isArabic(context) ? 'صورة السيارة' : 'Car Image';

  static String documentsSubmitted(BuildContext context) =>
      _isArabic(context)
          ? 'تم إرسال المستندات للمراجعة'
          : 'Documents submitted for review';

  // ================= AUTH / PHONE LOGIN =================

  static String captainLoginTitle(BuildContext context) =>
      _isArabic(context) ? 'تسجيل دخول الكابتن' : 'Captain Login';

  static String loginWithPhone(BuildContext context) =>
      _isArabic(context) ? 'تسجيل الدخول برقم الهاتف' : 'Login with Phone';

  static String fullName(BuildContext context) =>
      _isArabic(context) ? 'الاسم الكامل' : 'Full Name';

  static String phoneNumber(BuildContext context) =>
      _isArabic(context) ? 'رقم الهاتف' : 'Phone Number';

  static String sendOtp(BuildContext context) =>
      _isArabic(context) ? 'إرسال رمز التحقق' : 'Send OTP';

  static String enterNameAndPhone(BuildContext context) =>
      _isArabic(context)
          ? 'يرجى إدخال الاسم ورقم الهاتف'
          : 'Enter name and phone number';

  // ================= OTP =================

  static String verifyOtp(BuildContext context) =>
      _isArabic(context) ? 'تأكيد رمز التحقق' : 'Verify OTP';

  static String otpSentTo(BuildContext context, String phone) =>
      _isArabic(context)
          ? 'تم إرسال الرمز إلى $phone'
          : 'Code sent to $phone';

  static String enterOtp(BuildContext context) =>
      _isArabic(context) ? 'أدخل رمز التحقق' : 'Enter OTP';

  static String verify(BuildContext context) =>
      _isArabic(context) ? 'تأكيد' : 'Verify';

  static String invalidOtp(BuildContext context) =>
      _isArabic(context) ? 'أدخل رمز تحقق صحيح' : 'Enter valid OTP';


  // ================= AUTH / EMAIL LOGIN =================

  static String email(BuildContext context) =>
      _isArabic(context) ? 'البريد الإلكتروني' : 'Email';

  static String password(BuildContext context) =>
      _isArabic(context) ? 'كلمة المرور' : 'Password';

  static String continueText(BuildContext context) =>
      _isArabic(context) ? 'متابعة' : 'Continue';

  static String allFieldsRequired(BuildContext context) =>
      _isArabic(context)
          ? 'جميع الحقول مطلوبة'
          : 'All fields are required';

// ================= END TRIP =================

  static String tripCompletedTitle(BuildContext context) =>
      _isArabic(context) ? 'تم إنهاء الرحلة' : 'Trip Completed';

  static String tripSummary(BuildContext context) =>
      _isArabic(context) ? 'ملخص الرحلة' : 'Trip Summary';

  static String clientLabel(BuildContext context) =>
      _isArabic(context) ? 'العميل' : 'Client';

  static String pickupLabel(BuildContext context) =>
      _isArabic(context) ? 'نقطة الالتقاء' : 'Pickup';

  static String dropoffLabel(BuildContext context) =>
      _isArabic(context) ? 'الوجهة' : 'Drop-off';

  static String distanceLabel(BuildContext context) =>
      _isArabic(context) ? 'المسافة' : 'Distance';

  static String totalFare(BuildContext context) =>
      _isArabic(context) ? 'إجمالي الأجرة' : 'Total Fare';

  static String clientFeedback(BuildContext context) =>
      _isArabic(context) ? 'تقييم العميل' : 'Client Feedback';

  static String addComment(BuildContext context) =>
      _isArabic(context) ? 'أضف تعليقاً (اختياري)' : 'Add a comment (optional)';



  static String completing(BuildContext context) =>
      _isArabic(context) ? 'جارٍ الإنهاء...' : 'Completing...';

  static String tripCompletedSuccess(BuildContext context) =>
      _isArabic(context)
          ? 'تم إنهاء الرحلة بنجاح'
          : 'Trip completed successfully!';

  // ================= CANCEL RIDE =================

  static String cancelRideTitle(BuildContext context) =>
      _isArabic(context) ? 'إلغاء الرحلة' : 'Cancel Ride';

  static String cancelRideConfirmMessage(BuildContext context) =>
      _isArabic(context)
          ? 'هل أنت متأكد أنك تريد إلغاء هذه الرحلة؟\nلا يمكن التراجع عن هذا الإجراء.'
          : 'Are you sure you want to cancel this ride?\nThis action cannot be undone.';

  static String yesCancel(BuildContext context) =>
      _isArabic(context) ? 'نعم، إلغاء' : 'Yes, Cancel';

  static String no(BuildContext context) =>
      _isArabic(context) ? 'لا' : 'No';


  static const Map<String, Map<String, String>> values = {
    'en': {
      'welcome': 'Welcome, Captain',
      'online': 'You are online',
      'offline': 'You are offline',
      'trips': 'Total Trips',
      'total_trips': 'Total Trips',
      'my_earnings': 'My Earnings',
      'available_balance': 'Available Balance',
      'withdraw': 'Withdraw',
      'weekly_earnings': 'This Week',
      'time_online': 'Time Online',
      'distance': 'Distance',
      'earnings_breakdown': 'Earnings Breakdown',
      'total_gross': 'Total Gross Earnings',
      'commission': 'Company Commission',
      'earnings': 'Earnings',
      'profile': 'Profile',
      'logout': 'Logout',
      'accept': 'ACCEPT',
      'my_trips': 'My Trips',
      'no_trips': 'No trips yet',
    },
    'ar': {
      'welcome': 'مرحباً كابتن',
      'online': 'أنت متصل',
      'offline': 'أنت غير متصل',
      'earnings': 'الأرباح',
      'trips': 'الرحلات',
      'total_trips': 'إجمالي الرحلات',
      'my_earnings': 'أرباحي',
      'available_balance': 'الرصيد المتاح',
      'withdraw': 'سحب',
      'weekly_earnings': 'هذا الأسبوع',
      'time_online': 'وقت العمل',
      'distance': 'المسافة',
      'earnings_breakdown': 'تفاصيل الأرباح',
      'total_gross': 'إجمالي الدخل',
      'commission': 'عمولة الشركة',
      'profile': 'الملف الشخصي',
      'logout': 'تسجيل الخروج',
      'accept': 'قبول',
      'my_trips': 'رحلاتي',
      'no_trips': 'لا توجد رحلات بعد',
    },
  };

  static String t(String key, String lang) {
    return values[lang]?[key] ?? key;
  }
}
