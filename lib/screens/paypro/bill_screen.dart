import 'package:flutter/material.dart';
import 'package:grubypro/models/bills.dart';
import 'package:grubypro/screens/gruby/setting.dart';
import 'package:grubypro/services/supabase_service.dart';
import 'package:intl/intl.dart';

class BillsScreen extends StatefulWidget {
  final String? initialName;
  final bool showArchived;
  const BillsScreen({Key? key, this.initialName, this.showArchived = false})
    : super(key: key);

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  List<Bill> _bills = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  final ScrollController _horizontalScrollController = ScrollController();
  double get _totalAmountDue {
  return _bills.fold(0, (sum, bill) => sum + (bill.paymentMade ? 0 : bill.amount));
}

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddBillModal(widget.initialName);
      });
    }
    _loadBills();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBills() async {
    try {
      final bills = await SupabaseService().getBills(
        archived: widget.showArchived,
      );
      if (mounted) {
        setState(() {
          _bills = bills;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading bills: $e')));
      }
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadBills();
  }

  Future<void> _unarchiveBill(Bill bill) async {
    try {
      await SupabaseService().unarchiveBill(bill.id);
      await _loadBills();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill restored successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error restoring bill: $e')));
      }
    }
  }

  void _showAddBillModal([String? name]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: AddBillForm(onBillAdded: _loadBills, initialName: name),
          ),
    );
  }

  void _showEditBillModal(Bill bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: AddBillForm(onBillAdded: _loadBills, existingBill: bill),
          ),
    );
  }

  Future<void> _archiveBill(Bill bill) async {
    try {
      await SupabaseService().archiveBill(bill.id);
      await _loadBills();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill archived successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error archiving bill: $e')));
      }
    }
  }

  void _showDeleteConfirmation(Bill bill) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Bill'),
      content: Text(
        'Are you sure you want to delete "${bill.name}"? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async{
           await _deleteBill(bill);
           if (mounted) Navigator.pop(context);
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

  Future<void> _deleteBill(Bill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Bill'),
            content: const Text(
              'Are you sure you want to permanently delete this bill?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService().deleteBill(bill.id);
        await _loadBills();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bill deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting bill: $e')));
        }
      }
    }
  }
  // Date formatter
  final dateFormatter = DateFormat('MMM d yyyy');


  Widget _buildBillList() {
  // Sort bills by due date for prioritization
  _bills.sort((a, b) => a.dueDate.compareTo(b.dueDate));

  return Column(
    children: [
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _bills.length,
          itemBuilder: (context, index) {
            final bill = _bills[index];
            return _buildBillItem(bill);
          },
        ),
      ),
      // Total amount due section
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Amount Due:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '\$${_totalAmountDue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// Extracted bill item widget for better readability
Widget _buildBillItem(Bill bill) {
  return Dismissible(
    key: Key(bill.id),
    direction: DismissDirection.endToStart,
    background: Container(
      color: widget.showArchived ? Colors.red : Colors.blue,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      child: Icon(
        widget.showArchived ? Icons.delete : Icons.archive,
        color: Colors.white,
      ),
    ),
    confirmDismiss: (direction) async {
      return await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm'),
          content: Text(
              'Are you sure you want to ${widget.showArchived ? 'delete' : 'archive'} this bill?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
    },
    onDismissed: (direction) {
      if (widget.showArchived) {
        _deleteBill(bill);
      } else {
        _archiveBill(bill);
      }
    },
    child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: !bill.paymentMade && bill.dueDate.isBefore(DateTime.now())
          ? Colors.red.withOpacity(0.1)
          : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          bill.paymentMade ? Icons.check_circle : Icons.radio_button_unchecked,
          color: bill.paymentMade ? Colors.green : Colors.grey,
          size: 24,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                bill.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (bill.autoPay)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Auto Pay',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ),
          ],
        ),
        subtitle: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: Colors.black),
            children: [
              TextSpan(
                text:
                    'Amount: \$${bill.amount.toStringAsFixed(2)} • Due: ${dateFormatter.format(bill.dueDate)}',
              ),
              if (!bill.paymentMade && bill.dueDate.isBefore(DateTime.now()))
                const TextSpan(
                  text: ' (Overdue)',
                  style: TextStyle(color: Colors.red),
                ),
              if (bill.paymentMade)
                TextSpan(
                  text:
                      '\nPaid on: ${bill.paymentDate != null ? dateFormatter.format(bill.paymentDate!) : "-"}',
                ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditBillModal(bill);
            } else if (value == 'archive') {
              _archiveBill(bill);
            } else if (value == 'restore') {
              _unarchiveBill(bill);
            } else if (value == 'delete') {
              _showDeleteConfirmation(bill);
            }
          },
          itemBuilder: (context) {
            if (widget.showArchived) {
              return [
                const PopupMenuItem(
                  value: 'restore',
                  child: Text('Restore'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ];
            } else {
              return [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem(
                  value: 'archive',
                  child: Text('Archive'),
                ),
              ];
            }
          },
        ),
      ),
    ),
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
            widget.showArchived ? 'No archived bills' : 'No bills yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            widget.showArchived
                ? 'Archive bills to see them here'
                : 'Tap the + button to add a bill',
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
        title: Text(widget.showArchived ? 'Archived Bills' : 'Active Bills',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        actions: [
          if (!widget.showArchived) // Only show add button for active bills
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddBillModal,
            tooltip: 'Add Bill',
          ),
          IconButton(onPressed: _loadBills, icon: const Icon(Icons.refresh)),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _onRefresh,
                child: _bills.isEmpty ? _buildEmptyState() : _buildBillList(),
              ),
      
  );
}
}

class AddBillForm extends StatefulWidget {
  final VoidCallback onBillAdded;
  final Bill? existingBill;
  final String? initialName;

  const AddBillForm({
    super.key,
    required this.onBillAdded,
    this.existingBill,
    this.initialName,
  });

  @override
  State<AddBillForm> createState() => _AddBillFormState();
}

class _AddBillFormState extends State<AddBillForm> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String? dropdownValue;
  String customName = '';
  double amount = 0;
  DateTime? dueDate;
  bool paymentMade = false;
  DateTime? paymentDate;
  bool autoPay = false;
  bool _isSaving = false;

  final List<String> _billOptions = [
    'Xfinity',
    'Comcast',
    'Water',
    'Nicor',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final bill = widget.existingBill;
    if (bill != null) {
      name = bill.name;
      amount = bill.amount;
      dueDate = bill.dueDate;
      paymentMade = bill.paymentMade;
      paymentDate = bill.paymentDate;
      autoPay = bill.autoPay;
      if (_billOptions.contains(name)) {
        dropdownValue = name;
      } else {
        dropdownValue = 'Other';
        customName = name;
      }
    } else if (widget.initialName != null) {
      name = widget.initialName!;
      dropdownValue = _billOptions.contains(name) ? name : 'Other';
      if (dropdownValue == 'Other') customName = name;
    }
  }

  Future<void> _pickDate(BuildContext context, bool isPaymentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isPaymentDate) {
          paymentDate = picked;
        } else {
          dueDate = picked;
        }
      });
    }
  }

  void _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (dueDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a due date')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bill = Bill(
        id: widget.existingBill?.id ?? '',
        name: dropdownValue == 'Other' ? customName : name,
        amount: amount,
        dueDate: dueDate!,
        paymentMade: paymentMade,
        paymentDate: paymentMade ? paymentDate : null,
        autoPay: autoPay,
        archived: false,
      );

      if (widget.existingBill != null) {
        await SupabaseService().updateBill(bill);
      } else {
        await SupabaseService().addBill(bill);
      }

      widget.onBillAdded();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      print('Error saving bill: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving bill: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: dropdownValue,
                items:
                    _billOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    dropdownValue = newValue;
                    if (newValue != 'Other') {
                      name = newValue!;
                    }
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Bill Type',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) => value == null ? 'Select a bill type' : null,
              ),
              const SizedBox(height: 12),
              if (dropdownValue == 'Other')
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Custom Bill Name',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: customName,
                  onChanged: (val) => setState(() => customName = val),
                  validator:
                      (val) => val?.isEmpty ?? true ? 'Enter bill name' : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: amount > 0 ? amount.toString() : '',
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => amount = double.tryParse(value) ?? 0,
                validator: (value) {
                  final val = double.tryParse(value ?? '');
                  if (val == null || val <= 0) return 'Enter valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  dueDate == null
                      ? 'Select Due Date*'
                      : 'Due Date: ${DateFormat('MMM d yyyy').format(dueDate!)}'

                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(context, false),
              ),
              if (dueDate == null)
                const Padding(
                  padding: EdgeInsets.only(left: 16.0),
                  child: Text(
                    'Please select a due date',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Payment Made?'),
                value: paymentMade,
                onChanged: (value) {
                  setState(() {
                    paymentMade = value;
                    if (!value) paymentDate = null;
                  });
                },
              ),
              if (paymentMade) ...[
                const SizedBox(height: 12),
                ListTile(
                  title: Text(
                    paymentDate == null
                        ? 'Select Payment Date*'
                        : 'Payment Date: ${DateFormat('MMM d yyyy').format(paymentDate!)}'

                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(context, true),
                ),
                if (paymentDate == null)
                  const Padding(
                    padding: EdgeInsets.only(left: 16.0),
                    child: Text(
                      'Please select a payment date',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Auto Pay?'),
                value: autoPay,
                onChanged: (value) => setState(() => autoPay = value),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child:
                    _isSaving
                        ? const CircularProgressIndicator()
                        : const Text('Save Bill'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
