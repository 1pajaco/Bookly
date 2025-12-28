import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

class LibrarianService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if a user email is a librarian and return their library ID
  static Future<String?> getLibrarianLibraryId(String userEmail) async {
    // Find user by email
    final usersSnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .limit(1)
        .get();

    if (usersSnapshot.docs.isNotEmpty) {
      final userData = usersSnapshot.docs.first.data();
      if (userData['role'] == 'librarian') {
        return userData['libraryId'] as String?;
      }
    }
    return null;
  }

  /// Check if user is a librarian (has permissions)
  static Future<bool> isLibrarian(String userEmail) async {
    final libraryId = await getLibrarianLibraryId(userEmail);
    return libraryId != null;
  }

  /// Get the library ID for a librarian by UID
  static Future<String?> getUserLibraryId(String userEmail) async {
    return await getLibrarianLibraryId(userEmail);
  }

  /// Check if user is librarian by UID (more efficient)
  static Future<bool> isLibrarianByUid(String uid) async {
    return await UserService.isLibrarian(uid);
  }

  /// Get library ID by UID (more efficient)
  static Future<String?> getLibraryIdByUid(String uid) async {
    return await UserService.getLibrarianLibraryId(uid);
  }
}
