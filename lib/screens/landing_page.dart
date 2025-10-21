import 'package:flutter/material.dart';
import 'package:grubypro/screens/ecb/ecb_home.dart';
import 'package:grubypro/screens/gruby/grubyhome.dart';
import 'paypro/paypro_home.dart';
import 'package:desktop_updater/desktop_updater.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _isCheckingUpdate = false;

  Future<void> _checkForUpdates() async {
  setState(() => _isCheckingUpdate = true);

  try {
    final updater = DesktopUpdater();
    final updateInfo = await updater.versionCheck(
      appArchiveUrl: 'https://raw.githubusercontent.com/KCUkeka/grubypro/blob/Desktop/releases/latest.json',
    );

    if (updateInfo != null) {
      // e.g. compare updateInfo.version with current version
      // if new version → call updateApp
      final updateStream = await updater.updateApp(
        remoteUpdateFolder: updateInfo.url, 
        changedFiles: updateInfo.changes, // depends on how updateInfo is structured
      );

      // maybe listen to updateStream for progress
      await updater.restartApp();
      _showSnack('Update applied. Restarting...');
    } else {
      _showSnack('No update available.');
    }
  } catch (e) {
    _showSnack('Error checking updates: $e');
  } finally {
    setState(() => _isCheckingUpdate = false);
  }
}


  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Select Your App',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
        toolbarHeight: 80,
        actions: [
          IconButton(
            tooltip: 'Check for Updates',
            icon:
                _isCheckingUpdate
                    ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : const Icon(Icons.system_update),
            onPressed: _isCheckingUpdate ? null : _checkForUpdates,
          ),
        ],
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
              icon: Image.asset(
                'lib/img/paypro_blue.png',
                width: 40,
                height: 40,
              ),
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
            ),
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
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
