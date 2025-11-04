import 'package:flutter/material.dart';
import 'package:grubypro/screens/ecb/driving.dart';
import 'package:grubypro/screens/ecb/invoice.dart';
import 'package:grubypro/screens/ecb/receipts.dart';
import 'package:grubypro/screens/ecb/sales.dart';

class EcbHomeScreen extends StatefulWidget {
  const EcbHomeScreen({super.key});

  @override
  State<EcbHomeScreen> createState() => _EcbHomeScreenState();
}

class _EcbHomeScreenState extends State<EcbHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const SalesScreen(),
    const InvoiceScreen(),
    const ReceiptsScreen(),
    const DrivingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // This ensures all 4 tabs are visible
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFFD4AF37), // Golden color matching your brand
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.money_off_outlined),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Invoice',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Receipts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Driving',
          ),
        ],
      ),
    );
  }
}