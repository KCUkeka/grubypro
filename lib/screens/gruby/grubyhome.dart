import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'shopping_list_screen.dart';
import 'pantry_screen.dart';
import 'recipe.dart';

class GrubyHome extends StatefulWidget {
  const GrubyHome({super.key});

  @override
  State<GrubyHome> createState() => _GrubyHomeState();
}

class _GrubyHomeState extends State<GrubyHome> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(),
    ShoppingListScreen(),
    PantryScreen(),
    RecipeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 8,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            label: 'Shopping',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.kitchen_outlined),
            label: 'Pantry',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Recipe',
          ),
        ],
      ),
    );
  }
}
