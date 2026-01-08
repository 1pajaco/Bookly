import 'package:flutter/material.dart';
import '../auth.dart';
import '../services/book_service.dart';
import '../services/library_service.dart';
import '../services/librarian_service.dart';

class RemoveCopiesPage extends StatefulWidget {
  const RemoveCopiesPage({super.key});

  @override
  State<RemoveCopiesPage> createState() => _RemoveCopiesPageState();
}

class _RemoveCopiesPageState extends State<RemoveCopiesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _countCtrl = TextEditingController(text: '1');
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selectedBook;
  String? _libraryId;
  bool _isSearching = false;
  bool _isWorking = false;
  int _availableInLibrary = 0;
  int _rentedInLibrary = 0;

  @override
  void initState() {
    super.initState();
    _loadLibrarianLibraryId();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLibrarianLibraryId() async {
    // Use Auth().currentUser and LibrarianService via UserService
    final user = Auth().currentUser;
    if (user == null) return;
    try {
      final libId = await LibrarianService.getLibraryIdByUid(user.uid);
      if (mounted)
        setState(() {
          _libraryId = libId;
        });
    } catch (_) {}
  }

  Future<void> _search(String q) async {
    setState(() {
      _isSearching = true;
    });
    try {
      final results = await BookService.searchBooks(q);
      setState(() {
        _results = results;
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _selectBook(Map<String, dynamic> book) async {
    setState(() {
      _selectedBook = book;
      _availableInLibrary = 0;
      _rentedInLibrary = 0;
    });
    final libId = _libraryId;
    if (libId == null) return;
    final stats = await LibraryService.getCopyStats(
      libraryId: libId,
      bookId: book['id'] as String,
    );
    setState(() {
      _availableInLibrary = stats['available'] ?? 0;
      _rentedInLibrary = stats['rented'] ?? 0;
    });
  }

  Future<void> _removeCopies() async {
    final libId = _libraryId;
    final book = _selectedBook;
    if (libId == null || book == null) return;

    final count = int.tryParse(_countCtrl.text.trim());
    if (count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid number of copies to remove'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (count > _availableInLibrary) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You cannot remove $count copies. Only $_availableInLibrary available.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_rentedInLibrary > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove copies while some are rented out'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isWorking = true;
    });
    try {
      final removed = await LibraryService.removeAvailableCopies(
        libraryId: libId,
        bookId: book['id'] as String,
        count: count,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $removed available copies'),
          backgroundColor: removed > 0 ? Colors.green : Colors.orange,
        ),
      );
      await _selectBook(book);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing copies: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted)
        setState(() {
          _isWorking = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remove Copies')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_selectedBook == null) ...[
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search books by title or author',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _results = [];
                              _selectedBook = null;
                            });
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _search,
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: _selectedBook == null
                  ? (_isSearching
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final book = _results[index];
                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.book),
                                  title: Text(book['title'] ?? 'Untitled'),
                                  subtitle: Text(book['author'] ?? ''),
                                  onTap: () => _selectBook(book),
                                ),
                              );
                            },
                          ))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected: ${_selectedBook!['title']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Available in your library: $_availableInLibrary',
                          ),
                          Text('Currently rented: $_rentedInLibrary'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _countCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Copies to remove',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _isWorking ? null : _removeCopies,
                            icon: const Icon(Icons.delete),
                            label: const Text('Remove Available Copies'),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => setState(() {
                              _selectedBook = null;
                            }),
                            child: const Text('Back to results'),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
