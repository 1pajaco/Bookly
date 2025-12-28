import 'package:cloud_firestore/cloud_firestore.dart';

class LibraryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _librariesCollection = 'libraries';

  /// Returns first library document ID (useful when you have only one)
  static Future<String?> getFirstLibraryId() async {
    final snapshot = await _firestore.collection(_librariesCollection).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  /// Add [count] copies for every book in `books` collection under given library.
  /// Structure: libraries/{libraryId}/books/{bookId}/copies/{copyId}
  static Future<Map<String, int>> addCopiesForAllBooksToLibrary({
    required String libraryId,
    int count = 3,
  }) async {
    final result = {'created': 0, 'skipped': 0};
    final books = await _firestore.collection('books').get();

    for (final book in books.docs) {
      final bookId = book.id;
      final bookData = book.data();
      final title = bookData['title'] ?? 'Unknown';
      final copiesCol = _firestore
          .collection(_librariesCollection)
          .doc(libraryId)
          .collection('books')
          .doc(bookId)
          .collection('copies');

      // Check existing copies
      final existing = await copiesCol.get();
      final existingCount = existing.docs.length;

      if (existingCount >= count) {
        result['skipped'] = (result['skipped'] ?? 0) + 1;
        continue;
      }

      final toCreate = count - existingCount;
      for (int i = 0; i < toCreate; i++) {
        await copiesCol.add({
          'available': true,
          'rentedBy': null,
          'createdAt': FieldValue.serverTimestamp(),
          'bookTitle': title,
        });
        result['created'] = (result['created'] ?? 0) + 1;
      }
    }

    return result;
  }

  /// Add [count] copies for a specific book under a library.
  /// Returns how many copies were created.
  static Future<int> addCopiesForBook({
    required String libraryId,
    required String bookId,
    required String bookTitle,
    int count = 1,
  }) async {
    int created = 0;
    final copiesCol = _firestore
        .collection(_librariesCollection)
        .doc(libraryId)
        .collection('books')
        .doc(bookId)
        .collection('copies');

    for (int i = 0; i < count; i++) {
      await copiesCol.add({
        'available': true,
        'rentedBy': null,
        'createdAt': FieldValue.serverTimestamp(),
        'bookTitle': bookTitle,
      });
      created++;
    }

    // Ensure the book is not marked retired anymore
    await _firestore.collection('books').doc(bookId).set({'retired': false}, SetOptions(merge: true));

    return created;
  }

  /// Get libraries that have an available copy for the given book
  /// Returns list of {libraryId, name, availableCount}
  static Future<List<Map<String, dynamic>>> getLibrariesWithStock(String bookId) async {
    final libraries = await _firestore.collection(_librariesCollection).get();
    final List<Map<String, dynamic>> result = [];

    for (final lib in libraries.docs) {
      final libId = lib.id;
      final name = lib.data()['name'] ?? 'Library';

      final copiesCol = _firestore
          .collection(_librariesCollection)
          .doc(libId)
          .collection('books')
          .doc(bookId)
          .collection('copies');

      final availableSnapshot = await copiesCol.where('available', isEqualTo: true).get();
      final availableCount = availableSnapshot.docs.length;

      if (availableCount > 0) {
        result.add({
          'libraryId': libId,
          'name': name,
          'availableCount': availableCount,
        });
      }
    }

    return result;
  }

  /// Get libraries that hold at least one copy of the book (regardless of availability)
  /// Returns list of {libraryId, name, totalCount, availableCount}
  static Future<List<Map<String, dynamic>>> getLibrariesHoldingBook(String bookId) async {
    final libraries = await _firestore.collection(_librariesCollection).get();
    final List<Map<String, dynamic>> result = [];

    for (final lib in libraries.docs) {
      final libId = lib.id;
      final name = lib.data()['name'] ?? 'Library';

      final copiesCol = _firestore
          .collection(_librariesCollection)
          .doc(libId)
          .collection('books')
          .doc(bookId)
          .collection('copies');

      final allSnapshot = await copiesCol.get();
      final totalCount = allSnapshot.docs.length;

      if (totalCount > 0) {
        int availableCount = 0;
        for (final doc in allSnapshot.docs) {
          final data = doc.data();
          if ((data['available'] as bool?) == true) {
            availableCount++;
          }
        }

        result.add({
          'libraryId': libId,
          'name': name,
          'totalCount': totalCount,
          'availableCount': availableCount,
        });
      }
    }

    return result;
  }

  /// Reserve an available copy (no rental document creation here)
  /// Returns the reserved copyId or null if none available
  static Future<String?> reserveAvailableCopy({
    required String libraryId,
    required String bookId,
    required String userId,
  }) async {
    final copiesCol = _firestore
        .collection(_librariesCollection)
        .doc(libraryId)
        .collection('books')
        .doc(bookId)
        .collection('copies');

    return _firestore.runTransaction((txn) async {
      final available = await copiesCol.where('available', isEqualTo: true).limit(1).get();
      if (available.docs.isEmpty) return null;

      final docRef = available.docs.first.reference;
      txn.update(docRef, {
        'available': false,
        'rentedBy': userId,
        'reservedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    });
  }

  /// Remove up to [count] available copies of a book from a specific library
  /// Returns how many copies were removed. Does not remove rented copies.
  static Future<int> removeAvailableCopies({
    required String libraryId,
    required String bookId,
    int count = 1,
  }) async {
    final stats = await getCopyStats(libraryId: libraryId, bookId: bookId);
    if ((stats['rented'] ?? 0) > 0) {
      throw StateError('Copies are currently rented and cannot be removed');
    }

    final copiesCol = _firestore
        .collection(_librariesCollection)
        .doc(libraryId)
        .collection('books')
        .doc(bookId)
        .collection('copies');

    final availableSnapshot = await copiesCol.where('available', isEqualTo: true).limit(count).get();
    int removed = 0;
    for (final doc in availableSnapshot.docs) {
      await doc.reference.delete();
      removed++;
    }

    // If no copies remain anywhere, mark book as retired
    final anyCopiesLeft = await hasAnyCopies(bookId);
    if (!anyCopiesLeft) {
      await _firestore.collection('books').doc(bookId).set({'retired': true}, SetOptions(merge: true));
    }

    return removed;
  }

  /// Check across all libraries whether any copies exist for a given book.
  static Future<bool> hasAnyCopies(String bookId) async {
    final libraries = await _firestore.collection(_librariesCollection).get();
    for (final lib in libraries.docs) {
      final copiesCol = _firestore
          .collection(_librariesCollection)
          .doc(lib.id)
          .collection('books')
          .doc(bookId)
          .collection('copies');

      final allSnapshot = await copiesCol.limit(1).get();
      if (allSnapshot.docs.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Get copy counts for a specific book within a specific library.
  /// Returns map with {available, rented, total}.
  static Future<Map<String, int>> getCopyStats({
    required String libraryId,
    required String bookId,
  }) async {
    final copiesCol = _firestore
        .collection(_librariesCollection)
        .doc(libraryId)
        .collection('books')
        .doc(bookId)
        .collection('copies');
    final snapshot = await copiesCol.get();
    int available = 0;
    int rented = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if ((data['available'] as bool?) == true) {
        available++;
      } else {
        rented++;
      }
    }
    return {
      'available': available,
      'rented': rented,
      'total': snapshot.docs.length,
    };
  }
}
