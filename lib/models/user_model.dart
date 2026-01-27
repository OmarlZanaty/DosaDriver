class UserModel {
  final String uid;
  final String name;
  final String role; // 'client' or 'captain'
  final bool online;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.role,
    required this.online,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'role': role,
      'online': online,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'client',
      online: map['online'] ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
