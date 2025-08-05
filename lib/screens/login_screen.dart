import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sohbetx/screens/home_screen.dart';
import 'package:sohbetx/screens/auth/register_screen.dart';
import 'package:sohbetx/utils/constants.dart';
import 'package:sohbetx/utils/snackbar.dart';
import 'package:sohbetx/utils/theme.dart';
import 'package:sohbetx/utils/database_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final supabase = Supabase.instance.client;
  final dbHelper = DatabaseHelper(Supabase.instance.client);

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final identifier = _identifierController.text.trim();
      String email;

      // Kullanıcı adı ile giriş yapılıyorsa, e-posta adresini bul
      if (!identifier.contains('@')) {
        final foundEmail = await dbHelper.getEmailFromUsername(identifier);
        if (foundEmail == null) {
          if (mounted) {
            showSnackBar(context, 'Kullanıcı adı bulunamadı', isError: true);
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
        email = foundEmail;
      } else {
        email = identifier;
      }

      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );
      
      final user = res.user;
      
      if (user != null) {
        // Kullanıcı durumunu çevrimiçi olarak güncelle
        await supabase
            .from(Constants.usersTable)
            .update({
              'status': Constants.online,
              'last_online': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
        
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
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
                    'SohbetX',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF424242),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hesabınıza giriş yapın',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF757575),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _identifierController,
                    decoration: const InputDecoration(
                      labelText: 'E-posta veya Kullanıcı Adı',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen e-posta adresinizi veya kullanıcı adınızı girin';
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
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Giriş Yap'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Hesabınız yok mu? Kayıt olun',
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

