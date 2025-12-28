import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final DateTime createdAt;
  final String role; // 'user', 'librarian', 'admin'
  final String? libraryId; // For librarians, which library they manage

  UserModel({
    required this.uid,
    required this.email,
    required this.createdAt,
    this.role = 'user',
    this.libraryId,
  });

  /// Convert UserModel to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'role': role,
      'libraryId': libraryId,
    };
  }

  /// Create UserModel from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      role: map['role'] ?? 'user',
      libraryId: map['libraryId'],
    );
  }

  /// Create a copy of UserModel with modified fields
  UserModel copyWith({
    String? uid,
    String? email,
    DateTime? createdAt,
    String? role,
    String? libraryId,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      libraryId: libraryId ?? this.libraryId,
    );
  }
}
