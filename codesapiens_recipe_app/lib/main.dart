import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_screen.dart';
import 'features/recipes/favorites_provider.dart';
import 'features/profile/preferences_provider.dart';
import 'features/activities/activities_provider.dart';
import 'features/root/root_shell.dart';
import 'features/root/start_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => ActivitiesProvider()),
        ChangeNotifierProvider(create: (_) => PreferencesProvider()),
      ],
      child: MaterialApp(
        title: 'Codesapiens Recipes',
        theme: buildLightTheme(),
        home: const AuthenticationWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthenticationWrapper extends StatefulWidget {
  const AuthenticationWrapper({super.key});

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Show splash screen for 3 seconds on first load
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const StartPage();
    }

    // Wrap the entire Consumer-based navigation to ensure it responds to auth changes
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        print(
            'AuthenticationWrapper.Consumer rebuilding. isAuthenticated = ${authProvider.isAuthenticated}');

        // If authenticated, show RootShell
        if (authProvider.isAuthenticated) {
          return const RootShell();
        }

        // If not authenticated, show AuthScreen
        return const AuthScreen();
      },
    );
  }
}
