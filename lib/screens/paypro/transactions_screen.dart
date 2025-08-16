import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:grubypro/services/supabase_service.dart';
import 'package:grubypro/models/transactions.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<AppTransaction> _transactions = [];
  List<AppTransaction> _filteredTransactions = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _selectedPaymentType;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final transactions = await SupabaseService().getTransactions();
      setState(() {
        _transactions = transactions;
        _filteredTransactions = transactions;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadTransactions();
  }

  void _filterTransactions() {
    setState(() {
      _filteredTransactions =
          _transactions.where((txn) {
            final matchType =
                _selectedPaymentType == null ||
                txn.paymentType == _selectedPaymentType;
            final matchStart =
                _startDate == null ||
                txn.date.isAfter(_startDate!.subtract(const Duration(days: 1)));
            final matchEnd =
                _endDate == null ||
                txn.date.isBefore(_endDate!.add(const Duration(days: 1)));
            return matchType && matchStart && matchEnd;
          }).toList();
    });
  }

  Future<void> _exportCSV() async {
    try {
      // Check if we have transactions to export
      if (_filteredTransactions.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No transactions to export')),
          );
        }
        return;
      }

      // Request storage permission
      var status = await Permission.storage.request();
      if (status.isDenied) {
        // Try requesting MANAGE_EXTERNAL_STORAGE for Android 11+
        status = await Permission.manageExternalStorage.request();
      }

      if (!status.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission required to export CSV'),
            ),
          );
        }
        return;
      }

      // Create CSV data
      final rows = [
        ['Title', 'Amount', 'Date', 'Payment Type'],
        ..._filteredTransactions.map(
          (txn) => [
            txn.title,
            txn.amount.toStringAsFixed(2),
            DateFormat.yMMMd().format(txn.date),
            txn.paymentType,
          ],
        ),
      ];

      final csv = const ListToCsvConverter().convert(rows);

      // Create filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'transactions_$timestamp.csv';

      // Try multiple common Android directories
      final possiblePaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Download',
        '/sdcard/Downloads',
      ];

      File? savedFile;

      for (String path in possiblePaths) {
        try {
          final directory = Directory(path);
          if (await directory.exists()) {
            final file = File('$path/$fileName');
            await file.writeAsString(csv);
            savedFile = file;
            print('Successfully saved to: ${file.path}');
            break;
          }
        } catch (e) {
          print('Failed to save to $path: $e');
          continue;
        }
      }

      if (savedFile != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'CSV exported successfully!\nSaved as: $fileName\nLocation: ${savedFile.parent.path}',
              ),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }
      } else {
        throw Exception('Could not access Downloads folder');
      }
    } catch (e) {
      print('Export error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (range != null) {
      _startDate = range.start;
      _endDate = range.end;
      _filterTransactions();
    }
  }

  // Delete functionality
  void _showDeleteConfirmation(AppTransaction transaction) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Transaction'),
            content: Text(
              'Are you sure you want to delete "${transaction.title}"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _deleteTransaction(transaction);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteTransaction(AppTransaction transaction) async {
    try {
      await SupabaseService().deleteTransaction(transaction.id);
      await _loadTransactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting transaction: $e')),
        );
      }
    }
  }

  Widget _buildFilters() {
    final types = ['Amex', 'Sapphire', 'Capital 1', 'Cash', 'Freedom'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedPaymentType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Filter by Payment Type',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All')),
              ...types.map((t) => DropdownMenuItem(value: t, child: Text(t))),
            ],
            onChanged: (val) {
              setState(() => _selectedPaymentType = val);
              _filterTransactions();
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Date Range'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportCSV,
                  icon: const Icon(Icons.download),
                  label: const Text('Export CSV'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final total = _filteredTransactions.fold(
      0.0,
      (sum, txn) => sum + txn.amount,
    );
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        'Total: \$${total.toStringAsFixed(2)} • ${_filteredTransactions.length} transaction(s)',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showAddTransactionModal([AppTransaction? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: AddTransactionForm(
              onTransactionSaved: _loadTransactions,
              existingTransaction: existing,
            ),
          ),
    );
  }

  void _showEditTransactionModal(AppTransaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: AddTransactionForm(
              onTransactionSaved: _loadTransactions,
              existingTransaction: transaction,
            ),
          ),
    );
  }

  Widget _buildTransactionList() {
    // Sort transactions by date (newest first)
    _filteredTransactions.sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTransactions.length,
      itemBuilder: (context, index) {
        final txn = _filteredTransactions[index];
        return Dismissible(
          key: Key(txn.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Confirm'),
                    content: const Text(
                      'Are you sure you want to delete this transaction?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
            );
          },
          onDismissed: (direction) {
            _deleteTransaction(txn);
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Text(
                txn.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '${DateFormat.yMMMd().format(txn.date)} • ${txn.paymentType}',
                style: const TextStyle(fontSize: 14),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\$${txn.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditTransactionModal(txn);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(txn);
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                  ),
                ],
              ),
              onTap: () => _showEditTransactionModal(txn),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '0 transactions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add a transaction',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          // Add Transaction button
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddTransactionModal,
            tooltip: 'Add Transaction',
          ),
          IconButton(
            onPressed: _loadTransactions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _onRefresh,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildFilters(),
                    _buildSummary(),
                    const Divider(),
                    Expanded(
                      child:
                          _filteredTransactions.isEmpty
                              ? _buildEmptyTransactionList()
                              : _buildTransactionList(),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildEmptyTransactionList() {
    // Check if we have transactions but they're filtered out
    final hasTransactions = _transactions.isNotEmpty;
    final isFiltered =
        _selectedPaymentType != null || _startDate != null || _endDate != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasTransactions && isFiltered
                  ? Icons.filter_list_off
                  : Icons.receipt_long,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              hasTransactions && isFiltered
                  ? 'No transactions match your filters'
                  : '0 transactions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hasTransactions && isFiltered
                  ? 'Try adjusting your date range or payment type filter'
                  : 'Tap the + button to add a transaction',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (hasTransactions && isFiltered) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedPaymentType = null;
                    _startDate = null;
                    _endDate = null;
                  });
                  _filterTransactions();
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AddTransactionForm extends StatefulWidget {
  final VoidCallback onTransactionSaved;
  final AppTransaction? existingTransaction;

  const AddTransactionForm({
    super.key,
    required this.onTransactionSaved,
    this.existingTransaction,
  });

  @override
  State<AddTransactionForm> createState() => _AddTransactionFormState();
}

class _AddTransactionFormState extends State<AddTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late String title;
  late double amount;
  DateTime date = DateTime.now();
  String paymentType = 'Amex';
  bool _isSaving = false;

  final List<String> paymentTypes = [
    'Amex',
    'Freedom',
    'Capital 1',
    'Sapphire',
    'Cash',
  ];

  @override
  void initState() {
    super.initState();
    final txn = widget.existingTransaction;
    if (txn != null) {
      title = txn.title;
      amount = txn.amount;
      date = txn.date;
      paymentType = txn.paymentType;
    } else {
      title = '';
      amount = 0;
    }
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => date = picked);
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final txn = AppTransaction(
      id: widget.existingTransaction?.id ?? '',
      title: title,
      amount: amount,
      date: date,
      paymentType: paymentType,
    );

    try {
      if (widget.existingTransaction != null) {
        await SupabaseService().updateTransaction(txn);
      } else {
        await SupabaseService().addTransaction(txn);
      }
      widget.onTransactionSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print('Full error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving transaction: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => title = val,
                validator:
                    (val) => val == null || val.isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: amount > 0 ? amount.toString() : '',
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => amount = double.tryParse(val) ?? 0,
                validator:
                    (val) =>
                        (double.tryParse(val ?? '') ?? 0) <= 0
                            ? 'Enter valid amount'
                            : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text('Date: ${DateFormat.yMMMd().format(date)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paymentType,
                items:
                    paymentTypes
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                onChanged: (val) => setState(() => paymentType = val ?? 'Cash'),
                decoration: const InputDecoration(
                  labelText: 'Payment Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child:
                    _isSaving
                        ? const CircularProgressIndicator()
                        : Text(
                          widget.existingTransaction != null
                              ? 'Update Transaction'
                              : 'Save Transaction',
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
