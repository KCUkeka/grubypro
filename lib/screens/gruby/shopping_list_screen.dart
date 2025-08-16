import 'package:flutter/material.dart';
import 'package:grubypro/screens/app_bar.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _purchasedItems = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _unitController = TextEditingController();
  late TabController _tabController;

  Map<String, dynamic>? _lastPurchasedItem;
  int? _lastPurchasedIndex;

  // Unit types
  final List<String> _unitOptions = [
    "Stick(s)",
    "Bag(s)",
    "Box(es)",
    "Container(s)",
    "Piece(s)",
    "Packet(s)",
    "Bottle(s)",
    "Dozen",
    "Gallon",
    "Pair",
    "Other",
  ];

  String? _selectedUnit;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadItems();
    _loadPurchasedItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final response = await Supabase.instance.client
        .from('shopping_list')
        .select('id, name, quantity, unit, is_purchased')
        .eq('is_purchased', false)
        .order('created_at', ascending: false);

    setState(() {
      _items = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _undoPurchase() async {
    if (_lastPurchasedItem == null || _lastPurchasedIndex == null) return;

    await Supabase.instance.client
        .from('shopping_list')
        .update({'is_purchased': false})
        .eq('id', _lastPurchasedItem!['id']);

    setState(() {
      // Remove from purchased items
      _purchasedItems.removeWhere(
        (item) => item['id'] == _lastPurchasedItem!['id'],
      );

      // Add back to active items at original position
      _items.insert(_lastPurchasedIndex!, _lastPurchasedItem!);

      // Clear the undo cache
      _lastPurchasedItem = null;
      _lastPurchasedIndex = null;
    });
  }
Future<void> _undoMarkAsActive() async {
  if (_lastPurchasedItem == null || _lastPurchasedIndex == null) return;

  await Supabase.instance.client
      .from('shopping_list')
      .update({'is_purchased': true})
      .eq('id', _lastPurchasedItem!['id']);

  setState(() {
    // Remove from active items
    _items.removeWhere((item) => item['id'] == _lastPurchasedItem!['id']);
    
    // Add back to purchased items at original position
    _purchasedItems.insert(_lastPurchasedIndex!, _lastPurchasedItem!);
    
    // Clear the undo cache
    _lastPurchasedItem = null;
    _lastPurchasedIndex = null;
  });
}

  Future<void> _loadPurchasedItems() async {
    final response = await Supabase.instance.client
        .from('shopping_list')
        .select('id, name, quantity, unit, is_purchased')
        .eq('is_purchased', true)
        .order('created_at', ascending: false);

    setState(() {
      _purchasedItems = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _markAsPurchased(int index) async {
    final item = _items[index];
    _lastPurchasedItem = Map<String, dynamic>.from(item);
    _lastPurchasedIndex = index;

    await Supabase.instance.client
        .from('shopping_list')
        .update({'is_purchased': true})
        .eq('id', item['id']);

    setState(() {
      _items.removeAt(index);
      _purchasedItems.insert(0, item);
    });
    // Show undo snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item['name']} marked as purchased'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () => _undoPurchase(),
        ),
      ),
    );
  }

  Future<void> _markAsActive(int index) async {
    final item = _purchasedItems[index];
    _lastPurchasedItem = Map<String, dynamic>.from(item); 
    _lastPurchasedIndex = index;

    await Supabase.instance.client
        .from('shopping_list')
        .update({'is_purchased': false})
        .eq('id', item['id']);

    setState(() {
      _purchasedItems.removeAt(index);
      _items.insert(0, item);
    });
    // Show undo snackbar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${item['name']} marked as active'),
      backgroundColor: Colors.blue,
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'UNDO',
        textColor: Colors.white,
        onPressed: () => _undoMarkAsActive(),
      ),
    ),
  );
  }

  Future<bool> _addToPantry(Map<String, dynamic> item) async {
    bool success = false;
    final quantityController = TextEditingController(
      text: item['quantity'].toString(),
    );
    String? selectedCategory = "Other";
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
                          await Supabase.instance.client
                              .from('pantry_items')
                              .insert({
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

  String formatUnit(String unit, int quantity) {
    if (unit.isEmpty) return 'Pcs';
    final unchangeableUnits = ["Dozen", "Gallon", "Pair"];
    if (unchangeableUnits.contains(unit)) return unit;

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

    if (unit.contains("(s)")) {
      final base = unit.replaceAll("(s)", "");
      return quantity > 1 ? "${base}s" : base;
    }

    if (unit.contains("(es)")) {
      final base = unit.replaceAll("(es)", "");
      return quantity > 1 ? "${base}es" : base;
    }

    return quantity > 1 ? "${unit}s" : unit;
  }

  Future<void> _addItem() async {
    final itemName = _nameController.text.trim();
    final quantityText = _quantityController.text.trim();
    final quantity = int.tryParse(quantityText) ?? 1;
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
            'is_purchased': false,
          }).select();

      final data = response as List<dynamic>;

      if (data.isEmpty) return;

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

  Future<void> _removeItem(int index, bool isPurchased) async {
    final item = isPurchased ? _purchasedItems[index] : _items[index];
    await Supabase.instance.client
        .from('shopping_list')
        .delete()
        .eq('id', item['id']);

    setState(() {
      isPurchased ? _purchasedItems.removeAt(index) : _items.removeAt(index);
    });
  }

  Future<void> _editItem(int index, bool isPurchased) async {
    final item = isPurchased ? _purchasedItems[index] : _items[index];
    _nameController.text = item['name'];
    _quantityController.text = item['quantity'].toString();
    _selectedUnit =
        _unitOptions.contains(item['unit']) ? item['unit'] : "Other";
    _unitController.text = _selectedUnit == "Other" ? item['unit'] ?? "" : "";

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
                onChanged: (val) => setState(() => _selectedUnit = val),
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
                Navigator.pop(context);
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
                    if (isPurchased) {
                      _purchasedItems[index]['name'] = newName;
                      _purchasedItems[index]['quantity'] = newQty;
                      _purchasedItems[index]['unit'] = newUnit;
                    } else {
                      _items[index]['name'] = newName;
                      _items[index]['quantity'] = newQty;
                      _items[index]['unit'] = newUnit;
                    }
                  });
                } catch (e) {
                  print('❌ Update error: $e');
                }

                _nameController.clear();
                _quantityController.text = '1';
                _unitController.clear();
                _selectedUnit = null;
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemCard(
    Map<String, dynamic> item,
    int index,
    bool isPurchased,
  ) {
    final quantity = item['quantity'] ?? 1;
    final unit = item['unit'] ?? "";
    final formattedUnit = formatUnit(unit, quantity);

    return Dismissible(
      key: Key(item['id'].toString()),
      direction:
          isPurchased
              ? DismissDirection.startToEnd
              : DismissDirection.endToStart,
      background: Container(
        alignment: isPurchased ? Alignment.centerLeft : Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: isPurchased ? Colors.blue : Colors.green,
        child: Row(
          mainAxisAlignment:
              isPurchased ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            Icon(
              isPurchased ? Icons.shopping_cart : Icons.check,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isPurchased ? 'Mark Active' : 'Mark Purchased',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (isPurchased) {
          await _markAsActive(index);
        } else {
          await _markAsPurchased(index);
        }
        return true;
      },
      onDismissed: (direction) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${item['name']} moved to ${isPurchased ? 'Active' : 'Purchased'}',
            ),
            backgroundColor: isPurchased ? Colors.blue : Colors.green,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _editItem(index, isPurchased),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  isPurchased
                      ? Icons.check_circle
                      : Icons.shopping_bag_outlined,
                  color: isPurchased ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          decoration:
                              isPurchased ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quantity: $quantity ${formattedUnit.isNotEmpty ? formattedUnit : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          decoration:
                              isPurchased ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                        if (!isPurchased)
                          const PopupMenuItem(
                            value: 'pantry',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.kitchen,
                                  size: 20,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 8),
                                Text('Add to Pantry'),
                              ],
                            ),
                          ),
                      ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editItem(index, isPurchased);
                    } else if (value == 'delete') {
                      _removeItem(index, isPurchased);
                    } else if (value == 'pantry') {
                      _addToPantry(item);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isPurchased) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isPurchased
              ? Icons.check_circle_outline
              : Icons.shopping_cart_outlined,
          size: 80,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 24),
        Text(
          isPurchased ? 'No purchased items' : 'Your shopping list is empty',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isPurchased
              ? 'Items you mark as purchased will appear here'
              : 'Add items to your shopping list using the form below',
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
          onChanged: (val) => setState(() => _selectedUnit = val),
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
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: CustomAppBar(
          title: const Text(
            'Shopping List',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'Active'), Tab(text: 'Purchased')],
            indicatorColor: Colors.green,
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Active Items Tab
            Column(
              children: [
                Expanded(
                  child:
                      _items.isEmpty
                          ? _buildEmptyState(false)
                          : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            itemBuilder:
                                (context, index) =>
                                    _buildItemCard(_items[index], index, false),
                          ),
                ),
                _buildInputForm(),
              ],
            ),
            // Purchased Items Tab
            _purchasedItems.isEmpty
                ? _buildEmptyState(true)
                : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _purchasedItems.length,
                  itemBuilder:
                      (context, index) =>
                          _buildItemCard(_purchasedItems[index], index, true),
                ),
          ],
        ),
      ),
    );
  }
}
