import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sohbetx/utils/constants.dart';
import 'package:sohbetx/utils/snackbar.dart';
import 'package:sohbetx/utils/theme.dart';
import 'package:sohbetx/utils/database_helper.dart';
import 'package:sohbetx/screens/auth/login_screen.dart';
import 'package:sohbetx/screens/home_screen.dart';
import 'package:logger/logger.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isUsernameAvailable = true;
  bool _isCheckingUsername = false;
  final supabase = Supabase.instance.client;
  final dbHelper = DatabaseHelper(Supabase.instance.client);
  final _logger = Logger();

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkUsername(String username) async {
    if (username.isEmpty || username.length < 3) return;
    
    setState(() {
      _isCheckingUsername = true;
    });

    try {
      final isAvailable = await dbHelper.isUsernameAvailable(username);
      
      if (mounted) {
        setState(() {
          _isUsernameAvailable = isAvailable;
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      _logger.e('Kullanıcı adı kontrolü sırasında hata: $e');
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
        });
      }
    }
  }

  // Ensure profile creation on registration
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Kullanıcı adı kontrolü
      if (!_isUsernameAvailable) {
        showSnackBar(context, 'Bu kullanıcı adı zaten kullanılıyor', isError: true);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Create auth user
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'full_name': _nameController.text.trim(),
          'username': _usernameController.text.trim(),
        },
      );
      
      final User? user = res.user;
      
      if (user != null) {
        // Create profile immediately
        try {
          await supabase.from(Constants.usersTable).upsert({
            'id': user.id,
            'username': _usernameController.text.trim(),
            'full_name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          
          _logger.i('Profile created successfully');
          
          // Set user status to online
          await supabase
            .from(Constants.usersTable)
            .update({
              'status': Constants.online,
              'last_online': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
          
          if (mounted) {
            // Navigate directly to home screen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }
        } catch (e) {
          _logger.e('Profil oluşturma hatası: $e');
          // If profile creation fails, still allow login but show a message
          if (mounted) {
            showSnackBar(
              context, 
              'Hesabınız oluşturuldu ancak profil bilgileriniz kaydedilirken bir sorun oluştu. Lütfen daha sonra profil bilgilerinizi güncelleyin.',
            );
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        showSnackBar(context, error.message, isError: true);
      }
    } catch (error) {
      if (mounted) {
        showSnackBar(context, 'Beklenmeyen bir hata oluştu: ${error.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Ol'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'SohbetX\'e Hoş Geldiniz',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF424242),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Yeni bir hesap oluşturun',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF757575),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                      prefixIcon: Icon(Icons.person_outline),
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
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen e-posta adresinizi girin';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Geçerli bir e-posta adresi girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen şifrenizi girin';
                      }
                      if (value.length < 6) {
                        return 'Şifre en az 6 karakter olmalıdır';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Şifreyi Doğrula',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen şifrenizi tekrar girin';
                      }
                      if (value != _passwordController.text) {
                        return 'Şifreler eşleşmiyor';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Kayıt Ol'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Zaten hesabınız var mı? Giriş yapın',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

