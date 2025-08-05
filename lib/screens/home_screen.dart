import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sohbetx/screens/chat/chats_screen.dart';
import 'package:sohbetx/screens/friends/friends_screen.dart';
import 'package:sohbetx/screens/profile/profile_screen.dart';
import 'package:sohbetx/utils/constants.dart';
import 'package:logger/logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  final _logger = Logger();
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const ChatsScreen(),
    const FriendsScreen(),
    const ProfileScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
    _updateUserStatus(Constants.online);
  }
  
  @override
  void dispose() {
    _updateUserStatus(Constants.offline);
    super.dispose();
  }
  
  Future<void> _updateUserStatus(String status) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase
          .from(Constants.usersTable)
          .update({
            'status': status,
            'last_online': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      
      _logger.i('User status updated to: $status');
    } catch (e) {
      _logger.e('Error updating user status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Sohbetler',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Arkadaşlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

