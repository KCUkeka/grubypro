import 'package:flutter/material.dart';
import 'package:grubypro/screens/ecb/ecb_home.dart';
import 'package:grubypro/screens/gruby/grubyhome.dart';
import 'package:grubypro/screens/paypro/paypro_home.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  String _currentVersion = '1.0.2';
  bool _checkingForUpdates = false;
  String _platform = 'unknown';

  @override
  void initState() {
    super.initState();
    _initializeAppInfo();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoCheckForUpdates();
    });
  }

  Future<void> _initializeAppInfo() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      
      // Detect platform
    if (kIsWeb) {
  _platform = 'web';
} else if (defaultTargetPlatform == TargetPlatform.android) {
  _platform = 'android';
} else if (defaultTargetPlatform == TargetPlatform.iOS) {
  _platform = 'ios';
} else if (defaultTargetPlatform == TargetPlatform.windows) {
  _platform = 'windows';
} else if (defaultTargetPlatform == TargetPlatform.macOS) {
  _platform = 'macos';
} else if (defaultTargetPlatform == TargetPlatform.linux) {
  _platform = 'linux';
}

      
      setState(() {
        _currentVersion = packageInfo.version;
      });
    } catch (e) {
      debugPrint('Failed to get package info: $e');
    }
  }

  Future<void> _autoCheckForUpdates() async {
    try {
      await _checkForUpdates(showDialogIfUpToDate: false);
    } catch (e) {
      debugPrint('Auto update check failed: $e');
    }
  }

  Future<void> _manualCheckForUpdates() async {
    await _checkForUpdates(showDialogIfUpToDate: true);
  }

  Future<void> _checkForUpdates({bool showDialogIfUpToDate = true}) async {
    if (kIsWeb) {
  debugPrint("Skipping update check on Web");
  return;
}

    if (_checkingForUpdates) return;
    
    setState(() {
      _checkingForUpdates = true;
    });

    try {
      final response = await http.get(
  Uri.parse('https://raw.githubusercontent.com/KCUkeka/grubypro/main/releases/app-archive.json'),
);

if (response.statusCode != 200) {
  throw Exception('Failed to fetch update info');
}

final jsonData = jsonDecode(response.body);

      
      // Find the correct platform item
      final platformItems = (jsonData['items'] as List)
          .where((item) => item['platform'] == _platform)
          .toList();
          
      if (platformItems.isEmpty) {
        throw Exception('No update information available for $_platform');
      }
      
      final latestItem = platformItems.first;
      final latestVersion = latestItem['version'];
      
      if (_isNewerVersion(latestVersion, _currentVersion)) {
        final downloadUrl = latestItem['url'];
        final changes = latestItem['changes'] as List;
        _showUpdateDialog(downloadUrl, latestVersion, changes);
      } else {
        if (showDialogIfUpToDate && mounted) {
          _showUpToDateDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update check failed: $e")),
        );
      }
      debugPrint("Update check failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          _checkingForUpdates = false;
        });
      }
    }
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _showUpdateDialog(String downloadUrl, String version, List changes) {
    String platformName = _getPlatformName();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Version $version is available for $platformName!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('What\'s new:'),
              const SizedBox(height: 5),
              ...changes
                  .map(
                    (change) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 4),
                      child: Text('• ${change['message']}'),
                    ),
                  )
                  .toList(),
              const SizedBox(height: 10),
              Text(
                'Click "Download Update" to get the latest $platformName version.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchDownload(downloadUrl);
            },
            child: const Text('Download Update'),
          ),
        ],
      ),
    );
  }

  String _getPlatformName() {
    switch (_platform) {
      case 'android': return 'Android';
      case 'ios': return 'iOS';
      case 'windows': return 'Windows';
      case 'macos': return 'macOS';
      case 'linux': return 'Linux';
      default: return 'this platform';
    }
  }

  void _showUpToDateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Up to Date'),
        content: Text(
          'You are using the latest version of GrubyPro for ${_getPlatformName()}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchDownload(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening download page...'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open download: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Choose Your App',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
        toolbarHeight: 80,
        actions: [
          IconButton(
            icon: _checkingForUpdates 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update),
            tooltip: 'Check for Updates',
            onPressed: _checkingForUpdates ? null : _manualCheckForUpdates,
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