import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_error_banner.dart';
import '../../../core/network/api_exception.dart';
import '../data/recipe_repository.dart';
import 'recipe_providers.dart';

typedef PickScanImage = Future<XFile?> Function(ImageSource source);
typedef LoadRecentScanImages = Future<List<RecentScanImage>> Function();

class RecentScanImage {
  const RecentScanImage({
    required this.id,
    required this.thumbnail,
    required this.loadFile,
  });

  final String id;
  final Uint8List thumbnail;
  final Future<XFile?> Function() loadFile;
}

class ImageScanState {
  const ImageScanState({
    this.bytes,
    this.filename,
    this.mimeType,
    this.keyword,
    this.error,
    this.retryAfterSeconds,
    this.isScanning = false,
  });

  final Uint8List? bytes;
  final String? filename;
  final String? mimeType;
  final String? keyword;
  final String? error;
  final int? retryAfterSeconds;
  final bool isScanning;

  bool get hasImage => bytes != null;
}

class ImageScanController extends Notifier<ImageScanState> {
  @override
  ImageScanState build() => const ImageScanState();

  void selectImage({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) {
    if (bytes.isEmpty) {
      state = const ImageScanState(error: 'Ảnh đã chọn không có dữ liệu.');
      return;
    }
    if (bytes.length > RecipeRepository.maxScanImageBytes) {
      state = const ImageScanState(error: 'Ảnh tối đa 5MB.');
      return;
    }
    if (!RecipeRepository.scanImageMimeTypes.contains(mimeType)) {
      state = const ImageScanState(
        error: 'Chỉ chấp nhận ảnh JPG, PNG, WEBP hoặc HEIC.',
      );
      return;
    }
    state = ImageScanState(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );
  }

  void setSelectionError(String message) {
    state = ImageScanState(error: message);
  }

  void clear() => state = const ImageScanState();

  Future<String?> scan() async {
    if (!state.hasImage || state.isScanning) return null;
    final selected = state;
    state = ImageScanState(
      bytes: selected.bytes,
      filename: selected.filename,
      mimeType: selected.mimeType,
      isScanning: true,
    );
    try {
      final result = await ref
          .read(recipeRepositoryProvider)
          .scanDishImage(
            bytes: selected.bytes!,
            filename: selected.filename!,
            mimeType: selected.mimeType!,
          );
      state = ImageScanState(
        bytes: selected.bytes,
        filename: selected.filename,
        mimeType: selected.mimeType,
        keyword: result.keyword,
      );
      return result.keyword;
    } on ApiException catch (error) {
      state = ImageScanState(
        bytes: selected.bytes,
        filename: selected.filename,
        mimeType: selected.mimeType,
        error: error.message,
        retryAfterSeconds: error.retryAfterSeconds,
      );
      return null;
    } catch (_) {
      state = ImageScanState(
        bytes: selected.bytes,
        filename: selected.filename,
        mimeType: selected.mimeType,
        error: 'Không thể nhận diện ảnh lúc này. Vui lòng thử lại.',
      );
      return null;
    }
  }
}

final imageScanProvider =
    NotifierProvider.autoDispose<ImageScanController, ImageScanState>(
      ImageScanController.new,
    );

class ImageSearchScreen extends ConsumerStatefulWidget {
  const ImageSearchScreen({
    super.key,
    this.pickImage,
    this.loadRecentImages,
    this.enableLiveCamera = true,
  });

  final PickScanImage? pickImage;
  final LoadRecentScanImages? loadRecentImages;
  final bool enableLiveCamera;

  @override
  ConsumerState<ImageSearchScreen> createState() => _ImageSearchScreenState();
}

class _ImageSearchScreenState extends ConsumerState<ImageSearchScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  List<RecentScanImage> _recentImages = const [];
  bool _cameraInitializing = false;
  bool _capturing = false;
  bool _loadingRecent = true;
  String? _cameraError;
  String? _galleryMessage;
  bool _cameraPermissionPermanentlyDenied = false;
  bool _processingSelection = false;
  bool _hasNavigated = false;
  FlashMode _flashMode = FlashMode.off;
  int _cameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadRecentImages());
    if (widget.enableLiveCamera) unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enableLiveCamera) return;
    if (state == AppLifecycleState.inactive) {
      unawaited(_disposeCamera());
    } else if (state == AppLifecycleState.resumed &&
        _cameraController == null) {
      unawaited(_initializeCamera(preferredIndex: _cameraIndex));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeCamera());
    super.dispose();
  }

  Future<void> _initializeCamera({int preferredIndex = 0}) async {
    if (_cameraInitializing) return;
    setState(() {
      _cameraInitializing = true;
      _cameraError = null;
      _cameraPermissionPermanentlyDenied = false;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'Không tìm thấy camera.');
      }
      final index = preferredIndex.clamp(0, cameras.length - 1);
      final controller = CameraController(
        cameras[index],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final oldController = _cameraController;
      setState(() {
        _cameras = cameras;
        _cameraIndex = index;
        _cameraController = controller;
        _cameraInitializing = false;
      });
      await oldController?.dispose();
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraInitializing = false;
        _cameraPermissionPermanentlyDenied =
            error.code == 'CameraAccessDeniedWithoutPrompt';
        _cameraError = switch (error.code) {
          'CameraAccessDenied' => 'Cần quyền camera để chụp món ăn.',
          'CameraAccessDeniedWithoutPrompt' =>
            'Quyền camera đã bị tắt. Hãy bật lại trong cài đặt ứng dụng.',
          'CameraAccessRestricted' => 'Cần quyền camera để chụp món ăn.',
          _ => 'Không thể mở camera. Bạn vẫn có thể chọn ảnh từ thư viện.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraInitializing = false;
        _cameraError =
            'Không thể mở camera. Bạn vẫn có thể chọn ảnh từ thư viện.';
      });
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    await controller?.dispose();
  }

  Future<void> _loadRecentImages() async {
    try {
      final images =
          await (widget.loadRecentImages?.call() ?? _loadDeviceRecentImages());
      if (!mounted) return;
      setState(() {
        _recentImages = images;
        _loadingRecent = false;
        _galleryMessage = images.isEmpty
            ? 'Chưa có ảnh gần đây. Chọn “Xem tất cả” để mở thư viện.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingRecent = false;
        _galleryMessage =
            'Không thể đọc ảnh gần đây. Bạn vẫn có thể mở thư viện.';
      });
    }
  }

  Future<List<RecentScanImage>> _loadDeviceRecentImages() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) return const [];
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (albums.isEmpty) return const [];
    final assets = await albums.first.getAssetListPaged(page: 0, size: 6);
    final images = <RecentScanImage>[];
    for (final asset in assets) {
      final thumbnail = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(240),
        quality: 82,
      );
      if (thumbnail == null) continue;
      images.add(
        RecentScanImage(
          id: asset.id,
          thumbnail: thumbnail,
          loadFile: () async {
            final file = await asset.file;
            if (file == null) return null;
            return XFile(
              file.path,
              name: asset.title ?? file.uri.pathSegments.last,
              mimeType: _mimeTypeFromName(
                asset.title ?? file.uri.pathSegments.last,
              ),
            );
          },
        ),
      );
    }
    return images;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageScanProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.darkSurface,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final cameraHeight = (constraints.maxHeight * 0.61).clamp(
              410.0,
              570.0,
            );
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: cameraHeight,
                  child: _buildVisualPreview(state),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: cameraHeight - 30,
                  bottom: 0,
                  child: _BottomLibraryPanel(
                    state: state,
                    recentImages: _recentImages,
                    loadingRecent: _loadingRecent,
                    galleryMessage: _galleryMessage,
                    onPickGallery: () => _pick(ImageSource.gallery),
                    onRecentSelected: _selectRecentImage,
                    onRetry: _scanSelectedImage,
                    onClear: () => ref.read(imageScanProvider.notifier).clear(),
                  ),
                ),
                if (!state.hasImage)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: cameraHeight - 45,
                    child: Center(
                      child: _CaptureButton(
                        busy: _capturing || state.isScanning,
                        onPressed: _capturing || state.isScanning
                            ? null
                            : _capture,
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: _CameraToolbar(
                      flashMode: _flashMode,
                      canUseCamera:
                          _cameraController?.value.isInitialized == true,
                      canSwitchCamera: _cameras.length > 1,
                      showingSelection: state.hasImage,
                      onClose: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/explore');
                        }
                      },
                      onToggleFlash: _toggleFlash,
                      onSwitchCamera: _switchCamera,
                      onClearSelection: () =>
                          ref.read(imageScanProvider.notifier).clear(),
                    ),
                  ),
                ),
                if (!state.hasImage)
                  Positioned(
                    left: 32,
                    right: 32,
                    top: cameraHeight - 145,
                    child: const _CameraHint(),
                  ),
                if (state.isScanning)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: cameraHeight,
                    child: const _ScanningOverlay(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVisualPreview(ImageScanState state) {
    if (state.bytes != null) {
      return Image.memory(
        state.bytes!,
        key: const Key('image-preview'),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const _CameraUnavailable(message: 'Không thể hiển thị ảnh này.'),
      );
    }
    final controller = _cameraController;
    if (controller?.value.isInitialized == true) {
      return ColoredBox(
        color: Colors.black,
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller!.value.previewSize?.height ?? 720,
              height: controller.value.previewSize?.width ?? 1280,
              child: CameraPreview(controller),
            ),
          ),
        ),
      );
    }
    if (_cameraError != null) {
      return _CameraUnavailable(
        message: _cameraError!,
        actionLabel: _cameraPermissionPermanentlyDenied
            ? 'Mở cài đặt'
            : 'Thử lại',
        onAction: _cameraPermissionPermanentlyDenied
            ? _openAppSettings
            : _initializeCamera,
      );
    }
    if (!widget.enableLiveCamera) {
      return const _CameraUnavailable(
        message: 'Camera preview không hoạt động trong môi trường kiểm thử.',
      );
    }
    return const ColoredBox(
      color: AppColors.darkSurface,
      child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
    );
  }

  Future<void> _capture() async {
    if (_processingSelection || ref.read(imageScanProvider).isScanning) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      await _pick(ImageSource.camera);
      return;
    }
    if (controller.value.isTakingPicture) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      await _selectFile(file);
    } on CameraException {
      ref
          .read(imageScanProvider.notifier)
          .setSelectionError('Không thể chụp ảnh. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _openAppSettings() async {
    await PhotoManager.openSetting();
    if (mounted) await _initializeCamera(preferredIndex: _cameraIndex);
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    final next = _flashMode == FlashMode.off ? FlashMode.auto : FlashMode.off;
    try {
      await controller.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } on CameraException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera này không hỗ trợ chế độ flash.')),
      );
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _cameraInitializing) return;
    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    await _disposeCamera();
    if (mounted) {
      ref.read(imageScanProvider.notifier).clear();
      await _initializeCamera(preferredIndex: nextIndex);
    }
  }

  Future<void> _selectRecentImage(RecentScanImage image) async {
    if (_processingSelection || ref.read(imageScanProvider).isScanning) return;
    try {
      final file = await image.loadFile();
      if (file == null) {
        throw const FileSystemException('Asset unavailable');
      }
      await _selectFile(file);
    } catch (_) {
      ref
          .read(imageScanProvider.notifier)
          .setSelectionError('Không thể đọc ảnh. Vui lòng chọn ảnh khác.');
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_processingSelection || ref.read(imageScanProvider).isScanning) return;
    try {
      final file =
          await (widget.pickImage?.call(source) ??
              ImagePicker().pickImage(
                source: source,
                maxWidth: 1280,
                maxHeight: 1280,
                imageQuality: 85,
                requestFullMetadata: false,
              ));
      if (file == null) return;
      await _selectFile(file);
    } catch (_) {
      ref
          .read(imageScanProvider.notifier)
          .setSelectionError('Không thể đọc ảnh. Vui lòng chọn ảnh khác.');
    }
  }

  Future<void> _selectFile(XFile file) async {
    if (_processingSelection || ref.read(imageScanProvider).isScanning) return;
    _processingSelection = true;
    try {
      final bytes = await file.readAsBytes();
      final mimeType = file.mimeType ?? _mimeTypeFromName(file.name);
      if (mimeType == null) {
        ref
            .read(imageScanProvider.notifier)
            .setSelectionError('Không xác định được định dạng ảnh đã chọn.');
        return;
      }
      ref
          .read(imageScanProvider.notifier)
          .selectImage(bytes: bytes, filename: file.name, mimeType: mimeType);
      if (!ref.read(imageScanProvider).hasImage) return;
      await _scanSelectedImage();
    } finally {
      _processingSelection = false;
    }
  }

  Future<void> _scanSelectedImage() async {
    if (_hasNavigated || ref.read(imageScanProvider).isScanning) return;
    final keyword = await ref.read(imageScanProvider.notifier).scan();
    if (!mounted ||
        keyword == null ||
        keyword.trim().isEmpty ||
        _hasNavigated) {
      return;
    }
    _hasNavigated = true;
    await _disposeCamera();
    if (!mounted) return;
    context.go(
      Uri(
        path: '/explore',
        queryParameters: {'search': keyword.trim()},
      ).toString(),
    );
  }
}

class _CameraToolbar extends StatelessWidget {
  const _CameraToolbar({
    required this.flashMode,
    required this.canUseCamera,
    required this.canSwitchCamera,
    required this.showingSelection,
    required this.onClose,
    required this.onToggleFlash,
    required this.onSwitchCamera,
    required this.onClearSelection,
  });

  final FlashMode flashMode;
  final bool canUseCamera;
  final bool canSwitchCamera;
  final bool showingSelection;
  final VoidCallback onClose;
  final VoidCallback onToggleFlash;
  final VoidCallback onSwitchCamera;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _DarkIconButton(
        key: const Key('close-image-search'),
        tooltip: 'Đóng',
        icon: Icons.close_rounded,
        onPressed: onClose,
      ),
      const Spacer(),
      if (showingSelection)
        _DarkIconButton(
          tooltip: 'Bỏ ảnh đã chọn',
          icon: Icons.refresh_rounded,
          onPressed: onClearSelection,
        )
      else ...[
        _DarkIconButton(
          key: const Key('toggle-flash'),
          tooltip: flashMode == FlashMode.off
              ? 'Bật flash tự động'
              : 'Tắt flash',
          icon: flashMode == FlashMode.off
              ? Icons.flash_off_rounded
              : Icons.flash_auto_rounded,
          onPressed: canUseCamera ? onToggleFlash : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        _DarkIconButton(
          key: const Key('switch-camera'),
          tooltip: 'Đổi camera',
          icon: Icons.cameraswitch_rounded,
          onPressed: canSwitchCamera ? onSwitchCamera : null,
        ),
      ],
    ],
  );
}

class _DarkIconButton extends StatelessWidget {
  const _DarkIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size.square(48),
      backgroundColor: const Color(0xaa15180f),
      foregroundColor: AppColors.white,
      disabledBackgroundColor: const Color(0x6615180f),
      disabledForegroundColor: const Color(0x99ffffff),
    ),
    icon: Icon(icon),
  );
}

class _CameraHint extends StatelessWidget {
  const _CameraHint();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xb315180f),
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Text(
        'Đặt một món ăn rõ nét trong khung hình',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Chụp ảnh món ăn',
    child: Material(
      key: const Key('capture-image'),
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 6,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 88,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 66,
              height: 66,
              decoration: const BoxDecoration(
                color: AppColors.limeStrong,
                shape: BoxShape.circle,
              ),
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(21),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.olive,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.olive,
                      size: 30,
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BottomLibraryPanel extends StatelessWidget {
  const _BottomLibraryPanel({
    required this.state,
    required this.recentImages,
    required this.loadingRecent,
    required this.galleryMessage,
    required this.onPickGallery,
    required this.onRecentSelected,
    required this.onRetry,
    required this.onClear,
  });

  final ImageScanState state;
  final List<RecentScanImage> recentImages;
  final bool loadingRecent;
  final String? galleryMessage;
  final VoidCallback onPickGallery;
  final ValueChanged<RecentScanImage> onRecentSelected;
  final VoidCallback onRetry;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const Key('image-search-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 64, 20, 24),
        child: state.hasImage
            ? _SelectedImageActions(
                state: state,
                onPickGallery: onPickGallery,
                onRetry: onRetry,
                onClear: onClear,
              )
            : _RecentGallery(
                images: recentImages,
                loading: loadingRecent,
                message: galleryMessage,
                error: state.error,
                onPickGallery: onPickGallery,
                onSelected: onRecentSelected,
              ),
      ),
    ),
  );
}

class _RecentGallery extends StatelessWidget {
  const _RecentGallery({
    required this.images,
    required this.loading,
    required this.message,
    required this.error,
    required this.onPickGallery,
    required this.onSelected,
  });

  final List<RecentScanImage> images;
  final bool loading;
  final String? message;
  final String? error;
  final VoidCallback onPickGallery;
  final ValueChanged<RecentScanImage> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Tìm trong thư viện',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton.icon(
            key: const Key('pick-gallery'),
            onPressed: onPickGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Xem tất cả'),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.smMd),
      if (loading)
        const SizedBox(
          height: 96,
          child: Center(child: CircularProgressIndicator()),
        )
      else if (images.isNotEmpty)
        SizedBox(
          height: 96,
          child: ListView.separated(
            key: const Key('recent-image-list'),
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final image = images[index];
              return Semantics(
                button: true,
                label: 'Chọn ảnh gần đây ${index + 1}',
                child: InkWell(
                  key: Key('recent-image-${image.id}'),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  onTap: () => onSelected(image),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    child: Image.memory(
                      image.thumbnail,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.square(
                        dimension: 96,
                        child: ColoredBox(
                          color: AppColors.limeSurface,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.oliveSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        )
      else if (message != null)
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.limeSurface,
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Text(message!, style: Theme.of(context).textTheme.bodyMedium),
        ),
      if (error != null) ...[
        const SizedBox(height: AppSpacing.md),
        _ScanError(message: error!),
      ],
      const SizedBox(height: AppSpacing.md),
      Text(
        'Ảnh JPG, PNG, WEBP hoặc HEIC · tối đa 5MB',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.inkMuted),
      ),
    ],
  );
}

class _SelectedImageActions extends StatelessWidget {
  const _SelectedImageActions({
    required this.state,
    required this.onPickGallery,
    required this.onRetry,
    required this.onClear,
  });

  final ImageScanState state;
  final VoidCallback onPickGallery;
  final VoidCallback onRetry;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              state.isScanning ? 'Đang nhận diện món ăn' : 'Không thể quét ảnh',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton(
            key: const Key('pick-gallery'),
            onPressed: state.isScanning ? null : onPickGallery,
            child: const Text('Đổi ảnh'),
          ),
        ],
      ),
      if (state.isScanning)
        Text(
          'Gemini đang phân tích ảnh. Kết quả tìm kiếm sẽ tự động mở.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      if (state.error != null) ...[
        const SizedBox(height: AppSpacing.md),
        _ScanError(
          message: state.error!,
          retryAfterSeconds: state.retryAfterSeconds,
        ),
      ],
      if (state.error != null) ...[
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const Key('retry-image-scan'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Thử quét lại'),
        ),
      ],
      if (!state.isScanning) ...[
        const SizedBox(height: AppSpacing.xs),
        TextButton(onPressed: onClear, child: const Text('Chụp lại')),
      ],
      Text(
        'Giới hạn 5 lượt quét trong 10 phút cho mỗi kết nối.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.inkMuted),
      ),
    ],
  );
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.darkSurface,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: AppColors.lime,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.smMd),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.white),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: AppSpacing.smMd),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ScanningOverlay extends StatelessWidget {
  const _ScanningOverlay();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0x9915180f),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.lime),
          SizedBox(height: AppSpacing.md),
          Text(
            'Gemini đang nhận diện món ăn…',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScanError extends StatelessWidget {
  const _ScanError({required this.message, this.retryAfterSeconds});

  final String message;
  final int? retryAfterSeconds;

  @override
  Widget build(BuildContext context) => AppErrorBanner(
    message: retryAfterSeconds == null
        ? message
        : '$message\nCó thể thử lại sau khoảng ${_formatDelay(retryAfterSeconds!)}.',
  );

  String _formatDelay(int seconds) {
    final minutes = (seconds / 60).ceil().clamp(1, 9999);
    return '$minutes phút';
  }
}

String? _mimeTypeFromName(String name) {
  final extension = name.toLowerCase().split('.').last;
  return const {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif',
  }[extension];
}
