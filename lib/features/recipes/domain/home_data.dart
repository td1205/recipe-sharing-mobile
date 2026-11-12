import 'category.dart';
import 'recipe.dart';

class HomeData {
  const HomeData({
    required this.featured,
    required this.latest,
    required this.categories,
  });

  final List<Recipe> featured;
  final List<Recipe> latest;
  final List<RecipeCategory> categories;
}
