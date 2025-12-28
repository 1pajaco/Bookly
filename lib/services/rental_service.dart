import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rental.dart';
import 'library_service.dart';

class RentalService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'rentals';

  /// Rent a book for the current user
  /// Returns the rental ID if successful
  static Future<String?> rentBook({
    required String userId,
    required String bookId,
    required String bookTitle,
    required String bookCoverUrl,
    int rentalDays = 15,
  }) async {
    try {
      final now = DateTime.now();
      final dueDate = now.add(Duration(days: rentalDays));

      final rental = Rental(
        userId: userId,
        bookId: bookId,
        bookTitle: bookTitle,
        bookCoverUrl: bookCoverUrl,
        rentalDate: now,
        dueDate: dueDate,
        status: 'active',
      );

      final docRef = await _firestore.collection(_collectionName).add(rental.toMap());
      return docRef.id;
    } catch (e) {
      print('Error renting book: $e');
      return null;
    }
  }

  /// Rent a book from a specific library, reserving an available copy.
  /// Returns the rental ID if successful.
  static Future<String?> rentBookFromLibrary({
    required String userId,
    required String bookId,
    required String bookTitle,
    required String bookCoverUrl,
    required String libraryId,
    int rentalDays = 15,
  }) async {
    try {
      // Reserve a copy first (transaction inside LibraryService)
      final copyId = await LibraryService.reserveAvailableCopy(
        libraryId: libraryId,
        bookId: bookId,
        userId: userId,
      );

      if (copyId == null) {
        return null; // No available copy
      }

      final now = DateTime.now();
      final dueDate = now.add(Duration(days: rentalDays));

      final rental = Rental(
        userId: userId,
        bookId: bookId,
        libraryId: libraryId,
        copyId: copyId,
        bookTitle: bookTitle,
        bookCoverUrl: bookCoverUrl,
        rentalDate: now,
        dueDate: dueDate,
        status: 'active',
      );

      final docRef = await _firestore.collection(_collectionName).add(rental.toMap());
      return docRef.id;
    } catch (e) {
      print('Error renting book from library: $e');
      return null;
    }
  }

  /// Get all active rentals for a user
  static Stream<List<Rental>> getUserRentals(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Rental.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get full rental history for a user (active and returned), newest first
  static Stream<List<Rental>> getUserRentalHistory(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('rentalDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Rental.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Fetch rental history once (non-stream), newest first.
  static Future<List<Rental>> fetchUserRentalHistory(String userId, {int limit = 50}) async {
    final snapshot = await _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('rentalDate', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => Rental.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get a single rental by ID
  static Future<Rental?> getRental(String rentalId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(rentalId).get();
      if (doc.exists) {
        return Rental.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting rental: $e');
      return null;
    }
  }

  /// Check if a user has already rented a specific book
  static Future<bool> hasUserRentedBook(String userId, String bookId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .where('bookId', isEqualTo: bookId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking rental: $e');
      return false;
    }
  }

  /// Return a rented book and release the copy. Returns success and late fee (if any).
  static Future<({bool success, double lateFee})> returnBook(String rentalId, {double lateFeePerDay = 2.5}) async {
    try {
      // Get rental details first
      final rentalDoc = await _firestore.collection(_collectionName).doc(rentalId).get();
      if (!rentalDoc.exists) return (success: false, lateFee: 0.0);

      final rental = Rental.fromMap(rentalDoc.data()!, rentalId);

      // Compute late fee
      double lateFee = 0.0;
      final now = DateTime.now();
      if (now.isAfter(rental.dueDate)) {
        final overdueDays = now.difference(rental.dueDate).inDays;
        final chargeableDays = overdueDays > 0 ? overdueDays : 0;
        lateFee = chargeableDays * lateFeePerDay;
      }

      // Release the copy if it exists
      if (rental.libraryId != null && rental.copyId != null) {
        await _firestore
            .collection('libraries')
            .doc(rental.libraryId)
            .collection('books')
            .doc(rental.bookId)
            .collection('copies')
            .doc(rental.copyId)
            .update({
          'available': true,
          'rentedBy': null,
        });
      }

      // Mark rental as returned
      await _firestore.collection(_collectionName).doc(rentalId).update({
        'status': 'returned',
        'returnedDate': Timestamp.now(),
      });

      return (success: true, lateFee: lateFee);
    } catch (e) {
      print('Error returning book: $e');
      return (success: false, lateFee: 0.0);
    }
  }

  /// Get all active rentals for a user with rental IDs. Optionally filter by library.
  static Future<List<Map<String, dynamic>>> getUserActiveRentalsWithIds(
    String userId, {
    String? libraryId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active');

      if (libraryId != null) {
        query = query.where('libraryId', isEqualTo: libraryId);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) {
        final rental = Rental.fromMap(doc.data(), doc.id);
        return {
          'rental': rental,
          'rentalId': doc.id,
        };
      })
          .toList();
    } catch (e) {
      print('Error getting user active rentals: $e');
      return [];
    }
  }

  /// Get all rentals (for admin purposes)
  static Stream<List<Rental>> getAllRentals() {
    return _firestore
        .collection(_collectionName)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Rental.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Clear all rentals and reset all copies to available (admin function)
  static Future<void> clearAllRentals() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      
      // Reset all copies to available first
      for (final doc in snapshot.docs) {
        final rental = Rental.fromMap(doc.data(), doc.id);
        
        // If rental has library and copy info, reset that copy
        if (rental.libraryId != null && rental.copyId != null) {
          try {
            await _firestore
                .collection('libraries')
                .doc(rental.libraryId)
                .collection('books')
                .doc(rental.bookId)
                .collection('copies')
                .doc(rental.copyId)
                .update({
              'available': true,
              'rentedBy': null,
            });
          } catch (e) {
            print('Error resetting copy ${rental.copyId}: $e');
          }
        }
      }
      
      // Delete all rental documents
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      
      print('All rentals cleared and copies reset to available');
    } catch (e) {
      print('Error clearing rentals: $e');
    }
  }
}
