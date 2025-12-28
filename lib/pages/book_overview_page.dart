import 'package:flutter/material.dart';
import '../auth.dart';
import '../services/rental_service.dart';
import '../services/library_service.dart';
import '../services/librarian_service.dart';
import 'book_admin_page.dart';

class BookOverviewPage extends StatefulWidget {
  final Map<String, dynamic> bookData;

  const BookOverviewPage({super.key, required this.bookData});

  @override
  State<BookOverviewPage> createState() => _BookOverviewPageState();
}

class _BookOverviewPageState extends State<BookOverviewPage> {
  bool _isRenting = false;
  bool _isRented = false;
  List<Map<String, dynamic>> _librariesWithStock = [];
  List<Map<String, dynamic>> _librariesHolding = [];
  bool _isLibrarian = false;

  @override
  void initState() {
    super.initState();
    _checkLibrarian();
    _checkIfAlreadyRented();
    _loadLibrariesWithStock();
    _loadLibrariesHolding();
  }

  Future<void> _checkLibrarian() async {
    final user = Auth().currentUser;
    if (user == null) return;
    final isLib = await LibrarianService.isLibrarianByUid(user.uid);
    if (mounted) {
      setState(() => _isLibrarian = isLib);
    }
  }

  Future<void> _checkIfAlreadyRented() async {
    final user = Auth().currentUser;
    if (user != null) {
      final hasRented = await RentalService.hasUserRentedBook(
        user.uid,
        widget.bookData['id'] ?? '',
      );
      if (mounted) {
        setState(() {
          _isRented = hasRented;
        });
      }
    }
  }

  Future<void> _loadLibrariesWithStock() async {
    final bookId = widget.bookData['id'] ?? '';
    final libs = await LibraryService.getLibrariesWithStock(bookId);
    if (mounted) {
      setState(() {
        _librariesWithStock = libs;
      });
    }
  }

  Future<void> _loadLibrariesHolding() async {
    final bookId = widget.bookData['id'] ?? '';
    final libs = await LibraryService.getLibrariesHoldingBook(bookId);
    if (mounted) {
      setState(() {
        _librariesHolding = libs;
      });
    }
  }

  Future<void> _rentBook() async {
    final user = Auth().currentUser;
    if (user == null) return;

    setState(() {
      _isRenting = true;
    });

    final bookId = widget.bookData['id'] ?? '';
    final bookTitle = widget.bookData['title'] ?? 'Unknown Book';
    final bookCoverUrl = widget.bookData['coverUrl'] ?? '';

    // Always prompt selection, even if only one library
    String? selectedLibraryId = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final list = _librariesWithStock.isNotEmpty ? _librariesWithStock : _librariesHolding;
        return AlertDialog(
          title: const Text('Select Library'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (context, index) {
                final lib = list[index];
                return ListTile(
                  title: Text(lib['name'] as String),
                  subtitle: Text(
                    lib.containsKey('totalCount')
                        ? 'Available: ${lib['availableCount']} • Rented: ${(lib['totalCount'] as int) - (lib['availableCount'] as int)}'
                        : 'Available copies: ${lib['availableCount']}',
                  ),
                  onTap: () => Navigator.pop(ctx, lib['libraryId'] as String),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    String? rentalId;
    if (selectedLibraryId != null) {
      // If selected library has no available copies, inform the user
      final selected = _librariesWithStock.firstWhere(
        (e) => e['libraryId'] == selectedLibraryId,
        orElse: () => {'availableCount': 0},
      );
      final availableCount = (selected['availableCount'] as int?) ?? 0;
      if (availableCount == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No copies available in selected library'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
      rentalId = await RentalService.rentBookFromLibrary(
        userId: user.uid,
        bookId: bookId,
        bookTitle: bookTitle,
        bookCoverUrl: bookCoverUrl,
        libraryId: selectedLibraryId,
      );
      }
    }

    if (mounted) {
      setState(() {
        _isRenting = false;
      });

      if (rentalId != null) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rental successful!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _isRented = true;
        });
        _loadLibrariesWithStock();
      } else {
        // Error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to rent book. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top section: Cover photo and title/description
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover photo
                  Container(
                    width: 140,
                    height: 210,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[800],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.bookData['coverUrl'] != null
                          ? Image.network(
                              widget.bookData['coverUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.book, size: 50);
                              },
                            )
                          : const Icon(Icons.book, size: 50),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title and short description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Book title
                        Text(
                          widget.bookData['title'] ?? 'No title',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Author
                        Text(
                          'by ${widget.bookData['author'] ?? 'Unknown author'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Additional info
                        if (widget.bookData['publishedDate'] != null) ...[
                          Text(
                            'Published: ${widget.bookData['publishedDate']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (widget.bookData['pageCount'] != null) ...[
                          Text(
                            'Pages: ${widget.bookData['pageCount']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Book synopsis section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Book Synopsis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.bookData['description'] ?? 'No description available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[300],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Action button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isLibrarian
                    ? ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookAdminPage(initialBookData: widget.bookData),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Add / Edit Book'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: (_isRenting || _isRented || Auth().currentUser == null)
                            ? null
                            : _rentBook,
                        style: ElevatedButton.styleFrom(
                          disabledBackgroundColor: Colors.grey[800],
                          disabledForegroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isRenting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _isRented
                                    ? 'Rented'
                                    : (_librariesWithStock.isEmpty ? 'None in stock' : 'Rent'),
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
