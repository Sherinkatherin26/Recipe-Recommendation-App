import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/db/sqlite_db.dart';
import '../recipes/favorites_provider.dart';
import '../auth/auth_provider.dart';
import '../activities/activities_provider.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _imageUrl;

  static const _kProfileImageKey = 'profile_image_url';

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.userName ?? 'Guest';
    final userEmail = authProvider.userEmail ?? 'Not logged in';

    // Mock data
    const int recipesCreated = 5;
    const int favoriteRecipes = 12;
    const int followersCount = 25;
    const int followingCount = 30;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(userName),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.7),
                    ],
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
                          backgroundImage:
                              _imageUrl != null && _imageUrl!.isNotEmpty
                                  ? NetworkImage(_imageUrl!) as ImageProvider
                                  : const NetworkImage(
                                      'https://i.pravatar.cc/150?img=5'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userEmail,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        context,
                        'Recipes',
                        recipesCreated.toString(),
                        Icons.restaurant_menu,
                      ),
                      _buildStatCard(
                        context,
                        'Favorites',
                        favoriteRecipes.toString(),
                        Icons.favorite,
                      ),
                      _buildStatCard(
                        context,
                        'Followers',
                        followersCount.toString(),
                        Icons.people,
                      ),
                      _buildStatCard(
                        context,
                        'Following',
                        followingCount.toString(),
                        Icons.person_add,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Profile'),
                  onTap: () {
                    // TODO: Navigate to edit profile
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.group_add),
                  title: const Text('Manage Follows'),
                  subtitle: const Text('Follow other users and sync favorites'),
                  onTap: () => _showManageFollowsDialog(context, userEmail),
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.favorite),
                  title: const Text('My Favorite Recipes'),
                  onTap: () {
                    // TODO: Navigate to favorites
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restaurant_menu),
                  title: const Text('My Recipes'),
                  onTap: () {
                    // TODO: Navigate to user recipes
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  onTap: () {
                    // TODO: Navigate to help & support
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () => _showLogoutDialog(context, authProvider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              controller.text = '';
              Navigator.pop(context, null);
            },
            child: const Text('Use Default'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _saveProfileImage(controller.text.trim());
    } else if (result == null) {
      // Use default
      await _saveProfileImage('');
    }
  }

  Future<void> _showManageFollowsDialog(
      BuildContext context, String userEmail) async {
    if (userEmail == 'Not logged in') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to manage follows')));
      }
      return;
    }

    final favProvider = context.read<FavoritesProvider>();
    final controller = TextEditingController();

    // Load current following list
    List<String> following = [];
    try {
      following = await LocalDatabase.instance.getFollowing(userEmail);
    } catch (_) {}

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
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
                  child: Text('Currently following:')),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                width: double.maxFinite,
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
                                // After unfollowing, reload/sync favorites and activities
                                try {
                                  await favProvider
                                      .loadFavoritesForUser(userEmail);
                                  await favProvider
                                      .syncFavoritesFromFollowing(userEmail);
                                } catch (_) {}
                                try {
                                  final activities =
                                      context.read<ActivitiesProvider>();
                                  await activities
                                      .loadActivitiesForUser(userEmail);
                                  await activities
                                      .syncActivitiesFromFollowing(userEmail);
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
                // After following, sync favorites
                await favProvider.syncFavoritesFromFollowing(userEmail);
                try {
                  final activities = context.read<ActivitiesProvider>();
                  await activities.loadActivitiesForUser(userEmail);
                  await activities.syncActivitiesFromFollowing(userEmail);
                } catch (_) {}
                setState(() {
                  if (!following.contains(emailToFollow))
                    following.add(emailToFollow);
                });
                controller.clear();
              },
              child: const Text('Follow'),
            ),
          ],
        );
      }),
    );
  }

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
            Icon(icon, color: Theme.of(context).primaryColor),
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final userEmail = authProvider.userEmail;

      // Sync activities to backend before logout
      if (userEmail != null) {
        try {
          final activities = context.read<ActivitiesProvider>();
          await activities.syncLocalActivitiesToBackend(userEmail);
        } catch (_) {
          // Continue with logout even if sync fails
        }
      }

      await authProvider.logout();
      // Clear user-scoped providers so UI resets between users
      try {
        final favProvider = context.read<FavoritesProvider>();
        favProvider.clear();
      } catch (_) {}
      try {
        final activities = context.read<ActivitiesProvider>();
        activities.clear();
      } catch (_) {}
    }
  }
}
