import 'dart:io';
import 'dart:typed_data';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  static const _scopes = [drive.DriveApi.driveFileScope];
  
  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;
  
  GoogleDriveService() {
    // _googleSignIn = GoogleSignIn(scopes: _scopes);
  }

  // Initialize and sign in to Google
  // Future<bool> signIn() async {
  //   try {
  //     final GoogleSignInAccount? account = await _googleSignIn?.signIn();
  //     if (account != null) {
  //       final GoogleSignInAuthentication auth = await account.authentication;
  //       final AuthClient authClient = authenticatedClient(
  //         http.Client(),
  //         AccessCredentials(
  //           AccessToken(
  //             'Bearer',
  //             auth.accessToken!,
  //             DateTime.now().add(const Duration(hours: 1)).toUtc(),
  //           ),
  //           auth.idToken,
  //           _scopes,
  //         ),
  //       );
  //       _driveApi = drive.DriveApi(authClient);
  //       return true;
  //     }
  //   } catch (e) {
  //     print('Sign in error: $e');
  //   }
  //   return false;
  // }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    _driveApi = null;
  }

  // Check if user is signed in
  bool get isSignedIn => _driveApi != null;

  // Upload image to Google Drive
  Future<String?> uploadImage({
    required File imageFile,
    required String fileName,
    String? folderId, // Optional: specify folder ID to upload to specific folder
  }) async {
    if (_driveApi == null) {
      throw Exception('Not signed in to Google Drive');
    }

    try {
      // Read file bytes
      final bytes = await imageFile.readAsBytes();
      
      // Create file metadata
      final driveFile = drive.File()
        ..name = fileName
        ..parents = folderId != null ? [folderId] : null;

      // Create media
      final media = drive.Media(
        Stream.fromIterable([bytes]),
        bytes.length,
        contentType: 'image/jpeg', // Adjust based on your image type
      );

      // Upload file
      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      print('File uploaded successfully. File ID: ${result.id}');
      return result.id;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  // Create a folder in Google Drive (optional)
  Future<String?> createFolder(String folderName, {String? parentFolderId}) async {
    if (_driveApi == null) {
      throw Exception('Not signed in to Google Drive');
    }

    try {
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = parentFolderId != null ? [parentFolderId] : null;

      final result = await _driveApi!.files.create(folder);
      print('Folder created successfully. Folder ID: ${result.id}');
      return result.id;
    } catch (e) {
      print('Create folder error: $e');
      return null;
    }
  }

  // List files in Google Drive (optional)
  Future<List<drive.File>?> listFiles({String? folderId}) async {
    if (_driveApi == null) {
      throw Exception('Not signed in to Google Drive');
    }

    try {
      String query = "trashed=false";
      if (folderId != null) {
        query += " and '$folderId' in parents";
      }

      final result = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
      );

      return result.files;
    } catch (e) {
      print('List files error: $e');
      return null;
    }
  }
}
