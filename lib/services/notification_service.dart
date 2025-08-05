import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sohbetx/utils/constants.dart';
import 'dart:io';
import 'package:logger/logger.dart';

// Use our own Message model to avoid import conflicts
class MessageNotification {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final bool isImage;
  final bool isFile;
  final String? fileName;

  MessageNotification({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isImage,
    required this.isFile,
    this.fileName,
  });

  factory MessageNotification.fromJson(Map<String, dynamic> json) {
    return MessageNotification(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      content: json['content'],
      isImage: json['is_image'] ?? false,
      isFile: json['is_file'] ?? false,
      fileName: json['file_name'],
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _subscription;
  String? _currentUserId;
  bool _isInitialized = false;
  final _logger = Logger();

  // Initialize notification service
  Future<void> init() async {
    if (_isInitialized) return;

    _currentUserId = _supabase.auth.currentUser?.id;
    if (_currentUserId == null) {
      _logger.e('Cannot initialize notification service: User not logged in');
      return;
    }

    // Initialize notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    // Request permission on iOS
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    // Set up real-time subscription for messages
    _setupRealtimeSubscription();

    _isInitialized = true;
    _logger.i('Notification service initialized successfully');

    // Send a test notification to verify it's working
    await _sendTestNotification();
  }

  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      // Create the message notifications channel
      const AndroidNotificationChannel messagesChannel =
          AndroidNotificationChannel(
        'messages_channel',
        'Mesajlar',
        description: 'Yeni mesaj bildirimleri',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(messagesChannel);

      _logger.i('Notification channels created');
    }
  }

  void _setupRealtimeSubscription() {
    _subscription = _supabase
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: Constants.messagesTable,
          callback: (payload) {
            final newMessage = MessageNotification.fromJson(payload.newRecord);

            // Only show notification if the message is for the current user
            // and not sent by the current user
            if (newMessage.receiverId == _currentUserId &&
                newMessage.senderId != _currentUserId) {
              _showMessageNotification(newMessage);
            }
          },
        )
        .subscribe();

    _logger.i('Real-time subscription set up for message notifications');
  }

  Future<void> _sendTestNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'messages_channel',
        'Mesajlar',
        channelDescription: 'Yeni mesaj bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.show(
        0,
        'SohbetX',
        'Bildirimler başarıyla etkinleştirildi',
        platformChannelSpecifics,
      );

      _logger.i('Test notification sent');
    } catch (e) {
      _logger.e('Error sending test notification: $e');
    }
  }

  Future<void> _showMessageNotification(MessageNotification message) async {
    try {
      // Get sender information
      final senderData = await _supabase
          .from(Constants.usersTable)
          .select('full_name, username, avatar_url')
          .eq('id', message.senderId)
          .single();

      final senderName = senderData['full_name'] as String;
      final username = senderData['username'] as String?;

      // Prepare notification content
      String title = senderName;
      if (username != null) {
        title += ' (@$username)';
      }

      String body;
      if (message.isImage) {
        body = '📷 Fotoğraf gönderdi';
      } else if (message.isFile) {
        body = '📎 Dosya gönderdi: ${message.fileName ?? 'Dosya'}';
      } else {
        body = message.content;
      }

      // Show notification
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'messages_channel',
        'Mesajlar',
        channelDescription: 'Yeni mesaj bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.show(
        message.id.hashCode,
        title,
        body,
        platformChannelSpecifics,
        payload: 'message:${message.senderId}',
      );

      _logger.i('Notification shown for message from $senderName');
    } catch (e) {
      _logger.e('Error showing notification: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      final payload = response.payload!;

      if (payload.startsWith('message:')) {
        // The navigation will be handled by the app's navigation system
        _logger.i('Notification tapped: $payload');
      }
    }
  }

  void dispose() {
    _subscription?.unsubscribe();
  }
}
