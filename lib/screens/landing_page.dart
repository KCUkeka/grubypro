import 'package:flutter/material.dart';
import 'package:grubypro/screens/ecb/ecb_home.dart';
import 'package:grubypro/screens/gruby/grubyhome.dart';
import 'paypro/paypro_home.dart'; 

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Choose Your App',
          style: TextStyle(
            fontWeight: FontWeight.bold, // Makes text bold
            fontSize: 20, // Optional: Adjust font size if needed
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
        toolbarHeight: 80, // Increases AppBar height (brings text down)
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AppCard(
              title: 'Gruby',
              description: 'Grocery & Pantry Tracker',
              icon: Image.asset('lib/img/gruby.png', width: 40, height: 40),
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GrubyHome()),
                );
              },
            ),
            const SizedBox(height: 24),
            _AppCard(
              title: 'PayPro',
              description: 'Bill Management & Payments',
              icon: Image.asset('lib/img/paypro_blue.png', width: 40, height: 40),
              color: Colors.deepOrange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PayproHomeScreen()),
                );
              },
            ),
            const SizedBox(height: 24),
            _AppCard(
              title: 'ECB',
              description: 'Ethalle Cake & Bakes',
              icon: Image.asset('lib/img/ecb_logo.png', width: 40, height: 40),
              color: const Color.fromARGB(234, 225, 84, 131),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EcbHomeScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget icon;
  final Color color;
  final VoidCallback onTap;

  const _AppCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.1),
              child: icon,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
