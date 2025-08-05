import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sohbetx/utils/constants.dart';
import 'package:sohbetx/utils/snackbar.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  late final String _currentUserId;
  
  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser!.id;
  }
  
  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    
    try {
      // Search for users by email or name
      final data = await supabase
          .from(Constants.usersTable)
          .select()
          .or('email.ilike.%${query}%,full_name.ilike.%${query}%')
          .neq('id', _currentUserId);
      
      // Filter out users who are already friends or have pending requests
      List<Map<String, dynamic>> filteredResults = [];
      
      for (final user in data) {
        // Check if already friends or has pending request
        final existingRelation = await supabase
            .from(Constants.friendRequestsTable)
            .select()
            .or('and(sender_id.eq.${_currentUserId},receiver_id.eq.${user['id']}),and(sender_id.eq.${user['id']},receiver_id.eq.${_currentUserId})')
            .not('status', 'eq', Constants.rejected);
        
        if (existingRelation.isEmpty) {
          filteredResults.add(user);
        }
      }
      
      setState(() {
        _searchResults = filteredResults;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      print('Error searching users: $error');
    }
  }
  
  Future<void> _sendFriendRequest(String userId) async {
    try {
      await supabase.from(Constants.friendRequestsTable).insert({
        'sender_id': _currentUserId,
        'receiver_id': userId,
        'status': Constants.pending,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      showSnackBar(context, 'Arkadaşlık isteği gönderildi');
      
      // Remove user from search results
      setState(() {
        _searchResults.removeWhere((user) => user['id'] == userId);
      });
    } catch (error) {
      showSnackBar(context, 'Bir hata oluştu', isError: true);
      print('Error sending friend request: $error');
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arkadaş Ekle'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'E-posta veya isim ile ara',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _searchUsers(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchUsers,
                  child: const Text('Ara'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? const Center(
                        child: Text('Kullanıcı aramak için yukarıdaki arama kutusunu kullanın'),
                      )
                    : _searchResults.isEmpty
                        ? const Center(
                            child: Text('Sonuç bulunamadı'),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: user['avatar_url'] != null
                                      ? NetworkImage(user['avatar_url'])
                                      : null,
                                  child: user['avatar_url'] == null
                                      ? Text(user['full_name'][0].toUpperCase())
                                      : null,
                                ),
                                title: Text(user['full_name']),
                                subtitle: Text('@${user['username'] ?? ''}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.person_add),
                                  onPressed: () => _sendFriendRequest(user['id']),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

