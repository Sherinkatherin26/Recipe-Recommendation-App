// lib/features/recipes/recipe_repository.dart
import 'dart:async';
import 'recipe.dart';
import 'mock_recipes.dart';

class RecipeRepository {
  // Allow both: RecipeRepository() and RecipeRepository.instance
  const RecipeRepository();

  // Singleton instance still supported
  static final RecipeRepository instance = RecipeRepository();

  static List<Recipe>? _cache;

  Future<List<Recipe>> loadRecipes() async {
    // return cached data if already loaded
    if (_cache != null) return _cache!;

    // Load mock recipes (or real API in future)
    _cache = kMockRecipes;
    return _cache!;
  }
}
