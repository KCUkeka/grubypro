import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// *************************************CART PAGE********************************

class SaleCalculator extends StatefulWidget {
  final Map<String, dynamic>? existingSale;

  const SaleCalculator({super.key, this.existingSale});

  @override
  State<SaleCalculator> createState() => _SaleCalculator();
}

class _SaleCalculator extends State<SaleCalculator> {
  final List<CartItem> _cartItems = [];
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _taxController = TextEditingController(text: '1.75');

  String? _saleId;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  final _supabase = Supabase.instance.client;

  // New variables for product management
  List<String> _availableProducts = [];
  String? _selectedProduct;
  bool _isCustomProduct = false;
  bool _isLoadingProducts = true;
  
  // New variable for macaron size selection
  String? _selectedMacaronSize;

  double get _subtotal {
    return _cartItems.fold(
      0,
      (sum, item) => sum + (item.quantity * item.price),
    );
  }

  double get _taxRate => double.tryParse(_taxController.text) ?? 0;
  double get _taxAmount => _subtotal * (_taxRate / 100);
  double get _total => _subtotal + _taxAmount;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    
    // Load existing sale data if editing
    if (widget.existingSale != null) {
      _loadExistingSale();
    }
  }

  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoadingProducts = true);
      
      // Fetch distinct product names from existing sales
      final response = await _supabase
          .from('sale_items')
          .select('product_name')
          .order('product_name');
      
      if (response.isNotEmpty) {
        final products = response
            .map<String>((item) => item['product_name'] as String)
            .toSet() // Remove duplicates
            .toList()
          ..sort();
        
        setState(() {
          _availableProducts = products;
        });
      }
    } catch (e) {
      print('Error loading products: $e');
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  void _loadExistingSale() {
    final sale = widget.existingSale!;
    _saleId = sale['id'];
    _selectedDate = DateTime.parse(sale['sale_date']);
    _taxController.text = (sale['tax_rate'] as num).toStringAsFixed(2);

    // Load items
    final items = List<Map<String, dynamic>>.from(sale['sale_items'] ?? []);
    for (var item in items) {
      _cartItems.add(CartItem(
        name: item['product_name'],
        price: (item['price'] as num).toDouble(),
        quantity: item['quantity'] as int,
      ));
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(_saleId != null ? 'Edit Sale' : 'Shopping Cart'),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.white,
        actions: [
          if (_cartItems.isNotEmpty)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _saveSale,
                    tooltip: 'Save Sale',
                  ),
        ],
      ),
      body: isWideScreen ? _buildWideLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 1, child: _buildProductsSection()),
        Container(width: 1, color: Colors.grey[300]),
        Expanded(flex: 1, child: _buildCartSection()),
      ],
    );
  }

Widget _buildMobileLayout() {
  return Column(
    children: [
      // Products Section - Reduced height for mobile
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.4, // Reduced from 50% to 40%
        child: _buildProductsSection(),
      ),
      Divider(thickness: 2, color: Colors.grey[300]),
      // Cart Section - More space now (60% instead of 50%)
      Expanded(
        child: _buildCartSection(),
      ),
    ],
  );
}

  Widget _buildProductsSection() {
  final isMobile = MediaQuery.of(context).size.width <= 600;
  
  return Container(
    color: Colors.grey[50],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Smaller header for mobile
        Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Text(
            'Products',
            style: TextStyle(
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        // More compact form for mobile
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Product Selection
                      _buildProductInputField(),
                      SizedBox(height: isMobile ? 12 : 16),
                      
                      // Price Input
                      TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Price',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.attach_money),
                          isDense: isMobile, // Reduces height on mobile
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      ),
                      SizedBox(height: isMobile ? 12 : 16),
                      
                      // Add to Cart Button
                      ElevatedButton.icon(
                        onPressed: _addToCart,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Add to Cart'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      
                      // Recent Products (only show if there's space)
                      if (_availableProducts.isNotEmpty) ...[
                        SizedBox(height: isMobile ? 12 : 16),
                        _buildRecentProducts(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildProductInputField() {
  // Define the main product options
  final mainProducts = ['Cake Pop', 'Macaron', 'Cake Jar'];
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Dropdown with custom option
      DropdownButtonFormField<String>(
        value: _isCustomProduct ? null : _selectedProduct,
        decoration: InputDecoration(
          labelText: 'Product Name',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          prefixIcon: const Icon(Icons.shopping_bag),
        ),
        items: [
          // Main product options
          ...mainProducts.map((product) {
            return DropdownMenuItem(
              value: product,
              child: Text(product),
            );
          }).toList(),
          
          // Separator
          const DropdownMenuItem(
            value: '__divider__',
            enabled: false,
            child: Divider(),
          ),
          
          // Custom product option
          const DropdownMenuItem(
            value: '__custom__',
            child: Row(
              children: [
                Icon(Icons.create, size: 18),
                SizedBox(width: 8),
                Text('Add custom product...'),
              ],
            ),
          ),
          
          // Another separator
          const DropdownMenuItem(
            value: '__divider2__',
            enabled: false,
            child: Divider(),
          ),
          
          // Available products from database (excluding main products)
          ..._availableProducts.where((product) => !mainProducts.contains(product)).map((product) {
            return DropdownMenuItem(
              value: product,
              child: Text(product),
            );
          }).toList(),
        ],
        onChanged: (String? value) {
          if (value == '__custom__') {
            setState(() {
              _isCustomProduct = true;
              _selectedProduct = null;
              _selectedVariant = null;
              _nameController.clear();
              _priceController.clear();
            });
          } else if (value != null && value != '__divider__' && value != '__divider2__') {
            setState(() {
              _isCustomProduct = false;
              _selectedProduct = value;
              _nameController.text = value;
              _selectedVariant = null; // Reset variant when product changes
              
              // Auto-fill price based on product type
              _autoFillPrice(value);
            });
          }
        },
        validator: (value) {
          if (!_isCustomProduct && (value == null || value.isEmpty)) {
            return 'Please select a product';
          }
          if (_isCustomProduct && _nameController.text.isEmpty) {
            return 'Please enter a product name';
          }
          return null;
        },
      ),
      
      // Custom product text field (shown when custom is selected)
      if (_isCustomProduct) ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Custom Product Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.create),
          ),
          onChanged: (value) {
            // Auto-fill price for custom products that match known types
            if (value.isNotEmpty) {
              _autoFillPrice(value);
            }
          },
          validator: (v) => _isCustomProduct && (v?.isEmpty ?? true) 
              ? 'Required' 
              : null,
        ),
      ],
      
      // Macaron Variant Selection
      if (_selectedProduct == 'Macaron') ...[
        const SizedBox(height: 12),
        Text(
          'Macaron Size:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Medium (\$3.50)'),
              selected: _selectedVariant == 'Medium',
              onSelected: (selected) {
                setState(() {
                  _selectedVariant = 'Medium';
                  _priceController.text = '3.50';
                });
              },
              selectedColor: const Color(0xFFD4AF37).withOpacity(0.3),
              checkmarkColor: const Color(0xFFD4AF37),
            ),
            ChoiceChip(
              label: const Text('Large (\$4.00)'),
              selected: _selectedVariant == 'Large',
              onSelected: (selected) {
                setState(() {
                  _selectedVariant = 'Large';
                  _priceController.text = '4.00';
                });
              },
              selectedColor: const Color(0xFFD4AF37).withOpacity(0.3),
              checkmarkColor: const Color(0xFFD4AF37),
            ),
            ChoiceChip(
              label: const Text('Bundle (\$10.00)'),
              selected: _selectedVariant == 'Bundle',
              onSelected: (selected) {
                setState(() {
                  _selectedVariant = 'Bundle';
                  _priceController.text = '10.00';
                });
              },
              selectedColor: const Color(0xFFD4AF37).withOpacity(0.3),
              checkmarkColor: const Color(0xFFD4AF37),
            ),
          ],
        ),
      ],
      
      // Cake Jar Variant Selection
      if (_selectedProduct == 'Cake Jar') ...[
        const SizedBox(height: 12),
        Text(
          'Cake Jar Option:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Regular (\$9.50)'),
              selected: _selectedVariant == 'Regular',
              onSelected: (selected) {
                setState(() {
                  _selectedVariant = 'Regular';
                  _priceController.text = '9.50';
                });
              },
              selectedColor: const Color(0xFFD4AF37).withOpacity(0.3),
              checkmarkColor: const Color(0xFFD4AF37),
            ),
            ChoiceChip(
              label: const Text('Bundle (\$18.00)'),
              selected: _selectedVariant == 'Bundle',
              onSelected: (selected) {
                setState(() {
                  _selectedVariant = 'Bundle';
                  _priceController.text = '18.00';
                });
              },
              selectedColor: const Color(0xFFD4AF37).withOpacity(0.3),
              checkmarkColor: const Color(0xFFD4AF37),
            ),
          ],
        ),
      ],
      
      // Cake Pop Auto-price (no variant selection needed)
      if (_selectedProduct == 'Cake Pop') ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.attach_money, color: Colors.green[700], size: 16),
              const SizedBox(width: 8),
              Text(
                'Price automatically set to \$4.00',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
  // Add this variable to your state class
String? _selectedVariant;

void _autoFillPrice(String productName) {
  setState(() {
    switch (productName) {
      case 'Cake Pop':
        _priceController.text = '4.00';
        _selectedVariant = null; // No variant for cake pops
        break;
      case 'Macaron':
        // Don't auto-fill price until variant is selected
        // Set default to Medium if no variant selected
        if (_selectedVariant == null) {
          _selectedVariant = 'Medium';
          _priceController.text = '3.50';
        }
        break;
      case 'Cake Jar':
        // Don't auto-fill price until variant is selected
        // Set default to Regular if no variant selected
        if (_selectedVariant == null) {
          _selectedVariant = 'Regular';
          _priceController.text = '9.50';
        }
        break;
      default:
        // For custom products, try to find the most recent price
        _setPriceForProduct(productName);
        _selectedVariant = null;
    }
  });
}

  Widget _buildRecentProducts() {
  final isMobile = MediaQuery.of(context).size.width <= 600;
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Recent Products:',
        style: TextStyle(
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: isMobile ? 60 : null, // Fixed height on mobile
        child: SingleChildScrollView(
          scrollDirection: isMobile ? Axis.horizontal : Axis.vertical,
          child: isMobile 
              ? Row(
                  children: _availableProducts.take(6).map((product) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(
                          product,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            _isCustomProduct = false;
                            _selectedProduct = product;
                            _nameController.text = product;
                            _selectedVariant = null;
                            _autoFillPrice(product);
                          });
                        },
                        backgroundColor: _selectedProduct == product 
                            ? const Color(0xFFD4AF37).withOpacity(0.2)
                            : Colors.grey[200],
                      ),
                    );
                  }).toList(),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableProducts.take(6).map((product) {
                    return InputChip(
                      label: Text(product),
                      onPressed: () {
                        setState(() {
                          _isCustomProduct = false;
                          _selectedProduct = product;
                          _nameController.text = product;
                          _selectedVariant = null;
                          _autoFillPrice(product);
                        });
                      },
                      backgroundColor: _selectedProduct == product 
                          ? const Color(0xFFD4AF37).withOpacity(0.2)
                          : Colors.grey[200],
                    );
                  }).toList(),
                ),
        ),
      ),
    ],
  );
}

  void _setPriceForProduct(String productName) {
    // Try to find the most recent price for this product
    try {
      final existingItem = _cartItems.firstWhere(
        (item) => item.name.toLowerCase() == productName.toLowerCase(),
        orElse: () => CartItem(name: '', price: 0, quantity: 0),
      );
      
      if (existingItem.name.isNotEmpty) {
        _priceController.text = existingItem.price.toStringAsFixed(2);
        return;
      }
    } catch (e) {
      // Ignore error and proceed
    }
    
    // If not found in current cart, clear the price field
    _priceController.clear();
  }

  // Rest of your existing methods remain mostly the same...
  // Only _addToCart needs modification to include size in product name

  Widget _buildCartSection() {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final isWideScreen = screenWidth > 600;
  
  return Container(
    color: Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with date picker
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Cart',
                style: TextStyle(
                  fontSize: isWideScreen ? 22 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD4AF37)),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFD4AF37).withOpacity(0.1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: isWideScreen ? 16 : 14,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: TextStyle(
                          fontSize: isWideScreen ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Cart items or empty state
        if (_cartItems.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: isWideScreen ? 80 : 60,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: isWideScreen ? 18 : 16,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add products to get started',
                    style: TextStyle(
                      fontSize: isWideScreen ? 14 : 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          // Cart items list with flexible height
          Expanded(
            child: Column(
              children: [
                // Cart items header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Items (${_cartItems.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                          fontSize: isWideScreen ? 16 : 14,
                        ),
                      ),
                      Text(
                        'Quantity',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                          fontSize: isWideScreen ? 16 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Scrollable cart items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Product info
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: isWideScreen ? 16 : 14,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        maxLines: 2,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '\$${item.price.toStringAsFixed(2)} each',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: isWideScreen ? 14 : 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total: \$${(item.quantity * item.price).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: const Color(0xFFD4AF37),
                                          fontWeight: FontWeight.bold,
                                          fontSize: isWideScreen ? 14 : 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Quantity controls
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.remove, 
                                                  size: isWideScreen ? 20 : 18),
                                              onPressed: () => _decrementQuantity(index),
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              padding: EdgeInsets.zero,
                                            ),
                                            Text(
                                              '${item.quantity}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isWideScreen ? 16 : 14,
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.add, 
                                                  size: isWideScreen ? 20 : 18),
                                              onPressed: () => _incrementQuantity(index),
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: TextButton.icon(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: isWideScreen ? 16 : 14,
                                          ),
                                          label: Text(
                                            'Remove',
                                            style: TextStyle(
                                              fontSize: isWideScreen ? 12 : 10,
                                            ),
                                          ),
                                          onPressed: () => _removeFromCart(index),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        // Summary section - only show if there are items
        if (_cartItems.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                _summaryRow('Subtotal', _subtotal, isWideScreen: isWideScreen),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text('Tax Rate', style: TextStyle(
                        fontSize: isWideScreen ? 16 : 14
                      )),
                    ),
                    SizedBox(
                      width: isWideScreen ? 80 : 70,
                      height: 40,
                      child: TextFormField(
                        controller: _taxController,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          suffixText: '%',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        onChanged: (value) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Tax: \$${_taxAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: isWideScreen ? 16 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, thickness: 2),
                _summaryRow('Total', _total, 
                    isTotal: true, isWideScreen: isWideScreen),
              ],
            ),
          ),
      ],
    ),
  );
}

  Widget _summaryRow(String label, double amount, 
    {bool isTotal = false, bool isWideScreen = true}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: isTotal 
              ? (isWideScreen ? 20 : 18) 
              : (isWideScreen ? 16 : 14),
          fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      Text(
        '\$${amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: isTotal 
              ? (isWideScreen ? 24 : 20) 
              : (isWideScreen ? 16 : 14),
          fontWeight: FontWeight.bold,
          color: isTotal ? const Color(0xFFD4AF37) : Colors.black87,
        ),
      ),
    ],
  );
}

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addToCart() {
  if (_formKey.currentState!.validate()) {
    String name = _nameController.text;
    final price = double.parse(_priceController.text);

    // Add variant to product name if applicable
    if ((_selectedProduct == 'Macaron' || _selectedProduct == 'Cake Jar') && 
        _selectedVariant != null) {
      name = '$_selectedProduct ($_selectedVariant)';
    }

    final existingIndex = _cartItems.indexWhere(
      (item) => item.name.toLowerCase() == name.toLowerCase(),
    );

    setState(() {
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity++;
      } else {
        _cartItems.add(CartItem(name: name, price: price, quantity: 1));
        
        // Add to available products if it's a new product
        if (!_availableProducts.contains(name)) {
          _availableProducts.add(name);
          _availableProducts.sort();
        }
      }

      // Reset form
      _nameController.clear();
      _priceController.clear();
      _selectedProduct = null;
      _isCustomProduct = false;
      _selectedVariant = null;
    });
  }
}

  void _incrementQuantity(int index) {
    setState(() {
      _cartItems[index].quantity++;
    });
  }

  void _decrementQuantity(int index) {
    setState(() {
      if (_cartItems[index].quantity > 1) {
        _cartItems[index].quantity--;
      } else {
        _removeFromCart(index);
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _saveSale() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_saleId != null) {
        // UPDATE existing sale
        await _supabase.from('sales').update({
          'sale_date': _selectedDate.toIso8601String().split('T')[0],
          'subtotal': _subtotal,
          'tax_amount': _taxAmount,
          'tax_rate': _taxRate,
          'total': _total,
        }).eq('id', _saleId!);

        // Delete old items
        await _supabase.from('sale_items').delete().eq('sale_id', _saleId!);

        // Insert new items
        final saleItemsData = _cartItems.map((item) {
          return {
            'sale_id': _saleId,
            'product_name': item.name,
            'quantity': item.quantity,
            'price': item.price,
            'line_total': item.quantity * item.price,
          };
        }).toList();

        await _supabase.from('sale_items').insert(saleItemsData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Sale updated successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // CREATE new sale
        final saleResponse = await _supabase
            .from('sales')
            .insert({
              'sale_date': _selectedDate.toIso8601String().split('T')[0],
              'subtotal': _subtotal,
              'tax_amount': _taxAmount,
              'tax_rate': _taxRate,
              'total': _total,
            })
            .select()
            .single();

        final saleId = saleResponse['id'];

        final saleItemsData = _cartItems.map((item) {
          return {
            'sale_id': saleId,
            'product_name': item.name,
            'quantity': item.quantity,
            'price': item.price,
            'line_total': item.quantity * item.price,
          };
        }).toList();

        await _supabase.from('sale_items').insert(saleItemsData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Sale saved! Total: \$${_total.toStringAsFixed(2)}'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving sale: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _taxController.dispose();
    super.dispose();
  }
}

class CartItem {
  final String name;
  final double price;
  int quantity;

  CartItem({required this.name, required this.price, required this.quantity});
}