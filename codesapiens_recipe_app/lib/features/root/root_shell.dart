import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home/home_page.dart';
import '../search/search_page.dart';
import '../favourites/favourites_page.dart';
import '../profile/profile_page.dart';
import '../recipes/favorites_provider.dart';
import '../activities/activities_provider.dart';
import '../auth/auth_provider.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  final _pages = const [
    HomePage(),
    SearchPage(),
    SizedBox.shrink(), // Center add action placeholder
    FavouritesPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    // After the first frame, load user-scoped data if authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final favs = context.read<FavoritesProvider>();
      final activities = context.read<ActivitiesProvider>();
      if (auth.isAuthenticated && auth.userEmail != null) {
        try {
          await favs.loadFavoritesForUser(auth.userEmail!);
          await favs.syncFavoritesFromFollowing(auth.userEmail!);
        } catch (_) {}
        try {
          await activities.loadActivitiesForUser(auth.userEmail!);
          await activities.syncActivitiesFromFollowing(auth.userEmail!);
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
