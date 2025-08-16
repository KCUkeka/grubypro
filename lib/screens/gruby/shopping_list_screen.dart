import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<Map<String, dynamic>> _items = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _unitController = TextEditingController();

  // Unit types
  final List<String> _unitOptions = [
    "Stick(s)",
    "Bag(s)",
    "Box(es)",
    "Container(s)",
    "Piece(s)",
    "Packet(s)",
    "Dozen",
    "Gallon",
    "Pair",
    "Other",
  ];

  String? _selectedUnit;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  // Adding to Pantry list
  Future<bool> _addToPantry(Map<String, dynamic> item) async {
    bool success = false;
    final quantityController = TextEditingController(
      text: item['quantity'].toString(),
    );
    String? selectedCategory = "Other"; // Default category
    DateTime? selectedExpiryDate;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('Add ${item['name']} to Pantry'),
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
                      value: selectedCategory,
                      items: const [
                        DropdownMenuItem(
                          value: 'Fruits',
                          child: Text('Fruits'),
                        ),
                        DropdownMenuItem(
                          value: 'Vegetables',
                          child: Text('Vegetables'),
                        ),
                        DropdownMenuItem(value: 'Dairy', child: Text('Dairy')),
                        DropdownMenuItem(value: 'Meat', child: Text('Meat')),
                        DropdownMenuItem(
                          value: 'Dry Goods',
                          child: Text('Dry Goods'),
                        ),
                        DropdownMenuItem(
                          value: 'Baking',
                          child: Text('Baking'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged:
                          (value) => setState(() => selectedCategory = value),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 7),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 2),
                          ),
                        );
                        if (picked != null) {
                          setState(() => selectedExpiryDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Expiry Date (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedExpiryDate != null
                                  ? DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(selectedExpiryDate!)
                                  : 'Select date',
                            ),
                            Icon(Icons.calendar_today, color: Colors.grey[600]),
                          ],
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
                      final quantity =
                          int.tryParse(quantityController.text) ?? 1;
                      if (quantity > 0) {
                        try {
                          await Supabase.instance.client.from('pantry_items').insert({
                            'name': item['name'],
                            'quantity': quantity,
                            'category': selectedCategory,
                            'expiry_date':
                                selectedExpiryDate?.toIso8601String(),
                            'added_at': DateTime.now().toIso8601String(),
                          });

                          success = true;
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to add to pantry: ${e.toString()}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    child: const Text('Add to Pantry'),
                  ),
                ],
              );
            },
          ),
    );
    return success;
  }

  Future<void> _loadItems() async {
    final response = await Supabase.instance.client
        .from('shopping_list')
        .select('id, name, quantity, unit')
        .order('created_at', ascending: false);

    setState(() {
      _items = List<Map<String, dynamic>>.from(response);
    });
  }
  //Plural helper function:

  String formatUnit(String unit, int quantity) {
    if (unit.isEmpty) return 'Pcs';
    // Handle units that don't change with quantity
    final unchangeableUnits = ["Dozen", "Gallon", "Pair"];
    if (unchangeableUnits.contains(unit)) return unit;
    // Handle irregular plurals
    final irregulars = {
      "Loaf": "Loaves",
      "Leaf": "Leaves",
      "Box": "Boxes",
      "Piece": "Pieces",
      "Other": "Others",
    };

    if (quantity > 1 && irregulars.containsKey(unit)) {
      return irregulars[unit]!;
    }

    // Handle cases like Stick(s), Bag(s), Container(s), Piece(s)
    if (unit.contains("(s)")) {
      final base = unit.replaceAll("(s)", "");
      return quantity > 1 ? "${base}s" : base;
    }

    // Handle cases like Box(es)
    if (unit.contains("(es)")) {
      final base = unit.replaceAll("(es)", "");
      return quantity > 1 ? "${base}es" : base;
    }

    // Default: return unchanged for quantity = 1, add 's' for quantity > 1
    return quantity > 1 ? "${unit}s" : unit;
  }

  Future<void> _addItem() async {
    final itemName = _nameController.text.trim();
    final quantityText = _quantityController.text.trim();
    final quantity = int.tryParse(quantityText) ?? 1;

    // Get the base unit (without pluralization)
    String unitText =
        _selectedUnit == "Other"
            ? _unitController.text.trim()
            : _selectedUnit ?? "";

    if (itemName.isEmpty || quantity <= 0) return;

    try {
      final response =
          await Supabase.instance.client.from('shopping_list').insert({
            'name': itemName,
            'quantity': quantity,
            'unit': unitText,
          }).select();

      final data = response as List<dynamic>;

      if (data.isEmpty) {
        print('❌ Insert returned no data.');
        return;
      }

      setState(() {
        _items.insert(0, data.first as Map<String, dynamic>);
        _nameController.clear();
        _quantityController.text = '1';
        _unitController.clear();
        _selectedUnit = null;
      });
    } catch (e) {
      print('❌ Insert error: $e');
    }
  }

  Future<void> _removeItem(int index) async {
    final item = _items[index];
    final itemId = item['id'];

    await Supabase.instance.client
        .from('shopping_list')
        .delete()
        .eq('id', itemId);

    setState(() {
      _items.removeAt(index);
    });
  }

  // Edit Items
  Future<void> _editItem(int index) async {
    final item = _items[index];

    // Pre-fill controllers
    _nameController.text = item['name'];
    _quantityController.text = item['quantity'].toString();
    _selectedUnit =
        _unitOptions.contains(item['unit']) ? item['unit'] : "Other";
    _unitController.text = _selectedUnit == "Other" ? item['unit'] ?? "" : "";

    // Show dialog to update
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                items:
                    _unitOptions
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                onChanged: (val) {
                  setState(() => _selectedUnit = val);
                },
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
              if (_selectedUnit == "Other")
                TextField(
                  controller: _unitController,
                  decoration: const InputDecoration(labelText: 'Custom Unit'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _nameController.clear();
                _quantityController.text = '1';
                _unitController.clear();
                _selectedUnit = null;
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = _nameController.text.trim();
                final newQty =
                    int.tryParse(_quantityController.text.trim()) ?? 1;
                final newUnit =
                    _selectedUnit == "Other"
                        ? _unitController.text.trim()
                        : _selectedUnit ?? "";

                if (newName.isEmpty || newQty <= 0) return;

                try {
                  await Supabase.instance.client
                      .from('shopping_list')
                      .update({
                        'name': newName,
                        'quantity': newQty,
                        'unit': newUnit,
                      })
                      .eq('id', item['id']);

                  setState(() {
                    _items[index]['name'] = newName;
                    _items[index]['quantity'] = newQty;
                    _items[index]['unit'] = newUnit;
                  });
                } catch (e) {
                  print('❌ Update error: $e');
                }

                _nameController.clear();
                _quantityController.text = '1';
                _unitController.clear();
                _selectedUnit = null;
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Shopping List',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _items.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final quantity = item['quantity'] ?? 1;
                        final unit = item['unit'] ?? "";
                        final formattedUnit = formatUnit(unit, quantity);

                        return Dismissible(
                          key: Key(item['id'].toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.green,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(
                                  Icons.kitchen,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Add to Pantry',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 16),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            await _addToPantry(item);
                            return false; // We'll handle dismissal in the _addToPantry method
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _editItem(index),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.shopping_bag_outlined,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Quantity: $quantity ${formattedUnit.isNotEmpty ? formattedUnit : ''}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Colors.grey,
                                      ),
                                      itemBuilder:
                                          (context) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit,
                                                    size: 20,
                                                    color: Colors.grey,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Edit'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.delete,
                                                    size: 20,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _editItem(index);
                                        } else if (value == 'delete') {
                                          _removeItem(index);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          _buildInputForm(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
        const SizedBox(height: 24),
        Text(
          'Your shopping list is empty',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add items to your shopping list using the form\nbelow',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
      ],
    ),
  );

  Widget _buildInputForm() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedUnit,
          items:
              _unitOptions
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
          onChanged: (val) {
            setState(() => _selectedUnit = val);
          },
          decoration: const InputDecoration(labelText: 'Unit'),
        ),
        if (_selectedUnit == "Other")
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Custom Unit',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            label: const Text(
              'Add Item',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }
}
