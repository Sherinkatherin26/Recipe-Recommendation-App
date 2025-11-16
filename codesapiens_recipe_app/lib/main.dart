import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'core/api_service.dart';
import 'core/theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_screen.dart';
import 'features/recipes/favorites_provider.dart';
import 'features/profile/preferences_provider.dart';
import 'features/activities/activities_provider.dart';
import 'features/root/root_shell.dart';
import 'features/root/start_page.dart';

void main() {
  // Configure API base URL depending on platform.
  // - On Android emulators use 10.0.2.2 to reach host machine.
  // - On web and desktop use localhost.
  try {
    if (kIsWeb) {
      ApiService.instance.baseUrl = 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      ApiService.instance.baseUrl = 'http://10.0.2.2:5000';
    } else {
      ApiService.instance.baseUrl = 'http://localhost:5000';
    }
  } catch (_) {
    // Fallback if Platform import isn't supported.
    ApiService.instance.baseUrl = 'http://localhost:5000';
  }

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
  String? _loadedForEmail;

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

        // If a user just logged in (different email than last loaded), load user-scoped data
        if (authProvider.isAuthenticated &&
            authProvider.userEmail != null &&
            authProvider.userEmail != _loadedForEmail) {
          // schedule after frame so providers are available
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              final favs = context.read<FavoritesProvider>();
              final activities = context.read<ActivitiesProvider>();
              final email = authProvider.userEmail!;
              await favs.loadFavoritesForUser(email);
              await favs.syncFavoritesFromFollowing(email);
              await activities.loadActivitiesForUser(email);
              await activities.syncActivitiesFromFollowing(email);
              _loadedForEmail = email;
            } catch (e) {
              debugPrint('Failed to load user-scoped data: $e');
            }
          });
        }

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
