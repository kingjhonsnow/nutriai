import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/widgets/custom_button.dart';
import 'package:nutri_ai/features/food_scanner/camera/scanner_camera.dart';
import 'package:nutri_ai/features/food_scanner/providers/food_scanner_provider.dart';
import 'package:nutri_ai/features/food_scanner/screens/food_recognition_results_screen.dart';

class FoodScannerScreen extends ConsumerStatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  ConsumerState<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends ConsumerState<FoodScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _scanLineController;
  late final ScannerCameraController _cameraController;
  final ImagePicker _picker = ImagePicker();
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _cameraController = createScannerCameraController(
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );

    // Automatically initialize the live camera stream
    _cameraController.initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanLineController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  /// Release the camera when the app goes to the background and restart it on
  /// return (otherwise the preview stays black on iPhone).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _cameraController.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && !_cameraController.isStreaming) {
      _cameraController.initialize();
    }
  }

  // ── Process captured image bytes ───────────────────────────────────────────
  Future<void> _processCapturedBytes(Uint8List bytes) async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      ref.read(foodScannerProvider.notifier).scanImageBytes(bytes);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FoodRecognitionResultsScreen(),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  // ── Snap photo directly from the embedded live camera stream ───────────────
  Future<void> _captureFromLiveCamera() async {
    if (_cameraController.isHttpsRequired) {
      await _takePhotoWithCameraApp();
      return;
    }

    if (!_cameraController.isStreaming) {
      // If camera is not yet streaming, try initializing
      await _cameraController.initialize();
      if (!_cameraController.isStreaming) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _cameraController.errorMessage ??
                  'Camera is not ready. Please check permissions.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // Capture frame from the live video feed
    final bytes = await _cameraController.captureFrame();
    if (bytes != null && bytes.isNotEmpty) {
      await _processCapturedBytes(bytes);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not capture a photo from the live camera.'),
          backgroundColor: AppColors.error,
          action: SnackBarAction(label: 'Use camera app', onPressed: _takePhotoWithCameraApp),
        ),
      );
    }
  }

  // ── Pick from Gallery (separate independent flow) ─────────────────────────
  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        await _processCapturedBytes(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gallery error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Fallback: opens the phone's own camera app (works everywhere, also when
  /// the live preview is not available). Same analysis pipeline as gallery.
  Future<void> _takePhotoWithCameraApp() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        await _processCapturedBytes(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Layer 1: Live Camera Stream or Fallback / Guidance Viewport ──
          Positioned.fill(
            child: _buildCameraViewport(),
          ),

          // ── Layer 2: Scanning Reticle & Laser Line ───────────────────────
          Center(
            child: Container(
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.6),
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  // Animated green laser scanner line
                  AnimatedBuilder(
                    animation: _scanLineController,
                    builder: (context, child) {
                      return Positioned(
                        top: _scanLineController.value * 270,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.primary,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Reticle Corner Accents
                  _buildCornerAccent(Alignment.topLeft),
                  _buildCornerAccent(Alignment.topRight),
                  _buildCornerAccent(Alignment.bottomLeft),
                  _buildCornerAccent(Alignment.bottomRight),
                ],
              ),
            ),
          ),

          // ── Layer 3: Top Navigation Controls (Close, Switch, Flash) ──────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.5),
                    ),
                  ),
                  Row(
                    children: [
                      // Camera flip (front/back)
                      IconButton(
                        onPressed: () => _cameraController.switchCamera(),
                        icon: const Icon(Icons.flip_camera_ios_rounded,
                            color: Colors.white, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Flash/Torch toggle
                      IconButton(
                        onPressed: () => _cameraController.toggleFlash(),
                        icon: Icon(
                          _cameraController.isFlashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: _cameraController.isFlashOn
                              ? Colors.amber
                              : Colors.white,
                          size: 24,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Layer 4: Bottom Shutter Controls ─────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _cameraController.isStreaming
                                ? AppColors.success
                                : Colors.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _cameraController.isStreaming
                              ? 'LIVE CAMERA ACTIVE'
                              : 'AI FOOD SCANNER',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Pick from gallery button (independent)
                      IconButton(
                        tooltip: 'Select from Photo Gallery',
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined,
                            color: Colors.white, size: 28),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.15),
                          padding: const EdgeInsets.all(14),
                        ),
                      ),

                      // Central Shutter Button (captures live frame)
                      GestureDetector(
                        onTap: _captureFromLiveCamera,
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 66,
                              height: 66,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.primaryGradient,
                              ),
                              child: _isCapturing
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                            ),
                          ),
                        ),
                      ),

                      // Manual Food Search shortcut
                      IconButton(
                        tooltip: 'Search Food Database',
                        onPressed: () {
                          context.pop();
                          context.push('/food-search');
                        },
                        icon: const Icon(Icons.search_rounded,
                            color: Colors.white, size: 28),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.15),
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Live Camera Viewport Widget ───────────────────────────────────────────
  Widget _buildCameraViewport() {
    if (_cameraController.isStreaming) {
      return _cameraController.buildPreview();
    }

    if (_cameraController.isHttpsRequired) {
      return Container(
        color: const Color(0xFF0F141C),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 70, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Live camera not available here',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The live camera preview needs a secure https address.\n\n'
              'You can still take a photo with the camera app or choose one from your gallery.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Take photo with camera',
              icon: Icons.photo_camera_rounded,
              width: 260,
              onPressed: _takePhotoWithCameraApp,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined, color: Colors.white70),
              label: const Text(
                'Or choose photo from gallery',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    if (_cameraController.errorMessage != null) {
      return Container(
        color: const Color(0xFF0F141C),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_rounded,
                size: 70, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Camera Access Blocked',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _cameraController.errorMessage!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Retry Camera',
              icon: Icons.refresh_rounded,
              width: 220,
              onPressed: () => _cameraController.initialize(),
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Use camera app instead',
              icon: Icons.photo_camera_rounded,
              width: 220,
              isOutlined: true,
              onPressed: _takePhotoWithCameraApp,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined, color: Colors.white70),
              label: const Text('Or choose a photo from the gallery', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    }

    // Camera is loading
    return Container(
      color: const Color(0xFF0F141C),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 20),
            Text(
              'Starting live camera feed...',
              style: TextStyle(color: Colors.white60, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerAccent(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
