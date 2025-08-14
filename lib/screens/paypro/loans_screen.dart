import 'package:flutter/material.dart';
import 'package:grubypro/models/loans.dart';
import 'package:grubypro/services/supabase_service.dart';
import 'package:intl/intl.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});
  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

// Helper currency format
final NumberFormat currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

// LoanOverviewScreen class:
class LoanOverviewScreen extends StatefulWidget {
  final List<Loan> loans;
  final VoidCallback onLoanUpdated;

  const LoanOverviewScreen({
    super.key,
    required this.loans,
    required this.onLoanUpdated,
  });

  @override
  State<LoanOverviewScreen> createState() => _LoanOverviewScreenState();
}

class _LoanOverviewScreenState extends State<LoanOverviewScreen> {
  Map<String, List<Map<String, dynamic>>> _paymentHistory = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    setState(() => _isLoading = true);
    try {
      Map<String, List<Map<String, dynamic>>> history = {};
      
      for (Loan loan in widget.loans) {
        final payments = await SupabaseService().getLoanPaymentHistory(loan.id);
        history[loan.id] = payments;
      }
      
      setState(() {
        _paymentHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payment history: $e')),
        );
      }
    }
  }

  void _showEditPaymentModal(Map<String, dynamic> payment, Loan loan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _EditPaymentForm(
          payment: payment,
          loan: loan,
          onPaymentUpdated: () {
            _loadPaymentHistory();
            widget.onLoanUpdated();
          },
        ),
      ),
    );
  }

  void _showDeletePaymentConfirmation(Map<String, dynamic> payment, Loan loan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text('Are you sure you want to delete this payment of ${currencyFormatter.format(payment['payment_amount'])}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await SupabaseService().deletePayment(payment['id']);
                _loadPaymentHistory();
                widget.onLoanUpdated();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting payment: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(Loan loan) {
    final payments = _paymentHistory[loan.id] ?? [];
    final totalPaid = payments.fold<double>(0, (sum, payment) => sum + (payment['payment_amount'] as num).toDouble());
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                loan.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (loan.isPriority)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Priority',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: ${currencyFormatter.format(loan.totalAmount)}'),
                Text('Paid: ${currencyFormatter.format(totalPaid)}', 
     style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Remaining: ${currencyFormatter.format(loan.totalAmount - totalPaid)}'),
                if (loan.interestRate != null)
                  Text('Rate: ${loan.interestRate!.toStringAsFixed(2)}%'),
              ],
            ),
          ],
        ),
        children: [
          if (payments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No payments recorded yet'),
            )
          else
            ...payments.map((payment) => _buildPaymentTile(payment, loan)).toList(),
        ],
      ),
    );
  }

  Widget _buildPaymentTile(Map<String, dynamic> payment, Loan loan) {
    final amount = (payment['payment_amount'] as num).toDouble();
    final date = DateTime.parse(payment['payment_date']);
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Colors.green[100],
        child: const Icon(Icons.payment, color: Colors.green),
      ),
      title: Text(currencyFormatter.format(amount)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Date: ${DateFormat('MMM dd, yyyy').format(date)}'),
          if (payment['notes'] != null && payment['notes'].toString().isNotEmpty)
            Text('Note: ${payment['notes']}', style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') {
            _showEditPaymentModal(payment, loan);
          } else if (value == 'delete') {
            _showDeletePaymentConfirmation(payment, loan);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Overview',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadPaymentHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : widget.loans.isEmpty
              ? const Center(
                  child: Text('No loans found'),
                )
              : ListView.builder(
                  itemCount: widget.loans.length,
                  itemBuilder: (context, index) {
                    return _buildLoanCard(widget.loans[index]);
                  },
                ),
    );
  }
}

// Create the edit payment form:
class _EditPaymentForm extends StatefulWidget {
  final Map<String, dynamic> payment;
  final Loan loan;
  final VoidCallback onPaymentUpdated;

  const _EditPaymentForm({
    required this.payment,
    required this.loan,
    required this.onPaymentUpdated,
  });

  @override
  State<_EditPaymentForm> createState() => _EditPaymentFormState();
}

class _EditPaymentFormState extends State<_EditPaymentForm> {
  final _formKey = GlobalKey<FormState>();
  late double paymentAmount;
  late DateTime paymentDate;
  late String notes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    paymentAmount = (widget.payment['payment_amount'] as num).toDouble();
    paymentDate = DateTime.parse(widget.payment['payment_date']);
    notes = widget.payment['notes']?.toString() ?? '';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => paymentDate = picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await SupabaseService().updatePayment(
        paymentId: widget.payment['id'],
        amount: paymentAmount,
        date: paymentDate,
        notes: notes.isEmpty ? null : notes,
      );

      widget.onPaymentUpdated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating payment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Payment for ${widget.loan.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: paymentAmount.toString(),
              decoration: const InputDecoration(
                labelText: 'Payment Amount',
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
              validator: (val) => val == null || val.isEmpty
                  ? 'Required'
                  : double.tryParse(val) == null
                      ? 'Enter valid amount'
                      : null,
              onChanged: (val) => paymentAmount = double.tryParse(val) ?? paymentAmount,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text('Date: ${DateFormat('yyyy-MM-dd').format(paymentDate)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: notes,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
              ),
              onChanged: (val) => notes = val,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : const Text('Update Payment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoansScreenState extends State<LoansScreen> {
  List<Loan> _loans = [];
  Map<String, double> _statistics = {};
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadLoans();
    _loadStatistics();
  }

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);
    try {
      List<Loan> loans = await SupabaseService().getLoans();
      
      setState(() {
        _loans = loans;
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
          SnackBar(content: Text('Error loading loans: $e')),
        );
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await SupabaseService().getLoanStatistics();
      setState(() => _statistics = stats);
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadLoans();
    await _loadStatistics();
  }

  void _showAddLoanModal([Loan? existingLoan]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _LoanEntryForm(
          existingLoan: existingLoan,
          onLoanSaved: () {
            _loadLoans();
            _loadStatistics();
          },
        ),
      ),
    );
  }

  void _showPaymentModal(Loan loan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _PaymentForm(
          loan: loan,
          onPaymentMade: () {
            _loadLoans();
            _loadStatistics();
          },
        ),
      ),
    );
  }

// View Loan overview
  void _showLoanOverviewScreen() {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => LoanOverviewScreen(
        loans: _loans,
        onLoanUpdated: () {
          _loadLoans();
          _loadStatistics();
        },
      ),
    ),
  );
}

  void _showDeleteConfirmation(Loan loan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Loan'),
        content: Text('Are you sure you want to delete "${loan.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await SupabaseService().deleteLoan(loan.id);
                _loadLoans();
                _loadStatistics();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Loan deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting loan: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
  if (_statistics.isEmpty) return const SizedBox.shrink();
  
  return Card(
    margin: const EdgeInsets.all(16),
    child: InkWell(
      onTap: () => _showLoanOverviewScreen(),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Loan Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Total Debt', currencyFormatter.format(_statistics['totalDebt'] ?? 0)),
                _buildStatItem('Min Payments', currencyFormatter.format(_statistics['totalMinimumPayments'] ?? 0)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Total Paid', currencyFormatter.format(_statistics['totalPaid'] ?? 0)),
                _buildStatItem('Remaining', currencyFormatter.format(_statistics['totalRemaining'] ?? 0)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Highest Rate', '${_statistics['highestInterestRate']?.toStringAsFixed(2) ?? '0.00'}%'),
                _buildStatItem('Avg Rate', '${_statistics['averageInterestRate']?.toStringAsFixed(2) ?? '0.00'}%'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}


  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLoanList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _loans.length,
      itemBuilder: (context, index) {
        final loan = _loans[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    loan.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (loan.isPriority)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Priority',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total: ${currencyFormatter.format(loan.totalAmount)}'),
                    if (loan.dueDate != null) 
                      Text('Due: ${DateFormat('yyyy-MM-dd').format(loan.dueDate!)}'),
                  ],
                ),
                if (loan.minimumPayment != null)
                  Text('Min Payment: ${currencyFormatter.format(loan.minimumPayment!)}'),
                if (loan.interestRate != null)
                  Text('Interest: ${loan.interestRate!.toStringAsFixed(2)}%'),
                if (loan.notes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      loan.notes!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showAddLoanModal(loan);
                } else if (value == 'payment') {
                  _showPaymentModal(loan);
                } else if (value == 'delete') {
                  _showDeleteConfirmation(loan);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'payment', child: Text('Make Payment')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
            onTap: () => _showAddLoanModal(loan),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadLoans,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildStatisticsCard(),
                    if (_loans.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No loans found'),
                        ),
                      )
                    else
                      _buildLoanList(),
                    const SizedBox(height: 80), // Space for FAB
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLoanModal,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LoanEntryForm extends StatefulWidget {
  final Loan? existingLoan;
  final VoidCallback onLoanSaved;
  const _LoanEntryForm({this.existingLoan, required this.onLoanSaved});
  
  @override
  State<_LoanEntryForm> createState() => __LoanEntryFormState();
}

class __LoanEntryFormState extends State<_LoanEntryForm> {
  final _formKey = GlobalKey<FormState>();
  late String name;
  late double totalAmount;
  double? minimumPayment;
  double? interestRate;
  DateTime? dueDate;
  String? notes;
  bool isPriority = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final loan = widget.existingLoan;
    name = loan?.name ?? '';
    totalAmount = loan?.totalAmount ?? 0;
    minimumPayment = loan?.minimumPayment;
    interestRate = loan?.interestRate;
    dueDate = loan?.dueDate;
    notes = loan?.notes;
    isPriority = loan?.isPriority ?? false;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => dueDate = picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      if (widget.existingLoan != null) {
        // For updating existing loan
        final loan = Loan(
          id: widget.existingLoan!.id,
          type: widget.existingLoan!.type,
          name: name,
          totalAmount: totalAmount,
          minimumPayment: minimumPayment,
          interestRate: interestRate,
          dueDate: dueDate,
          notes: notes,
          isPriority: isPriority,
          paymentAmountMade: widget.existingLoan!.paymentAmountMade,
          payDate: widget.existingLoan!.payDate,
          amountMinusPayment: widget.existingLoan!.amountMinusPayment,
          createdAt: widget.existingLoan!.createdAt,
          updatedAt: DateTime.now(),
        );
        await SupabaseService().updateLoan(loan);
      } else {
        // For creating new loan
        final loan = Loan(
          id: '', // Empty for new loans - Supabase will generate
          type: 'LOAN', // Default type
          name: name,
          totalAmount: totalAmount,
          minimumPayment: minimumPayment,
          interestRate: interestRate,
          dueDate: dueDate,
          notes: notes,
          isPriority: isPriority,
          paymentAmountMade: 0,
          payDate: null,
          amountMinusPayment: totalAmount, // Initially equals total amount
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await SupabaseService().addLoan(loan);
      }
      
      widget.onLoanSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving loan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingLoan != null ? 'Edit Loan' : 'Add Loan',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(labelText: 'Loan Name'),
                onChanged: (val) => name = val,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: totalAmount > 0 ? totalAmount.toString() : '',
                decoration: const InputDecoration(labelText: 'Total Amount'),
                keyboardType: TextInputType.number,
                onChanged: (val) => totalAmount = double.tryParse(val) ?? 0,
                validator: (val) => totalAmount <= 0 ? 'Enter valid amount' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: minimumPayment?.toString(),
                decoration: const InputDecoration(labelText: 'Minimum Payment'),
                keyboardType: TextInputType.number,
                onChanged: (val) => minimumPayment = double.tryParse(val),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: interestRate?.toString(),
                decoration: const InputDecoration(labelText: 'Interest Rate %'),
                keyboardType: TextInputType.number,
                onChanged: (val) => interestRate = double.tryParse(val),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  dueDate == null
                      ? 'Select Due Date'
                      : 'Due: ${DateFormat('yyyy-MM-dd').format(dueDate!)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                onChanged: (val) => notes = val,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: isPriority,
                title: const Text('Mark as Priority'),
                onChanged: (val) => setState(() => isPriority = val ?? false),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Save Loan'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentForm extends StatefulWidget {
  final Loan loan;
  final VoidCallback onPaymentMade;
  const _PaymentForm({required this.loan, required this.onPaymentMade});
  
  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  final _formKey = GlobalKey<FormState>();
  double? paymentAmount;
  DateTime? paymentDate;
  bool _isSaving = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => paymentDate = picked);
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await SupabaseService().addLoanPayment(
        loanId: widget.loan.id,
        amount: paymentAmount!,
        date: paymentDate ?? DateTime.now(),
      );
      widget.onPaymentMade();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving payment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record Payment for ${widget.loan.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Payment Amount',
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
              validator: (val) => val == null || val.isEmpty
                  ? 'Required'
                  : double.tryParse(val) == null
                      ? 'Enter valid amount'
                      : null,
              onChanged: (val) => paymentAmount = double.tryParse(val),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(
                paymentDate == null
                    ? 'Select Payment Date'
                    : 'Date: ${DateFormat('yyyy-MM-dd').format(paymentDate!)}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _submitPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }
}