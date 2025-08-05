import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sohbetx/utils/constants.dart';
import 'package:sohbetx/utils/permission_handler.dart';
import 'package:sohbetx/utils/snackbar.dart';
import 'package:mime/mime.dart';
import 'dart:developer' as developer;

class FileHandler {
  static final supabase = Supabase.instance.client;

  /// Kameradan fotoğraf çek
  static Future<File?> takePhoto(BuildContext context) async {
    final hasPermission =
        await PermissionHandler.requestCameraPermission(context);
    if (!hasPermission) return null;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo == null) return null;
      return File(photo.path);
    } catch (e) {
      developer.log('Kamera hatası: $e', name: 'FileHandler');
      showSnackBar(context, 'Fotoğraf çekilirken bir hata oluştu',
          isError: true);
      return null;
    }
  }

  /// Galeriden fotoğraf seç
  static Future<File?> pickImage(BuildContext context) async {
    final hasPermission =
        await PermissionHandler.requestGalleryPermission(context);
    if (!hasPermission) return null;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      developer.log('Galeri hatası: $e', name: 'FileHandler');
      showSnackBar(context, 'Fotoğraf seçilirken bir hata oluştu',
          isError: true);
      return null;
    }
  }

  /// Dosya seç
  static Future<File?> pickFile(BuildContext context) async {
    final hasPermission =
        await PermissionHandler.requestStoragePermission(context);
    if (!hasPermission) return null;

    try {
      developer.log('Dosya seçme işlemi başlatılıyor...', name: 'FileHandler');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowCompression: true,
        type: FileType.any, // Tüm dosya türlerini izin ver
      );

      if (result == null || result.files.single.path == null) {
        developer.log('Dosya seçilmedi veya yol bulunamadı',
            name: 'FileHandler');
        return null;
      }
      developer.log('Dosya seçildi: ${result.files.single.path}',
          name: 'FileHandler');
      return File(result.files.single.path!);
    } catch (e) {
      developer.log('Dosya seçme hatası: $e', name: 'FileHandler');
      showSnackBar(context, 'Dosya seçilirken bir hata oluştu: $e',
          isError: true);
      return null;
    }
  }

  /// Profil fotoğrafı yükle
  static Future<String?> uploadProfileImage(
      BuildContext context, String userId, File imageFile) async {
    try {
      final String fileName =
          '${userId}/${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final String? mimeType = lookupMimeType(imageFile.path);
      developer.log(
          'Profil fotoğrafı yüklenecek: $fileName (MimeType: $mimeType)',
          name: 'FileHandler');

      // HEIC/HEIF formatını JPEG'e dönüştür
      File fileToUpload = imageFile;

      await supabase.storage.from(Constants.profileImagesBucket).upload(
            fileName,
            fileToUpload,
            fileOptions: FileOptions(
              contentType: mimeType ?? 'application/octet-stream',
              upsert: true,
            ),
          );

      final String imageUrl = supabase.storage
          .from(Constants.profileImagesBucket)
          .getPublicUrl(fileName);

      developer.log('Profil fotoğrafı yüklendi: $imageUrl',
          name: 'FileHandler');
      return imageUrl;
    } catch (error) {
      developer.log('Profil fotoğrafı yükleme hatası: $error',
          name: 'FileHandler');
      if (error is StorageException) {
        developer.log('Storage hata kodu: ${error.statusCode}',
            name: 'FileHandler');
        developer.log('Storage hata mesajı: ${error.message}',
            name: 'FileHandler');

        if (error.statusCode == 404) {
          showSnackBar(
            context,
            'Storage bucket bulunamadı. Lütfen Supabase panelinden "${Constants.profileImagesBucket}" adında bir bucket oluşturun.',
            isError: true,
          );
        } else {
          showSnackBar(
              context, 'Fotoğraf yüklenirken bir hata oluştu: ${error.message}',
              isError: true);
        }
      } else {
        showSnackBar(context, 'Fotoğraf yüklenirken bir hata oluştu: $error',
            isError: true);
      }
      return null;
    }
  }

  /// Sohbet fotoğrafı yükle
  static Future<String?> uploadChatImage(BuildContext context, String senderId,
      String receiverId, File imageFile) async {
    try {
      final String fileName =
          '$senderId/$receiverId/${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final String? mimeType = lookupMimeType(imageFile.path);
      developer.log(
          'Sohbet fotoğrafı yüklenecek: $fileName (MimeType: $mimeType)',
          name: 'FileHandler');

      // HEIC/HEIF formatını JPEG'e dönüştür
      File fileToUpload = imageFile;

      await supabase.storage.from(Constants.chatImagesBucket).upload(
            fileName,
            fileToUpload,
            fileOptions: FileOptions(
              contentType: mimeType ?? 'application/octet-stream',
              upsert: true,
            ),
          );

      final String imageUrl = supabase.storage
          .from(Constants.chatImagesBucket)
          .getPublicUrl(fileName);

      developer.log('Sohbet fotoğrafı yüklendi: $imageUrl',
          name: 'FileHandler');
      return imageUrl;
    } catch (error) {
      developer.log('Sohbet fotoğrafı yükleme hatası: $error',
          name: 'FileHandler');
      if (error is StorageException) {
        developer.log('Storage hata kodu: ${error.statusCode}',
            name: 'FileHandler');
        developer.log('Storage hata mesajı: ${error.message}',
            name: 'FileHandler');

        if (error.statusCode == 404) {
          showSnackBar(
            context,
            'Storage bucket bulunamadı. Lütfen Supabase panelinden "${Constants.chatImagesBucket}" adında bir bucket oluşturun.',
            isError: true,
          );
        } else {
          showSnackBar(
              context, 'Fotoğraf yüklenirken bir hata oluştu: ${error.message}',
              isError: true);
        }
      } else {
        showSnackBar(context, 'Fotoğraf yüklenirken bir hata oluştu',
            isError: true);
      }
      return null;
    }
  }

  /// Dosya yükle
  static Future<Map<String, dynamic>?> uploadFile(BuildContext context,
      String senderId, String receiverId, File file) async {
    try {
      final String originalFileName = path.basename(file.path);
      final String fileName =
          '$senderId/$receiverId/${DateTime.now().millisecondsSinceEpoch}_$originalFileName';
      final String? mimeType = lookupMimeType(file.path);
      final int fileSize = await file.length();

      developer.log(
          'Dosya yüklenecek: $fileName (Boyut: ${formatFileSize(fileSize)}, MimeType: $mimeType)',
          name: 'FileHandler');

      // Dosya boyutu kontrolü (20MB limit)
      if (fileSize > 20 * 1024 * 1024) {
        showSnackBar(context, 'Dosya boyutu 20MB\'dan büyük olamaz',
            isError: true);
        return null;
      }

      await supabase.storage.from(Constants.filesBucket).upload(
            fileName,
            file,
            fileOptions: FileOptions(
              contentType: mimeType ?? 'application/octet-stream',
              upsert: true,
            ),
          );

      final String fileUrl =
          supabase.storage.from(Constants.filesBucket).getPublicUrl(fileName);

      developer.log('Dosya yüklendi: $fileUrl', name: 'FileHandler');

      return {
        'url': fileUrl,
        'name': originalFileName,
        'size': fileSize,
        'type': mimeType ?? 'application/octet-stream'
      };
    } catch (error) {
      developer.log('Dosya yükleme hatası: $error', name: 'FileHandler');
      if (error is StorageException) {
        developer.log('Storage hata kodu: ${error.statusCode}',
            name: 'FileHandler');
        developer.log('Storage hata mesajı: ${error.message}',
            name: 'FileHandler');

        if (error.statusCode == 404) {
          showSnackBar(
            context,
            'Storage bucket bulunamadı. Lütfen Supabase panelinden "${Constants.filesBucket}" adında bir bucket oluşturun.',
            isError: true,
          );
        } else if (error.statusCode == 413) {
          showSnackBar(context,
              'Dosya boyutu çok büyük. Maksimum 20MB dosya yükleyebilirsiniz.',
              isError: true);
        } else {
          showSnackBar(
              context, 'Dosya yüklenirken bir hata oluştu: ${error.message}',
              isError: true);
        }
      } else {
        showSnackBar(context, 'Dosya yüklenirken bir hata oluştu',
            isError: true);
      }
      return null;
    }
  }

  /// Dosya adını formatla
  static String formatFileName(String url) {
    try {
      final fileName = path.basename(url);
      if (fileName.length > 20) {
        return '${fileName.substring(0, 10)}...${fileName.substring(fileName.length - 10)}';
      }
      return fileName;
    } catch (e) {
      return 'Dosya';
    }
  }

  /// Dosya türünü belirle
  static String getFileType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    final imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.heic',
      '.heif'
    ];
    final documentExtensions = [
      '.pdf',
      '.doc',
      '.docx',
      '.xls',
      '.xlsx',
      '.ppt',
      '.pptx',
      '.txt'
    ];
    final audioExtensions = ['.mp3', '.wav', '.aac', '.ogg', '.flac'];
    final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];

    if (imageExtensions.contains(extension)) {
      return 'image';
    } else if (documentExtensions.contains(extension)) {
      return 'document';
    } else if (audioExtensions.contains(extension)) {
      return 'audio';
    } else if (videoExtensions.contains(extension)) {
      return 'video';
    } else {
      return 'file';
    }
  }

  /// Dosya boyutunu formatla
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Dosya simgesini belirle
  static IconData getFileIcon(String fileType) {
    switch (fileType) {
      case 'image':
        return Icons.image;
      case 'document':
        return Icons.description;
      case 'audio':
        return Icons.audio_file;
      case 'video':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }
}
