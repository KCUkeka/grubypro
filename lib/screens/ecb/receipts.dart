import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final List<Receipt> _receipts = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // Cloudinary configuration
  static const String _cloudName = 'dztqw4mtu';
  static const String _uploadPreset = 'receipts';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await dotenv.load(fileName: ".env");
      // For web, we'll start with an empty list and rely on uploads
      // Loading from Cloudinary requires a backend due to CORS
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getApiKey() {
    return dotenv.get('CLOUDINARY_API_KEY', fallback: '');
  }

  String _getApiSecret() {
    return dotenv.get('CLOUDINARY_API_SECRET', fallback: '');
  }

  // Simple method to store receipts locally (for web compatibility)
  void _saveReceiptsLocally() {
    // Store in local storage for web persistence
    final receiptsJson = _receipts.map((receipt) => {
      'id': receipt.id,
      'imageUrl': receipt.imageUrl,
      'uploadDate': receipt.uploadDate.toIso8601String(),
      'fileName': receipt.fileName,
    }).toList();
    
    // For web, use shared_preferences or similar for persistence
    // For now, we'll just keep it in memory
  }

  // Load receipts from local storage
  void _loadReceiptsLocally() {
    // In a real app, you'd load from shared_preferences or similar
    // For now, we'll rely on the user uploading new receipts
  }

  Future<void> _uploadReceipt(XFile xFile) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String publicId = 'receipt_${DateTime.now().millisecondsSinceEpoch}';
      final bytes = await xFile.readAsBytes();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload'),
      );

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['public_id'] = publicId;
      request.fields['folder'] = 'receipts';

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200) {
        final Receipt newReceipt = Receipt(
          id: jsonResponse['public_id'],
          imageUrl: jsonResponse['secure_url'],
          uploadDate: DateTime.now(),
          fileName: 'Receipt_${DateFormat('MMM dd, yyyy - HH:mm').format(DateTime.now())}',
        );

        setState(() {
          _receipts.insert(0, newReceipt);
        });

        _saveReceiptsLocally();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Upload failed: ${jsonResponse['error']['message']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Alternative: Try to fetch using a different endpoint that might not have CORS issues
  Future<void> _tryAlternativeLoad() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // This is a long shot, but let's try the regular resources endpoint
      final response = await http.get(
        Uri.parse('https://res.cloudinary.com/$_cloudName/image/list/receipts.json'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final resources = jsonResponse['resources'] as List<dynamic>?;

        if (resources != null) {
          final List<Receipt> cloudinaryReceipts = [];

          for (var resource in resources) {
            final receipt = Receipt(
              id: resource['public_id'],
              imageUrl: 'https://res.cloudinary.com/$_cloudName/image/upload/${resource['public_id']}',
              uploadDate: DateTime.parse(resource['created_at']),
              fileName: _formatFileName(resource['public_id']),
            );
            cloudinaryReceipts.add(receipt);
          }

          setState(() {
            _receipts.clear();
            _receipts.addAll(cloudinaryReceipts);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Receipts loaded successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        throw Exception('Alternative load failed: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alternative load also failed: $e\n\nFor web deployment, consider using a backend API to avoid CORS issues.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatFileName(String publicId) {
    final name = publicId.replaceAll('receipts/', '');
    return 'Receipt_${name.replaceAll('receipt_', '').replaceAll('_', ' ')}';
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      await _uploadReceipt(image);
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      await _uploadReceipt(image);
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Color(0xFFD4AF37)),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFD4AF37)),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewReceipt(Receipt receipt) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(receipt.fileName),
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 3.0,
                child: Image.network(
                  receipt.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy - HH:mm').format(receipt.uploadDate),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteReceipt(receipt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteReceipt(Receipt receipt) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: const Text('Are you sure you want to delete this receipt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() {
        _receipts.removeWhere((r) => r.id == receipt.id);
      });
      
      _saveReceiptsLocally();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt removed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'alternative') {
                _tryAlternativeLoad();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'alternative',
                child: Text('Try Load Existing Receipts'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showUploadOptions,
            tooltip: 'Upload Receipt',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _receipts.isEmpty
              ? _buildEmptyState()
              : _buildReceiptsGrid(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showUploadOptions,
        backgroundColor: const Color(0xFFD4AF37),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          const Text(
            'No Receipts Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Upload your first receipt to get started',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Note: Web version can upload but cannot load existing receipts due to browser security restrictions.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _showUploadOptions,
            icon: const Icon(Icons.upload),
            label: const Text('Upload Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _tryAlternativeLoad,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Load Existing Receipts'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptsGrid() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_receipts.length} ${_receipts.length == 1 ? 'Receipt' : 'Receipts'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showUploadOptions,
                icon: const Icon(Icons.add),
                label: const Text('Add Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            itemCount: _receipts.length,
            itemBuilder: (context, index) {
              final receipt = _receipts[index];
              return _buildReceiptCard(receipt);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptCard(Receipt receipt) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewReceipt(receipt),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  receipt.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.grey, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receipt.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(receipt.uploadDate),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Receipt {
  final String id;
  final String imageUrl;
  final DateTime uploadDate;
  final String fileName;

  Receipt({
    required this.id,
    required this.imageUrl,
    required this.uploadDate,
    required this.fileName,
  });
}