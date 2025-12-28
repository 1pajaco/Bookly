import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BookService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool _looksLikeCollection(String? title) {
    if (title == null) return false;
    final lower = title.toLowerCase();

    const bannedPhrases = [
      'box set',
      'boxed set',
      'collection',
      'omnibus',
      'bundle',
      'bind-up',
      'saga set',
      '3-in-1',
      '4-in-1',
      '5-in-1',
    ];

    if (bannedPhrases.any((p) => lower.contains(p))) return true;

    final rangePattern = RegExp(r'\bbooks?\s*\d+\s*[-–—]\s*\d+\b');
    return rangePattern.hasMatch(lower);
  }

  /// Simple Firestore search for books by title substring (client-side filter).
  /// Returns maps that include the document `id`.
  static Future<List<Map<String, dynamic>>> searchBooks(String query, {int maxFetch = 200}) async {
    final snapshot = await _firestore.collection('books').limit(maxFetch).get();
    final q = query.trim().toLowerCase();
    return snapshot.docs
        .map((doc) => {
              ...doc.data(),
              'id': doc.id,
            })
        .where((b) {
          if (b['retired'] == true) return false; // exclude retired
          final title = (b['title'] ?? '').toString().toLowerCase();
          final author = (b['author'] ?? '').toString().toLowerCase();
          return q.isEmpty || title.contains(q) || author.contains(q);
        })
        .toList();
  }

  /// Fetch books from Google Books API and add to Firestore
  /// If [author] is provided, we include an `inauthor:` qualifier to narrow results.
  static Future<Map<String, int>> fetchAndAddBooks(String title, {String? author, int maxResults = 10}) async {
    int added = 0;
    int skipped = 0;
    
    try {
      final qParts = <String>[];
      if (title.trim().isNotEmpty) qParts.add(title.trim());
      if (author != null && author.trim().isNotEmpty) qParts.add('inauthor:${author.trim()}');

      final url = Uri.https(
        'www.googleapis.com',
        '/books/v1/volumes',
        {
          'q': qParts.join(' '),
          'maxResults': maxResults.toString(),
        },
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>?;

        if (items == null || items.isEmpty) {
          print('No books found for query: ${qParts.join(' ')}');
          return {'added': added, 'skipped': skipped};
        }

        for (var item in items) {
          final volumeInfo = item['volumeInfo'];
          final title = volumeInfo['title'] as String?;
          final googleBooksId = item['id'];

          // Skip obvious collections/box-sets.
          if (_looksLikeCollection(title)) {
            print('⏭️  Skipping collection/box set: $title');
            skipped++;
            continue;
          }
          
          // Check if book already exists
          final existingBooks = await _firestore
              .collection('books')
              .where('googleBooksId', isEqualTo: googleBooksId)
              .get();
          
          if (existingBooks.docs.isNotEmpty) {
            print('⏭️  Book already exists: ${volumeInfo['title']}');
            skipped++;
            continue;
          }
          
          final book = {
            'title': volumeInfo['title'] ?? 'Unknown Title',
            'author': (volumeInfo['authors'] as List<dynamic>?)?.first ?? 'Unknown Author',
            'coverUrl': volumeInfo['imageLinks']?['thumbnail'],
            'description': volumeInfo['description'],
            'publishedDate': volumeInfo['publishedDate'],
            'pageCount': volumeInfo['pageCount'],
            'genre': (volumeInfo['categories'] as List<dynamic>?)?.firstOrNull,
            'categories': volumeInfo['categories'],
            'googleBooksId': googleBooksId,
          };

          // Add to Firestore
          try {
            final docRef = await _firestore.collection('books').add(book);
            print('✅ Successfully added book to Firestore: ${book['title']} (ID: ${docRef.id})');
            added++;
          } catch (firestoreError) {
            print('❌ Firestore error adding ${book['title']}: $firestoreError');
            rethrow;
          }
        }

        print('Successfully added $added books, skipped $skipped duplicates');
      } else {
        print('Failed to fetch books: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching books: $e');
    }
    
    return {'added': added, 'skipped': skipped};
  }

  /// Add a single book by searching for title and optional author
  static Future<void> addBookByTitle(String title, {String? author}) async {
    await fetchAndAddBooks(title, author: author, maxResults: 5);
  }

  /// Populate database with popular books
  static Future<Map<String, int>> populateWithPopularBooks() async {
    int totalAdded = 0;
    int totalSkipped = 0;
    
    final popularBooks = [
      {'title': 'Dune', 'author': 'Frank Herbert'},
      {'title': '1984', 'author': 'George Orwell'},
      {'title': 'The Lord of the Rings', 'author': 'J. R. R. Tolkien'},
      {'title': 'Foundation', 'author': 'Isaac Asimov'},
      {'title': 'The Hobbit', 'author': 'J. R. R. Tolkien'},
      {'title': 'Fahrenheit 451', 'author': 'Ray Bradbury'},
      {'title': 'Ruination: A League of Legends Novel', 'author': 'Anthony Reynolds'},
    ];

    for (var book in popularBooks) {
      final result = await fetchAndAddBooks(
        book['title']!,
        author: book['author'],
        maxResults: 1,
      );
      totalAdded += result['added'] ?? 0;
      totalSkipped += result['skipped'] ?? 0;
      // Add small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    return {'added': totalAdded, 'skipped': totalSkipped};
  }

  /// Get a single book by document ID. Returns null if not found.
  static Future<Map<String, dynamic>?> getBook(String bookId) async {
    final doc = await _firestore.collection('books').doc(bookId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return {
      ...data,
      'id': doc.id,
    };
  }

  /// Fetch books for a given genre. Returns raw maps with `id` included.
  static Future<List<Map<String, dynamic>>> getBooksByGenre(String genre, {int limit = 20}) async {
    final snapshot = await _firestore
        .collection('books')
        .where('genre', isEqualTo: genre)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => {
      ...doc.data(),
      'id': doc.id,
    }).toList();
  }

  /// Search Google Books but do not write to Firestore. Returns plain maps ready for editing.
  static Future<List<Map<String, dynamic>>> searchGoogleBooks(String title, {String? author, int maxResults = 10}) async {
    final qParts = <String>[];
    if (title.trim().isNotEmpty) qParts.add(title.trim());
    if (author != null && author.trim().isNotEmpty) qParts.add('inauthor:${author.trim()}');

    final url = Uri.https(
      'www.googleapis.com',
      '/books/v1/volumes',
      {
        'q': qParts.join(' '),
        'maxResults': maxResults.toString(),
      },
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return [];

    final data = json.decode(response.body);
    final items = data['items'] as List<dynamic>?;
    if (items == null) return [];

    return items.map((item) {
      final info = item['volumeInfo'] ?? {};
      final cats = info['categories'] as List<dynamic>?;
      return {
        'title': info['title'] ?? '',
        'author': (info['authors'] as List<dynamic>?)?.first ?? '',
        'coverUrl': info['imageLinks']?['thumbnail'],
        'description': info['description'] ?? '',
        'publishedDate': info['publishedDate'] ?? '',
        'pageCount': info['pageCount'],
        'genre': cats != null && cats.isNotEmpty ? cats.first : null,
        'categories': info['categories'],
        'googleBooksId': item['id'],
      };
    }).where((b) => !_looksLikeCollection(b['title'] as String?)).toList();
  }

  /// Create or update a book document. If [bookId] is null, creates a new doc.
  /// Returns the bookId used.
  static Future<String> upsertBook({
    String? bookId,
    required Map<String, dynamic> bookData,
  }) async {
    final collection = _firestore.collection('books');

    if (bookId == null) {
      final doc = await collection.add(bookData);
      return doc.id;
    } else {
      await collection.doc(bookId).update(bookData);
      return bookId;
    }
  }

  /// Clear all books from Firestore
  static Future<void> clearAllBooks() async {
    final snapshot = await _firestore.collection('books').get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
    print('Cleared all books from Firestore');
  }
}
