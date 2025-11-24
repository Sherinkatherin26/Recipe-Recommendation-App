import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../recipes/favorites_provider.dart';
import '../recipes/recipe.dart';
import '../recipes/recipe_repository.dart';
import '../recipe_detail/recipe_detail_page.dart';
import '../recipes/recipe_image.dart';

class FavouritesPage extends StatelessWidget {
  const FavouritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Favourites', style: textTheme.headlineMedium),
        leading: const SizedBox(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Consumer<FavoritesProvider>(
          builder: (context, favoritesProvider, child) {
            return FutureBuilder<List<Recipe>>(
              future: const RecipeRepository().loadRecipes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = snapshot.data ?? [];
                final favoriteRecipes = list
                    .where((recipe) => favoritesProvider.isFavorite(recipe.id))
                    .toList();

                if (favoriteRecipes.isEmpty) return const _EmptyState();
                return _FavouritesList(recipes: favoriteRecipes);
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 72, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'Save and view your Favourites',
            style: textTheme.headlineMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavouritesList extends StatelessWidget {
  const _FavouritesList({required this.recipes});
  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: recipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _FavouriteCard(recipe: recipes[index]),
    );
  }
}

class _FavouriteCard extends StatelessWidget {
  const _FavouriteCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        // Avoid deprecated withOpacity; use explicit RGBA
        border: Border.all(color: const Color.fromRGBO(17, 24, 39, 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 84,
              height: 84,
              child: RecipeImage(src: recipe.imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.name, style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _Meta(
                      icon: Icons.schedule,
                      label: '${recipe.durationMinutes} mins',
                    ),
                    _Meta(icon: Icons.person_2_outlined, label: '2 servings'),
                    _Meta(icon: Icons.flag_outlined, label: 'Easy'),
                    _Tag('South Indian'),
                    _Tag('Quick'),
                    _Tag(recipe.kcal > 0 ? 'Vegetarian' : ''),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 180,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecipeDetailPage(recipe: recipe),
                        ),
                      );
                    },
                    child: const Text('View Recipe'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(label, style: textTheme.bodyMedium),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFF3F4F6),
      ),
      child: Text(
        label,
        style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF1F2937)),
      ),
    );
  }
}
