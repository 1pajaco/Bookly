import 'dart:math';

import 'package:flutter/material.dart';

import '../services/book_service.dart';
import '../services/rental_service.dart';
import 'book_overview_page.dart';

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key, required this.userId});

  final String userId;

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  late Future<_RecommendationsResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRecommendations();
  }

  Future<_RecommendationsResult> _loadRecommendations() async {
    try {
      final rentals = await RentalService.fetchUserRentalHistory(widget.userId, limit: 50);
      if (rentals.isEmpty) {
        return const _RecommendationsResult(message: 'No rental history yet to base recommendations on.');
      }

      // Collect genre counts from rented books.
      final genreCounts = <String, int>{};
      final rentedBookIds = <String>{};
      for (final rental in rentals) {
        rentedBookIds.add(rental.bookId);
        final book = await BookService.getBook(rental.bookId);
        final genre = (book?['genre'] as String?)?.trim();
        if (genre != null && genre.isNotEmpty) {
          genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
        }
      }

      if (genreCounts.isEmpty) {
        return const _RecommendationsResult(message: 'No genres found on your rented books yet.');
      }

      // Pick top 3 genres by frequency.
      final topGenres = genreCounts.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      final selectedGenres = topGenres.take(3).map((e) => e.key).toList();

      // Fetch books for each genre and shuffle.
      final rand = Random();
      final recommendations = <Map<String, dynamic>>[];
      for (final genre in selectedGenres) {
        final books = await BookService.getBooksByGenre(genre, limit: 25);
        books.shuffle(rand);
        for (final book in books) {
          if (!rentedBookIds.contains(book['id'])) {
            recommendations.add(book);
          }
        }
      }

      if (recommendations.isEmpty) {
        return const _RecommendationsResult(message: 'No recommendations found yet.');
      }

      // Shuffle and trim to a reasonable size.
      recommendations.shuffle(rand);
      final trimmed = recommendations.take(15).toList();

      return _RecommendationsResult(books: trimmed, genresUsed: selectedGenres);
    } catch (e) {
      return _RecommendationsResult(message: 'Error loading recommendations: $e');
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadRecommendations();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recommended for You')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_RecommendationsResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final result = snapshot.data;
            if (result == null) {
              return const Center(child: Text('Loading recommendations...'));
            }

            if (result.books == null || result.books!.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(result.message ?? 'No recommendations yet.'),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: result.books!.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final book = result.books![index];
                final title = (book['title'] ?? '') as String;
                final author = (book['author'] ?? '') as String;
                final genre = (book['genre'] ?? '') as String;
                final cover = (book['coverUrl'] ?? '') as String;

                return Card(
                  child: ListTile(
                    leading: _Cover(url: cover),
                    title: Text(title.isNotEmpty ? title : 'Untitled'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (author.isNotEmpty) Text(author),
                        if (genre.isNotEmpty) Text('Genre: $genre'),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookOverviewPage(bookData: book),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RecommendationsResult {
  const _RecommendationsResult({this.books, this.message, this.genresUsed});

  final List<Map<String, dynamic>>? books;
  final String? message;
  final List<String>? genresUsed;
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 52,
        height: 72,
        color: Colors.grey.shade200,
        child: hasUrl
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.book, size: 32),
              )
            : const Icon(Icons.book, size: 32),
      ),
    );
  }
}
