import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sohbetx/models/message.dart';
import 'package:sohbetx/utils/constants.dart';
import 'package:sohbetx/widgets/message_bubble.dart';
import 'package:sohbetx/utils/theme.dart';
import 'package:sohbetx/utils/file_handler.dart';
import 'package:sohbetx/utils/permission_handler.dart';
import 'package:sohbetx/screens/profile/user_profile_view_screen.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatDetailScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? username;

  const ChatDetailScreen({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.username,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final _logger = Logger();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _showAttachmentOptions = false;
  bool _isAtBottom = true; // Kullanıcı sohbetin en altında mı
  late final String _currentUserId;
  late final RealtimeChannel _subscription;
  late final AnimationController _animationController;
  late final Animation<double> _animation;
  String? _userUsername;

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser!.id;
    _loadMessagesFromLocalStorage(); // Load cached messages first
    _loadMessages(); // Then load from server
    _setupRealtimeSubscription();
    _loadUserDetails();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Add listener to scroll controller to detect when user scrolls
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      // Consider user at bottom if within 50 pixels of the bottom
      _isAtBottom = (maxScroll - currentScroll) < 50;
    }
  }

  Future<void> _loadUserDetails() async {
    if (widget.username != null) {
      _userUsername = widget.username;
      return;
    }

    try {
      final userData = await _supabase
          .from(Constants.usersTable)
          .select('username')
          .eq('id', widget.userId)
          .single();

      if (mounted) {
        setState(() {
          _userUsername = userData['username'];
        });
      }
    } catch (e) {
      _logger.e('Kullanıcı detayları yüklenirken hata: $e');
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
            final newMessage = Message.fromJson(payload.newRecord);

            // Check if this message belongs to this conversation
            if ((newMessage.senderId == _currentUserId &&
                    newMessage.receiverId == widget.userId) ||
                (newMessage.senderId == widget.userId &&
                    newMessage.receiverId == _currentUserId)) {
              // Check if message already exists to avoid duplicates
              final messageExists =
                  _messages.any((msg) => msg.id == newMessage.id);

              if (!messageExists) {
                if (mounted) {
                  setState(() {
                    _messages.add(newMessage);
                    // Sort messages to ensure correct order
                    _messages
                        .sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  });

                  // Save to local storage immediately
                  _saveMessagesToLocalStorage();

                  // Mark message as read if it's from the other user
                  if (newMessage.senderId == widget.userId) {
                    _markMessageAsRead(newMessage.id);
                  }

                  // Ensure we scroll to bottom when new message arrives if we're at the bottom
                  if (_isAtBottom) {
                    Future.delayed(const Duration(milliseconds: 50), () {
                      _scrollToBottom();
                    });
                  }
                }
              }
            }
          },
        )
        .subscribe();

    _logger.i('Real-time subscription set up for messages');
  }

  // Add a method to mark a single message as read
  Future<void> _markMessageAsRead(String messageId) async {
    try {
      await _supabase.rpc(
        'mark_message_as_read',
        params: {'message_id': messageId},
      );
    } catch (e) {
      _logger.e('Mesaj okundu olarak işaretlerken hata: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final data = await _supabase
          .from(Constants.messagesTable)
          .select()
          .or('and(sender_id.eq.$_currentUserId,receiver_id.eq.${widget.userId}),and(sender_id.eq.${widget.userId},receiver_id.eq.$_currentUserId)')
          .order('created_at');

      final newMessages =
          data.map((message) => Message.fromJson(message)).toList();

      // Merge with existing messages and remove duplicates
      final Map<String, Message> messageMap = {};

      // Add existing messages to map
      for (final message in _messages) {
        messageMap[message.id] = message;
      }

      // Add or update with new messages
      for (final message in newMessages) {
        messageMap[message.id] = message;
      }

      // Convert back to list and sort
      final mergedMessages = messageMap.values.toList();
      mergedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      setState(() {
        _messages = mergedMessages;
        _isLoading = false;
      });

      // Save updated messages to local storage
      _saveMessagesToLocalStorage();

      // Mesajlar yüklendikten sonra aşağı kaydır
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      // Mark messages as read
      _markMessagesAsRead();
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesajlar yüklenirken bir hata oluştu')),
        );
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      // Mark all messages from this sender as read
      await _supabase.rpc(
        'mark_all_messages_as_read',
        params: {
          'sender_id': widget.userId,
          'receiver_id': _currentUserId,
        },
      );
    } catch (e) {
      _logger.e('Mesajları okundu olarak işaretlerken hata: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      try {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } catch (e) {
        _logger.e('Error scrolling to bottom: $e');
        // Fallback method if the first one fails
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_scrollController.hasClients && mounted) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } else {
      // If controller is not attached yet, try again after a delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollToBottom();
        }
      });
    }
  }

  void _viewUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileViewScreen(
          userId: widget.userId,
          name: widget.name,
          avatarUrl: widget.avatarUrl,
          username: _userUsername,
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      File? imageFile;

      if (source == ImageSource.camera) {
        final hasPermission =
            await PermissionHandler.requestCameraPermission(context);
        if (!hasPermission) return;

        final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
        );

        if (photo == null) return;
        imageFile = File(photo.path);
      } else {
        final hasPermission =
            await PermissionHandler.requestGalleryPermission(context);
        if (!hasPermission) return;

        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );

        if (image == null) return;
        imageFile = File(image.path);
      }

      setState(() {
        _isSending = true;
        _showAttachmentOptions = false;
      });
      _animationController.reverse();

      // Fotoğrafı yükle
      final imageUrl = await FileHandler.uploadChatImage(
          context, _currentUserId, widget.userId, imageFile);

      if (imageUrl == null) {
        setState(() {
          _isSending = false;
        });
        return;
      }

      // Mesajı kaydet
      await _supabase.from(Constants.messagesTable).insert({
        'sender_id': _currentUserId,
        'receiver_id': widget.userId,
        'content': imageUrl,
        'is_image': true,
        'is_file': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Aşağı kaydıralım
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (error) {
      _logger.e('Görüntü gönderme hatası: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Görüntü gönderilirken hata oluştu: ${error.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final hasPermission =
          await PermissionHandler.requestStoragePermission(context);
      if (!hasPermission) return;

      final file = await FileHandler.pickFile(context);
      if (file == null) return;

      setState(() {
        _isSending = true;
        _showAttachmentOptions = false;
      });
      _animationController.reverse();

      // Dosyayı yükle
      final fileData = await FileHandler.uploadFile(
          context, _currentUserId, widget.userId, file);

      if (fileData == null) {
        setState(() {
          _isSending = false;
        });
        return;
      }

      // Mesajı kaydet with improved file details
      await _supabase.from(Constants.messagesTable).insert({
        'sender_id': _currentUserId,
        'receiver_id': widget.userId,
        'content': fileData['url'],
        'file_name': fileData['name'],
        'file_size': fileData['size'],
        'file_type': fileData['type'],
        'is_image': false,
        'is_file': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Aşağı kaydıralım
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      _logger.i('File message sent successfully: ${fileData['name']}');
    } catch (error) {
      _logger.e('Dosya gönderme hatası: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Dosya gönderilirken hata oluştu: ${error.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    if (!mounted) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Mesaj gönderildikten sonra input'u temizleyelim
      _messageController.clear();

      // Şimdi mesajı veritabanına gönderelim
      final response = await _supabase.from(Constants.messagesTable).insert({
        'sender_id': _currentUserId,
        'receiver_id': widget.userId,
        'content': message,
        'is_image': false,
        'is_file': false,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      // Veritabanından dönen mesajı kullanarak UI'ı güncelleyelim
      if (response.isNotEmpty) {
        final newMessage = Message.fromJson(response[0]);

        setState(() {
          // Önce mesajın zaten eklenip eklenmediğini kontrol edelim
          final messageExists = _messages.any((msg) => msg.id == newMessage.id);

          if (!messageExists) {
            _messages.add(newMessage);
            // Mesajları tarih sırasına göre sıralayalım
            _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          }
        });

        // Mesajları yerel depolamaya kaydedelim
        _saveMessagesToLocalStorage();
      }

      // Aşağı kaydıralım
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (error) {
      _logger.e('Mesaj gönderme hatası: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Mesaj gönderilirken hata oluştu: ${error.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _toggleAttachmentOptions() {
    setState(() {
      _showAttachmentOptions = !_showAttachmentOptions;
    });

    if (_showAttachmentOptions) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  Future<void> _saveMessagesToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Sort messages before saving to ensure correct order when loaded
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final messagesJson =
          _messages.map((msg) => jsonEncode(msg.toJson())).toList();
      await prefs.setStringList('chat_messages_${widget.userId}', messagesJson);
      _logger.i('Messages saved to local storage');
    } catch (e) {
      _logger.e('Error saving messages to local storage: $e');
    }
  }

// Add a method to load messages from local storage
// Add this new method:

  Future<void> _loadMessagesFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson =
          prefs.getStringList('chat_messages_${widget.userId}');

      if (messagesJson != null && messagesJson.isNotEmpty) {
        final loadedMessages = messagesJson
            .map((json) => Message.fromJson(jsonDecode(json)))
            .toList();

        // Sort messages by creation time to ensure correct order
        loadedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        setState(() {
          _messages = loadedMessages;
        });

        _logger.i('Messages loaded from local storage');
      }
    } catch (e) {
      _logger.e('Error loading messages from local storage: $e');
    }
  }

  @override
  void dispose() {
    _saveMessagesToLocalStorage(); // Save messages when leaving the screen
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _subscription.unsubscribe();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _viewUserProfile,
          child: Row(
            children: [
              Hero(
                tag: 'avatar_${widget.userId}',
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: widget.avatarUrl != null
                      ? NetworkImage(widget.avatarUrl!)
                      : null,
                  child: widget.avatarUrl == null
                      ? Text(
                          widget.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _userUsername != null ? '@$_userUsername' : 'Çevrimiçi',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: _viewUserProfile,
          ),
          IconButton(
            icon: const Icon(Icons.video_camera_back_rounded),
            onPressed: _viewUserProfile,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFFF5F5F5),
                      image: DecorationImage(
                        image: AssetImage(
                          isDarkMode
                              ? 'assets/images/chat_bg_dark.png'
                              : 'assets/images/chat_bg_light.png',
                        ),
                        opacity: 0.05,
                        repeat: ImageRepeat.repeat,
                      ),
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _messages.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Henüz mesaj yok',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Sohbete başlamak için mesaj gönderin',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final message = _messages[index];
                                  final isMe =
                                      message.senderId == _currentUserId;

                                  // Group messages by date
                                  final showDateSeparator = index == 0 ||
                                      !isSameDay(_messages[index].createdAt,
                                          _messages[index - 1].createdAt);

                                  return Column(
                                    children: [
                                      if (showDateSeparator)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          child: Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDarkMode
                                                    ? Colors.grey[800]
                                                    : Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Text(
                                                formatDateForSeparator(
                                                    message.createdAt),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDarkMode
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      MessageBubble(
                                        message: message,
                                        isMe: isMe,
                                      ),
                                    ],
                                  );
                                },
                              ),
                  ),
                  // Attachment options
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SizeTransition(
                      sizeFactor: _animation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppTheme.darkCardColor
                              : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            ),
                          ],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildAttachmentOption(
                                  icon: Icons.photo,
                                  label: 'Galeri',
                                  color: Colors.purple,
                                  onTap: () => _pickImage(ImageSource.gallery),
                                ),
                                _buildAttachmentOption(
                                  icon: Icons.camera_alt,
                                  label: 'Kamera',
                                  color: Colors.red,
                                  onTap: () => _pickImage(ImageSource.camera),
                                ),
                                _buildAttachmentOption(
                                  icon: Icons.insert_drive_file,
                                  label: 'Dosya',
                                  color: Colors.blue,
                                  onTap: () {
                                    _pickFile();
                                    _toggleAttachmentOptions();
                                  },
                                ),
                                _buildAttachmentOption(
                                  icon: Icons.location_on,
                                  label: 'Konum',
                                  color: Colors.green,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Konum paylaşımı yakında gelecek')),
                                    );
                                    _toggleAttachmentOptions();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: isDarkMode
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFF5F5F5),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _toggleAttachmentOptions,
                    color: AppTheme.primaryColor,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                        borderRadius:
                            BorderRadius.circular(24), // Tam oval görünüm
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Mesaj yazın...',
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          hintStyle: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 5,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                            ),
                      onPressed: _isSending ? null : _sendMessage,
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

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function to check if two dates are the same day
bool isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

// Format date for separator
String formatDateForSeparator(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dateToCheck = DateTime(date.year, date.month, date.day);

  if (dateToCheck == today) {
    return 'Bugün';
  } else if (dateToCheck == yesterday) {
    return 'Dün';
  } else {
    return '${date.day}/${date.month}/${date.year}';
  }
}
