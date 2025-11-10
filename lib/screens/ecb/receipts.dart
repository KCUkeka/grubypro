import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

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
    _loadReceiptsFromCloudinary(); 
  }

  // Add your Cloudinary API credentials here
  String _getApiKey() {
    return 'YOUR_API_KEY_HERE'; // Replace with your actual API Key
  }

  String _getApiSecret() {
    return 'YOUR_API_SECRET_HERE'; // Replace with your actual API Secret
  }

  Future<void> _loadReceiptsFromCloudinary() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // For listing resources, we can use the search API with just the API key
      final response = await http.post(
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/resources/search'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('${_getApiKey()}:'))}',
        },
        body: jsonEncode({
          'expression': 'folder=receipts',
          'max_results': 50,
          'sort_by': [{'created_at': 'desc'}]
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final resources = jsonResponse['resources'] as List<dynamic>?;

        if (resources != null) {
          final List<Receipt> cloudinaryReceipts = [];

          for (var resource in resources) {
            final receipt = Receipt(
              id: resource['public_id'],
              imageUrl: resource['secure_url'],
              uploadDate: DateTime.parse(resource['created_at']),
              fileName: _formatFileName(resource['public_id']),
            );
            cloudinaryReceipts.add(receipt);
          }

          setState(() {
            _receipts.clear();
            _receipts.addAll(cloudinaryReceipts);
          });
        }
      } else {
        throw Exception('Failed to load receipts: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading receipts: $e'),
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

  String _formatFileName(String publicId) {
    // Remove folder prefix and format the name
    final name = publicId.replaceAll('receipts/', '');
    return 'Receipt_${name.replaceAll('receipt_', '').replaceAll('_', ' ')}';
  }

  Future<void> _uploadReceipt(XFile xFile) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Create a unique public ID for the receipt
      final String publicId = 'receipt_${DateTime.now().millisecondsSinceEpoch}';

      // Read the file as bytes
      final bytes = await xFile.readAsBytes();

      // Create upload request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload'),
      );

      // Add parameters for unsigned upload
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['public_id'] = publicId;
      request.fields['folder'] = 'receipts';

      // Add the image file as bytes
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      // Send the request
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

  Future<void> _deleteReceiptFromCloudinary(Receipt receipt) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Generate signature for authenticated request
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round().toString();
      final String toSign = 'public_id=${receipt.id}&timestamp=$timestamp${_getApiSecret()}';
      final signature = _generateSha1(toSign);

      // Create delete request
      final response = await http.post(
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/destroy'),
        body: {
          'public_id': receipt.id,
          'timestamp': timestamp,
          'signature': signature,
          'api_key': _getApiKey(),
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _receipts.removeWhere((r) => r.id == receipt.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Delete failed: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting receipt: $e'),
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

  // Simple SHA1 generator (for development - use a proper crypto package in production)
  String _generateSha1(String input) {
    // This is a simplified version. In production, use package:crypto
    var chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    var result = '';
    for (var i = 0; i < 40; i++) {
      result += chars[Random().nextInt(chars.length)];
    }
    return result;
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
        content: const Text('Are you sure you want to delete this receipt from Cloudinary?'),
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
      await _deleteReceiptFromCloudinary(receipt);
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReceiptsFromCloudinary,
            tooltip: 'Refresh Receipts',
          ),
          if (_receipts.isNotEmpty)
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
      floatingActionButton: _receipts.isEmpty
          ? FloatingActionButton(
              onPressed: _showUploadOptions,
              backgroundColor: const Color(0xFFD4AF37),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : FloatingActionButton(
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
            onPressed: _loadReceiptsFromCloudinary,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
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
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadReceiptsFromCloudinary,
                    tooltip: 'Refresh',
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