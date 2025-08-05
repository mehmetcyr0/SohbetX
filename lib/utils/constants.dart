class Constants {
  // Supabase credentials - Gerçek değerlerinizi buraya ekleyin
  static const String supabaseUrl = 'https://fixbofhjtkshouvvpifo.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZpeGJvZmhqdGtzaG91dnZwaWZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE5ODYxODUsImV4cCI6MjA1NzU2MjE4NX0.r0G_4J-kxAxkXOXKIGzHmM2-1Q90KXZom75bStvA0uo';

  // Database tables
  static const String usersTable = 'profiles';
  static const String messagesTable = 'messages';
  static const String friendRequestsTable = 'friend_requests';

  // Storage buckets - Supabase'de tam olarak bu isimlerle oluşturun
  static const String profileImagesBucket = 'profile-images';
  static const String chatImagesBucket = 'chat-images';
  static const String filesBucket = 'files';

  // Friend request status
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';

  // File types
  static const String imageType = 'image';
  static const String fileType = 'file';

  // User status
  static const String online = 'online';
  static const String offline = 'offline';
  static const String away = 'away';
}
