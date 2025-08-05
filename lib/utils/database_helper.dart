import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sohbetx/utils/constants.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class DatabaseHelper {
  final SupabaseClient supabase;

  DatabaseHelper(this.supabase);

  /// Kullanıcı profilinin var olup olmadığını kontrol eder
  Future<bool> checkProfileExists(String userId) async {
    try {
      final data = await supabase
          .from(Constants.usersTable)
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      return data != null;
    } catch (e) {
      logger.e('Profile check error: $e');
      return false;
    }
  }

  /// Kullanıcı profili oluşturur
  Future<void> createProfile(String userId, String email, String fullName, {String? username}) async {
    try {
      // Kullanıcı adı belirtilmemişse, e-postadan oluştur
      final usernameToUse = username ?? email.split('@').first;
      
      await supabase.from(Constants.usersTable).insert({
        'id': userId,
        'username': usernameToUse,
        'email': email,
        'full_name': fullName,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      logger.i('Profile created: $userId');
    } catch (e) {
      logger.e('Profile creation error: $e');
      throw e;
    }
  }

  /// Kullanıcı adının kullanılabilir olup olmadığını kontrol eder
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final result = await supabase
          .from(Constants.usersTable)
          .select()
          .eq('username', username)
          .maybeSingle();
      
      return result == null;
    } catch (e) {
      logger.e('Username availability check error: $e');
      return false;
    }
  }

  /// Kullanıcı adından e-posta adresini bulur
  Future<String?> getEmailFromUsername(String username) async {
    try {
      final userData = await supabase
          .from(Constants.usersTable)
          .select('email')
          .eq('username', username)
          .maybeSingle();
      
      return userData?['email'] as String?;
    } catch (e) {
      logger.e('Get email from username error: $e');
      return null;
    }
  }

  /// Mesajı okundu olarak işaretler
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await supabase.rpc('mark_message_as_read', params: {'message_id': messageId});
    } catch (e) {
      logger.e('Mesaj okundu işaretleme hatası: $e');
    }
  }

  /// Kullanıcının arkadaşlarını getirir
  Future<List<Map<String, dynamic>>> getFriends(String userId) async {
    try {
      final friendsData = await supabase
          .from(Constants.friendRequestsTable)
          .select('sender_id, receiver_id')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .eq('status', Constants.accepted);
      
      List<String> friendIds = [];
      for (final friend in friendsData) {
        if (friend['sender_id'] == userId) {
          friendIds.add(friend['receiver_id']);
        } else {
          friendIds.add(friend['sender_id']);
        }
      }
      
      if (friendIds.isEmpty) {
        return [];
      }
      
      List<Map<String, dynamic>> friends = [];
      
      for (final friendId in friendIds) {
        final userData = await supabase
            .from(Constants.usersTable)
            .select()
            .eq('id', friendId)
            .single();
        
        friends.add(userData);
      }
      
      return friends;
    } catch (e) {
      logger.e('Arkadaşları getirme hatası: $e');
      return [];
    }
  }

  /// Bekleyen arkadaşlık isteklerini getirir
  Future<List<Map<String, dynamic>>> getPendingFriendRequests(String userId) async {
    try {
      final pendingRequestsData = await supabase
          .from(Constants.friendRequestsTable)
          .select('id, sender_id, receiver_id, created_at')
          .eq('receiver_id', userId)
          .eq('status', Constants.pending);
      
      List<Map<String, dynamic>> pendingRequests = [];
      
      for (final request in pendingRequestsData) {
        final userData = await supabase
            .from(Constants.usersTable)
            .select()
            .eq('id', request['sender_id'])
            .single();
        
        pendingRequests.add({...request, 'user': userData});
      }
      
      return pendingRequests;
    } catch (e) {
      logger.e('Bekleyen istekleri getirme hatası: $e');
      return [];
    }
  }

  /// Kullanıcı arama
  Future<List<Map<String, dynamic>>> searchUsers(String query, String currentUserId) async {
    try {
      final results = await supabase
          .from(Constants.usersTable)
          .select()
          .or('email.ilike.%$query%,full_name.ilike.%$query%,username.ilike.%$query%')
          .neq('id', currentUserId);
      
      // Mevcut arkadaşları ve bekleyen istekleri filtrele
      List<Map<String, dynamic>> filteredResults = [];
      for (final user in results) {
        final existingRelation = await supabase
            .from(Constants.friendRequestsTable)
            .select()
            .or(
              'and(sender_id.eq.${currentUserId},receiver_id.eq.${user['id']}),and(sender_id.eq.${user['id']},receiver_id.eq.${currentUserId})',
            )
            .not('status', 'eq', Constants.rejected);
        
        if (existingRelation.isEmpty) {
          filteredResults.add(user);
        }
      }
      
      return filteredResults;
    } catch (e) {
      logger.e('Kullanıcı arama hatası: $e');
      return [];
    }
  }
}

