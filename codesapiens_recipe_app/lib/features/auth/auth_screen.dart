import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import '../root/root_shell.dart';
import '../recipes/favorites_provider.dart';
import '../activities/activities_provider.dart';
import 'package:logging/logging.dart';

final _logger = Logger('AuthScreen');

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      String? error;

      if (_isLogin) {
        error = await authProvider.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        // Provide defaults if user left name or password empty
        final email = _emailController.text.trim();
        var name = _nameController.text.trim();
        if (name.isEmpty) {
          name = email.contains('@') ? email.split('@').first : 'User';
        }
        var password = _passwordController.text;
        String? generatedPassword;
        if (password.isEmpty) {
          // generate a simple deterministic 8-char password (not cryptographically secure)
          const chars =
              'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
          final seed = DateTime.now().millisecondsSinceEpoch;
          final sb = StringBuffer();
          for (var i = 0; i < 8; i++) {
            sb.write(chars[(seed + i) % chars.length]);
          }
          generatedPassword = sb.toString();
          password = generatedPassword;
        }

        error = await authProvider.signup(
          name,
          email,
          password,
        );

        if (error == null && generatedPassword != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Account created. Generated password: $generatedPassword'),
              backgroundColor: Colors.blueGrey,
            ),
          );
        }
      }

      if (error == null && mounted) {
        // Success: AuthenticationWrapper will rebuild and show RootShell
        _logger.info(
            'Login/Signup successful. AuthProvider.isAuthenticated = ${authProvider.isAuthenticated}');
        // Load and sync user-specific favorites so UI shows correct state
        try {
          final favProvider = context.read<FavoritesProvider>();
          final userEmail =
              authProvider.userEmail ?? _emailController.text.trim();
          await favProvider.loadFavoritesForUser(userEmail);
          await favProvider.syncFavoritesFromFollowing(userEmail);
          // Load recent activities for the authenticated user and merge following
          try {
            final activities = context.read<ActivitiesProvider>();
            await activities.loadActivitiesForUser(userEmail);
            await activities.syncActivitiesFromFollowing(userEmail);
          } catch (e) {
            debugPrint('AuthScreen: activities load/sync failed: $e');
          }
        } catch (e) {
          // Non-fatal; continue to navigation
          debugPrint('AuthScreen: favorites sync failed: $e');
        }
        // Force navigation to RootShell to ensure we land on home
        try {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RootShell()),
          );
        } catch (_) {}
      } else if (error != null && mounted) {
        // Smart UX: switch modes based on common error messages
        if (error.toLowerCase().contains('already exists')) {
          // If signup failed because account exists, switch to login mode and prefill email
          setState(() {
            _isLogin = true;
            _emailController.text = _emailController.text.trim();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Account already exists — switched to Login. Please enter your password.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (error.toLowerCase().contains('account does not exist')) {
          // If login failed because account doesn't exist, switch to signup mode and prefill email
          setState(() {
            _isLogin = false;
            _emailController.text = _emailController.text.trim();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Account not found — switched to Sign Up. Please provide your name and password.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Icon(
                    Icons.restaurant_menu,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    _isLogin ? 'Welcome Back!' : 'Create Account',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Name field (only for signup)
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      // Name is optional now; we'll default it from email if omitted
                      validator: (value) {
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    // Password is optional for signup; if omitted we'll generate one.
                    validator: (value) {
                      if (_isLogin) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                      } else {
                        if (value != null &&
                            value.isNotEmpty &&
                            value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isLogin ? 'Login' : 'Sign Up',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle button
                  TextButton(
                    onPressed: _isLoading ? null : _toggleAuthMode,
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign Up"
                          : 'Already have an account? Login',
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
