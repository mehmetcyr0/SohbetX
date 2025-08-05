class ChatPreview {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String lastMessage;
  final bool isImage;
  final DateTime timestamp;
  final int unreadCount;

  ChatPreview({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.lastMessage,
    required this.isImage,
    required this.timestamp,
    required this.unreadCount,
  });
}

