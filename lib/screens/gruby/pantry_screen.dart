import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../models/pantry_item.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});
  @override
  _PantryScreenState createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final SupabaseService _svc = SupabaseService();
  List<PantryItem> _pantryItems = [];
  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  DateTime? _selectedExpiryDate;

  @override
  void initState() {
    super.initState();
    _loadPantryItems();
  }

  Future<void> _loadPantryItems() async {
    final items = await _svc.getPantryItems();
    setState(() {
      _pantryItems = items;
    });
  }

  Future<void> _addPantryItem(
    String name,
    String category,
    int quantity,
    DateTime? expiryDate, {
    String? barcode,
  }) async {
    final item = PantryItem(
      name: name,
      category: category,
      quantity: quantity,
      expiryDate: expiryDate,
      addedAt: DateTime.now(),
    );
    await _svc.addPantryItem(item);
    await _loadPantryItems();
    _clearForm();
  }

  Future<void> _updatePantryItem(PantryItem item) async {
    await _svc.updatePantryItem(item);
    await _loadPantryItems();
  }

  Future<void> _deleteItem(String id) async {
    await _svc.deletePantryItem(id);
    await _loadPantryItems();
  }

  void _clearForm() {
    _nameController.clear();
    _categoryController.clear();
    _quantityController.text = '1';
    _selectedExpiryDate = null;
  }

  Future<void> _selectExpiryDate(StateSetter setDialogState) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedExpiryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: const Color(0xFF4CAF50)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setDialogState(() => _selectedExpiryDate = picked);
  }

  // Add items to shoppingList
  Future<void> _addToShoppingList(PantryItem item) async {
  final quantityController = TextEditingController(text: '1');
  String? selectedUnit;
  final unitController = TextEditingController();

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text('Add ${item.name} to Shopping List'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedUnit,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Stick(s)', child: Text('Stick(s)')),
                  DropdownMenuItem(value: 'Bag(s)', child: Text('Bag(s)')),
                  DropdownMenuItem(value: 'Box(es)', child: Text('Box(es)')),
                  DropdownMenuItem(
                    value: 'Container(s)', 
                    child: Text('Container(s)'),
                  ),
                  DropdownMenuItem(
                    value: 'Piece(s)', 
                    child: Text('Piece(s)'),
                  ),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedUnit = value;
                    if (value != 'Other') {
                      unitController.text = value ?? '';
                    }
                  });
                },
              ),
              if (selectedUnit == 'Other')
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: TextField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'Custom Unit',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final quantity = int.tryParse(quantityController.text) ?? 1;
                if (quantity > 0) {
                  try {
                    final unit = selectedUnit == 'Other'
                        ? unitController.text.trim()
                        : selectedUnit ?? item.category;

                    await Supabase.instance.client.from('shopping_list').insert({
                      'name': item.name,
                      'quantity': quantity,
                      'unit': unit,
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Added $quantity ${unit.isEmpty ? item.name : '$unit of ${item.name}'} to shopping list',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to add item: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    ),
  );
}

  List<PantryItem> get _filteredItems {
    return _pantryItems.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesCategory =
          _selectedCategory == 'All Categories' ||
          item.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<String> get _categories {
    final categories =
        _pantryItems.map((item) => item.category).toSet().toList();
    categories.sort();
    return ['All Categories', ...categories];
  }

  void _showAddItemDialog({String? barcode, PantryItem? editItem}) {
    if (editItem != null) {
      _nameController.text = editItem.name;
      _categoryController.text = editItem.category;
      _quantityController.text = editItem.quantity.toString();
      _selectedExpiryDate = editItem.expiryDate;
    } else {
      _clearForm();
    }

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editItem != null
                              ? 'Edit Pantry Item'
                              : barcode != null
                              ? 'Add Scanned Item'
                              : 'Add Pantry Item',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (barcode != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.qr_code,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Barcode: $barcode',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _buildTextField(
                          _nameController,
                          'Item Name',
                          Icons.shopping_basket_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _categoryController,
                          'Category',
                          Icons.category_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _quantityController,
                          'Quantity',
                          Icons.numbers,
                          isNumber: true,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () => _selectExpiryDate(setDialogState),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 20,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Expiry Date (Optional)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedExpiryDate != null
                                            ? DateFormat(
                                              'MMM dd, yyyy',
                                            ).format(_selectedExpiryDate!)
                                            : 'Select expiry date',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color:
                                              _selectedExpiryDate != null
                                                  ? Colors.black87
                                                  : Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_selectedExpiryDate != null)
                                  IconButton(
                                    onPressed:
                                        () => setDialogState(
                                          () => _selectedExpiryDate = null,
                                        ),
                                    icon: const Icon(Icons.clear, size: 20),
                                    color: Colors.grey[600],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _clearForm();
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final name = _nameController.text.trim();
                                  final cat = _categoryController.text.trim();
                                  final qty =
                                      int.tryParse(_quantityController.text) ??
                                      1;
                                  if (name.isNotEmpty && cat.isNotEmpty) {
                                    if (editItem != null) {
                                      final updated = editItem.copyWith(
                                        name: name,
                                        category: cat,
                                        quantity: qty,
                                        expiryDate: _selectedExpiryDate,
                                      );
                                      _updatePantryItem(updated);
                                    } else {
                                      _addPantryItem(
                                        name,
                                        cat,
                                        qty,
                                        _selectedExpiryDate,
                                        barcode: barcode,
                                      );
                                    }
                                    Navigator.pop(context);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  editItem != null ? 'Update' : 'Add',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          labelStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    final expired = filteredItems.where((i) => i.isExpired).toList();
    final soon =
        filteredItems.where((i) => i.isExpiringSoon && !i.isExpired).toList();
    final fresh =
        filteredItems.where((i) => !i.isExpired && !i.isExpiringSoon).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Pantry',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPantryItems,
        child: Column(
          children: [
            // Search and Filter Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      onChanged:
                          (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search pantry items...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        hintStyle: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items:
                            _categories
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) =>
                                setState(() => _selectedCategory = value!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Items List
            Expanded(
              child:
                  _pantryItems.isEmpty
                      ? _buildEmptyState()
                      : filteredItems.isEmpty
                      ? _buildNoResultsState()
                      : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          if (expired.isNotEmpty) ...[
                            _buildSectionHeader(
                              'Expired Items',
                              expired.length,
                              const Color(0xFFE53E3E),
                            ),
                            const SizedBox(height: 12),
                            ...expired.map(
                              (item) => _buildPantryItemCard(item),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (soon.isNotEmpty) ...[
                            _buildSectionHeader(
                              'Expiring Soon',
                              soon.length,
                              const Color(0xFFFF9500),
                            ),
                            const SizedBox(height: 12),
                            ...soon.map((item) => _buildPantryItemCard(item)),
                            const SizedBox(height: 24),
                          ],
                          if (fresh.isNotEmpty) ...[
                            _buildSectionHeader(
                              'Fresh Items',
                              fresh.length,
                              const Color(0xFF4CAF50),
                            ),
                            const SizedBox(height: 12),
                            ...fresh.map((item) => _buildPantryItemCard(item)),
                          ],
                        ],
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddItemDialog(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.kitchen_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your pantry is empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add items using the + button or scan barcodes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            const Text(
              'No items found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try adjusting your search or filter criteria',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$title ($count)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPantryItemCard(PantryItem item) {
    Color? statusColor;
    if (item.isExpired) {
      statusColor = const Color(0xFFE53E3E);
    } else if (item.isExpiringSoon) {
      statusColor = const Color(0xFFFF9500);
    }

    return InkWell(
      onTap: () => _showAddItemDialog(editItem: item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              statusColor != null
                  ? Border.all(color: statusColor.withOpacity(0.3))
                  : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (statusColor != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        decoration:
                            item.isExpired ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  _buildQuantityBadge(item),
                  const SizedBox(width: 8),
                  _buildMoreMenu(item),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (item.expiryDate != null)
                    Text(
                      DateFormat('MMM dd, yyyy').format(item.expiryDate!),
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor ?? Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              if (item.barcode != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.qr_code, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      item.barcode!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityBadge(PantryItem item) {
    return InkWell(
      onTap: () => _showQuantityDialog(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '${item.quantity}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2196F3),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenu(PantryItem item) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder:
          (_) => [
            
            PopupMenuItem(
              value: 'add_to_list',
              child: Row(
                children: const [
                  Icon(Icons.add_shopping_cart, size: 18, color: Colors.green),
                  SizedBox(width: 12),
                  Text('Add to Shopping List'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: const [
                  Icon(
                    Icons.delete_outline,
                    color: Color(0xFFE53E3E),
                    size: 18,
                  ),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Color(0xFFE53E3E))),
                ],
              ),
            ),
          ],
      onSelected: (value) async {
        if (value == 'edit') {
          _showAddItemDialog(editItem: item);
        } else if (value == 'delete') {
          _deleteItem(item.id!);
        } else if (value == 'add_to_list') {
          await _addToShoppingList(item);
        }
      },
    );
  }

  void _showQuantityDialog(PantryItem item) {
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Quantity',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(
                          Icons.numbers,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final newQty =
                                int.tryParse(qtyCtrl.text) ?? item.quantity;
                            if (newQty > 0) {
                              _updatePantryItem(
                                item.copyWith(quantity: newQty),
                              );
                            } else {
                              _deleteItem(item.id!);
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Update',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}
