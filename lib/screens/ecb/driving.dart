import 'package:flutter/material.dart';

class DrivingScreen extends StatelessWidget {
  const DrivingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driving'),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Driving Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}