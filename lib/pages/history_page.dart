import 'package:flutter/material.dart';

import '../models/rental.dart';
import '../services/rental_service.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rental History')),
      body: StreamBuilder<List<Rental>>(
        stream: RentalService.getUserRentalHistory(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading history: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rentals = snapshot.data ?? [];
          if (rentals.isEmpty) {
            return const Center(child: Text('No rental history yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rentals.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final rental = rentals[index];
              return Card(
                child: ListTile(
                  leading: _CoverImage(url: rental.bookCoverUrl),
                  title: Text(rental.bookTitle.isNotEmpty ? rental.bookTitle : 'Untitled book'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rented: ${_formatDate(rental.rentalDate)}'),
                        Text('Due: ${_formatDate(rental.dueDate)}'),
                        if (rental.returnedDate != null)
                          Text('Returned: ${_formatDate(rental.returnedDate!)}'),
                      ],
                    ),
                  ),
                  trailing: _StatusChip(status: rental.status),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final color = switch (normalized) {
      'returned' => Colors.green.shade100,
      'active' => Colors.blue.shade100,
      _ => Colors.grey.shade300,
    };
    final textColor = switch (normalized) {
      'returned' => Colors.green.shade900,
      'active' => Colors.blue.shade900,
      _ => Colors.grey.shade800,
    };
    final label = normalized.isNotEmpty
        ? normalized[0].toUpperCase() + normalized.substring(1)
        : 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});

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
