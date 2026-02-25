import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? kpssType;
  final DateTime createdAt;
  final DateTime? lastLogin;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.kpssType,
    required this.createdAt,
    this.lastLogin,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      uid: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      kpssType: map['kpssType'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastLogin: map['lastLogin'] != null
          ? (map['lastLogin'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'kpssType': kpssType,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    };
  }
}
