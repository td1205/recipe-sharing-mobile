import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_sharing_mobile/core/network/api_client.dart';
import 'package:recipe_sharing_mobile/features/recipes/application/cooking_sync_controller.dart';
import 'package:recipe_sharing_mobile/features/recipes/data/recipe_repository.dart';

void main() {
  test('parses valid cooking progress and rejects invalid ordering', () {
    final progress = CookingProgress.tryParse(const {
      'recipeId': 12,
      'completedSteps': 2,
      'currentStep': 3,
      'totalSteps': 5,
    });
    final invalid = CookingProgress.tryParse(const {
      'recipeId': 12,
      'completedSteps': 2,
      'currentStep': 4,
      'totalSteps': 5,
    });

    expect(progress?.currentStep, 3);
    expect(invalid, isNull);
  });

  test('uses verified report and community-tag contracts', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: options.path == '/api/reports' ? 201 : 200,
              data: options.path.endsWith('/tags')
                  ? const {'success': true, 'isAdded': true}
                  : const {
                      'success': true,
                      'report': {'id': 1, 'status': 'Pending'},
                    },
            ),
          );
        },
      ),
    );
    final repository = RecipeRepository(ApiClient(dio: dio));

    expect(await repository.voteTag(9, 'dễ làm'), isTrue);
    await repository.createReport(
      targetType: 'recipe',
      targetId: 9,
      reason: 'Nội dung không phù hợp',
    );

    expect(requests[0].path, '/api/recipes/9/tags');
    expect(requests[0].data, {'tagName': 'dễ làm'});
    expect(requests[1].path, '/api/reports');
    expect(requests[1].data, {
      'target_type': 'recipe',
      'target_id': 9,
      'reason': 'Nội dung không phù hợp',
    });
  });
}
