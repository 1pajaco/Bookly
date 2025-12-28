import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'users';

  /// Create a new user document in Firestore
  static Future<void> createUser({
    required String uid,
    required String email,
  }) async {
    try {
      final user = UserModel(
        uid: uid,
        email: email,
        createdAt: DateTime.now(),
        role: 'user', // Default role for all new users
        libraryId: null,
      );

      await _firestore.collection(_collectionName).doc(uid).set(user.toMap());
      print('User document created for $email with role: user');
    } catch (e) {
      print('Error creating user document: $e');
    }
  }

  /// Get a user by UID
  static Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  /// Check if a user is a librarian
  static Future<bool> isLibrarian(String uid) async {
    try {
      final user = await getUser(uid);
      return user?.role == 'librarian';
    } catch (e) {
      print('Error checking librarian status: $e');
      return false;
    }
  }

  /// Get the library ID for a librarian
  static Future<String?> getLibrarianLibraryId(String uid) async {
    try {
      final user = await getUser(uid);
      if (user?.role == 'librarian') {
        return user?.libraryId;
      }
      return null;
    } catch (e) {
      print('Error getting librarian library ID: $e');
      return null;
    }
  }

  /// Update user role (admin function)
  static Future<void> updateUserRole({
    required String uid,
    required String role,
    String? libraryId,
  }) async {
    try {
      await _firestore.collection(_collectionName).doc(uid).update({
        'role': role,
        'libraryId': libraryId,
      });
    } catch (e) {
      print('Error updating user role: $e');
    }
  }

  /// Get all users (admin function)
  static Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  /// Search for users by username/email or UID
  static Future<List<UserModel>> searchUsers(String query) async {
    try {
      if (query.isEmpty) {
        return [];
      }

      final snapshot = await _firestore.collection(_collectionName).get();
      final users = snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();

      // Filter by email or UID (case-insensitive for email)
      final lowerQuery = query.toLowerCase();
      return users
          .where((user) =>
              user.email.toLowerCase().contains(lowerQuery) || 
              user.uid.toLowerCase().contains(lowerQuery))
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }
}
