import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sohbetx/utils/theme.dart';
import 'package:sohbetx/widgets/message_bubble.dart';
import 'package:sohbetx/models/message.dart';
import 'package:logger/logger.dart';

class GeminiChatbotScreen extends StatefulWidget {
  const GeminiChatbotScreen({super.key});

  @override
  State<GeminiChatbotScreen> createState() => _GeminiChatbotScreenState();
}

class _GeminiChatbotScreenState extends State<GeminiChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _logger = Logger();

  List<Message> _messages = [];
  bool _isLoading = false;
  final String _apiKey = "Kendi API'ni gir";

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    final welcomeMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'kankax_bot',
      receiverId: 'user',
      content:
          'Merhaba! Ben KankaX, SohbetX\'teki Yapay Zekalı dostunum. Sana nasıl yardımcı olabilirim?',
      isImage: false,
      isFile: false,
      isRead: true,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(welcomeMessage);
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'user',
      receiverId: 'kankax_bot',
      content: message,
      isImage: false,
      isFile: false,
      isRead: true,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Özel yanıtlar
    if (message.toLowerCase() == 'sen kimsin') {
      _addBotMessage('Ben KankaX, SohbetX\'teki Yapay Zekalı dostunum.');
      return;
    }

    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('mehmet çayır kim') ||
        lowerMessage.contains('kim bu mehmet çayır')) {
      _addBotMessage(
        'Mehmet Çayır, full-stack geliştirici olarak mobil, web ve masaüstü uygulamaları geliştiren bir yazılımcıdır. '
        'Flutter, Dart, React, Firebase, Supabase gibi teknolojilerle projeler üretmektedir. '
        'Detaylı bilgi için GitHub profiline göz atabilirsin: (https://github.com/mehmetcyr0)',
      );
      return;
    }

    if (message.toLowerCase() == 'sohbetx nedir?') {
      _addBotMessage(
          'SohbetX, Mehmet Çayır tarafından geliştirilmiş yenilikçi ve güvenli sohbet uygulamasıdır.');
      return;
    }

    try {
      final response = await _sendToGemini(message);
      _addBotMessage(response);
    } catch (e) {
      _logger.e('Gemini API hatası: $e');
      _addBotMessage(
          'Üzgünüm, bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
    }
  }

  void _addBotMessage(String content) {
    final botMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'kankax_bot',
      receiverId: 'user',
      content: content,
      isImage: false,
      isFile: false,
      isRead: true,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(botMessage);
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<String> _sendToGemini(String message) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey',
      );

      final contents = _messages.map((msg) {
        return {
          'role': msg.senderId == 'user' ? 'user' : 'model',
          'parts': [
            {'text': msg.content}
          ]
        };
      }).toList();

      contents.add({
        'role': 'user',
        'parts': [
          {
            'text':
                'Sen KankaX adında bir yapay zeka arkadaşısın. Samimi, esprili ve yardımsever bir şekilde konuşmalısın. Türkçe konuşuyorsun ve Türk kültürüne hakimsin. fazla uzun cevaplar vermemeye dikkat et kısa ve samimi ol. Kullanıcı sorusu: "$message"',
          }
        ]
      });

      final payload = {
        'contents': contents,
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        }
      };

      _logger.i('Payload: ${jsonEncode(payload)}');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        return 'API yanıt hatası: ${response.statusCode}. Lütfen daha sonra tekrar deneyin.';
      }
    } catch (e) {
      _logger.e('Bağlantı hatası: $e');
      return 'Üzgünüm, bir bağlantı hatası oluştu. İnternet bağlantınızı kontrol edip tekrar deneyin.';
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                'K',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 12),
            Text('KankaX'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFF5F5F5),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isMe = message.senderId == 'user';

                    return MessageBubble(
                      message: message,
                      isMe: isMe,
                    );
                  },
                ),
              ),
            ),
            if (_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('KankaX düşünüyor...'),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF2C2C2C)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'KankaX\'e bir şey sor...',
                          border: InputBorder.none,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 5,
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isLoading,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _isLoading ? Colors.grey : AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _isLoading ? null : _sendMessage,
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
}
