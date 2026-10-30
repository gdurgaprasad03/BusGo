class Complaint {
  final int id;
  final String reference;
  final String? bookingReference;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;

  const Complaint({
    required this.id,
    required this.reference,
    required this.bookingReference,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
        id: json['id'] as int,
        reference: json['reference'] as String,
        bookingReference: json['bookingReference'] as String?,
        subject: json['subject'] as String,
        message: json['message'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
