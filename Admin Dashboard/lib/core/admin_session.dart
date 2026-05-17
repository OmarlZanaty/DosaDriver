class AdminSession {
  final int id;
  final String email;
  final String? name;
  final String role; // SUPER_ADMIN | DASHBOARD_USER
  final bool isActive;
  final Set<String> permissions;

  AdminSession({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    required this.permissions,
  });

  bool has(String key) => role == 'SUPER_ADMIN' || permissions.contains(key);

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    final perms = (json['permissions'] as List? ?? []).map((e) => e.toString()).toSet();
    return AdminSession(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String,
      name: json['name']?.toString(),
      role: json['role'] as String,
      isActive: (json['isActive'] as bool?) ?? true,
      permissions: perms,
    );
  }
}