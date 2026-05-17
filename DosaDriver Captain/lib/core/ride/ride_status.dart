enum RideStatus {
  requested, accepted, arrived, started, completed, canceled, unknown;

  static RideStatus fromString(String? raw) {
    if (raw == null) return unknown;
    switch (raw.trim().toUpperCase()) {
      case 'REQUESTED': return requested;
      case 'ACCEPTED':  return accepted;
      case 'ARRIVED':   return arrived;
      case 'STARTED':   return started;
      case 'COMPLETED': return completed;
      case 'CANCELED':
      case 'CANCELLED': return canceled;
      default:          return unknown;
    }
  }

  bool get isTerminal => this == completed || this == canceled;
  bool get isActive   => !isTerminal && this != unknown;

  String get labelAr {
    switch (this) {
      case requested: return 'بانتظار الكابتن';
      case accepted:  return 'في الطريق إليك';
      case arrived:   return 'الكابتن وصل';
      case started:   return 'الرحلة جارية';
      case completed: return 'اكتملت الرحلة';
      case canceled:  return 'تم الإلغاء';
      default:        return 'غير معروف';
    }
  }
}

enum RideType {
  fairValue, premium, cuteCar, scooter;

  static RideType fromString(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'FAIR_VALUE': return fairValue;
      case 'PREMIUM':    return premium;
      case 'CUTE_CAR':
      case 'ECONOMIC':
      case 'CUTECAR':   return cuteCar;
      case 'SCOOTER':   return scooter;
      default:           return fairValue;
    }
  }

  String get backendValue {
    switch (this) {
      case fairValue: return 'FAIR_VALUE';
      case premium:   return 'PREMIUM';
      case cuteCar:   return 'CUTE_CAR';
      case scooter:   return 'SCOOTER';
    }
  }

  String get labelAr {
    switch (this) {
      case fairValue: return 'قيمة عادلة';
      case premium:   return 'بريميوم';
      case cuteCar:   return 'كيوت كار';
      case scooter:   return 'سكوتر';
    }
  }

  String get emoji {
    switch (this) {
      case fairValue: return '🚖';
      case premium:   return '🏆';
      case cuteCar:   return '🚙';
      case scooter:   return '🛵';
    }
  }
}
