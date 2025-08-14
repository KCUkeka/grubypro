import 'package:grubypro/models/bills.dart';
import 'package:grubypro/models/loans.dart';
import 'package:grubypro/models/transactions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/grocery_item.dart';
import '../models/pantry_item.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  SupabaseClient get client => _client;

  // ─── Grocery Items ───────────────────────────────────────────

  Future<void> addGroceryItem(GroceryItem item) =>
      _client.from('grocery_items').insert(item.toMap());

  Future<List<GroceryItem>> getGroceryItems() async {
    final data = await _client
        .from('shopping_list')
        .select()
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => GroceryItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateGroceryItem(GroceryItem item) => _client
      .from('shopping_list')
      .update(item.toMap())
      .eq('id', item.id as Object);

  Future<void> deleteGroceryItem(String id) =>
      _client.from('shopping_list').delete().eq('id', id);

  Future<List<String>> getSuggestions(String query) async {
    final data = await _client
        .from('purchase_history')
        .select('name')
        .ilike('name', '$query%')
        .order('purchase_date', ascending: false)
        .limit(5);
    return (data as List).map((e) => e['name'] as String).toList();
  }

  Future<void> addToPurchaseHistory(
    String name,
    String category,
    String? barcode,
  ) => _client.from('purchase_history').insert({
    'name': name,
    'category': category,
    'purchase_date': DateTime.now().toIso8601String(),
    'barcode': barcode,
  });

  // ─── Pantry Items ────────────────────────────────────────────

  Future<void> addPantryItem(PantryItem item) =>
      _client.from('pantry_items').insert(item.toMap());

  Future<List<PantryItem>> getPantryItems() async {
    final data = await _client
        .from('pantry_items')
        .select()
        .order('added_at', ascending: false);
    return (data as List)
        .map((e) => PantryItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updatePantryItem(PantryItem item) => _client
      .from('pantry_items')
      .update(item.toMap())
      .eq('id', item.id as Object);

  Future<void> deletePantryItem(String id) =>
      _client.from('pantry_items').delete().eq('id', id);

  Future<List<PantryItem>> getExpiringSoonItems() async {
    final now = DateTime.now().toIso8601String();
    final soon = DateTime.now().add(Duration(days: 3)).toIso8601String();
    final data = await _client
        .from('pantry_items')
        .select()
        .gte('expiry_date', now)
        .lte('expiry_date', soon)
        .order('expiry_date', ascending: true);
    return (data as List)
        .map((e) => PantryItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }
  // ─── Bill Items ────────────────────────────────────────────

  Future<void> addBill(Bill bill) async {
    await _client.from('bills').insert(bill.toJson());
  }

  // ─── Get Bill  ────────────────────────────────────────────
  Future<List<Bill>> getBills({bool archived = false}) async {
    final data = await _client
        .from('bills')
        .select()
        .eq('archived', archived)
        .order('due_date');

    return (data as List).map((json) => Bill.fromJson(json)).toList();
  }

  // ─── Update Bill  ────────────────────────────────────────────
  Future<void> updateBill(Bill bill) async {
    await _client.from('bills').update(bill.toJson()).eq('id', bill.id);
  }

  // ─── Archive Bill  ────────────────────────────────────────────
  Future<void> archiveBill(String id) async {
    await _client.from('bills').update({'archived': true}).eq('id', id);
  }

  Future<void> unarchiveBill(String id) async {
    await _client.from('bills').update({'archived': false}).eq('id', id);
  }

  // ─── Delete Bill  ────────────────────────────────────────────
  Future<void> deleteBill(String id) async {
    await _client.from('bills').delete().eq('id', id);
  }

  // ─── Search Bill  ────────────────────────────────────────────
  Future<List<String>> getBillNameSuggestions(String query) async {
    final response = await _client
        .from('bills')
        .select('name')
        .ilike('name', '%$query%') // Match anywhere in name
        .eq('archived', false); // Only unarchived bills

    return (response as List)
        .map((e) => e['name'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
  }
  //  ─── Transactions  ────────────────────────────────────────────
  // Add these methods to your SupabaseService class

  // Get transactions with archive filter
  Future<List<AppTransaction>> getTransactions() async {
    final response = await _client
        .from('transactions')
        .select('*')
        .order('date', ascending: false);
    return (response as List)
        .map((e) => AppTransaction.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Add a transaction
  Future<void> addTransaction(AppTransaction transaction) async {
    await _client.from('transactions').insert(transaction.toMapForInsert());
  }

  // Update a transaction
  Future<void> updateTransaction(AppTransaction transaction) async {
    await _client
        .from('transactions')
        .update(transaction.toMapForUpdate())
        .eq('id', transaction.id);
  }

  // Delete a transaction
  Future<void> deleteTransaction(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }


  
// ─── Loan Management ────────────────────────────────────────────

// Get all loans
Future<List<Loan>> getLoans() async {
  final response = await _client
      .from('loans')
      .select('*')
      .order('type')
      .order('name');
  return (response as List)
      .map((e) => Loan.fromJson(e as Map<String, dynamic>))
      .toList();
}

// Get loans by type
Future<List<Loan>> getLoansByType(String type) async {
  final response = await _client
      .from('loans')
      .select('*')
      .eq('type', type)
      .order('name');
  return (response as List)
      .map((e) => Loan.fromJson(e as Map<String, dynamic>))
      .toList();
}

// Get priority loans
Future<List<Loan>> getPriorityLoans() async {
  final response = await _client
      .from('loans')
      .select('*')
      .eq('is_priority', true)
      .order('interest_rate', ascending: false);
  return (response as List)
      .map((e) => Loan.fromJson(e as Map<String, dynamic>))
      .toList();
}

// Add a loan
Future<void> addLoan(Loan loan) async {
  await _client.from('loans').insert(loan.toJsonForInsert());
}

// Update a loan
Future<void> updateLoan(Loan loan) async {
  await _client
      .from('loans')
      .update(loan.toJsonForUpdate())
      .eq('id', loan.id);
}

// Delete a loan
Future<void> deleteLoan(String id) async {
  await _client.from('loans').delete().eq('id', id);
}

// Make a payment on a loan
Future<void> makePayment(String loanId, double paymentAmount, DateTime paymentDate, {String? notes}) async {
  // Update the loan with payment info
  final loan = await _client
      .from('loans')
      .select('*')
      .eq('id', loanId)
      .single();
  
  final currentPayment = (loan['payment_amount_made'] as num?)?.toDouble() ?? 0.0;
  final totalAmount = (loan['total_amount'] as num?)?.toDouble() ?? 0.0;
  final newPaymentTotal = currentPayment + paymentAmount;
  final newRemainingAmount = totalAmount - newPaymentTotal;

  await _client
      .from('loans')
      .update({
        'payment_amount_made': newPaymentTotal,
        'pay_date': paymentDate.toIso8601String(),
        'amount_minus_payment': newRemainingAmount,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('id', loanId);

  // Add to payment history
  await _client.from('loan_payments').insert({
    'loan_id': loanId,
    'payment_amount': paymentAmount,
    'payment_date': paymentDate.toIso8601String(),
    'notes': notes,
  });
}

Future<void> addLoanPayment({
  required String loanId,
  required double amount,
  required DateTime date,
  String? notes,
}) async {
  // This calls the existing makePayment method
  await makePayment(loanId, amount, date, notes: notes);
}

// Get payment history for a loan
Future<List<Map<String, dynamic>>> getLoanPaymentHistory(String loanId) async {
  final response = await _client
      .from('loan_payments')
      .select('*')
      .eq('loan_id', loanId)
      .order('payment_date', ascending: false);
  return List<Map<String, dynamic>>.from(response);
}

// Get loan statistics
Future<Map<String, double>> getLoanStatistics() async {
  final loans = await getLoans();
  
  double totalDebt = 0;
  double totalMinimumPayments = 0;
  double totalPaid = 0;
  double totalRemaining = 0;
  double highestInterestRate = 0;
  
  for (final loan in loans) {
    totalDebt += loan.totalAmount;
    totalMinimumPayments += loan.minimumPayment ?? 0;
    totalPaid += loan.paymentAmountMade;
    totalRemaining += loan.amountMinusPayment;
    if (loan.interestRate != null && loan.interestRate! > highestInterestRate) {
      highestInterestRate = loan.interestRate!;
    }
  }
  
  return {
    'totalDebt': totalDebt,
    'totalMinimumPayments': totalMinimumPayments,
    'totalPaid': totalPaid,
    'totalRemaining': totalRemaining,
    'highestInterestRate': highestInterestRate,
    'averageInterestRate': loans.where((l) => l.interestRate != null).isEmpty
        ? 0
        : loans.where((l) => l.interestRate != null).map((l) => l.interestRate!).reduce((a, b) => a + b) /
            loans.where((l) => l.interestRate != null).length,
  };
}
// Update a payment record
Future<void> updatePayment({
  required String paymentId,
  required double amount,
  required DateTime date,
  String? notes,
}) async {
  // First get the old payment to calculate difference
  final oldPayment = await _client
      .from('loan_payments')
      .select('payment_amount, loan_id')
      .eq('id', paymentId)
      .single();

  final oldAmount = (oldPayment['payment_amount'] as num).toDouble();
  final loanId = oldPayment['loan_id'];
  final amountDifference = amount - oldAmount;

  // Update the payment record
  await _client
      .from('loan_payments')
      .update({
        'payment_amount': amount,
        'payment_date': date.toIso8601String(),
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('id', paymentId);

  // Update the loan's payment totals
  final loan = await _client
      .from('loans')
      .select('payment_amount_made, total_amount')
      .eq('id', loanId)
      .single();

  final currentPaymentTotal = (loan['payment_amount_made'] as num?)?.toDouble() ?? 0.0;
  final totalAmount = (loan['total_amount'] as num?)?.toDouble() ?? 0.0;
  final newPaymentTotal = currentPaymentTotal + amountDifference;
  final newRemainingAmount = totalAmount - newPaymentTotal;

  await _client
      .from('loans')
      .update({
        'payment_amount_made': newPaymentTotal,
        'amount_minus_payment': newRemainingAmount,
        'pay_date': date.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('id', loanId);
}

// Delete a payment record
Future<void> deletePayment(String paymentId) async {
  // First get the payment details to update the loan
  final payment = await _client
      .from('loan_payments')
      .select('payment_amount, loan_id')
      .eq('id', paymentId)
      .single();

  final paymentAmount = (payment['payment_amount'] as num).toDouble();
  final loanId = payment['loan_id'];

  // Delete the payment record
  await _client
      .from('loan_payments')
      .delete()
      .eq('id', paymentId);

  // Update the loan's payment totals
  final loan = await _client
      .from('loans')
      .select('payment_amount_made, total_amount')
      .eq('id', loanId)
      .single();

  final currentPaymentTotal = (loan['payment_amount_made'] as num?)?.toDouble() ?? 0.0;
  final totalAmount = (loan['total_amount'] as num?)?.toDouble() ?? 0.0;
  final newPaymentTotal = currentPaymentTotal - paymentAmount;
  final newRemainingAmount = totalAmount - newPaymentTotal;

  await _client
      .from('loans')
      .update({
        'payment_amount_made': newPaymentTotal,
        'amount_minus_payment': newRemainingAmount,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('id', loanId);

  // If no payments left, clear the pay_date
  final remainingPayments = await _client
      .from('loan_payments')
      .select('id')
      .eq('loan_id', loanId);

  if (remainingPayments.isEmpty) {
    await _client
        .from('loans')
        .update({'pay_date': null})
        .eq('id', loanId);
  }
}

// Get all payments for all loans (useful for overview)
Future<Map<String, List<Map<String, dynamic>>>> getAllLoanPayments() async {
  final response = await _client
      .from('loan_payments')
      .select('*, loans!inner(name)')
      .order('payment_date', ascending: false);

  Map<String, List<Map<String, dynamic>>> groupedPayments = {};
  
  for (var payment in response) {
    final loanId = payment['loan_id'];
    if (!groupedPayments.containsKey(loanId)) {
      groupedPayments[loanId] = [];
    }
    groupedPayments[loanId]!.add(payment);
  }
  
  return groupedPayments;
}

// Get payment summary for a specific loan
Future<Map<String, dynamic>> getLoanPaymentSummary(String loanId) async {
  final payments = await getLoanPaymentHistory(loanId);
  
  double totalPaid = 0;
  int paymentCount = payments.length;
  DateTime? lastPaymentDate;
  
  for (var payment in payments) {
    totalPaid += (payment['payment_amount'] as num).toDouble();
    
    final paymentDate = DateTime.parse(payment['payment_date']);
    if (lastPaymentDate == null || paymentDate.isAfter(lastPaymentDate)) {
      lastPaymentDate = paymentDate;
    }
  }
  
  return {
    'totalPaid': totalPaid,
    'paymentCount': paymentCount,
    'lastPaymentDate': lastPaymentDate?.toIso8601String(),
    'averagePayment': paymentCount > 0 ? totalPaid / paymentCount : 0,
  };
}
}
