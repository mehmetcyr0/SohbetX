import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sohbetx/screens/splash_screen.dart';
import 'package:sohbetx/utils/constants.dart';
import 'package:sohbetx/utils/theme.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sohbetx/services/notification_service.dart';

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: Constants.supabaseUrl,
      anonKey: Constants.supabaseAnonKey,
      debug: true, // Debug modunu açalım
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 40, // Saniyede daha fazla event işleme
        timeout: Duration(seconds: 30), // Timeout süresini artır
      ),
    );

    logger.i('Supabase initialized successfully');

    // Request permissions at app start
    await _requestInitialPermissions();

    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.init();
  } catch (e) {
    logger.e('Supabase initialization error: $e');
  }

  runApp(const MyApp());
}

// Request permissions when app starts
Future<void> _requestInitialPermissions() async {
  try {
    // Request camera, storage and notification permissions on app start
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      Permission.photos,
      Permission.notification,
    ].request();

    logger.i('Permission statuses: $statuses');

    // Ensure notification permission is granted
    if (statuses[Permission.notification] != PermissionStatus.granted) {
      logger.w('Notification permission not granted. Requesting again...');
      await Permission.notification.request();
    }
  } catch (e) {
    logger.e('Error requesting permissions: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SohbetX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      locale: const Locale('tr', 'TR'),
      home: const SplashScreen(),
    );
  }
}
