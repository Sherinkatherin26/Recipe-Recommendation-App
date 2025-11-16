import 'recipe.dart';
import 'mock_recipes.dart';

class RecipeRepository {
  const RecipeRepository();

  Future<List<Recipe>> loadRecipes() async {
    // try {
    //   final raw = await rootBundle.loadString('assets/recipes.json');
    //   final dynamic decoded = jsonDecode(raw);
    //   if (decoded is List) {
    //     final recipes = decoded.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
    //     if (recipes.isNotEmpty) return recipes;
    //   }
    //   return kMockRecipes; // fallback
    // } catch (_) {
    //   return kMockRecipes; // fallback if file missing or invalid
    // }
    return kMockRecipes;
  }
}
