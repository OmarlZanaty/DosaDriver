class Captain {
  final String uid;
  final String email;
  final bool online;

  Captain({
    required this.uid,
    required this.email,
    required this.online,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'online': online,
    };
  }
}
