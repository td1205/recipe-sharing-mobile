import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_sharing_mobile/core/network/api_exception.dart';
import 'package:recipe_sharing_mobile/features/recipes/domain/recipe.dart';
import 'package:recipe_sharing_mobile/features/recipes/domain/recipe_page.dart';
import 'package:recipe_sharing_mobile/features/recipes/domain/recipe_detail.dart';

void main() {
  test('parses the real backend recipe fields', () {
    final recipe = Recipe.fromJson({
      'id': 12,
      'title': 'Phở bò',
      'image_url': 'https://example.com/pho.jpg',
      'prep_time': 20,
      'cook_time': 90,
      'servings': 4,
      'category_id': 3,
      'author_name': 'An',
      'category_name': 'Món nước',
      'avg_rating': '4.5',
      'total_ratings': 8,
      'view_count': 100,
    });
    expect(recipe.id, 12);
    expect(recipe.averageRating, 4.5);
    expect(recipe.cookTime, 90);
    expect(recipe.servings, 4);
    expect(recipe.categoryId, 3);
  });

  test('parses detail response with ingredients and steps', () {
    final detail = RecipeDetail.fromJson({
      'recipe': {'id': 1, 'title': 'Cơm rang', 'servings': 2},
      'ingredients': [
        {'name': 'Cơm nguội', 'amount': '2', 'unit': 'bát'},
      ],
      'steps': [
        {'step_number': 1, 'instruction': 'Làm nóng chảo.'},
      ],
    });
    expect(detail.recipe.servings, 2);
    expect(detail.ingredients.single.quantity, '2 bát');
    expect(detail.steps.single.number, 1);
  });

  test('parses paginated response envelope', () {
    final page = RecipePage.fromJson({
      'success': true,
      'total': 1,
      'page': 1,
      'limit': 20,
      'recipes': [
        {'id': 1, 'title': 'Cơm rang'},
      ],
    });
    expect(page.recipes.single.title, 'Cơm rang');
    expect(page.total, 1);
  });

  test('rejects malformed recipe data', () {
    expect(
      () => Recipe.fromJson({'id': 1}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.invalidResponse,
        ),
      ),
    );
  });
}
