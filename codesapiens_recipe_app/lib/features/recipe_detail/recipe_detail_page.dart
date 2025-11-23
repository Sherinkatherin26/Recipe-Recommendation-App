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
        // LOAD FROM SQLITE ONLY
        final progress = await LocalDatabase.instance
            .getUserProgressForRecipe(userEmail, widget.recipe.id);
        if (progress != null && progress['status'] == 'completed') {
          setState(() => _completed = true);
        }

        // Mark viewed
        await LocalDatabase.instance
            .setUserProgress(userEmail, widget.recipe.id, 'viewed');
      }
    } catch (e) {
      debugPrint('RecipeDetailPage _loadProgress error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProgress();

      final userEmail =
          Provider.of<AuthProvider>(context, listen: false).userEmail;

      if (userEmail != null) {
        // LOCAL ACTIVITY LOG (SQLite)
        await LocalDatabase.instance
            .addActivity(userEmail, 'view_recipe:${widget.recipe.id}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recipe = widget.recipe;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Back to Recipes'),
        actions: [
          // Completed toggle
          IconButton(
            tooltip: 'Mark completed',
            icon: Icon(
              _completed ? Icons.check_circle : Icons.check_circle_outline,
              color: _completed ? Colors.greenAccent : Colors.white,
            ),
            onPressed: () async {
              final userEmail =
                  Provider.of<AuthProvider>(context, listen: false).userEmail;
              if (userEmail == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please login to save progress')),
                );
                return;
              }

              final nowCompleted = !_completed;
              setState(() => _completed = nowCompleted);

              // SAVE TO SQLITE ONLY
              await LocalDatabase.instance.setUserProgress(
                userEmail,
                recipe.id,
                nowCompleted ? 'completed' : 'in_progress',
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      nowCompleted
                          ? 'Marked as completed'
                          : 'Marked as in progress',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          // Favorite toggle
          Consumer<FavoritesProvider>(
            builder: (context, favoritesProvider, child) {
              final isFavorite = favoritesProvider.isFavorite(recipe.id);
              return InkWell(
                customBorder: const CircleBorder(),
                onTap: () async {
                  final userEmail =
                      Provider.of<AuthProvider>(context, listen: false)
                          .userEmail;

                  await favoritesProvider.toggleFavorite(
                    recipe.id,
                    userEmail: userEmail,
                  );

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
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.grey.shade600,
                    size: 28,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IMAGE
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: RecipeImage(
                    src: recipe.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // NAME
              Text(
                recipe.name,
                style: textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              // DETAILS ROW
              Row(
                children: [
                  const Icon(Icons.schedule,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${recipe.durationMinutes} mins',
                      style: textTheme.bodyMedium),
                  const SizedBox(width: 12),
                  const Icon(Icons.local_fire_department_outlined,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${recipe.kcal} kcal', style: textTheme.bodyMedium),
                ],
              ),

              const SizedBox(height: 20),

              // INGREDIENTS
              if (recipe.ingredients.isNotEmpty) ...[
                Text('Ingredients',
                    style: textTheme.headlineMedium
                        ?.copyWith(color: const Color(0xFF3F6212))),
                const SizedBox(height: 8),
                ...recipe.ingredients.map(
                  (ingredient) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(
                          child: Text(ingredient, style: textTheme.bodyLarge),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // INSTRUCTIONS
              if (recipe.instructions.isNotEmpty) ...[
                Text('Instructions',
                    style: textTheme.headlineMedium
                        ?.copyWith(color: const Color(0xFF3F6212))),
                const SizedBox(height: 8),
                ...recipe.instructions.map(
                  (instruction) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(instruction, style: textTheme.bodyLarge),
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
