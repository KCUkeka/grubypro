
// // File: lib/screens/camera_upload_screen.dart
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:grubypro/services/google_drive_service.dart';
// import 'package:image_picker/image_picker.dart';

// class CameraUploadScreen extends StatefulWidget {
//   const CameraUploadScreen({super.key});

//   @override
//   State<CameraUploadScreen> createState() => _CameraUploadScreenState();
// }

// class _CameraUploadScreenState extends State<CameraUploadScreen> {
//   final GoogleDriveService _driveService = GoogleDriveService();
//   final ImagePicker _picker = ImagePicker();
  
//   File? _selectedImage;
//   bool _isUploading = false;
//   bool _isSignedIn = false;

//   @override
//   void initState() {
//     super.initState();
//     _checkSignInStatus();
//   }

//   void _checkSignInStatus() {
//     setState(() {
//       _isSignedIn = _driveService.isSignedIn;
//     });
//   }

//   Future<void> _signInToGoogleDrive() async {
//     final success = await _driveService.signIn();
//     setState(() {
//       _isSignedIn = success;
//     });
    
//     if (success) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Successfully signed in to Google Drive')),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to sign in to Google Drive')),
//       );
//     }
//   }

//   Future<void> _signOut() async {
//     await _driveService.signOut();
//     setState(() {
//       _isSignedIn = false;
//       _selectedImage = null;
//     });
    
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Signed out from Google Drive')),
//     );
//   }

//   Future<void> _takePicture() async {
//     final XFile? image = await _picker.pickImage(
//       source: ImageSource.camera,
//       maxWidth: 1920,
//       maxHeight: 1080,
//       imageQuality: 85,
//     );
    
//     if (image != null) {
//       setState(() {
//         _selectedImage = File(image.path);
//       });
//     }
//   }

//   Future<void> _pickFromGallery() async {
//     final XFile? image = await _picker.pickImage(
//       source: ImageSource.gallery,
//       maxWidth: 1920,
//       maxHeight: 1080,
//       imageQuality: 85,
//     );
    
//     if (image != null) {
//       setState(() {
//         _selectedImage = File(image.path);
//       });
//     }
//   }

//   Future<void> _uploadToGoogleDrive() async {
//     if (_selectedImage == null || !_isSignedIn) return;

//     setState(() {
//       _isUploading = true;
//     });

//     try {
//       // Generate filename with timestamp
//       final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
//       final fileId = await _driveService.uploadImage(
//         imageFile: _selectedImage!,
//         fileName: fileName,
//         // folderId: 'your-folder-id-here', // Uncomment to upload to specific folder
//       );

//       if (fileId != null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Image uploaded successfully! File ID: $fileId')),
//         );
//         setState(() {
//           _selectedImage = null; // Clear the image after successful upload
//         });
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Failed to upload image')),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Upload error: $e')),
//       );
//     } finally {
//       setState(() {
//         _isUploading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Camera to Google Drive'),
//         backgroundColor: const Color(0xFFD4AF37),
//         foregroundColor: Colors.white,
//         actions: [
//           if (_isSignedIn)
//             IconButton(
//               onPressed: _signOut,
//               icon: const Icon(Icons.logout),
//               tooltip: 'Sign Out',
//             ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             // Google Drive Sign In Section
//             if (!_isSignedIn) ...[
//               const Text(
//                 'Sign in to Google Drive to upload photos',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 16),
//               ElevatedButton.icon(
//                 onPressed: _signInToGoogleDrive,
//                 icon: const Icon(Icons.login),
//                 label: const Text('Sign In to Google Drive'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFFD4AF37),
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                 ),
//               ),
//             ] else ...[
//               // Camera Controls Section
//               Row(
//                 children: [
//                   Expanded(
//                     child: ElevatedButton.icon(
//                       onPressed: _takePicture,
//                       icon: const Icon(Icons.camera_alt),
//                       label: const Text('Take Picture'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFFD4AF37),
//                         foregroundColor: Colors.white,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: ElevatedButton.icon(
//                       onPressed: _pickFromGallery,
//                       icon: const Icon(Icons.photo_library),
//                       label: const Text('From Gallery'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFFD4AF37),
//                         foregroundColor: Colors.white,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
              
//               const SizedBox(height: 16),
              
//               // Image Preview Section
//               if (_selectedImage != null) ...[
//                 Container(
//                   height: 300,
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey.shade300),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(8),
//                     child: Image.file(
//                       _selectedImage!,
//                       fit: BoxFit.cover,
//                       width: double.infinity,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
                
//                 // Upload Button
//                 ElevatedButton.icon(
//                   onPressed: _isUploading ? null : _uploadToGoogleDrive,
//                   icon: _isUploading 
//                     ? const SizedBox(
//                         width: 20,
//                         height: 20,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                     : const Icon(Icons.cloud_upload),
//                   label: Text(_isUploading ? 'Uploading...' : 'Upload to Google Drive'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFFD4AF37),
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                   ),
//                 ),
//               ] else ...[
//                 Container(
//                   height: 300,
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: const Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(Icons.image, size: 64, color: Colors.grey),
//                         SizedBox(height: 8),
//                         Text('No image selected', style: TextStyle(color: Colors.grey)),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }