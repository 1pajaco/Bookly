import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:namer_app/services/book_service.dart';
import 'package:namer_app/services/library_service.dart';
import '../auth.dart';
import '../services/librarian_service.dart';

class BookAdminPage extends StatefulWidget {
  const BookAdminPage({super.key, this.initialBookData});

  final Map<String, dynamic>? initialBookData;

  @override
  State<BookAdminPage> createState() => _BookAdminPageState();
}

class _BookAdminPageState extends State<BookAdminPage> {
  final TextEditingController _searchTitleCtrl = TextEditingController();
  final TextEditingController _searchAuthorCtrl = TextEditingController();

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _authorCtrl = TextEditingController();
  final TextEditingController _coverCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _publishedCtrl = TextEditingController();
  final TextEditingController _pageCountCtrl = TextEditingController();
  final TextEditingController _categoriesCtrl = TextEditingController();
  final TextEditingController _genreCtrl = TextEditingController();
  final TextEditingController _copiesCtrl = TextEditingController(text: '1');

  // Genre options
  static const List<String> _predefinedGenres = [
    'Fiction',
    'Non-fiction',
    'Science Fiction',
    'Fantasy',
    'Mystery',
    'Romance',
    'Thriller',
    'Horror',
    'Historical',
    'Biography',
    'Self-Help',
    'Poetry',
    'Drama',
    'Adventure',
    'Comedy',
  ];

  bool _useGoogle = true; // toggle between Google search and existing
  bool _loadingSearch = false;
  bool _saving = false;
  List<Map<String, dynamic>> _results = [];

  String? _selectedBookId; // null means new book
  String? _selectedGoogleId;
  String? _selectedGenre;

  String? _selectedLibraryId;
  String? _selectedLibraryName;
  int _selectedLibraryTotalCopies = 0;
  int _selectedLibraryAvailableCopies = 0;

  @override
  void initState() {
    super.initState();
    _loadLibrarianLibraryId();
    if (widget.initialBookData != null) {
      // Pre-fill form with provided book data (treat as existing if id present)
      _loadIntoForm(widget.initialBookData!, existing: (widget.initialBookData!['id'] != null));
    }
  }

  Future<void> _loadLibrarianLibraryId() async {
    final user = Auth().currentUser;
    if (user == null) return;
    try {
      final libId = await LibrarianService.getLibraryIdByUid(user.uid);
      if (mounted) {
        setState(() => _selectedLibraryId = libId);
        if (libId != null) {
          await _loadLibraryName(libId);
          await _loadLibraryCopyStats(libId);
        }
      }
    } catch (e) {
      // leave null if not a librarian or no library assigned
    }
  }

  Future<void> _loadLibraryName(String libraryId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('libraries').doc(libraryId).get();
      final data = doc.data();
      final name = (data?['name'] as String?)?.trim();
      if (mounted) {
        setState(() => _selectedLibraryName = name != null && name.isNotEmpty ? name : 'Unknown library');
      }
    } catch (_) {}
  }

  Future<void> _loadLibraryCopyStats(String libraryId) async {
    try {
      final stats = await LibraryService.getCopyStats(libraryId: libraryId, bookId: _selectedBookId ?? '');
      if (mounted) {
        setState(() {
          _selectedLibraryAvailableCopies = stats['available'] ?? 0;
          _selectedLibraryTotalCopies = stats['total'] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _search() async {
    final title = _searchTitleCtrl.text.trim();
    final author = _searchAuthorCtrl.text.trim();
    if (!_useGoogle && title.isEmpty && author.isEmpty) {
      await _loadLocalBooks();
      return;
    }

    setState(() => _loadingSearch = true);
    try {
      List<Map<String, dynamic>> res;
      if (_useGoogle) {
        res = await BookService.searchGoogleBooks(title, author: author, maxResults: 10);
      } else {
        // simple contains filter client-side
        final snap = await FirebaseFirestore.instance.collection('books').get();
        res = snap.docs
            .map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            })
            .where((data) {
              if ((data['retired'] as bool?) == true) return false;
              final t = (data['title'] ?? '').toString().toLowerCase();
              final a = (data['author'] ?? '').toString().toLowerCase();
              return t.contains(title.toLowerCase()) || a.contains(author.toLowerCase());
            })
            .toList();
      }
      setState(() => _results = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _loadingSearch = false);
    }
  }

  Future<void> _loadLocalBooks() async {
    setState(() => _loadingSearch = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('books').get();
      final res = snap.docs
          .map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          })
          .where((data) => (data['retired'] as bool?) != true)
          .toList();
      setState(() => _results = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Load failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _loadingSearch = false);
    }
  }

  void _loadIntoForm(Map<String, dynamic> book, {bool existing = false}) {
    setState(() {
      _selectedBookId = existing ? (book['id'] as String?) : null;
      _selectedGoogleId = book['googleBooksId'] as String?;
      _titleCtrl.text = (book['title'] ?? '').toString();
      _authorCtrl.text = (book['author'] ?? '').toString();
      _coverCtrl.text = (book['coverUrl'] ?? '').toString();
      _descCtrl.text = (book['description'] ?? '').toString();
      _publishedCtrl.text = (book['publishedDate'] ?? '').toString();
      _pageCountCtrl.text = book['pageCount'] != null ? book['pageCount'].toString() : '';
      final genreValue = (book['genre'] ?? '').toString();
      _selectedGenre = _predefinedGenres.contains(genreValue) ? genreValue : null;
      _genreCtrl.text = _predefinedGenres.contains(genreValue) ? '' : genreValue;
      final cats = book['categories'];
      if (cats is List) {
        _categoriesCtrl.text = cats.join(', ');
      } else {
        _categoriesCtrl.text = cats?.toString() ?? '';
      }
    });

    final libId = _selectedLibraryId;
    final bookId = existing ? (book['id'] as String?) : null;
    if (libId != null && bookId != null) {
      _loadLibraryCopyStats(libId);
    }
  }

  Future<void> _save() async {
    if (_selectedLibraryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assigned library. Librarian account required.'), backgroundColor: Colors.red),
      );
      return;
    }

    final title = _titleCtrl.text.trim();
    final author = _authorCtrl.text.trim();
    if (title.isEmpty || author.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and author are required'), backgroundColor: Colors.red),
      );
      return;
    }

    final pageCount = int.tryParse(_pageCountCtrl.text.trim());
    final categories = _categoriesCtrl.text
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    final genre = _selectedGenre ?? _genreCtrl.text.trim();

    final bookData = {
      'title': title,
      'author': author,
      'coverUrl': _coverCtrl.text.trim().isEmpty ? null : _coverCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'publishedDate': _publishedCtrl.text.trim(),
      'pageCount': pageCount,
      'genre': genre.isEmpty ? null : genre,
      'categories': categories.isEmpty ? null : categories,
      'googleBooksId': _selectedGoogleId,
    };

    setState(() => _saving = true);
    try {
      final bookId = await BookService.upsertBook(bookId: _selectedBookId, bookData: bookData);

      final copies = int.tryParse(_copiesCtrl.text.trim()) ?? 0;
      if (copies > 0) {
        await LibraryService.addCopiesForBook(
          libraryId: _selectedLibraryId!,
          bookId: bookId,
          bookTitle: title,
          count: copies,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Book saved${copies > 0 ? ' and $copies copies added' : ''}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _searchTitleCtrl.dispose();
    _searchAuthorCtrl.dispose();
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _coverCtrl.dispose();
    _descCtrl.dispose();
    _publishedCtrl.dispose();
    _pageCountCtrl.dispose();
    _categoriesCtrl.dispose();
    _genreCtrl.dispose();
    _copiesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add / Edit Book'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchTitleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Search title',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchAuthorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Search author (optional)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  value: _useGoogle,
                  onChanged: (v) async {
                    setState(() => _useGoogle = v);
                    if (!v) {
                      await _loadLocalBooks();
                    } else {
                      setState(() => _results = []);
                    }
                  },
                ),
                const Text('Google Books search'),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _loadingSearch ? null : _search,
                  icon: _loadingSearch
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_results.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Results', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._results.map((book) {
                    final title = (book['title'] ?? '').toString();
                    final author = (book['author'] ?? '').toString();
                    return Card(
                      child: ListTile(
                        title: Text(title.isEmpty ? 'Untitled' : title),
                        subtitle: Text(author.isEmpty ? 'Unknown author' : author),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _loadIntoForm(book, existing: !_useGoogle),
                      ),
                    );
                  }),
                  const Divider(height: 24),
                ],
              ),
            const Text('Book details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *'),
            ),
            TextField(
              controller: _authorCtrl,
              decoration: const InputDecoration(labelText: 'Author *'),
            ),
            TextField(
              controller: _coverCtrl,
              decoration: const InputDecoration(labelText: 'Cover URL'),
            ),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            TextField(
              controller: _publishedCtrl,
              decoration: const InputDecoration(labelText: 'Published date'),
            ),
            TextField(
              controller: _pageCountCtrl,
              decoration: const InputDecoration(labelText: 'Page count'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            const Text('Genre', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedGenre,
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Select a genre...'),
                ),
                ..._predefinedGenres.map((genre) => DropdownMenuItem<String>(
                  value: genre,
                  child: Text(genre),
                )),
              ],
              onChanged: (v) => setState(() {
                _selectedGenre = v;
                _genreCtrl.clear();
              }),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            if (_selectedGenre == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: _genreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Or enter custom genre',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoriesCtrl,
              decoration: const InputDecoration(labelText: 'Categories (comma separated)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Library'),
                    child: Text(
                      _selectedLibraryId == null
                          ? 'Not assigned'
                          : (_selectedLibraryName ?? _selectedLibraryId!),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _copiesCtrl,
                    decoration: const InputDecoration(labelText: 'Copies'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            if (_selectedLibraryId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Text(
                      'Total copies: $_selectedLibraryTotalCopies',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Available: $_selectedLibraryAvailableCopies',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_selectedBookId == null ? 'Create and add copies' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
