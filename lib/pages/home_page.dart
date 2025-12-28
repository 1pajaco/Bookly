import 'package:firebase_auth/firebase_auth.dart';
import 'package:namer_app/pages/profile_page.dart';
import '../auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'book_overview_page.dart';
import '../services/librarian_service.dart';
import 'return_book_page.dart';
import 'book_admin_page.dart';
import 'history_page.dart';
import 'recommendations_page.dart';
import 'remove_copies_page.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? get user => Auth().currentUser;
  bool _isLibrarian = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _checkLibrarianStatus();
  }

  Future<void> _checkLibrarianStatus() async {
    final currentUser = user;
    if (currentUser != null) {
      final isLib = await LibrarianService.isLibrarianByUid(currentUser.uid);
      if (mounted) {
        setState(() {
          _isLibrarian = isLib;
        });
      }
    }
  }

  Future<void> signOut() async {
    await Auth().signOut();
    setState(() {
      _isLibrarian = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    ).then((_) {
      setState(() {});
      _checkLibrarianStatus();
    });
  }

  void navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    ).then((_) => setState(() {}));
  }

  Widget _title() {
    return const Text('Home');
  }

  Widget _userUid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('books').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            children: [
              const Text('Error loading data:', style: TextStyle(color: Colors.red)),
              Text('${snapshot.error}', style: const TextStyle(fontSize: 12)),
            ],
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No books in collection');
        }

        final q = _searchTerm.toLowerCase();
        final filtered = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if ((data['retired'] as bool?) == true) return false; // hide retired books
          final title = (data['title'] ?? '').toString().toLowerCase();
          final author = (data['author'] ?? '').toString().toLowerCase();
          final genre = (data['genre'] ?? '').toString().toLowerCase();
          if (q.isEmpty) return true;
          return title.contains(q) || author.contains(q) || genre.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return const Text('No books match your search');
        }

        return GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookOverviewPage(bookData: data),
                  ),
                );
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        width: double.infinity,
                        color: Colors.grey[800],
                        child: data['coverUrl'] != null
                            ? Image.network(
                                data['coverUrl'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.book, size: 50);
                                },
                              )
                            : const Icon(Icons.book, size: 50),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'] ?? 'No title',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['author'] ?? 'Unknown author',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _title(),
         leading: Builder(
           builder: (context) => IconButton(
             icon: const Icon(Icons.menu),
             onPressed: () => Scaffold.of(context).openDrawer(),
             tooltip: 'Open menu',
           ),
         ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: user == null
                ? ElevatedButton(
                    onPressed: navigateToLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(100, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Login'),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
       drawer: Drawer(
         child: ListView(
           padding: EdgeInsets.zero,
           children: [
             DrawerHeader(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   const Text('Menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   Text(user?.email ?? 'Not logged in'),
                 ],
               ),
             ),
             ListTile(
               leading: const Icon(Icons.person),
               title: const Text('Profile'),
               enabled: user != null,
               onTap: user != null
                   ? () {
                       Navigator.pop(context);
                       navigateToProfile();
                     }
                   : null,
             ),
              if (!_isLibrarian) ...[
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('History'),
                  enabled: user != null,
                  onTap: user != null
                      ? () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoryPage(userId: user!.uid),
                            ),
                          );
                        }
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.recommend),
                  title: const Text('Recommendations'),
                  enabled: user != null,
                  onTap: user != null
                      ? () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecommendationsPage(userId: user!.uid),
                            ),
                          );
                        }
                      : null,
                ),
              ],
             ListTile(
               leading: Icon(user == null ? Icons.login : Icons.logout),
               title: Text(user == null ? 'Login' : 'Sign out'),
               onTap: () async {
                 Navigator.pop(context);
                 if (user == null) {
                   navigateToLogin();
                 } else {
                   await signOut();
                 }
               },
             ),
             // Librarian-only actions
             if (_isLibrarian) ...[
               const Divider(),
               ListTile(
                 leading: const Icon(Icons.library_add),
                 title: const Text('Add / Edit Book'),
                 subtitle: const Text('Create or update a book and copies'),
                 onTap: () {
                   Navigator.pop(context);
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (context) => const BookAdminPage()),
                   );
                 },
               ),
               ListTile(
                 leading: const Icon(Icons.assignment_return),
                 title: const Text('Return Book'),
                 subtitle: const Text('Return a book to the library'),
                 onTap: () {
                   Navigator.pop(context);
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (context) => const ReturnBookPage()),
                   );
                 },
               ),
               ListTile(
                 leading: const Icon(Icons.delete_sweep),
                 title: const Text('Remove Copies'),
                 subtitle: const Text('Remove available copies from your library'),
                 onTap: () {
                   Navigator.pop(context);
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (context) => const RemoveCopiesPage()),
                   );
                 },
               ),
             ],
           ],
         ),
       ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by title, author, or genre',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchTerm = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchTerm = value.trim()),
            ),
            const SizedBox(height: 12),
            Expanded(child: _userUid()),
          ],
        ),
      ),
    );
  }
}
