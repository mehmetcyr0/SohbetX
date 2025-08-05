import 'package:flutter/material.dart';
import 'package:sohbetx/screens/friends/add_friend_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sohbetx/models/chat_preview.dart';
import 'package:sohbetx/screens/chat/chat_detail_screen.dart';
import 'package:sohbetx/utils/constants.dart';
import 'package:sohbetx/utils/date_formatter.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final supabase = Supabase.instance.client;
  List<ChatPreview> _chats = [];
  bool _isLoading = true;
  late final String _currentUserId;
  late final RealtimeChannel _subscription;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser!.id;
    _loadChats();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _subscription = supabase
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: Constants.messagesTable,
          callback: (payload) {
            if (mounted) {
              final newMessage = payload.newRecord;
              final senderId = newMessage['sender_id'];
              final receiverId = newMessage['receiver_id'];

              // Check if the message is relevant to the current user
              if (senderId == _currentUserId || receiverId == _currentUserId) {
                _loadChats(); // Refresh chats to include the new message
              }
            }
          },
        )
        .subscribe();

    print('Real-time subscription set up for messages');
  }

  Future<void> _loadChats() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Get all friends
      final friendsData = await supabase
          .from(Constants.friendRequestsTable)
          .select('sender_id, receiver_id')
          .or('sender_id.eq.$_currentUserId,receiver_id.eq.$_currentUserId')
          .eq('status', Constants.accepted);

      List<String> friendIds = [];
      for (final friend in friendsData) {
        if (friend['sender_id'] == _currentUserId) {
          friendIds.add(friend['receiver_id']);
        } else {
          friendIds.add(friend['sender_id']);
        }
      }

      if (friendIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _chats = [];
          _isLoading = false;
        });
        return;
      }

      // Get latest message with each friend
      List<ChatPreview> chatPreviews = [];

      for (final friendId in friendIds) {
        // Get latest message
        final messagesData = await supabase
            .from(Constants.messagesTable)
            .select()
            .or('sender_id.eq.$_currentUserId,receiver_id.eq.$_currentUserId')
            .or('sender_id.eq.$friendId,receiver_id.eq.$friendId')
            .order('created_at', ascending: false)
            .limit(1);

        if (messagesData.isNotEmpty) {
          // Get friend profile
          final userData = await supabase
              .from(Constants.usersTable)
              .select()
              .eq('id', friendId)
              .single();

          chatPreviews.add(
            ChatPreview(
              userId: friendId,
              name: userData['full_name'],
              avatarUrl: userData['avatar_url'],
              lastMessage: messagesData[0]['content'],
              isImage: messagesData[0]['is_image'] ?? false,
              timestamp: DateTime.parse(messagesData[0]['created_at']),
              unreadCount: 0,
            ),
          );
        }
      }

      // Sort by latest message
      chatPreviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (!mounted) return;
      setState(() {
        _chats = chatPreviews;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sohbetler yüklenirken hata oluştu')),
      );
    }
  }

  @override
  void dispose() {
    _subscription.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sohbetler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChats,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: null,
        child: const Icon(
          Icons.add,
          size: 35,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Henüz sohbet yok',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Arkadaşlarınızla sohbet etmeye başlayın',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddFriendScreen(),
                              ));
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Arkadaş Ekle'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: chat.avatarUrl != null
                            ? NetworkImage(chat.avatarUrl!)
                            : null,
                        child: chat.avatarUrl == null
                            ? Text(chat.name[0].toUpperCase())
                            : null,
                      ),
                      title: Text(
                        chat.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        chat.isImage ? '📷 Fotoğraf' : chat.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatChatTime(chat.timestamp),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          if (chat.unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF424242),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                chat.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ChatDetailScreen(
                              userId: chat.userId,
                              name: chat.name,
                              avatarUrl: chat.avatarUrl,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
