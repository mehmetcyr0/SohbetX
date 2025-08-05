import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:sohbetx/screens/auth/login_screen.dart';
import 'package:sohbetx/utils/constants.dart';
import 'package:sohbetx/utils/snackbar.dart';
import 'package:sohbetx/utils/theme.dart';
import 'package:sohbetx/utils/file_handler.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploading = false;
  String? _avatarUrl;
  String? _email;
  DateTime? _joinDate;
  late final String _userId;
  String? _error;
  bool _isInitializing = false;
  bool _isUsernameAvailable = true;
  bool _isCheckingUsername = false;

  @override
  void initState() {
    super.initState();
    _userId = supabase.auth.currentUser!.id;
    _email = supabase.auth.currentUser!.email;
    _loadProfile();
  }

  // Profil tablosunu kontrol et ve gerekirse oluştur
  Future<void> _ensureProfileExists() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      // Profil var mı kontrol et
      final data =
          await supabase.from(Constants.usersTable).select().eq('id', _userId);

      // Profil yoksa oluştur
      if (data.isEmpty) {
        await supabase.from(Constants.usersTable).insert({
          'id': _userId,
          'full_name': 'Kullanıcı',
          'email': _email,
          'username': _generateDefaultUsername(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          showSnackBar(context, 'Profil oluşturuldu');
        }
      }
    } catch (error) {
      print('Profil kontrolü sırasında hata: $error');
      if (mounted) {
        showSnackBar(
          context,
          'Profil kontrolü sırasında hata oluştu: ${error.toString()}',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  String _generateDefaultUsername() {
    if (_email == null) return 'user_${DateTime.now().millisecondsSinceEpoch}';
    return _email!.split('@')[0];
  }

  Future<void> _checkUsername(String username) async {
    if (username.isEmpty || username.length < 3) return;

    setState(() {
      _isCheckingUsername = true;
    });

    try {
      final data = await supabase
          .from(Constants.usersTable)
          .select()
          .eq('username', username)
          .neq('id', _userId);

      if (mounted) {
        setState(() {
          _isUsernameAvailable = data.isEmpty;
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      print('Kullanıcı adı kontrolü sırasında hata: $e');
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
        });
      }
    }
  }

  // Fix the profile loading to properly display user information
  Future<void> _loadProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Önce profil tablosunun varlığını kontrol et
      await _ensureProfileExists();

      // Profil verilerini getir
      final data = await supabase
          .from(Constants.usersTable)
          .select()
          .eq('id', _userId)
          .maybeSingle();

      if (data != null) {
        if (mounted) {
          setState(() {
            _nameController.text = data['full_name'] ?? '';
            _bioController.text = data['bio'] ?? '';
            _usernameController.text = data['username'] ?? '';
            _avatarUrl = data['avatar_url'];
            _email = _email ?? data['email'];
            _joinDate = data['created_at'] != null
                ? DateTime.parse(data['created_at'])
                : DateTime.now();
            _isLoading = false;
          });
        }
      } else {
        // Profil bulunamadı, yeni oluştur
        if (mounted) {
          setState(() {
            _nameController.text = 'Kullanıcı';
            _usernameController.text = _generateDefaultUsername();
            _isLoading = false;
          });
        }
      }
    } catch (error) {
      print('Profil yükleme hatası: $error');
      if (mounted) {
        setState(() {
          _error = 'Profil yüklenirken bir hata oluştu: ${error.toString()}';
          _isLoading = false;
        });
        showSnackBar(
          context,
          'Profil yüklenirken bir hata oluştu: ${error.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      // Profil güncelle
      await supabase.from(Constants.usersTable).upsert({
        'id': _userId,
        'full_name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'email': _email,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        showSnackBar(context, 'Profil başarıyla güncellendi');
      }
    } catch (error) {
      print('Profil güncelleme hatası: $error');
      if (mounted) {
        setState(() {
          _error = 'Profil güncellenirken bir hata oluştu: ${error.toString()}';
        });
        showSnackBar(
          context,
          'Profil güncellenirken bir hata oluştu: ${error.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _uploadAvatar() async {
    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      // Fotoğraf seçme işlemi
      final File? imageFile = await FileHandler.pickImage(context);
      if (imageFile == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // Eski avatarı sil (varsa)
      if (_avatarUrl != null) {
        try {
          final oldFileName = path.basename(_avatarUrl!);
          await supabase.storage
              .from(Constants.profileImagesBucket)
              .remove([oldFileName]);
        } catch (e) {
          print('Eski avatar silinirken hata: $e');
          // Eski avatar silinirken hata olsa bile devam et
        }
      }

      // Yeni avatarı yükle
      final imageUrl =
          await FileHandler.uploadProfileImage(context, _userId, imageFile);

      if (imageUrl == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // Profili güncelle
      await supabase.from(Constants.usersTable).update({
        'avatar_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _userId);

      setState(() {
        _avatarUrl = imageUrl;
      });

      if (mounted) {
        showSnackBar(context, 'Profil fotoğrafı güncellendi');
      }
    } catch (error) {
      print('Avatar yükleme hatası: $error');
      if (mounted) {
        setState(() {
          _error = 'Fotoğraf yüklenirken bir hata oluştu: ${error.toString()}';
        });
        showSnackBar(
          context,
          'Fotoğraf yüklenirken bir hata oluştu: ${error.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (error) {
      print('Çıkış yapma hatası: $error');
      if (mounted) {
        showSnackBar(
          context,
          'Çıkış yapılırken bir hata oluştu: ${error.toString()}',
          isError: true,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profil'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Profil yükleniyor...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profil'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppTheme.errorColor,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.errorColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
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
                  Stack(
                    children: [
                      Container(
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
                          backgroundImage: _avatarUrl != null
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: _avatarUrl == null
                              ? Text(
                                  _nameController.text.isNotEmpty
                                      ? _nameController.text[0].toUpperCase()
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
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: _isUploading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    color: AppTheme.primaryColor,
                                  ),
                            onPressed: _isUploading ? null : _uploadAvatar,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _nameController.text,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${_usernameController.text}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profil Bilgileri',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen adınızı ve soyadınızı girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Kullanıcı Adı',
                        prefixIcon: const Icon(Icons.alternate_email),
                        border: const OutlineInputBorder(),
                        suffixIcon: _isCheckingUsername
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : _usernameController.text.isNotEmpty
                                ? Icon(
                                    _isUsernameAvailable
                                        ? Icons.check_circle
                                        : Icons.error,
                                    color: _isUsernameAvailable
                                        ? Colors.green
                                        : Colors.red,
                                  )
                                : null,
                      ),
                      onChanged: (value) {
                        if (value.length >= 3) {
                          _checkUsername(value);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen bir kullanıcı adı girin';
                        }
                        if (!_isUsernameAvailable) {
                          return 'Bu kullanıcı adı zaten kullanılıyor';
                        }
                        if (value.length < 3) {
                          return 'Kullanıcı adı en az 3 karakter olmalıdır';
                        }
                        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                          return 'Kullanıcı adı sadece harf, rakam ve alt çizgi içerebilir';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Hakkımda',
                        prefixIcon: Icon(Icons.description_outlined),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      maxLength: 150,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Profili Güncelle'),
                      ),
                    ),
                    const SizedBox(height: 24),
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
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('E-posta'),
                        subtitle: Text(_email ?? ''),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                      child: OutlinedButton(
                        onPressed: _signOut,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Çıkış Yap'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
