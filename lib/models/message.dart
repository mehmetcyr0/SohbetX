class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final bool isImage;
  final bool isFile;
  final String? fileName;
  final int? fileSize; // Add fileSize property
  final String? fileType; // Add fileType property
  final bool isRead;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isImage,
    this.isFile = false,
    this.fileName,
    this.fileSize, // Include in constructor
    this.fileType, // Include in constructor
    this.isRead = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      content: json['content'],
      isImage: json['is_image'] ?? false,
      isFile: json['is_file'] ?? false,
      fileName: json['file_name'],
      fileSize: json['file_size'] != null ? int.tryParse(json['file_size'].toString()) : null,
      fileType: json['file_type'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'is_image': isImage,
      'is_file': isFile,
      'file_name': fileName,
      'file_size': fileSize,
      'file_type': fileType,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

