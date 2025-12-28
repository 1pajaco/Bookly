import 'package:cloud_firestore/cloud_firestore.dart';

class Rental {
  final String? id;
  final String userId;
  final String bookId;
  final String? libraryId; // library where the copy is held
  final String? copyId; // specific physical copy id
  final String bookTitle;
  final String bookCoverUrl;
  final DateTime rentalDate;
  final DateTime dueDate;
  final DateTime? returnedDate;
  final String status; // 'active' or 'returned'

  Rental({
    this.id,
    required this.userId,
    required this.bookId,
    this.libraryId,
    this.copyId,
    required this.bookTitle,
    required this.bookCoverUrl,
    required this.rentalDate,
    required this.dueDate,
    this.returnedDate,
    this.status = 'active',
  });

  /// Convert Rental to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'bookId': bookId,
      'libraryId': libraryId,
      'copyId': copyId,
      'bookTitle': bookTitle,
      'bookCoverUrl': bookCoverUrl,
      'rentalDate': Timestamp.fromDate(rentalDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'returnedDate': returnedDate != null ? Timestamp.fromDate(returnedDate!) : null,
      'status': status,
    };
  }

  /// Create Rental from Firestore document
  factory Rental.fromMap(Map<String, dynamic> map, String docId) {
    return Rental(
      id: docId,
      userId: map['userId'] ?? '',
      bookId: map['bookId'] ?? '',
      libraryId: map['libraryId'],
      copyId: map['copyId'],
      bookTitle: map['bookTitle'] ?? '',
      bookCoverUrl: map['bookCoverUrl'] ?? '',
      rentalDate: (map['rentalDate'] as Timestamp).toDate(),
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      returnedDate: map['returnedDate'] != null ? (map['returnedDate'] as Timestamp).toDate() : null,
      status: map['status'] ?? 'active',
    );
  }

  /// Create a copy of Rental with modified fields
  Rental copyWith({
    String? id,
    String? userId,
    String? bookId,
    String? libraryId,
    String? copyId,
    String? bookTitle,
    String? bookCoverUrl,
    DateTime? rentalDate,
    DateTime? dueDate,
    DateTime? returnedDate,
    String? status,
  }) {
    return Rental(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      libraryId: libraryId ?? this.libraryId,
      copyId: copyId ?? this.copyId,
      bookTitle: bookTitle ?? this.bookTitle,
      bookCoverUrl: bookCoverUrl ?? this.bookCoverUrl,
      rentalDate: rentalDate ?? this.rentalDate,
      dueDate: dueDate ?? this.dueDate,
      returnedDate: returnedDate ?? this.returnedDate,
      status: status ?? this.status,
    );
  }
}
