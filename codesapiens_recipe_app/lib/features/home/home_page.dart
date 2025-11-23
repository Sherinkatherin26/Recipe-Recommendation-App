import 'dart:async'; // <-- Added for debounce
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/db/sqlite_db.dart';
import '../auth/auth_provider.dart';
import '../recipes/favorites_provider.dart';
import '../recipes/recipe.dart';
import '../recipes/recipe_repository.dart';
import '../recipe_detail/recipe_detail_page.dart';
import '../recipes/recipe_image.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Recipe> _all = [];
  List<Recipe> _filtered = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  // Debounce timer for search
  Timer? _debounce;

  // Category management
  final List<String> _categories = [
    'All',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Vegan',
    'Dessert',
  ];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadRecipes();

    // Attach a debounced listener to search input
    _searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), () {
        _onSearchChanged();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    final list = await RecipeRepository.instance.loadRecipes();
    setState(() {
      _all = list;
      _applyFilters();
      _loading = false;
    });
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((r) {
        // Category filter
        final matchesCategory = _selectedCategory == 'All' ||
            (r.category.isNotEmpty &&
                r.category.toLowerCase() ==
                    _selectedCategory.trim().toLowerCase());

        if (q.isEmpty) return matchesCategory;

        final name = r.name.toLowerCase();
        final ingredients = r.ingredients.join(' ').toLowerCase();

        return matchesCategory && (name.contains(q) || ingredients.contains(q));
      }).toList();
    });
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      _applyFilters();
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated) {
      final userEmail = authProvider.userEmail;
      if (userEmail != null && userEmail.isNotEmpty) {
        LocalDatabase.instance
            .addActivity(userEmail, 'search:$q')
            .catchError((_) {});
      }
    }

    _applyFilters();
  }

  void _onCategorySelected(String category) {
    _selectedCategory = category;
    _applyFilters();
  }

  void _navigateToRecipe(Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: recipe)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Discover Recipes', style: textTheme.titleMedium),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What would you like to cook today?',
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    _SearchBar(
                      suggestions: _all.map((r) => r.name).toList(),
                      controller: _searchController,
                      onSelected: (s) {
                        _searchController.text = s;
                        _onSearchChanged();
                        final selected = _all.firstWhere(
                          (r) => r.name == s,
                          orElse: () => _all.first,
                        );
                        FocusScope.of(context).unfocus();
                        _navigateToRecipe(selected);
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const SizedBox.shrink()
                    else if (_all.isNotEmpty)
                      _FeaturedBanner(
                        recipe: _all.first,
                        onExplore: () => _navigateToRecipe(_all.first),
                      )
                    else
                      const SizedBox.shrink(),
                    const SizedBox(height: 24),
                    Text('Categories', style: textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _CategoryChips(
                      categories: _categories,
                      selected: _selectedCategory,
                      onSelected: (c) => setState(() => _onCategorySelected(c)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Popular', style: textTheme.titleMedium),
                        TextButton(
                          onPressed: _applyFilters,
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: _loading
                    ? const SizedBox.shrink()
                    : (_filtered.isEmpty
                        ? const SizedBox.shrink()
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filtered.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemBuilder: (context, index) =>
                                _RecipeCard(recipe: _filtered[index]),
                          )),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.suggestions,
    // ignore: unused_element_parameter
    this.onChanged,
    this.onSelected,
    required this.controller,
  });

  final List<String> suggestions;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSelected;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        final q = textEditingValue.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return suggestions.where((s) => s.toLowerCase().contains(q));
      },
      onSelected: (value) => onSelected?.call(value),
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Search recipes, ingredients...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                controller.clear();
                onChanged?.call('');
              },
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelectedOpt, options) {
        return Material(
          elevation: 4,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              return ListTile(
                title: Text(option),
                onTap: () => onSelectedOpt(option),
              );
            },
          ),
        );
      },
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == selected;
          return ChoiceChip(
            label: Text(cat),
            selected: isSelected,
            onSelected: (_) => onSelected(cat),
            selectedColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.14),
            labelStyle: TextStyle(
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
            backgroundColor: AppColors.surface,
            elevation: isSelected ? 2 : 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemCount: categories.length,
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: recipe)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: RecipeImage(src: recipe.imageUrl, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Consumer<FavoritesProvider>(
                    builder: (context, favoritesProvider, child) {
                      final isFavorite =
                          favoritesProvider.isFavorite(recipe.id);
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () async {
                              final userEmail = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              ).userEmail;

                              await favoritesProvider.toggleFavorite(
                                recipe.id,
                                userEmail: userEmail,
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      favoritesProvider.isFavorite(recipe.id)
                                          ? 'Added to favorites'
                                          : 'Removed from favorites',
                                    ),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 22,
                                color: isFavorite
                                    ? Colors.red
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.durationMinutes}m',
                        style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.local_fire_department_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.kcal}cal',
                        style: textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({required this.recipe, this.onExplore});

  final Recipe recipe;
  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 6,
            child: RecipeImage(src: recipe.imageUrl, fit: BoxFit.cover),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    recipe.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: Colors.white),
                  ),
                ),
                FilledButton(
                  onPressed: onExplore,
                  child: const Text('Explore'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
