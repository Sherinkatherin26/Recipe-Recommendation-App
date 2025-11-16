import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../../core/db/sqlite_db.dart';
import '../../core/theme.dart';
import '../recipes/favorites_provider.dart';
import '../recipes/recipe.dart';
import '../recipes/recipe_image.dart';

class RecipeDetailPage extends StatefulWidget {
  const RecipeDetailPage({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  bool _completed = false;

  Future<void> _loadProgress() async {
    try {
      final userEmail =
          Provider.of<AuthProvider>(context, listen: false).userEmail;
      if (userEmail != null) {
        final progress = await LocalDatabase.instance
            .getUserProgressForRecipe(userEmail, widget.recipe.id);
        if (progress != null && progress['status'] == 'completed') {
          setState(() => _completed = true);
        }
        // also record a 'viewed' activity/progress
        await LocalDatabase.instance
            .setUserProgress(userEmail, widget.recipe.id, 'viewed');
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    // load progress after first frame so Provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProgress());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recipe = widget.recipe;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Back to Recipes'),
        actions: [
          // Completed toggle
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              tooltip: 'Mark completed',
              icon: Icon(
                  _completed ? Icons.check_circle : Icons.check_circle_outline,
                  color: _completed ? Colors.greenAccent : Colors.white),
              onPressed: () async {
                final userEmail =
                    Provider.of<AuthProvider>(context, listen: false).userEmail;
                if (userEmail == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Please login to save progress')));
                  return;
                }
                final nowCompleted = !_completed;
                setState(() => _completed = nowCompleted);
                try {
                  await LocalDatabase.instance.setUserProgress(userEmail,
                      recipe.id, nowCompleted ? 'completed' : 'in_progress');
                } catch (_) {}
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(nowCompleted
                        ? 'Marked as completed'
                        : 'Marked as in progress'),
                    duration: const Duration(seconds: 1)));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Consumer<FavoritesProvider>(
              builder: (context, favoritesProvider, child) {
                final isFavorite = favoritesProvider.isFavorite(recipe.id);
                return InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    final userEmail =
                        Provider.of<AuthProvider>(context, listen: false)
                            .userEmail;
                    await favoritesProvider.toggleFavorite(recipe.id,
                        userEmail: userEmail);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isFavorite
                              ? 'Removed from favorites'
                              : 'Added to favorites',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey.shade600,
                      size: 28,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: RecipeImage(src: recipe.imageUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                recipe.name,
                style: textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${recipe.durationMinutes} mins',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.local_fire_department_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text('${recipe.kcal} kcal', style: textTheme.bodyMedium),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      recipe.category,
                      style: textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (recipe.ingredients.isNotEmpty) ...[
                Text(
                  'Ingredients',
                  style: textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF3F6212),
                  ),
                ),
                const SizedBox(height: 8),
                ...recipe.ingredients.map(
                  (ingredient) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(
                          child: Text(
                            ingredient,
                            style: textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (recipe.instructions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Instructions',
                  style: textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF3F6212),
                  ),
                ),
                const SizedBox(height: 8),
                ...recipe.instructions.map(
                  (instruction) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            instruction,
                            style: textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
