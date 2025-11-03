import 'package:flutter/material.dart';
import 'package:grubypro/screens/ecb/sale_calculator.dart';

// **********************************SALES PAGE******************************************
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        backgroundColor: const Color(0xFFD4AF37),
      ),
      body: Column(
        children: [
          // Summary cards
          _buildSummaryCards(),
          
          // Sales list
          Expanded(
            child: _buildSalesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SaleCalculator()),
          );
        },
        backgroundColor: const Color(0xFFD4AF37),
        icon: const Icon(Icons.add),
        label: const Text('New Sale'),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard('Today', '\$0.00', Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _summaryCard('This Week', '\$0.00', Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _summaryCard('This Month', '\$0.00', Colors.purple),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String amount, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesList() {
    // TODO: Fetch from Supabase
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 0, // Replace with actual data
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFD4AF37),
              child: const Icon(Icons.shopping_bag, color: Colors.white),
            ),
            title: const Text('Sale #123'),
            subtitle: const Text('Jan 15, 2025 • 3 items'),
            trailing: const Text(
              '\$45.00',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            onTap: () {
              // Navigate to sale detail
            },
          ),
        );
      },
    );
  }
}