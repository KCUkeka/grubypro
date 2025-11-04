import 'package:flutter/material.dart';
import 'package:grubypro/screens/ecb/sale_calculator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// *******************************SALE PAGE************************************
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _filteredSales = [];
  bool _isLoading = true;

  double _todayTotal = 0;
  double _weekTotal = 0;
  double _monthTotal = 0;

  // Filter state
  String _selectedFilter = 'Today'; // Default to Today
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _fetchSales();
  }

  Future<void> _fetchSales() async {
    setState(() => _isLoading = true);

    try {
      final data = await _supabase
          .from('sales')
          .select('*, sale_items(*)')
          .order('sale_date', ascending: false);

      setState(() {
        _sales = List<Map<String, dynamic>>.from(data);
        _calculateTotals();
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sales: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

// Filter for totals at the top
  void _calculateTotals() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    _todayTotal = 0;
    _weekTotal = 0;
    _monthTotal = 0;

    for (var sale in _sales) {
      final saleDate = DateTime.parse(sale['sale_date']);
      final total = (sale['total'] as num).toDouble();

      if (saleDate.isAfter(today.subtract(const Duration(days: 1)))) {
        _todayTotal += total;
      }
      if (saleDate.isAfter(weekAgo)) {
        _weekTotal += total;
      }
      if (saleDate.isAfter(monthStart.subtract(const Duration(days: 1)))) {
        _monthTotal += total;
      }
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      switch (_selectedFilter) {
        case 'Today':
          _filteredSales = _sales.where((sale) {
            final saleDate = DateTime.parse(sale['sale_date']);
            return saleDate.isAfter(today.subtract(const Duration(days: 1))) &&
                   saleDate.isBefore(today.add(const Duration(days: 1)));
          }).toList();
          break;
        case 'This Week':
          final weekAgo = today.subtract(const Duration(days: 7));
          _filteredSales = _sales.where((sale) {
            final saleDate = DateTime.parse(sale['sale_date']);
            return saleDate.isAfter(weekAgo);
          }).toList();
          break;
        case 'This Month':
          final monthStart = DateTime(now.year, now.month, 1);
          _filteredSales = _sales.where((sale) {
            final saleDate = DateTime.parse(sale['sale_date']);
            return saleDate.isAfter(monthStart.subtract(const Duration(days: 1)));
          }).toList();
          break;
        case 'Custom':
          if (_customDateRange != null) {
            _filteredSales = _sales.where((sale) {
              final saleDate = DateTime.parse(sale['sale_date']);
              return saleDate.isAfter(_customDateRange!.start.subtract(const Duration(days: 1))) &&
                     saleDate.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
            }).toList();
          } else {
            _filteredSales = _sales;
          }
          break;
        case 'All':
          _filteredSales = _sales;
          break;
        default:
          _filteredSales = _sales;
      }
    });
  }

  Future<void> _pickCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedFilter = 'Custom';
        _applyFilter();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        backgroundColor: const Color(0xFFD4AF37),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSales,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCards(),
                _buildFilterChips(),
                Expanded(child: _buildSalesList()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SaleCalculator()),
          );

          if (result == true) {
            _fetchSales();
          }
        },
        backgroundColor: const Color(0xFFD4AF37),
        icon: const Icon(Icons.add),
        label: const Text('New Sale'),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterChip('Today'),
          const SizedBox(width: 8),
          _filterChip('This Week'),
          const SizedBox(width: 8),
          _filterChip('This Month'),
          const SizedBox(width: 8),
          _filterChip('All'),
          const SizedBox(width: 8),
          _customDateChip(),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
          _applyFilter();
        });
      },
      selectedColor: const Color(0xFFD4AF37).withOpacity(0.3),
      checkmarkColor: const Color(0xFFD4AF37),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFFD4AF37) : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _customDateChip() {
    final isSelected = _selectedFilter == 'Custom';
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.date_range, size: 16),
          const SizedBox(width: 4),
          Text(
            _customDateRange != null
                ? '${DateFormat('MMM d').format(_customDateRange!.start)} - ${DateFormat('MMM d').format(_customDateRange!.end)}'
                : 'Custom',
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) => _pickCustomDateRange(),
      selectedColor: const Color(0xFFD4AF37).withOpacity(0.3),
      checkmarkColor: const Color(0xFFD4AF37),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFFD4AF37) : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

Widget _buildSummaryCards() {
  // Calculate the total for currently filtered sales
  double filteredTotal = _filteredSales.fold<double>(
    0, 
    (sum, sale) => sum + (sale['total'] as num).toDouble()
  );

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selectedFilter} Total',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '\$${filteredTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_filteredSales.length} sale${_filteredSales.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _summaryCard(String label, String amount, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesList() {
    if (_filteredSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No sales found',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'Today' 
                  ? 'No sales recorded today'
                  : 'Try selecting a different time period',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: _filteredSales.length,
    itemBuilder: (context, index) {
      final sale = _filteredSales[index];
      final items = List<Map<String, dynamic>>.from(sale['sale_items'] ?? []);
      final itemCount = items.fold<int>(0, (sum, item) => sum + (item['quantity'] as int));
      final date = DateTime.parse(sale['sale_date']);
      final isInvoiced = sale['invoice_id'] != null;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: isInvoiced ? Colors.green : const Color(0xFFD4AF37),
                child: Icon(
                  Icons.shopping_bag,
                  color: Colors.white,
                ),
              ),
              if (isInvoiced)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.green,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Text(
                'Sale #${sale['id'].toString().substring(0, 8)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (isInvoiced)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Icons.verified,
                    color: Colors.green,
                    size: 16,
                  ),
                ),
            ],
          ),
          subtitle: Text(
            '${DateFormat('MMM dd, yyyy').format(date)} • $itemCount item${itemCount != 1 ? 's' : ''}${isInvoiced ? ' • Invoiced' : ''}',
            style: TextStyle(
              color: isInvoiced ? Colors.green : null,
            ),
          ),
          trailing: Text(
            '\$${(sale['total'] as num).toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isInvoiced ? Colors.green : const Color(0xFFD4AF37),
            ),
          ),
          onTap: () => _showSaleDetails(sale),
        ),
      );
    },
  );
  }

  void _showSaleDetails(Map<String, dynamic> sale) {
    final items = List<Map<String, dynamic>>.from(sale['sale_items'] ?? []);
    final date = DateTime.parse(sale['sale_date']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sale Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFFD4AF37)),
                            onPressed: () {
                              Navigator.pop(context);
                              _editSale(sale);
                            },
                            tooltip: 'Edit Sale',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmDeleteSale(sale);
                            },
                            tooltip: 'Delete Sale',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('MMMM dd, yyyy').format(date),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item['product_name']),
                      subtitle: Text(
                        'Qty: ${item['quantity']} × \$${(item['price'] as num).toStringAsFixed(2)}',
                      ),
                      trailing: Text(
                        '\$${(item['line_total'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.1),
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                children: [
                  _detailRow('Subtotal', sale['subtotal']),
                  const SizedBox(height: 8),
                  _detailRow(
                      'Tax (${(sale['tax_rate'] as num).toStringAsFixed(2)}%)',
                      sale['tax_amount']),
                  const Divider(height: 20),
                  _detailRow('Total', sale['total'], isTotal: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSale(Map<String, dynamic> sale) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SaleCalculator(
          existingSale: sale,
        ),
      ),
    );

    if (result == true) {
      _fetchSales();
    }
  }

  Future<void> _confirmDeleteSale(Map<String, dynamic> sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sale'),
        content: Text(
          'Are you sure you want to delete this sale?\n\nTotal: \$${(sale['total'] as num).toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteSale(sale['id']);
    }
  }

  Future<void> _deleteSale(String saleId) async {
    try {
      // Delete sale (items will be deleted automatically due to CASCADE)
      await _supabase.from('sales').delete().eq('id', saleId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchSales();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting sale: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _detailRow(String label, num amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: isTotal ? const Color(0xFFD4AF37) : Colors.black87,
          ),
        ),
      ],
    );
  }
}