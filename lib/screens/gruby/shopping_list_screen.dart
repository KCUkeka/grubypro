import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final response = await Supabase.instance.client
        .from('shopping_list')
        .select('id, name, quantity')
        .order('created_at', ascending: false);

    setState(() {
      _items = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _addItem() async {
    final itemName = _nameController.text.trim();
    final quantityText = _quantityController.text.trim();
    final quantity = int.tryParse(quantityText) ?? 1;

    if (itemName.isEmpty || quantity <= 0) return;

    try {
      final response =
          await Supabase.instance.client.from('shopping_list').insert({
            'name': itemName,
            'quantity': quantity,
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

  Future<void> _editItem(int index) async {
    final item = _items[index];

    // Pre-fill controllers
    _nameController.text = item['name'];
    _quantityController.text = item['quantity'].toString();

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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _nameController.clear();
                _quantityController.text = '1';
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = _nameController.text.trim();
                final newQty =
                    int.tryParse(_quantityController.text.trim()) ?? 1;

                if (newName.isEmpty || newQty <= 0) return;

                try {
                  await Supabase.instance.client
                      .from('shopping_list')
                      .update({'name': newName, 'quantity': newQty})
                      .eq('id', item['id']);

                  setState(() {
                    _items[index]['name'] = newName;
                    _items[index]['quantity'] = newQty;
                  });
                } catch (e) {
                  print('❌ Update error: $e');
                }

                _nameController.clear();
                _quantityController.text = '1';
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
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.green,
                            ),
                            title: Text(
                              item['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Quantity: ${item['quantity'] ?? 1}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.orange,
                                  ),
                                  onPressed: () => _editItem(index),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => _removeItem(index),
                                ),
                              ],
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
    super.dispose();
  }
}
