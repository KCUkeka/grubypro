import 'package:flutter/material.dart';

class ReceiptsScreen extends StatelessWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Receipts Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'package:googleapis/drive/v3.dart' as drive;
// // Alias the package to avoid any name conflicts:
// import 'package:google_sign_in/google_sign_in.dart' as gsi;

// class ReceiptsScreen extends StatefulWidget {
//   const ReceiptsScreen({super.key});

//   @override
//   State<ReceiptsScreen> createState() => _ReceiptsScreenState();
// }

// class _ReceiptsScreenState extends State<ReceiptsScreen> {
//   // Use the named constructor to dodge the “unnamed constructor” error:
//   final gsi.GoogleSignIn _googleSignIn = gsi.GoogleSignIn.withScopes([
//     'ecbuisness@gmail.com',
//     'https://www.googleapis.com/auth/drive.file',
//   ]);

//   gsi.GoogleSignInAccount? _account;
//   bool _busy = false;

//   Future<gsi.GoogleSignInAccount?> _signIn() async {
//     // If already signed in, reuse:
//     _account ??= await _googleSignIn.signInSilently();
//     _account ??= await _googleSignIn.signIn();
//     return _account;
//   }

//   Future<File?> _pickImage() async {
//     final picker = ImagePicker();
//     final picked = await picker.pickImage(source: ImageSource.camera);
//     return picked != null ? File(picked.path) : null;
//   }

//   Future<void> _uploadToDrive(gsi.GoogleSignInAccount account, File file) async {
//     // Get an access token and create a client that injects the Authorization header
//     final auth = await account.authentication;
//     final client = _GoogleAuthClient(auth.accessToken!);

//     final api = drive.DriveApi(client);
//     final media = drive.Media(file.openRead(), await file.length());
//     final f = drive.File()
//       ..name = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
//     await api.files.create(f, uploadMedia: media);
//     client.close();
//   }

//   Future<void> _handleUpload() async {
//     if (_busy) return;
//     setState(() => _busy = true);
//     try {
//       final acct = await _signIn();
//       final image = await _pickImage();
//       if (acct != null && image != null) {
//         await _uploadToDrive(acct, image);
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Uploaded to Google Drive!')),
//           );
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Upload failed: $e')),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Receipts'),
//         backgroundColor: const Color(0xFFD4AF37),
//         foregroundColor: Colors.white,
//       ),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: _handleUpload,
//           child: Text(_busy ? 'Uploading…' : 'Take Picture & Save to Drive'),
//         ),
//       ),
//     );
//   }
// }

// // Minimal HTTP client that adds the Bearer token
// class _GoogleAuthClient extends http.BaseClient {
//   final String _token;
//   final http.Client _inner = http.Client();
//   _GoogleAuthClient(this._token);

//   @override
//   Future<http.StreamedResponse> send(http.BaseRequest request) {
//     request.headers['Authorization'] = 'Bearer $_token';
//     return _inner.send(request);
//   }

//   @override
//   void close() => _inner.close();
// }
