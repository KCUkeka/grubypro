class GroceryItem {
  final String? id;
  final String name;
  final String category;
  final bool isPurchased;
  final DateTime createdAt;
  final String? barcode;
  final int quantity;

  GroceryItem({
    this.id,
    required this.name,
    required this.category,
    this.isPurchased = false,
    required this.createdAt,
    this.barcode,
    this.quantity = 1,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'category': category,
        'is_purchased': isPurchased,
        'created_at': createdAt.toIso8601String(),
        'barcode': barcode,
        'quantity': quantity,
      };

  factory GroceryItem.fromMap(Map<String, dynamic> m) => GroceryItem(
        id: m['id']?.toString(), 
        name: m['name'] ?? '',
        category: m['category'] ?? '',
        isPurchased: m['is_purchased'] == 1 || m['is_purchased'] == true, // Handle both int and bool
        createdAt: DateTime.parse(m['created_at'] ?? DateTime.now().toIso8601String()),
        barcode: m['barcode']?.toString(), 
        quantity: (m['quantity'] is int) ? m['quantity'] : int.tryParse(m['quantity']?.toString() ?? '1') ?? 1,
      );

  GroceryItem copyWith({
    String? id,
    String? name,
    String? category,
    bool? isPurchased,
    DateTime? createdAt,
    String? barcode,
    int? quantity,
  }) =>
      GroceryItem(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        isPurchased: isPurchased ?? this.isPurchased,
        createdAt: createdAt ?? this.createdAt,
        barcode: barcode ?? this.barcode,
        quantity: quantity ?? this.quantity,
      );
}