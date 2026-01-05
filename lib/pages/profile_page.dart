import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../auth.dart';
import '../services/rental_service.dart';
import '../services/librarian_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.showBack = true});

  final bool showBack;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<dynamic> _selectedEvents = const [];
  bool _isOffline = false;
  Stream<List<ConnectivityResult>>? _connectivityStream;
  late final Stream<List<ConnectivityResult>> _connectivityBroadcast;
  late final Future<List<ConnectivityResult>> _initialConnectivity;

  Widget _title() {
    return const Text('Profile');
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _initialConnectivity = Connectivity().checkConnectivity();
    _connectivityBroadcast = Connectivity().onConnectivityChanged;
    _connectivityStream = _connectivityBroadcast;
    _listenConnectivity();
  }

  void _listenConnectivity() async {
    // initial state
    final initial = await _initialConnectivity;
    // On newer connectivity_plus, checkConnectivity returns a list; use first if present
    final initialResult = initial.isNotEmpty ? initial.first : ConnectivityResult.none;
    _setOffline(initialResult);

    _connectivityStream?.listen((statusList) {
      final status = statusList.isNotEmpty ? statusList.first : ConnectivityResult.none;
      _setOffline(status);
    });
  }

  void _setOffline(ConnectivityResult status) {
    final offline = status == ConnectivityResult.none;
    if (_isOffline != offline && mounted) {
      setState(() {
        _isOffline = offline;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Auth().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: _title(),
        centerTitle: true,
        leading: widget.showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<String?>(
          future: user != null ? LibrarianService.getLibraryIdByUid(user.uid) : Future.value(null),
          builder: (context, snapshot) {
            final libId = snapshot.data;
            final isLibrarian = libId != null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_isOffline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.cloud_off, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Offline mode',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                // Username Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Username',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user?.email?.split('@').first ?? 'User',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person, size: 30),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (isLibrarian) ...[
                  // Librarian: show assigned library info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assigned Library',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance.collection('libraries').doc(libId).get(),
                          builder: (context, libSnap) {
                            if (libSnap.connectionState == ConnectionState.waiting) {
                              return const Text('Loading library...');
                            }
                            final data = libSnap.data?.data();
                            final name = (data?['name'] as String?)?.trim();
                            return Text(
                              name != null && name.isNotEmpty ? name : 'Unknown library',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Non-librarian: show rentals and calendar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'List of rented books',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: user != null
                              ? StreamBuilder(
                                  stream: RentalService.getUserRentals(user.uid),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }

                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text('Error loading rentals', style: TextStyle(color: Colors.red[400])),
                                      );
                                    }

                                    final rentals = snapshot.data ?? [];
                                    if (rentals.isEmpty) {
                                      return const Center(child: Text('No rented books yet', style: TextStyle(color: Colors.grey)));
                                    }

                                    return ListView.builder(
                                      itemCount: rentals.length,
                                      itemBuilder: (context, index) {
                                        final rental = rentals[index];
                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              children: [
                                                if (rental.bookCoverUrl.isNotEmpty)
                                                  Container(
                                                    width: 50,
                                                    height: 75,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(4),
                                                      color: Colors.grey[800],
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: CachedNetworkImage(
                                                        imageUrl: rental.bookCoverUrl,
                                                        fit: BoxFit.cover,
                                                        placeholder: (c, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                        errorWidget: (c, url, err) => const Icon(Icons.book, size: 20),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    width: 50,
                                                    height: 75,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(4),
                                                      color: Colors.grey[800],
                                                    ),
                                                    child: const Icon(Icons.book, size: 20),
                                                  ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        rental.bookTitle,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Due: ${rental.dueDate.toString().split(' ')[0]}',
                                                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      // Show library name if available
                                                      if (rental.libraryId != null)
                                                        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                                          future: FirebaseFirestore.instance.collection('libraries').doc(rental.libraryId).get(),
                                                          builder: (context, libSnap) {
                                                            if (libSnap.connectionState == ConnectionState.waiting) {
                                                              return const Text('Library: loading...', style: TextStyle(fontSize: 12, color: Colors.grey));
                                                            }
                                                            final data = libSnap.data?.data();
                                                            final name = (data?['name'] as String?)?.trim();
                                                            return Text(
                                                              'From: ${name != null && name.isNotEmpty ? name : 'Unknown library'}',
                                                              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                                            );
                                                          },
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                )
                              : const Center(child: Text('Please log in to view rentals', style: TextStyle(color: Colors.grey))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Calendar integrated with user rentals (due dates)
                  StreamBuilder(
                    stream: user != null ? RentalService.getUserRentals(user.uid) : const Stream.empty(),
                    builder: (context, snap) {
                      final rentals = (snap.data ?? []) as List<dynamic>;
                      final Map<DateTime, List<dynamic>> events = {};
                      for (final r in rentals) {
                        final day = _normalize(r.dueDate);
                        events.putIfAbsent(day, () => []);
                        events[day]!.add(r);
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Calendar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: TableCalendar<dynamic>(
                                firstDay: DateTime.utc(2010, 1, 1),
                                lastDay: DateTime.utc(2035, 12, 31),
                                focusedDay: _focusedDay,
                                rowHeight: 40,
                                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                                selectedDayPredicate: (day) => _selectedDay != null && isSameDay(_selectedDay, day),
                                onDaySelected: (selectedDay, focusedDay) {
                                  setState(() {
                                    _selectedDay = selectedDay;
                                    _focusedDay = focusedDay;
                                    _selectedEvents = events[_normalize(selectedDay)] ?? [];
                                  });
                                },
                                eventLoader: (day) => events[_normalize(day)] ?? const [],
                                calendarStyle: const CalendarStyle(
                                  markerDecoration: BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                                  outsideDaysVisible: false,
                                ),
                                headerStyle: const HeaderStyle(
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_selectedEvents.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Selected day', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  ..._selectedEvents.map((e) => Card(
                                        child: ListTile(
                                          leading: const Icon(Icons.book),
                                          title: Text(e.bookTitle),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Due: ${_normalize(e.dueDate).toString().split(' ')[0]}'),
                                              if (e.libraryId != null)
                                                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                                  future: FirebaseFirestore.instance.collection('libraries').doc(e.libraryId).get(),
                                                  builder: (context, libSnap) {
                                                    if (libSnap.connectionState == ConnectionState.waiting) {
                                                      return const Text('Library: loading...', style: TextStyle(fontSize: 12));
                                                    }
                                                    final data = libSnap.data?.data();
                                                    final name = (data?['name'] as String?)?.trim();
                                                    return Text('From: ${name != null && name.isNotEmpty ? name : 'Unknown library'}');
                                                  },
                                                ),
                                            ],
                                          ),
                                        ),
                                      )),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
