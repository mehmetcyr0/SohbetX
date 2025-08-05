class FriendRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String status;
  final DateTime createdAt;
  final String senderName;
  final String? senderAvatar;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    required this.senderName,
    this.senderAvatar,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      senderName: json['profiles']['full_name'],
      senderAvatar: json['profiles']['avatar_url'],
    );
  }
}

