class AppTransaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String paymentType;
  final bool archived;

  AppTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.paymentType,
    this.archived = false,
  });

  factory AppTransaction.fromMap(Map<String, dynamic> map) {
    return AppTransaction(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      paymentType: map['payment_type']?.toString() ?? '',
      archived: map['archived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMapForInsert() {
    return {
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'payment_type': paymentType,
    };
  }

  Map<String, dynamic> toMapForUpdate() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'payment_type': paymentType,
    };
  }
}