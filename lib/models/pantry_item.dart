class PantryItem {
  final String? id;
  final String name;
  final String category;
  final int quantity;
  final DateTime? expiryDate;
  final DateTime addedAt;
  final String? barcode;

  PantryItem({
    this.id,
    required this.name,
    required this.category,
    this.quantity = 1,
    this.expiryDate,
    required this.addedAt,
    this.barcode,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'category': category,
        'quantity': quantity,
        'expiry_date': expiryDate?.toIso8601String(),
        'added_at': addedAt.toIso8601String(),
        'barcode': barcode,
      };

  factory PantryItem.fromMap(Map<String, dynamic> m) => PantryItem(
        id: m['id']?.toString(), 
        name: m['name'] ?? '',
        category: m['category'] ?? '',
        quantity: (m['quantity'] is int) ? m['quantity'] : int.tryParse(m['quantity']?.toString() ?? '1') ?? 1,
        expiryDate: m['expiry_date'] != null ? DateTime.tryParse(m['expiry_date']) : null,
        addedAt: DateTime.tryParse(m['added_at'] ?? DateTime.now().toIso8601String()) ?? DateTime.now(),
        barcode: m['barcode']?.toString(), 
      );

  PantryItem copyWith({
    String? id,
    String? name,
    String? category,
    int? quantity,
    DateTime? expiryDate,
    DateTime? addedAt,
    String? barcode,
  }) =>
      PantryItem(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        quantity: quantity ?? this.quantity,
        expiryDate: expiryDate ?? this.expiryDate,
        addedAt: addedAt ?? this.addedAt,
        barcode: barcode ?? this.barcode,
      );

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final diff = expiryDate!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 3;
  }
}