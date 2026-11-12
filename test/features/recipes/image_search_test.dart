import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recipe_sharing_mobile/app/theme/app_theme.dart';
import 'package:recipe_sharing_mobile/core/network/api_client.dart';
import 'package:recipe_sharing_mobile/core/network/api_exception.dart';
import 'package:recipe_sharing_mobile/features/recipes/data/recipe_repository.dart';
import 'package:recipe_sharing_mobile/features/recipes/domain/image_scan_result.dart';
import 'package:recipe_sharing_mobile/features/recipes/domain/recipe_filter.dart';
import 'package:recipe_sharing_mobile/features/recipes/domain/recipe_page.dart';
import 'package:recipe_sharing_mobile/features/recipes/presentation/explore_screen.dart';
import 'package:recipe_sharing_mobile/features/recipes/presentation/image_search_screen.dart';
import 'package:recipe_sharing_mobile/features/recipes/presentation/recipe_providers.dart';

class _DelayedScanRepository extends RecipeRepository {
  _DelayedScanRepository() : super(ApiClient(dio: Dio()));

  final result = Completer<ImageScanResult>();
  int calls = 0;
  final searches = <String>[];

  @override
  Future<ImageScanResult> scanDishImage({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) {
    calls++;
    return result.future;
  }

  @override
  Future<RecipePage> getRecipes({
    RecipeFilter filter = const RecipeFilter(),
    int page = 1,
    int limit = 12,
  }) async {
    searches.add(filter.search);
    return RecipePage(recipes: const [], total: 0, page: page, limit: limit);
  }
}

class _QuotaScanRepository extends RecipeRepository {
  _QuotaScanRepository() : super(ApiClient(dio: Dio()));

  @override
  Future<ImageScanResult> scanDishImage({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    calls++;
    throw const ApiException(
      ApiErrorKind.server,
      'Bạn đã dùng hết lượt quét.',
      statusCode: 429,
      code: 'AI_SCAN_LIMIT',
      retryAfterSeconds: 125,
    );
  }

  int calls = 0;
}

void main() {
  test('parses a valid Gemini scan response', () {
    final result = ImageScanResult.fromJson(const {
      'success': true,
      'keyword': '  Cơm tấm  ',
    });

    expect(result.keyword, 'Cơm tấm');
  });

  test('rejects an invalid Gemini scan response', () {
    expect(
      () => ImageScanResult.fromJson(const {'success': true, 'keyword': ''}),
      throwsA(isA<Exception>()),
    );
  });

  test('rejects an image larger than 5MB before upload', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(imageScanProvider.notifier)
        .selectImage(
          bytes: Uint8List(RecipeRepository.maxScanImageBytes + 1),
          filename: 'too-large.jpg',
          mimeType: 'image/jpeg',
        );

    expect(container.read(imageScanProvider).hasImage, isFalse);
    expect(container.read(imageScanProvider).error, contains('5MB'));
  });

  testWidgets('selecting an image scans immediately and opens Explore query', (
    tester,
  ) async {
    final image = XFile.fromData(
      Uint8List.fromList(const [0, 1, 2, 3]),
      name: 'pho.jpg',
      mimeType: 'image/jpeg',
    );
    final repository = _DelayedScanRepository();
    final router = GoRouter(
      initialLocation: '/image-search',
      routes: [
        GoRoute(
          path: '/image-search',
          builder: (_, _) => ImageSearchScreen(
            pickImage: (_) async => image,
            loadRecentImages: () async => const [],
            enableLiveCamera: false,
          ),
        ),
        GoRoute(
          path: '/explore',
          builder: (_, state) => ExploreScreen(
            initialQuery: state.uri.queryParameters['search'] ?? '',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [recipeRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-gallery')));
    await tester.pump();
    expect(find.byKey(const Key('image-preview')), findsOneWidget);
    expect(find.textContaining('Gemini đang nhận diện'), findsOneWidget);
    expect(repository.calls, 1);
    expect(find.byKey(const Key('scan-image')), findsNothing);
    expect(find.byKey(const Key('scan-result')), findsNothing);

    repository.result.complete(const ImageScanResult(keyword: 'Phở bò'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('explore-search')), findsOneWidget);
    expect(repository.searches, contains('Phở bò'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects an unsupported selected image before upload', (
    tester,
  ) async {
    final image = XFile.fromData(
      Uint8List.fromList(const [0, 1, 2]),
      name: 'dish.gif',
      mimeType: 'image/gif',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: ImageSearchScreen(
            pickImage: (_) async => image,
            loadRecentImages: () async => const [],
            enableLiveCamera: false,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-gallery')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chỉ chấp nhận ảnh'), findsOneWidget);
    expect(find.byKey(const Key('scan-image')), findsNothing);
  });

  testWidgets('camera-first layout exposes capture and recent gallery', (
    tester,
  ) async {
    final thumbnail = Uint8List.fromList(const [1, 2, 3]);
    final image = XFile.fromData(
      Uint8List.fromList(const [0, 1, 2, 3]),
      name: 'recent.jpg',
      mimeType: 'image/jpeg',
    );

    final repository = _QuotaScanRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [recipeRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: ImageSearchScreen(
            enableLiveCamera: false,
            pickImage: (_) async => image,
            loadRecentImages: () async => [
              RecentScanImage(
                id: 'recent-1',
                thumbnail: thumbnail,
                loadFile: () async => image,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('capture-image')), findsOneWidget);
    expect(find.byKey(const Key('close-image-search')), findsOneWidget);
    expect(find.text('Tìm trong thư viện'), findsOneWidget);
    expect(find.byKey(const Key('recent-image-list')), findsOneWidget);

    await tester.tap(find.byKey(const Key('recent-image-recent-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('image-preview')), findsOneWidget);
    expect(find.textContaining('hết lượt quét'), findsOneWidget);
    expect(find.byKey(const Key('scan-image')), findsNothing);
    expect(find.byKey(const Key('capture-image')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quota error keeps preview and offers a timed retry', (
    tester,
  ) async {
    final image = XFile.fromData(
      Uint8List.fromList(const [0, 1, 2, 3]),
      name: 'dish.jpg',
      mimeType: 'image/jpeg',
    );
    final repository = _QuotaScanRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [recipeRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: ImageSearchScreen(
            pickImage: (_) async => image,
            loadRecentImages: () async => const [],
            enableLiveCamera: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-gallery')));
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(find.byKey(const Key('image-preview')), findsOneWidget);
    expect(find.textContaining('hết lượt quét'), findsOneWidget);
    expect(find.textContaining('3 phút'), findsOneWidget);
    expect(find.byKey(const Key('retry-image-scan')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('retry-image-scan')));
    await tester.tap(find.byKey(const Key('retry-image-scan')));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.textContaining('hết lượt quét'), findsOneWidget);
  });
}
