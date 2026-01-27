class DbUser {
  final String id; // backend uuid or string id
  final String firebaseUid; // Firebase UID
  final String role; // RIDER / CAPTAIN / ADMIN
  final String? name;
  final String? email;
  final String? phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DbUser({
    required this.id,
    required this.firebaseUid,
    required this.role,
    this.name,
    this.email,
    this.phone,
    this.createdAt,
    this.updatedAt,
  });

  factory DbUser.fromJson(Map<String, dynamic> json) {
    // Backend might use different keys; we support common variants safely.
    final id = (json['id'] ?? json['_id'] ?? '').toString();
    final firebaseUid =
    (json['firebaseUid'] ?? json['firebase_uid'] ?? json['uid'] ?? '').toString();
    final role = (json['role'] ?? 'RIDER').toString();

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      final s = v.toString();
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    return DbUser(
      id: id,
      firebaseUid: firebaseUid,
      role: role,
      name: (json['name'] ?? json['fullName'] ?? json['full_name'])?.toString(),
      email: (json['email'])?.toString(),
      phone: (json['phone'] ?? json['phoneNumber'] ?? json['phone_number'])?.toString(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebaseUid': firebaseUid,
      'role': role,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  DbUser copyWith({
    String? id,
    String? firebaseUid,
    String? role,
    String? name,
    String? email,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DbUser(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
