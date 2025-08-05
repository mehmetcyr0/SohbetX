import 'package:flutter/material.dart';
import 'package:sohbetx/models/message.dart';
import 'package:sohbetx/screens/chat/image_view_screen.dart';
import 'package:sohbetx/utils/date_formatter.dart';
import 'package:sohbetx/utils/theme.dart';
import 'package:sohbetx/utils/file_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sohbetx/utils/snackbar.dart';
import 'package:path/path.dart' as path;

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.transparent,
              ),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.primaryColor
                    : isDarkMode
                        ? AppTheme.darkCardColor
                        : Colors.grey[200],
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: isMe ? const Radius.circular(4) : null,
                  bottomLeft: !isMe ? const Radius.circular(4) : null,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: isMe ? const Radius.circular(4) : null,
                  bottomLeft: !isMe ? const Radius.circular(4) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isImage)
                      _buildImageContent(context)
                    else if (message.isFile)
                      _buildFileContent(context)
                    else
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          message.content,
                          style: TextStyle(
                            color: isMe ? Colors.white : null,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    if (!message.isImage)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 6, left: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              formatMessageTime(message.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe ? Colors.white.withOpacity(0.7) : Colors.black54,
                              ),
                            ),
                            if (isMe)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  message.isRead ? Icons.done_all : Icons.done,
                                  size: 14,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ImageViewScreen(
              imageUrl: message.content,
            ),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Hero(
            tag: message.content,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                message.content,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: isMe ? Colors.white : AppTheme.primaryColor,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.error),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                formatMessageTime(message.createdAt),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileContent(BuildContext context) {
    final fileName = message.fileName ?? FileHandler.formatFileName(message.content);
    final fileExtension = path.extension(fileName).toLowerCase();
    final fileType = FileHandler.getFileType(fileName);
    final fileIcon = FileHandler.getFileIcon(fileType);
    final fileSize = message.fileSize != null 
        ? FileHandler.formatFileSize(message.fileSize!) 
        : '';
    
    Color iconColor;
    switch (fileType) {
      case 'document':
        iconColor = Colors.blue;
        break;
      case 'image':
        iconColor = Colors.green;
        break;
      case 'audio':
        iconColor = Colors.orange;
        break;
      case 'video':
        iconColor = Colors.red;
        break;
      default:
        iconColor = Colors.grey;
    }
    
    return InkWell(
      onTap: () async {
        try {
          final url = message.content;
          print('Opening file URL: $url'); // Debug log
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          } else {
            if (context.mounted) {
              showSnackBar(context, 'Dosya açılamadı', isError: true);
            }
          }
        } catch (e) {
          print('Error opening file: $e'); // Debug log
          if (context.mounted) {
            showSnackBar(context, 'Dosya açılırken hata oluştu: $e', isError: true);
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  fileIcon,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      color: isMe ? Colors.white : null,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        fileSize.isNotEmpty ? fileSize : 'Dosya',
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fileExtension.isNotEmpty ? fileExtension.toUpperCase().substring(1) : '',
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.download,
              size: 20,
              color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

