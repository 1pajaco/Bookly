import 'package:flutter/material.dart';
import 'package:namer_app/models/user.dart';
import 'package:namer_app/services/user_service.dart';
import 'package:namer_app/services/rental_service.dart';
import 'package:namer_app/models/rental.dart';
import 'package:namer_app/auth.dart';
import 'package:namer_app/services/librarian_service.dart';

class ReturnBookPage extends StatefulWidget {
  const ReturnBookPage({super.key});

  @override
  State<ReturnBookPage> createState() => _ReturnBookPageState();
}

class _ReturnBookPageState extends State<ReturnBookPage> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  UserModel? _selectedUser;
  List<Map<String, dynamic>> _userRentals = [];
  bool _isSearching = false;
  bool _isLoadingRentals = false;
  String? _librarianLibraryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadLibrarianLibraryId();
  }

  Future<void> _loadLibrarianLibraryId() async {
    final user = Auth().currentUser;
    if (user == null) return;
    try {
      final libId = await LibrarianService.getLibraryIdByUid(user.uid);
      if (mounted) setState(() => _librarianLibraryId = libId);
    } catch (_) {}
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedUser = null;
        _userRentals = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await UserService.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _selectUser(UserModel user) async {
    setState(() {
      _selectedUser = user;
      _isLoadingRentals = true;
    });

    try {
      final rentals = await RentalService.getUserActiveRentalsWithIds(
        user.uid,
        libraryId: _librarianLibraryId,
      );
      if (!mounted) return;
      setState(() {
        _userRentals = rentals;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load rentals: $e'), backgroundColor: Colors.red),
      );
      setState(() {
        _selectedUser = null;
        _userRentals = [];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingRentals = false);
      }
    }
  }

  Future<void> _returnBook(String rentalId, Rental rental) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Book?'),
        content: Text('Return "${rental.bookTitle}" for ${_selectedUser?.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Return'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    try {
      final result = await RentalService.returnBook(rentalId);
      if (!mounted) return;

      if (result.success) {
        if (result.lateFee > 0) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Late Fee'),
              content: Text(
                'This rental is overdue. Please collect a fee of \$${result.lateFee.toStringAsFixed(2)}.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              ],
            ),
          );
        }

        // Reload rentals after successful return
        await _selectUser(_selectedUser!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${rental.bookTitle}" returned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to return book'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error returning book: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Books'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search user by email or ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _selectedUser = null;
                            _userRentals = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 16),
            // Search results or user rentals
            Expanded(
              child: _selectedUser != null
                  ? _isLoadingRentals
                      ? const Center(child: CircularProgressIndicator())
                      : _userRentals.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.library_books, size: 48, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(
                                    '${_selectedUser!.email}\nhas no active rentals',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _userRentals.length,
                              itemBuilder: (context, index) {
                                final rentalData = _userRentals[index];
                                final rental = rentalData['rental'] as Rental;
                                final rentalId = rentalData['rentalId'] as String;

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Book cover
                                        Container(
                                          width: 60,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(4),
                                            image: DecorationImage(
                                              image: NetworkImage(rental.bookCoverUrl),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Book details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                rental.bookTitle,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Due: ${rental.dueDate.toString().split(' ')[0]}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: rental.dueDate.isBefore(DateTime.now())
                                                      ? Colors.red
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Return button
                                        ElevatedButton(
                                          onPressed: () => _returnBook(rentalId, rental),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Return'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                  : _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _searchResults.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.isEmpty
                                    ? 'Search for a user to see their rentals'
                                    : 'No users found',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final user = _searchResults[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  child: ListTile(
                                    title: Text(user.email),
                                    subtitle: Text('ID: ${user.uid.substring(0, 8)}...'),
                                    onTap: () => _selectUser(user),
                                    trailing: const Icon(Icons.arrow_forward),
                                  ),
                                );
                              },
                            ),
            ),
            // Back button
            if (_selectedUser != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedUser = null;
                      _userRentals = [];
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Search'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
