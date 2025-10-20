import 'package:flutter/material.dart';
import 'package:grubypro/screens/paypro/bill_screen.dart';
import 'package:grubypro/screens/paypro/loans_screen.dart';
import 'package:grubypro/screens/paypro/transactions_screen.dart';

class PayproHomeScreen extends StatefulWidget {
  const PayproHomeScreen({super.key});

  @override
  State<PayproHomeScreen> createState() => _PayproHomeScreenState();
}

class _PayproHomeScreenState extends State<PayproHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const BillsScreen(),
    const TransactionsScreen(),
    const LoansScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Bills'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: 'Loans'),
        ],
      ),
    );
  }
}
