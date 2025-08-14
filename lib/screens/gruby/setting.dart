import 'package:flutter/material.dart';
import 'package:grubypro/screens/paypro/bill_screen.dart';
import 'package:grubypro/screens/landing_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _expiryNotifications = true;
  bool _lowStockAlerts = true;
  bool _darkMode = false;

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Data'),
          content: const Text(
            'Are you sure you want to delete all shopping lists and pantry items? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Add your clear data logic here
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All data cleared successfully'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear Data'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.black87),
            tooltip: 'Go to Home',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LandingPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // Shopping List Section
          
          // _buildSectionHeader('GRUBY'),
          // _buildSettingsTile(
          //   icon: Icons.shopping_bag_outlined,
          //   iconColor: Colors.green,
          //   title: 'Shopping Lists',
          //   subtitle: 'View and restore archived shopping items',
          //   hasArrow: true,
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const BillsScreen(showArchived: true)),
          //     );
          //   },
          // ),
          const SizedBox(height: 24),
          // Manage Bills
          _buildSectionHeader('PAYPRO'),
          _buildSettingsTile(
            icon: Icons.receipt_long,
            iconColor: Colors.blueGrey,
            title: 'Manage Bills',
            subtitle: 'View and restore archived bills',
            hasArrow: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillsScreen(showArchived: true)),
              );
            },
          ),

          // NOTIFICATIONS Section
          _buildSectionHeader('NOTIFICATIONS'),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            iconColor: Colors.brown,
            title: 'Expiry Notifications',
            trailing: Switch(
              value: _expiryNotifications,
              onChanged: (value) {
                setState(() {
                  _expiryNotifications = value;
                });
              },
              activeColor: Colors.green,
            ),
          ),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            iconColor: Colors.brown,
            title: 'Low Stock Alerts',
            trailing: Switch(
              value: _lowStockAlerts,
              onChanged: (value) {
                setState(() {
                  _lowStockAlerts = value;
                });
              },
              activeColor: Colors.green,
            ),
          ),
          const SizedBox(height: 24),

          // APPEARANCE Section
          _buildSectionHeader('APPEARANCE'),
          _buildSettingsTile(
            icon: Icons.dark_mode_outlined,
            iconColor: Colors.orange,
            title: 'Dark Mode',
            trailing: Switch(
              value: _darkMode,
              onChanged: (value) {
                setState(() {
                  _darkMode = value;
                });
              },
              activeColor: Colors.green,
            ),
          ),
          const SizedBox(height: 24),

          // DATA Section

          // _buildSectionHeader('DATA'),
          // _buildSettingsTile(
          //   icon: Icons.delete_outline,
          //   iconColor: Colors.red,
          //   title: 'Clear All Data',
          //   subtitle: 'Delete all shopping lists and\npantry items',
          //   hasArrow: true,
          //   onTap: _showClearDataDialog,
          // ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool hasArrow = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        subtitle:
            subtitle != null
                ? Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                )
                : null,
        trailing:
            trailing ??
            (hasArrow
                ? Icon(Icons.chevron_right, color: Colors.grey[400])
                : null),
        onTap: onTap,
      ),
    );
  }
}
