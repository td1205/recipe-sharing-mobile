import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/api_config.dart';
import '../../../core/providers.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_providers.dart';
import '../presentation/recipe_providers.dart';

class CookingProgress {
  const CookingProgress({
    required this.recipeId,
    required this.completedSteps,
    required this.currentStep,
    required this.totalSteps,
  });
  final int recipeId;
  final int completedSteps;
  final int? currentStep;
  final int totalSteps;

  static CookingProgress? tryParse(Object? payload) {
    if (payload is! Map) return null;
    int? asInt(Object? value) => value is int ? value : int.tryParse('$value');
    final recipeId = asInt(payload['recipeId']);
    final completedSteps = asInt(payload['completedSteps']);
    final totalSteps = asInt(payload['totalSteps']);
    final currentStep = payload['currentStep'] == null
        ? null
        : asInt(payload['currentStep']);
    if (recipeId == null ||
        recipeId <= 0 ||
        completedSteps == null ||
        totalSteps == null ||
        totalSteps <= 0 ||
        completedSteps < 0 ||
        completedSteps > totalSteps ||
        currentStep !=
            (completedSteps < totalSteps ? completedSteps + 1 : null)) {
      return null;
    }
    return CookingProgress(
      recipeId: recipeId,
      completedSteps: completedSteps,
      currentStep: currentStep,
      totalSteps: totalSteps,
    );
  }
}

class CookingSyncErrorController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final cookingSyncErrorProvider =
    NotifierProvider<CookingSyncErrorController, String?>(
      CookingSyncErrorController.new,
    );

class CookingProgressController extends Notifier<Map<int, CookingProgress>> {
  @override
  Map<int, CookingProgress> build() => const {};
  void set(CookingProgress progress) =>
      state = {...state, progress.recipeId: progress};
}

final cookingProgressProvider =
    NotifierProvider<CookingProgressController, Map<int, CookingProgress>>(
      CookingProgressController.new,
    );

/// Keeps a single authenticated device connection while the user is signed in.
class CookingSyncController extends Notifier<int?> {
  io.Socket? _socket;
  int? _connectedUserId;
  final _pendingProgressRequests = <int>{};

  @override
  int? build() {
    ref.onDispose(_disconnect);
    ref.listen<AsyncValue<AuthUser?>>(authStateProvider, (_, next) {
      _syncAuth(next);
    });
    _syncAuth(ref.read(authStateProvider));
    return null;
  }

  void _syncAuth(AsyncValue<AuthUser?> auth) {
    final user = auth.asData?.value;
    if (user == null) {
      _connectedUserId = null;
      _disconnect();
      return;
    }
    final userId = user.id;
    if (_connectedUserId == userId) return;
    _connectedUserId = userId;
    _connect();
  }

  Future<void> _connect() async {
    final token = await ref.read(tokenStoreProvider).readAccessToken();
    if (token == null || token.isEmpty || _connectedUserId == null) return;
    _disconnect();
    final socket = io.io(
      ApiConfig.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(3)
          .setAuth({'token': token, 'clientType': 'mobile'})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );
    _socket = socket;
    socket.onConnect((_) {
      ref.read(cookingSyncErrorProvider.notifier).set(null);
      for (final recipeId in _pendingProgressRequests.toList()) {
        _requestProgressNow(recipeId);
      }
      debugPrint('Cooking sync connected to ${ApiConfig.baseUrl}');
    });
    socket.onConnectError((_) {
      ref
          .read(cookingSyncErrorProvider.notifier)
          .set('Không thể kết nối đồng bộ Cooking Mode.');
    });
    socket.onDisconnect((_) {});
    socket.on('cooking:open', (payload) {
      final rawId = payload is Map ? payload['recipeId'] : null;
      final recipeId = rawId is int ? rawId : int.tryParse('$rawId');
      if (recipeId != null && recipeId > 0) state = recipeId;
    });
    socket.on('favorites:changed', (_) {
      ref.invalidate(ownProfileProvider);
    });
    socket.on('recipes:changed', (payload) {
      final data = payload is Map ? payload : const <dynamic, dynamic>{};
      final rawId = data['recipeId'];
      final recipeId = rawId is int ? rawId : int.tryParse('$rawId');
      ref.invalidate(ownProfileProvider);
      ref.invalidate(homeProvider);
      ref.invalidate(exploreProvider);
      if (recipeId != null && recipeId > 0) {
        ref.invalidate(recipeDetailProvider(recipeId));
      }
    });
    socket.on('shopping-list:changed', (payload) {
      final data = payload is Map ? payload : const <dynamic, dynamic>{};
      final recipeId = data['recipeId'] is int
          ? data['recipeId'] as int
          : int.tryParse('${data['recipeId']}');
      final ingredientId = data['ingredientId'] is int
          ? data['ingredientId'] as int
          : int.tryParse('${data['ingredientId']}');
      final checked = data['checked'];
      if (recipeId != null && ingredientId != null && checked is bool) {
        ref
            .read(shoppingListChangesProvider.notifier)
            .setItem(recipeId, ingredientId, checked);
      }
      final servings = data['servings'];
      if (recipeId != null && servings is int) {
        ref.read(shoppingServingsProvider.notifier).set(recipeId, servings);
      }
    });
    socket.on('cooking:progress', (payload) {
      final progress = CookingProgress.tryParse(payload);
      if (progress != null) {
        ref.read(cookingProgressProvider.notifier).set(progress);
      }
    });
    socket.connect();
  }

  void startCooking(int recipeId, int totalSteps) {
    if (totalSteps <= 0) return;
    final existing = ref.read(cookingProgressProvider)[recipeId];
    if (existing != null && existing.completedSteps < existing.totalSteps) {
      return;
    }
    _sendProgress(
      CookingProgress(
        recipeId: recipeId,
        completedSteps: 0,
        currentStep: 1,
        totalSteps: totalSteps,
      ),
    );
  }

  void loadProgress(int recipeId) {
    if (recipeId <= 0) return;
    _pendingProgressRequests.add(recipeId);
    if (_socket?.connected != true) return;
    _requestProgressNow(recipeId);
  }

  void _requestProgressNow(int recipeId) {
    _socket!.emitWithAck(
      'cooking:progress:get',
      {'recipeId': recipeId},
      ack: (response) {
        _pendingProgressRequests.remove(recipeId);
        if (response is! Map || response['success'] != true) {
          ref
              .read(cookingSyncErrorProvider.notifier)
              .set('Không tải được tiến độ nấu đã đồng bộ.');
          return;
        }
        final progress = CookingProgress.tryParse(response['progress']);
        if (progress != null) {
          ref.read(cookingProgressProvider.notifier).set(progress);
        }
      },
    );
  }

  void completeCurrentStep(int recipeId, int totalSteps) {
    if (totalSteps <= 0) return;
    final previous = ref.read(cookingProgressProvider)[recipeId];
    final completed = ((previous?.completedSteps ?? 0) + 1)
        .clamp(0, totalSteps)
        .toInt();
    _sendProgress(
      CookingProgress(
        recipeId: recipeId,
        completedSteps: completed,
        currentStep: completed < totalSteps ? completed + 1 : null,
        totalSteps: totalSteps,
      ),
    );
  }

  void _sendProgress(CookingProgress progress) {
    ref.read(cookingProgressProvider.notifier).set(progress);
    _socket?.emitWithAck(
      'cooking:progress',
      {
        'recipeId': progress.recipeId,
        'completedSteps': progress.completedSteps,
        'currentStep': progress.currentStep,
      },
      ack: (response) {
        if (response is Map && response['success'] != true) {
          ref
              .read(cookingSyncErrorProvider.notifier)
              .set(
                response['error'] is String
                    ? response['error'] as String
                    : 'Không thể đồng bộ tiến độ nấu.',
              );
          return;
        }
        final confirmed = CookingProgress.tryParse(
          response is Map ? response['progress'] : null,
        );
        if (confirmed != null) {
          ref.read(cookingProgressProvider.notifier).set(confirmed);
        }
      },
    );
  }

  void dismiss() => state = null;

  void _disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}

final cookingSyncProvider = NotifierProvider<CookingSyncController, int?>(
  CookingSyncController.new,
);
