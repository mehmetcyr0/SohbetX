import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sohbetx/utils/snackbar.dart';
import 'dart:developer' as developer;

class PermissionHandler {
 /// Kamera izni iste
 static Future<bool> requestCameraPermission(BuildContext context) async {
   developer.log('Requesting camera permission', name: 'PermissionHandler');
   final status = await Permission.camera.request();
   
   developer.log('Camera permission status: $status', name: 'PermissionHandler');
   
   if (status.isGranted) {
     return true;
   } else if (status.isPermanentlyDenied) {
     _showPermanentlyDeniedDialog(context, 'kamera');
     return false;
   } else {
     showSnackBar(
       context, 
       'Kamera erişimi reddedildi. Bazı özellikler çalışmayabilir.',
       isError: true,
     );
     return false;
   }
 }
 
 /// Galeri izni iste
 static Future<bool> requestGalleryPermission(BuildContext context) async {
   developer.log('Requesting gallery permission', name: 'PermissionHandler');
   
   // On Android 13+, we need to request different permissions
   if (await Permission.photos.request().isGranted) {
     return true;
   }
   
   // Legacy request for older devices
   final status = await Permission.storage.request();
   
   developer.log('Gallery permission status: $status', name: 'PermissionHandler');
   
   if (status.isGranted) {
     return true;
   } else if (status.isPermanentlyDenied) {
     _showPermanentlyDeniedDialog(context, 'galeri');
     return false;
   } else {
     showSnackBar(
       context, 
       'Galeri erişimi reddedildi. Bazı özellikler çalışmayabilir.',
       isError: true,
     );
     return false;
   }
 }
 
 /// Depolama izni iste
 static Future<bool> requestStoragePermission(BuildContext context) async {
   developer.log('Requesting storage permission', name: 'PermissionHandler');
   
   // Request multiple storage permissions to handle different Android versions
   Map<Permission, PermissionStatus> statuses = await [
     Permission.storage,
     Permission.photos,  // For Android 13+
     Permission.mediaLibrary, // For iOS
   ].request();
   
   developer.log('Storage permissions statuses: $statuses', name: 'PermissionHandler');
   
   // If any of the permissions is granted, consider it a success
   if (statuses.values.any((status) => status.isGranted)) {
     return true;
   } else if (statuses.values.any((status) => status.isPermanentlyDenied)) {
     _showPermanentlyDeniedDialog(context, 'depolama');
     return false;
   } else {
     showSnackBar(
       context, 
       'Depolama erişimi reddedildi. Dosya işlemleri yapılamayacak.',
       isError: true,
     );
     return false;
   }
 }
 
 /// Kalıcı olarak reddedilen izinler için ayarlar sayfasına yönlendirme
 static void _showPermanentlyDeniedDialog(BuildContext context, String permissionType) {
   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       title: Text('$permissionType İzni Gerekli'),
       content: Text('$permissionType erişimi kalıcı olarak reddedildi. Lütfen uygulama ayarlarından izin verin.'),
       actions: [
         TextButton(
           onPressed: () => Navigator.of(context).pop(),
           child: const Text('İptal'),
         ),
         TextButton(
           onPressed: () {
             Navigator.of(context).pop();
             openAppSettings();
           },
           child: const Text('Ayarları Aç'),
         ),
       ],
     ),
   );
 }
}

