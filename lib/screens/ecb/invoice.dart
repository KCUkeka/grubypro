// invoice.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:typed_data';

// ************************************* INVOICE SYSTEM *************************************

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _invoices = [];
  List<String> _selectedSaleIds = [];
  bool _isLoading = true;
  int _currentTab = 0; // 0 for Create Invoice, 1 for View Invoices

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Delete invoice method
  Future<void> _deleteInvoice(Map<String, dynamic> invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Invoice'),
            content: Text(
              'Are you sure you want to delete invoice #${invoice['id']}?\n\nThis will remove the invoice but keep the sales records.',
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
      try {
        // First, remove invoice_id from all associated sales
        final saleIds = List<String>.from(invoice['sale_ids']);
        for (var saleId in saleIds) {
          await _supabase
              .from('sales')
              .update({'invoice_id': null})
              .eq('id', saleId);
        }

        // Then delete the invoice
        await _supabase.from('invoices').delete().eq('id', invoice['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchData(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting invoice: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Unsave Invoice method
  Future<void> _unsaveInvoice(Map<String, dynamic> invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Unsave Invoice'),
            content: Text(
              'Are you sure you want to unsave invoice #${invoice['id']}?\n\nThis will change it to draft status and remove invoice associations from sales.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Unsave'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        // Remove invoice_id from all associated sales
        final saleIds = List<String>.from(invoice['sale_ids']);
        for (var saleId in saleIds) {
          await _supabase
              .from('sales')
              .update({'invoice_id': null})
              .eq('id', saleId);
        }

        // Update invoice status to draft
        await _supabase
            .from('invoices')
            .update({
              'status': 'draft',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', invoice['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice unsaved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchData(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error unsaving invoice: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      final [salesData, invoicesData] = await Future.wait([
        _supabase
            .from('sales')
            .select('*, sale_items(*)')
            .order('sale_date', ascending: false),
        _supabase
            .from('invoices')
            .select('*')
            .order('created_date', ascending: false),
      ]);

      setState(() {
        _sales = List<Map<String, dynamic>>.from(salesData);
        _invoices = List<Map<String, dynamic>>.from(invoicesData);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleSaleSelection(String saleId) {
    setState(() {
      if (_selectedSaleIds.contains(saleId)) {
        _selectedSaleIds.remove(saleId);
      } else {
        _selectedSaleIds.add(saleId);
      }
    });
  }

  void _createInvoice() {
    if (_selectedSaleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one sale')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CreateInvoiceScreen(
              selectedSaleIds: _selectedSaleIds,
              sales: _sales,
            ),
      ),
    ).then((_) => _fetchData()); // Refresh data when returning
  }

  double get _selectedTotal {
    double total = 0;
    for (var saleId in _selectedSaleIds) {
      final sale = _sales.firstWhere((s) => s['id'] == saleId);
      total += (sale['total'] as num).toDouble();
    }
    return total;
  }

  bool _isSaleInvoiced(String saleId) {
    return _sales.any(
      (sale) => sale['id'] == saleId && sale['invoice_id'] != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invoices'),
          backgroundColor: const Color(0xFFD4AF37),
          bottom: TabBar(
            onTap: (index) => setState(() => _currentTab = index),
            tabs: const [
              Tab(text: 'Create Invoice'),
              Tab(text: 'View Invoices'),
            ],
          ),
          actions: [
            if (_currentTab == 0 && _selectedSaleIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.receipt_long),
                onPressed: _createInvoice,
                tooltip: 'Create Invoice',
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchData,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                  children: [
                    // Create Invoice Tab
                    Column(
                      children: [
                        // Selection Summary
                        if (_selectedSaleIds.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: const Color(0xFFD4AF37).withOpacity(0.1),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_selectedSaleIds.length} sale${_selectedSaleIds.length > 1 ? 's' : ''} selected',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Total: \$${_selectedTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFFD4AF37),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Sales List
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _sales.length,
                            itemBuilder: (context, index) {
                              final sale = _sales[index];
                              final isSelected = _selectedSaleIds.contains(
                                sale['id'],
                              );
                              final isInvoiced = _isSaleInvoiced(sale['id']);
                              final items = List<Map<String, dynamic>>.from(
                                sale['sale_items'] ?? [],
                              );
                              final date = DateTime.parse(sale['sale_date']);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                color:
                                    isSelected
                                        ? const Color(
                                          0xFFD4AF37,
                                        ).withOpacity(0.1)
                                        : isInvoiced
                                        ? Colors.green.withOpacity(0.1)
                                        : null,
                                child: ListTile(
                                  leading: Stack(
                                    children: [
                                      Checkbox(
                                        value: isSelected,
                                        onChanged:
                                            isInvoiced
                                                ? null
                                                : (value) =>
                                                    _toggleSaleSelection(
                                                      sale['id'],
                                                    ),
                                      ),
                                      if (isInvoiced)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isInvoiced ? Colors.green : null,
                                        ),
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
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('MMM dd, yyyy').format(date),
                                      ),
                                      Text(
                                        '${items.length} item${items.length != 1 ? 's' : ''}',
                                      ),
                                      if (isInvoiced)
                                        Text(
                                          'Invoiced',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Text(
                                    '\$${(sale['total'] as num).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color:
                                          isInvoiced
                                              ? Colors.green
                                              : const Color(0xFFD4AF37),
                                    ),
                                  ),
                                  onTap:
                                      isInvoiced
                                          ? null
                                          : () =>
                                              _toggleSaleSelection(sale['id']),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    // View Invoices Tab
                    _invoices.isEmpty
                        ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 80,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No invoices created yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _invoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _invoices[index];
                            final date = DateTime.parse(
                              invoice['created_date'],
                            );
                            final status = invoice['status'] ?? 'draft';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color:
                                        status == 'saved'
                                            ? Colors.green.withOpacity(0.2)
                                            : const Color(
                                              0xFFD4AF37,
                                            ).withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    status == 'saved'
                                        ? Icons.verified
                                        : Icons.drafts,
                                    color:
                                        status == 'saved'
                                            ? Colors.green
                                            : const Color(0xFFD4AF37),
                                  ),
                                ),
                                title: Text(
                                  'Invoice #${invoice['id']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(date),
                                    ),
                                    Text(
                                      '${(invoice['sale_ids'] as List).length} sales • \$${(invoice['total'] as num).toStringAsFixed(2)}',
                                    ),
                                    Text(
                                      status == 'saved' ? 'Saved' : 'Draft',
                                      style: TextStyle(
                                        color:
                                            status == 'saved'
                                                ? Colors.green
                                                : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editInvoice(invoice);
                                    } else if (value == 'delete') {
                                      _deleteInvoice(invoice);
                                    } else if (value == 'unsave' &&
                                        status == 'saved') {
                                      _unsaveInvoice(invoice);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) {
                                    return <PopupMenuEntry<String>>[
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: const Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit Invoice'),
                                          ],
                                        ),
                                      ),
                                      if (status == 'saved')
                                        PopupMenuItem<String>(
                                          value: 'unsave',
                                          child: const Row(
                                            children: [
                                              Icon(Icons.unarchive, size: 20),
                                              SizedBox(width: 8),
                                              Text('Unsave Invoice'),
                                            ],
                                          ),
                                        ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Delete Invoice',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ];
                                  },
                                ),
                                onTap: () => _editInvoice(invoice),
                              ),
                            );
                          },
                        ),
                  ],
                ),
        floatingActionButton:
            _currentTab == 0 && _selectedSaleIds.isNotEmpty
                ? FloatingActionButton.extended(
                  onPressed: _createInvoice,
                  backgroundColor: const Color(0xFFD4AF37),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Create Invoice'),
                )
                : null,
      ),
    );
  }

  void _editInvoice(Map<String, dynamic> invoice) async {
    // Fetch the sales included in this invoice
    final saleIds = List<String>.from(invoice['sale_ids']);
    final includedSales =
        _sales.where((sale) => saleIds.contains(sale['id'])).toList();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CreateInvoiceScreen(
              selectedSaleIds: saleIds,
              sales: _sales,
              existingInvoice: invoice,
              includedSales: includedSales,
            ),
      ),
    );

    if (result == true) {
      _fetchData(); // Refresh data after editing
    }
  }
}

// ************************************* CREATE INVOICE SCREEN *************************************

class CreateInvoiceScreen extends StatefulWidget {
  final List<String> selectedSaleIds;
  final List<Map<String, dynamic>> sales;
  final Map<String, dynamic>? existingInvoice;
  final List<Map<String, dynamic>>? includedSales;

  const CreateInvoiceScreen({
    super.key,
    required this.selectedSaleIds,
    required this.sales,
    this.existingInvoice,
    this.includedSales,
  });

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _supabase = Supabase.instance.client;
  final _customerNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isGenerating = false;
  bool _isSaving = false;

  // Validation methods
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return null; // Optional field
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Phone validation
  String? _validatePhone(String? value) {
  if (value == null || value.isEmpty) return null; // Optional field
  
  // Remove all non-digits and check length
  final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
  
  if (digitsOnly.length < 10) {
    return 'Please enter at least 10 digits';
  }
  
  return null;
}

  @override
  void initState() {
    super.initState();
    // Pre-fill data if editing existing invoice
    if (widget.existingInvoice != null) {
      _customerNameController.text =
          widget.existingInvoice!['customer_name'] ?? '';
      _customerEmailController.text =
          widget.existingInvoice!['customer_email'] ?? '';

      // Format existing phone number for display
      _customerPhoneController.text = widget.existingInvoice!['customer_phone'] ?? '';
    
    _notesController.text = widget.existingInvoice!['notes'] ?? '';
    }
  }

  List<Map<String, dynamic>> get _selectedSales {
    return widget.sales
        .where((sale) => widget.selectedSaleIds.contains(sale['id']))
        .toList();
  }

  double get _subtotal {
    return _selectedSales.fold<double>(
      0,
      (sum, sale) => sum + (sale['subtotal'] as num).toDouble(),
    );
  }

  double get _taxAmount {
    return _selectedSales.fold<double>(
      0,
      (sum, sale) => sum + (sale['tax_amount'] as num).toDouble(),
    );
  }

  double get _total {
    return _selectedSales.fold<double>(
      0,
      (sum, sale) => sum + (sale['total'] as num).toDouble(),
    );
  }

  List<Map<String, dynamic>> get _allItems {
    final allItems = <Map<String, dynamic>>[];
    for (var sale in _selectedSales) {
      final items = List<Map<String, dynamic>>.from(sale['sale_items'] ?? []);
      for (var item in items) {
        allItems.add({
          ...item,
          'sale_date': sale['sale_date'],
          'sale_id': sale['id'],
        });
      }
    }
    return allItems;
  }

  Future<void> _saveInvoice() async {
    // Validate email and phone if provided
    final emailError = _validateEmail(_customerEmailController.text);
    final phoneError = _validatePhone(_customerPhoneController.text);

    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emailError), backgroundColor: Colors.red),
      );
      return;
    }

    // Validate phone only when form is submitted (not during typing)
    final phoneDigits = _customerPhoneController.text.replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
    if (_customerPhoneController.text.isNotEmpty && phoneDigits.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid 10-digit phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final invoiceId =
          widget.existingInvoice?['id'] ??
          'INV-${DateTime.now().millisecondsSinceEpoch}';

      // Store phone number without formatting in database
      final rawPhone = _customerPhoneController.text.replaceAll(RegExp(r'[^\d]'), '');

      final invoice = {
        'id': invoiceId,
        'created_date':
            widget.existingInvoice?['created_date'] ??
            DateTime.now().toIso8601String(),
        'sale_ids': widget.selectedSaleIds,
        'subtotal': _subtotal,
        'tax_amount': _taxAmount,
        'total': _total,
        'customer_name':
            _customerNameController.text.isEmpty
                ? null
                : _customerNameController.text,
        'customer_email':
            _customerEmailController.text.isEmpty
                ? null
                : _customerEmailController.text,
        'customer_phone':
            rawPhone.isEmpty ? null : rawPhone, // Store unformatted
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
        'status': 'saved',
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Save/update invoice
      if (widget.existingInvoice != null) {
        await _supabase.from('invoices').update(invoice).eq('id', invoiceId);

        // Remove old invoice associations
        await _supabase
            .from('sales')
            .update({'invoice_id': null})
            .eq('invoice_id', invoiceId);
      } else {
        await _supabase.from('invoices').insert(invoice);
      }

      // Update sales with invoice_id
      for (var saleId in widget.selectedSaleIds) {
        await _supabase
            .from('sales')
            .update({'invoice_id': invoiceId})
            .eq('id', saleId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingInvoice != null
                  ? 'Invoice updated successfully!'
                  : 'Invoice saved successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return to previous screen with success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving invoice: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _generateInvoice() async {
    // Validate email and phone if provided
    final emailError = _validateEmail(_customerEmailController.text);
    final phoneError = _validatePhone(_customerPhoneController.text);

    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emailError), backgroundColor: Colors.red),
      );
      return;
    }

    if (phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneError), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final invoiceId =
          widget.existingInvoice?['id'] ??
          'INV-${DateTime.now().millisecondsSinceEpoch}';

      // Store phone number without formatting in database
      final rawPhone = _customerPhoneController.text.replaceAll(RegExp(r'[^\d]'), '');

      final invoice = {
        'id': invoiceId,
        'created_date':
            widget.existingInvoice?['created_date'] ??
            DateTime.now().toIso8601String(),
        'sale_ids': widget.selectedSaleIds,
        'subtotal': _subtotal,
        'tax_amount': _taxAmount,
        'total': _total,
        'customer_name':
            _customerNameController.text.isEmpty
                ? null
                : _customerNameController.text,
        'customer_email':
            _customerEmailController.text.isEmpty
                ? null
                : _customerEmailController.text,
        'customer_phone':
            rawPhone.isEmpty ? null : rawPhone, // Store unformatted
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
        'status': 'draft',
      };

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => InvoicePreviewScreen(
                  invoiceData: invoice,
                  items: _allItems,
                  sales: _selectedSales,
                  existingInvoice: widget.existingInvoice,
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating invoice: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingInvoice != null ? 'Edit Invoice' : 'Generate Invoice',
        ),
        backgroundColor: const Color(0xFFD4AF37),
        actions: [
          if (widget.existingInvoice != null)
            IconButton(
              icon:
                  _isSaving
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                      : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveInvoice,
              tooltip: 'Save Invoice',
            ),
        ],
      ),
      body:
          (_isGenerating || _isSaving)
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Information
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Customer Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _customerNameController,
                              decoration: const InputDecoration(
                                labelText: 'Customer Name (Optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _customerEmailController,
                              decoration: const InputDecoration(
                                labelText: 'Customer Email (Optional)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _customerPhoneController,
                              decoration: const InputDecoration(
                                labelText: 'Customer Phone (Optional)',
                                border: OutlineInputBorder(),
                                hintText: '1234567890 or 123-456-7890',
                              ),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                // Optional: Allow longer input for international numbers
                                LengthLimitingTextInputFormatter(10),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Selected Sales Summary
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Invoice Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryRow(
                              'Number of Sales',
                              '${_selectedSales.length}',
                            ),
                            _buildSummaryRow(
                              'Number of Items',
                              '${_allItems.length}',
                            ),
                            _buildSummaryRow(
                              'Subtotal',
                              '\$${_subtotal.toStringAsFixed(2)}',
                            ),
                            _buildSummaryRow(
                              'Tax Amount',
                              '\$${_taxAmount.toStringAsFixed(2)}',
                            ),
                            const Divider(),
                            _buildSummaryRow(
                              'Total',
                              '\$${_total.toStringAsFixed(2)}',
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Selected Sales List
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Sales',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._selectedSales.map((sale) {
                              final date = DateTime.parse(sale['sale_date']);
                              final isInvoiced =
                                  sale['invoice_id'] != null &&
                                  sale['invoice_id'] !=
                                      widget.existingInvoice?['id'];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.shopping_bag,
                                  color:
                                      isInvoiced
                                          ? Colors.green
                                          : const Color(0xFFD4AF37),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      'Sale #${sale['id'].toString().substring(0, 8)}',
                                    ),
                                    if (isInvoiced)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8.0),
                                        child: Icon(
                                          Icons.warning,
                                          color: Colors.orange,
                                          size: 16,
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(date),
                                    ),
                                    if (isInvoiced)
                                      Text(
                                        'Already in another invoice',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  '\$${(sale['total'] as num).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isInvoiced ? Colors.orange : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Itemized List
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Itemized Products',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._allItems.map((item) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.inventory_2,
                                  size: 20,
                                ),
                                title: Text(item['product_name']),
                                subtitle: Text(
                                  'Qty: ${item['quantity']} × \$${(item['price'] as num).toStringAsFixed(2)}',
                                ),
                                trailing: Text(
                                  '\$${(item['line_total'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Notes
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notes (Optional)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Add any additional notes...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _generateInvoice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Preview Invoice',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (widget.existingInvoice == null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveInvoice,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child:
                                  _isSaving
                                      ? const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text('Saving...'),
                                        ],
                                      )
                                      : const Text(
                                        'Save Invoice',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              // FIXED: Corrected color code
              color: isTotal ? const Color(0xFFD4AF37) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

// ************************************* INVOICE PREVIEW SCREEN *************************************

class InvoicePreviewScreen extends StatefulWidget {
  final Map<String, dynamic> invoiceData;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> sales;
  final Map<String, dynamic>? existingInvoice;

  const InvoicePreviewScreen({
    super.key,
    required this.invoiceData,
    required this.items,
    required this.sales,
    this.existingInvoice,
  });

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  final _supabase = Supabase.instance.client;
  bool _isSaving = false;

  String _formatPhoneForDisplay(String? phone) {
  if (phone == null || phone.isEmpty) return '';
  
  // Remove all non-digits
  final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
  
  if (digits.length == 10) {
    // Format as (xxx) xxx-xxxx
    return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6, 10)}';
  } else if (digits.length == 11 && digits.startsWith('1')) {
    // Format US numbers with country code: 1 (xxx) xxx-xxxx
    return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7, 11)}';
  } else {
    // Return as-is for other formats
    return phone;
  }
}

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Invoice #: ${widget.invoiceData['id']}'),
                      pw.Text(
                        'Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(widget.invoiceData['created_date']))}',
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Ethalle's Cakes and Bakes",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('Bolingbrook, IL 60490'),
                      pw.Text('ethallebakes@gmail.com'),
                      pw.Text('312-600-5810'),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Customer Information
              if (widget.invoiceData['customer_name'] != null ||
                  widget.invoiceData['customer_email'] != null ||
                  widget.invoiceData['customer_phone'] != null)
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Bill To:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      if (widget.invoiceData['customer_name'] != null)
                        pw.Text(widget.invoiceData['customer_name']),
                      if (widget.invoiceData['customer_email'] != null)
                        pw.Text(widget.invoiceData['customer_email']),
                      if (widget.invoiceData['customer_phone'] != null)
                        pw.Text(
                          _formatPhoneForDisplay(
                            widget.invoiceData['customer_phone'],
                          ),
                        ),
                    ],
                  ),
                ),

              pw.SizedBox(height: 20),

              // Items Table
              pw.Text(
                'Items',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Product',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Date',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Price',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  ...widget.items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(item['product_name']),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            DateFormat(
                              'MM/dd/yyyy',
                            ).format(DateTime.parse(item['sale_date'])),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(item['quantity'].toString()),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '\$${(item['price'] as num).toStringAsFixed(2)}',
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '\$${(item['line_total'] as num).toStringAsFixed(2)}',
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 20),

              // Totals
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.SizedBox(width: 100),
                        pw.Text(
                          'Subtotal: ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '\$${(widget.invoiceData['subtotal'] as num).toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.SizedBox(width: 100),
                        pw.Text(
                          'Tax: ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '\$${(widget.invoiceData['tax_amount'] as num).toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.SizedBox(width: 100),
                        pw.Text(
                          'TOTAL: ',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '\$${(widget.invoiceData['total'] as num).toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (widget.invoiceData['notes'] != null) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Notes:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(widget.invoiceData['notes']),
              ],
            ],
          );
        },
      ),
    );

    // Convert the document to bytes and return as Uint8List
    return pdf.save();
  }

  Future<void> _saveInvoice() async {
    setState(() => _isSaving = true);

    try {
      final invoice = {
        ...widget.invoiceData,
        'status': 'saved',
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Save/update invoice
      if (widget.existingInvoice != null) {
        await _supabase
            .from('invoices')
            .update(invoice)
            .eq('id', invoice['id']);

        // Remove old invoice associations
        await _supabase
            .from('sales')
            .update({'invoice_id': null})
            .eq('invoice_id', invoice['id']);
      } else {
        await _supabase.from('invoices').insert(invoice);
      }

      // Update sales with invoice_id
      final saleIds = List<String>.from(widget.invoiceData['sale_ids']);
      for (var saleId in saleIds) {
        await _supabase
            .from('sales')
            .update({'invoice_id': invoice['id']})
            .eq('id', saleId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return to previous screen with success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving invoice: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Preview'),
        backgroundColor: const Color(0xFFD4AF37),
        actions: [
          if (widget.existingInvoice == null ||
              widget.existingInvoice!['status'] != 'saved')
            IconButton(
              icon:
                  _isSaving
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                      : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveInvoice,
              tooltip: 'Save Invoice',
            ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              Printing.layoutPdf(onLayout: (format) => _generatePdf());
            },
          ),
          IconButton(icon: const Icon(Icons.share), onPressed: _shareInvoice),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Invoice Header
            Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFFD4AF37).withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INVOICE',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Invoice #: ${widget.invoiceData['id']}'),
                      Text(
                        'Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(widget.invoiceData['created_date']))}',
                      ),
                      if (widget.existingInvoice != null &&
                          widget.existingInvoice!['status'] == 'saved')
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SAVED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Ethalle's Cakes and Bakes",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Bolingbrook, IL 60490'),
                      Text('ethallebakes@gmail.com'),
                      Text('312-600-5810'),
                    ],
                  ),
                ],
              ),
            ),

            // Customer Information
            if (widget.invoiceData['customer_name'] != null ||
                widget.invoiceData['customer_email'] != null ||
                widget.invoiceData['customer_phone'] != null)
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bill To:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.invoiceData['customer_name'] != null)
                      Text(widget.invoiceData['customer_name']),
                    if (widget.invoiceData['customer_email'] != null)
                      Text(widget.invoiceData['customer_email']),
                    if (widget.invoiceData['customer_phone'] != null)
                      Text(
                        _formatPhoneForDisplay(
                          widget.invoiceData['customer_phone'],
                        ),
                      ),
                  ],
                ),
              ),

            // Items List
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...widget.items.map((item) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item['product_name']),
                        subtitle: Text(
                          'Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(item['sale_date']))}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Qty: ${item['quantity']}'),
                            Text(
                              '\$${(item['line_total'] as num).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD4AF37),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            // Totals
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD4AF37)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildTotalRow(
                    'Subtotal',
                    (widget.invoiceData['subtotal'] as num).toDouble(),
                  ),
                  _buildTotalRow(
                    'Tax Amount',
                    (widget.invoiceData['tax_amount'] as num).toDouble(),
                  ),
                  const Divider(),
                  _buildTotalRow(
                    'TOTAL',
                    (widget.invoiceData['total'] as num).toDouble(),
                    isTotal: true,
                  ),
                ],
              ),
            ),

            // Notes
            if (widget.invoiceData['notes'] != null)
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notes:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(widget.invoiceData['notes']),
                  ],
                ),
              ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Printing.layoutPdf(
                          onLayout: (format) => _generatePdf(),
                        );
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Print Invoice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareInvoice,
                      icon: const Icon(Icons.share),
                      label: const Text('Share Invoice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
              color: isTotal ? const Color(0xFFD4AF37) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareInvoice() async {
    final Uint8List pdfBytes = await _generatePdf();
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'invoice-${widget.invoiceData['id']}.pdf',
    );
  }
}
