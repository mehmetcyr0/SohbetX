import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sohbetx/utils/constants.dart';
import 'package:sohbetx/utils/theme.dart';
import 'package:sohbetx/screens/chat/chat_detail_screen.dart';

class UserProfileViewScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? username;

  const UserProfileViewScreen({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.username,
  });

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _bio;
  String? _username;
  DateTime? _joinDate;
  String? _status;
  DateTime? _lastOnline;
  bool _isFriend = false;
  String? _friendshipStatus;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkFriendshipStatus();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userData = await _supabase
          .from(Constants.usersTable)
          .select('bio, username, created_at, status, last_online')
          .eq('id', widget.userId)
          .single();

      if (mounted) {
        setState(() {
          _bio = userData['bio'];
          _username = userData['username'] ?? widget.username;
          _joinDate = userData['created_at'] != null
              ? DateTime.parse(userData['created_at'])
              : null;
          _status = userData['status'] ?? 'offline';
          _lastOnline = userData['last_online'] != null
              ? DateTime.parse(userData['last_online'])
              : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Kullanıcı profili yüklenirken hata: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkFriendshipStatus() async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;
      
      final friendshipData = await _supabase
          .from(Constants.friendRequestsTable)
          .select('status')
          .or('and(sender_id.eq.${currentUserId},receiver_id.eq.${widget.userId}),and(sender_id.eq.${widget.userId},receiver_id.eq.${currentUserId})')
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (friendshipData != null) {
            _friendshipStatus = friendshipData['status'];
            _isFriend = _friendshipStatus == Constants.accepted;
          }
        });
      }
    } catch (e) {
      print('Arkadaşlık durumu kontrol edilirken hata: $e');
    }
  }

  String _getStatusText() {
    if (_status == 'online') {
      return 'Çevrimiçi';
    } else if (_lastOnline != null) {
      final now = DateTime.now();
      final difference = now.difference(_lastOnline!);
      
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} dakika önce çevrimiçiydi';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} saat önce çevrimiçiydi';
      } else {
        return '${difference.inDays} gün önce çevrimiçiydi';
      }
    }
    return 'Çevrimdışı';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profil'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Hero(
                    tag: 'avatar_${widget.userId}',
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: widget.avatarUrl != null
                            ? NetworkImage(widget.avatarUrl!)
                            : null,
                        child: widget.avatarUrl == null
                            ? Text(
                                widget.name.isNotEmpty
                                    ? widget.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _username != null ? '@$_username' : '',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _status == 'online' ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_bio != null && _bio!.isNotEmpty) ...[
                    const Text(
                      'Hakkında',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppTheme.darkCardColor : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _bio!,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const Text(
                    'Hesap Bilgileri',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Katılma Tarihi'),
                      subtitle: Text(_joinDate != null
                          ? '${_joinDate!.day}/${_joinDate!.month}/${_joinDate!.year}'
                          : ''),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatDetailScreen(
                              userId: widget.userId,
                              name: widget.name,
                              avatarUrl: widget.avatarUrl,
                              username: _username,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text('Mesaj Gönder'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isFriend)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Arkadaşlık durumunu göster
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bu kişi arkadaş listenizde')),
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Arkadaşsınız'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    )
                  else if (_friendshipStatus == Constants.pending)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Bekleyen istek durumunu göster
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Arkadaşlık isteği beklemede')),
                          );
                        },
                        icon: const Icon(Icons.hourglass_empty),
                        label: const Text('İstek Beklemede'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Arkadaşlık isteği gönder
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Arkadaşlık isteği gönderme özelliği yakında eklenecek')),
                          );
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Arkadaş Ekle'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
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

