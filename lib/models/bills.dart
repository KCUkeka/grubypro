class Bill {
  final String id;
  final String name;
  final double amount;
  final DateTime dueDate;
  final bool paymentMade;
  final DateTime? paymentDate;
  final bool autoPay;
  final bool archived;

  Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.paymentMade,
    required this.paymentDate,
    required this.autoPay,
    this.archived = false,
  });

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        id: json['id'],
        name: json['name'],
        amount: (json['amount'] as num).toDouble(),
        dueDate: DateTime.parse(json['due_date']),
        paymentMade: json['payment_made'],
        paymentDate: json['payment_date'] != null
            ? DateTime.parse(json['payment_date'])
            : null,
        autoPay: json['auto_pay'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'due_date': dueDate.toIso8601String(),
        'payment_made': paymentMade,
        'payment_date': paymentDate?.toIso8601String(),
        'auto_pay': autoPay,
        'archived': archived,
      };
}
