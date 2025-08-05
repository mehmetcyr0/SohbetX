import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sohbetx/utils/constants.dart';
import 'package:sohbetx/screens/chat/chat_detail_screen.dart';
import 'package:sohbetx/screens/profile/user_profile_view_screen.dart';
import 'package:sohbetx/utils/snackbar.dart';
import 'package:sohbetx/utils/theme.dart';
import 'package:sohbetx/screens/chatbot/gemini_chatbot_screen.dart';
import 'package:sohbetx/screens/friends/add_friend_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;
  late final String _currentUserId;
  late final RealtimeChannel _subscription;
  bool _isLoading = true;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2 tab için
    _currentUserId = _supabase.auth.currentUser!.id;
    _loadFriends();
    _loadPendingRequests();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subscription.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _subscription = _supabase
      .channel('public:friend_requests')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: Constants.friendRequestsTable,
        callback: (payload) {
          if (mounted) {
            _loadFriends();
            _loadPendingRequests();
          }
        },
      )
      .subscribe();
  }

  Future<void> _loadFriends() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final friendsData = await _supabase
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

      List<Map<String, dynamic>> friends = [];

      for (final friendId in friendIds) {
        final userData = await _supabase
            .from(Constants.usersTable)
            .select()
            .eq('id', friendId)
            .single();

        friends.add(userData);
      }

      // KankaX yapay zeka asistanını ekle
      friends.add({
        'id': 'kankax_bot',
        'full_name': 'KankaX',
        'username': 'kankax',
        'avatar_url': null, // Avatar URL'i null olarak bırakıyoruz
        'is_bot': true, // Bot olduğunu belirtmek için özel bir alan
      });

      if (!mounted) return;
      setState(() {
        _friends = friends;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      showSnackBar(context, 'Arkadaşlar yüklenirken hata oluştu', isError: true);
    }
  }

  Future<void> _loadPendingRequests() async {
    if (!mounted) return;

    try {
      final pendingRequestsData = await _supabase
          .from(Constants.friendRequestsTable)
          .select('id, sender_id, receiver_id, created_at')
          .eq('receiver_id', _currentUserId)
          .eq('status', Constants.pending);

      List<Map<String, dynamic>> pendingRequests = [];

      for (final request in pendingRequestsData) {
        final userData = await _supabase
            .from(Constants.usersTable)
            .select()
            .eq('id', request['sender_id'])
            .single();

        pendingRequests.add({...request, 'user': userData});
      }

      if (!mounted) return;
      setState(() {
        _pendingRequests = pendingRequests;
      });
    } catch (error) {
      if (!mounted) return;
      showSnackBar(context, 'Bekleyen istekler yüklenirken hata oluştu', isError: true);
    }
  }

  Future<void> _acceptFriendRequest(String id) async {
    try {
      await _supabase
          .from(Constants.friendRequestsTable)
          .update({'status': Constants.accepted})
          .eq('id', id);

      if (!mounted) return;
      showSnackBar(context, 'Arkadaşlık isteği kabul edildi!');
      _loadFriends();
      _loadPendingRequests();
    } catch (error) {
      if (!mounted) return;
      showSnackBar(context, 'Arkadaşlık isteği kabul edilirken bir hata oluştu', isError: true);
    }
  }

  Future<void> _declineFriendRequest(String id) async {
    try {
      await _supabase
          .from(Constants.friendRequestsTable)
          .update({'status': Constants.rejected})
          .eq('id', id);

      if (!mounted) return;
      showSnackBar(context, 'Arkadaşlık isteği reddedildi!');
      _loadPendingRequests();
    } catch (error) {
      if (!mounted) return;
      showSnackBar(context, 'Arkadaşlık isteği reddedilirken bir hata oluştu', isError: true);
    }
  }

  Future<void> _removeFriend(String friendId) async {
    // KankaX botunu silmeye çalışıyorsa engelle
    if (friendId == 'kankax_bot') {
      if (!mounted) return;
      showSnackBar(context, 'KankaX arkadaş listenizden çıkarılamaz', isError: true);
      return;
    }
    
    try {
      await _supabase
          .from(Constants.friendRequestsTable)
          .delete()
          .or('and(sender_id.eq.$_currentUserId,receiver_id.eq.$friendId),and(sender_id.eq.$friendId,receiver_id.eq.$_currentUserId)');

      if (!mounted) return;
      showSnackBar(context, 'Arkadaş başarıyla silindi');
      _loadFriends();
    } catch (error) {
      if (!mounted) return;
      showSnackBar(context, 'Arkadaş silinirken bir hata oluştu', isError: true);
    }
  }

  void _showRemoveFriendDialog(Map<String, dynamic> friend) {
    // KankaX botunu silmeye çalışıyorsa engelle
    if (friend['id'] == 'kankax_bot') {
      showSnackBar(context, 'KankaX arkadaş listenizden çıkarılamaz', isError: true);
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arkadaşı Sil'),
        content: Text('${friend['full_name']} adlı kişiyi arkadaş listenizden silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeFriend(friend['id']);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arkadaşlar'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Arkadaşlar'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('İstekler'),
                  if (_pendingRequests.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _pendingRequests.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddFriendScreen(),
            ),
          ).then((_) => _loadFriends());
        },
        child: const Icon(Icons.person_add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Friends tab
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _friends.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Henüz arkadaşınız yok',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Arkadaş eklemek için sağ alttaki butonu kullanın',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _friends.length,
                      itemBuilder: (context, index) {
                        final friend = _friends[index];
                        final bool isBot = friend['is_bot'] == true;
                        
                        return Dismissible(
                          key: Key(friend['id']),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          direction: isBot ? DismissDirection.none : DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            if (!isBot) {
                              _showRemoveFriendDialog(friend);
                            }
                            return false;
                          },
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isBot ? AppTheme.primaryColor : null,
                              backgroundImage: friend['avatar_url'] != null
                                  ? NetworkImage(friend['avatar_url'])
                                  : null,
                              child: friend['avatar_url'] == null
                                  ? Text(
                                      friend['full_name'][0].toUpperCase(),
                                      style: TextStyle(
                                        color: isBot ? Colors.white : null,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(friend['full_name']),
                            subtitle: Text('@${friend['username'] ?? ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isBot ? Icons.smart_toy : Icons.chat,
                                    color: AppTheme.primaryColor,
                                  ),
                                  onPressed: () {
                                    if (isBot) {
                                      // Bot ile sohbet için özel ekrana yönlendir
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const GeminiChatbotScreen(),
                                        ),
                                      );
                                    } else {
                                      // Normal kullanıcı ile sohbet
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatDetailScreen(
                                            userId: friend['id'],
                                            name: friend['full_name'],
                                            avatarUrl: friend['avatar_url'],
                                            username: friend['username'],
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                if (!isBot)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _showRemoveFriendDialog(friend),
                                  ),
                              ],
                            ),
                            onTap: () {
                              if (isBot) {
                                // Bot ile sohbet için özel ekrana yönlendir
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const GeminiChatbotScreen(),
                                  ),
                                );
                              } else {
                                // Normal kullanıcı profili
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserProfileViewScreen(
                                      userId: friend['id'],
                                      name: friend['full_name'],
                                      avatarUrl: friend['avatar_url'],
                                      username: friend['username'],
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
          // Requests tab
          _pendingRequests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mail_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Bekleyen arkadaşlık isteği yok',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _pendingRequests.length,
                  itemBuilder: (context, index) {
                    final request = _pendingRequests[index];
                    final user = request['user'];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserProfileViewScreen(
                                        userId: user['id'],
                                        name: user['full_name'],
                                        avatarUrl: user['avatar_url'],
                                        username: user['username'],
                                      ),
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundImage: user['avatar_url'] != null
                                        ? NetworkImage(user['avatar_url'])
                                        : null,
                                    child: user['avatar_url'] == null
                                        ? Text(
                                            user['full_name'][0].toUpperCase(),
                                            style: const TextStyle(fontSize: 24),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['full_name'],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '@${user['username'] ?? ''}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'İstek Tarihi: ${DateTime.parse(request['created_at']).toLocal().toString().split('.')[0]}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.close),
                                  label: const Text('Reddet'),
                                  onPressed: () => _declineFriendRequest(request['id']),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.check),
                                  label: const Text('Kabul Et'),
                                  onPressed: () => _acceptFriendRequest(request['id']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

