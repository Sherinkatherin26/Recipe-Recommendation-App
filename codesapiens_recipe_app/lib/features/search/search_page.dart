import 'dart:async'; // <-- debounce
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../recipes/recipe.dart';
import '../recipes/recipe_repository.dart';
import '../recipes/recipe_image.dart';
import '../recipe_detail/recipe_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Recipe> _all = [];
  List<Recipe> _filtered = [];
  bool _loading = true;

  // debounce timer
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadRecipes();

    // debounce search listener
    _controller.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), () {
        _onChanged();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    final list = await RecipeRepository.instance.loadRecipes();
    setState(() {
      _all = list;
      _filtered = List.of(_all);
      _loading = false;
    });
  }

  void _onChanged() {
    final q = _controller.text.trim().toLowerCase();

    if (q.isEmpty) {
      setState(() => _filtered = List.of(_all));
      return;
    }

    setState(() {
      _filtered = _all.where((r) {
        final name = r.name.toLowerCase();
        final ingredients = r.ingredients.join(' ').toLowerCase();
        return name.contains(q) || ingredients.contains(q);
      }).toList();
    });
  }

  void _navigateTo(Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: recipe)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SearchField(
              controller: _controller,
              suggestions: _all.map((r) => r.name).toList(),
              onSelected: (s) {
                final match = _all.firstWhere(
                  (r) => r.name == s,
                  orElse: () => _all.first,
                );
                _controller.text = s;
                _onChanged();
                _navigateTo(match);
              },
            ),
            const SizedBox(height: 24),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off,
                          size: 72, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'No recipes found',
                        style: textTheme.headlineMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final recipe = _filtered[index];
                    return ListTile(
                      onTap: () => _navigateTo(recipe),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: RecipeImage(
                            src: recipe.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      title: Text(recipe.name),
                      subtitle: Text(
                        '${recipe.durationMinutes} mins • ${recipe.kcal} kcal',
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    this.controller,
    this.suggestions = const [],
    this.onSelected,
  });

  final TextEditingController? controller;
  final List<String> suggestions;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        final q = textEditingValue.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return suggestions.where((s) => s.toLowerCase().contains(q));
      },
      onSelected: onSelected,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        final ctrl = controller ?? textEditingController;
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          decoration: const InputDecoration(
            hintText: 'Search for Recipes...',
            prefixIcon: Icon(Icons.search),
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
