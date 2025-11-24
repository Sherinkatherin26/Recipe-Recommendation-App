class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.durationMinutes,
    required this.kcal,
    required this.category,
    this.ingredients = const [],
    this.instructions = const [],
  });

  final String id;
  final String name;
  final String imageUrl;
  final int durationMinutes;
  final int kcal;
  final String category; // e.g., Breakfast, Lunch, Dinner, Vegan
  final List<String> ingredients;
  final List<String> instructions;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image'] as String? ?? json['imageUrl'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      kcal: (json['kcal'] as num).toInt(),
      category: json['category'] as String? ?? '',
      ingredients:
          (json['ingredients'] as List<dynamic>?)?.cast<String>() ?? [],
      instructions:
          (json['instructions'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}
