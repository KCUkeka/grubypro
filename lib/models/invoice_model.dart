class Invoice {
  final String id;
  final DateTime createdDate;
  final List<String> saleIds;
  final double subtotal;
  final double taxAmount;
  final double total;
  final String? customerName;
  final String? customerEmail;
  final String? notes;

  Invoice({
    required this.id,
    required this.createdDate,
    required this.saleIds,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    this.customerName,
    this.customerEmail,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_date': createdDate.toIso8601String(),
      'sale_ids': saleIds,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'notes': notes,
    };
  }

  static Invoice fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      createdDate: DateTime.parse(map['created_date']),
      saleIds: List<String>.from(map['sale_ids']),
      subtotal: (map['subtotal'] as num).toDouble(),
      taxAmount: (map['tax_amount'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      customerName: map['customer_name'],
      customerEmail: map['customer_email'],
      notes: map['notes'],
    );
  }
}