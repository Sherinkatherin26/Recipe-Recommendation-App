import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/db/sqlite_db.dart';
import '../recipes/favorites_provider.dart';
import '../auth/auth_provider.dart';
import '../activities/activities_provider.dart';
import 'settings_page.dart';
import '../favourites/favourites_page.dart';
import 'edit_profile_page.dart';
import '../recipes/my_recipes_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _imageUrl;
  bool _loading = true;

  // Live stats
  int _recipesCreated = 0;
  int _favoriteRecipes = 0;
  int _followersCount = 0;
  int _followingCount = 0;

  static const _kProfileImageKey = 'profile_image_url';

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _imageUrl = prefs.getString(_kProfileImageKey);
    });
  }

  Future<void> _saveProfileImage(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.isEmpty) {
      await prefs.remove(_kProfileImageKey);
    } else {
      await prefs.setString(_kProfileImageKey, url);
    }
    setState(() => _imageUrl = url);
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final favProvider = context.read<FavoritesProvider>();

      final userEmail = auth.userEmail;
      if (userEmail != null && userEmail.isNotEmpty) {
        try {
          final following = await LocalDatabase.instance.getFollowing(userEmail);
          final followers = await LocalDatabase.instance.getFollowers(userEmail);
          final userFavs = await LocalDatabase.instance.getUserFavorites(userEmail);

          _followingCount = following.length;
          _followersCount = followers.length;
          _favoriteRecipes = userFavs.length;
        } catch (_) {}

        try {
          _recipesCreated =
              await LocalDatabase.instance.getUserRecipesCount(userEmail);
        } catch (_) {
          _recipesCreated = 0;
        }

        try {
          await favProvider.loadFavoritesForUser(userEmail);
        } catch (_) {}
      } else {
        try {
          final allFavs = await LocalDatabase.instance.getFavorites();
          _favoriteRecipes = allFavs.length;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('ProfilePage._loadStats error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showChangeImageDialog(BuildContext context) async {
    final controller = TextEditingController(text: _imageUrl ?? '');
    final result = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Profile Picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter an image URL to use as your profile picture.'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                controller.text = '';
                Navigator.pop(context, null);
              },
              child: const Text('Use Default')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (result == true) {
      await _saveProfileImage(controller.text.trim());
    } else if (result == null) {
      await _saveProfileImage('');
    }
  }

  Future<void> _showManageFollowsDialog(
      BuildContext context, String userEmail) async {
    if (userEmail.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to manage follows')));
      }
      return;
    }

    final favProvider = context.read<FavoritesProvider>();
    final controller = TextEditingController();

    List<String> following = [];
    try {
      following = await LocalDatabase.instance.getFollowing(userEmail);
    } catch (_) {}

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Manage Follows'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Email to follow',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Currently following:'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: following.isEmpty
                      ? const Center(child: Text('Not following anyone'))
                      : ListView.builder(
                          itemCount: following.length,
                          itemBuilder: (context, i) {
                            final e = following[i];
                            return ListTile(
                              title: Text(e),
                              trailing: TextButton(
                                onPressed: () async {
                                  await LocalDatabase.instance
                                      .removeFollower(userEmail, e);
                                  try {
                                    await favProvider
                                        .loadFavoritesForUser(userEmail);
                                    await favProvider
                                        .syncFavoritesFromFollowing(userEmail);
                                  } catch (_) {}
                                  try {
                                    final acts =
                                        context.read<ActivitiesProvider>();
                                    await acts.loadActivitiesForUser(userEmail);
                                    await acts.syncActivitiesFromFollowing(
                                        userEmail);
                                  } catch (_) {}
                                  setState(() => following.removeAt(i));
                                },
                                child: const Text('Unfollow',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
              ElevatedButton(
                onPressed: () async {
                  final emailToFollow = controller.text.trim();
                  if (emailToFollow.isEmpty) return;

                  await LocalDatabase.instance
                      .addFollower(userEmail, emailToFollow);

                  await favProvider.syncFavoritesFromFollowing(userEmail);

                  try {
                    final acts = context.read<ActivitiesProvider>();
                    await acts.loadActivitiesForUser(userEmail);
                    await acts.syncActivitiesFromFollowing(emailToFollow);
                  } catch (_) {}

                  setState(() {
                    if (!following.contains(emailToFollow)) {
                      following.add(emailToFollow);
                    }
                  });

                  controller.clear();
                },
                child: const Text('Follow'),
              ),
            ],
          );
        },
      ),
    );

    await _loadStats();
  }

  Future<void> _showLogoutDialog(
      BuildContext context, AuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final favProvider = context.read<FavoritesProvider>();
      final activitiesProvider = context.read<ActivitiesProvider>();

      final email = authProvider.userEmail;

      if (email != null) {
        try {
          await activitiesProvider.syncLocalActivitiesToBackend(email);
        } catch (_) {}
      }

      await authProvider.logout();

      try {
        favProvider.clear();
      } catch (_) {}
      try {
        activitiesProvider.clear();
      } catch (_) {}

      if (mounted) await _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.userName ?? 'Guest';
    final userEmail = authProvider.userEmail ?? '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(userName),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _showChangeImageDialog(context),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: _imageUrl != null &&
                                  _imageUrl!.isNotEmpty
                              ? NetworkImage(_imageUrl!)
                              : const NetworkImage(
                                  'https://i.pravatar.cc/150?img=5'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userEmail.isEmpty ? 'Not logged in' : userEmail,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Stats section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(context, 'Recipes',
                            _recipesCreated.toString(), Icons.restaurant_menu),
                        _buildStatCard(context, 'Favorites',
                            _favoriteRecipes.toString(), Icons.favorite),
                        _buildStatCard(context, 'Followers',
                            _followersCount.toString(), Icons.people),
                        _buildStatCard(context, 'Following',
                            _followingCount.toString(), Icons.person_add),
                      ],
                    ),
            ),
          ),

          const SliverToBoxAdapter(child: Divider()),

          // Options list
          SliverToBoxAdapter(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Profile'),
                  onTap: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditProfilePage()));
                    await _loadStats();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.group_add),
                  title: const Text('Manage Follows'),
                  subtitle:
                      const Text('Follow other users and sync favorites'),
                  onTap: () =>
                      _showManageFollowsDialog(context, userEmail),
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsPage())),
                ),
                ListTile(
                  leading: const Icon(Icons.favorite),
                  title: const Text('My Favorite Recipes'),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FavouritesPage())),
                ),
                ListTile(
                  leading: const Icon(Icons.restaurant_menu),
                  title: const Text('My Recipes'),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MyRecipesPage())),
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout',
                      style: TextStyle(color: Colors.red)),
                  onTap: () => _showLogoutDialog(context, authProvider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // FIXED: Corrected stat card (only change required)
  // -------------------------------------------------------
  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
