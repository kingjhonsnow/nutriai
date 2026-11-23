import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'scanner_camera_platform_interface.dart';

class NativeScannerCameraController implements ScannerCameraController {
  final VoidCallback onStateChanged;

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isFlashOn = false;

  NativeScannerCameraController({required this.onStateChanged});

  @override
  bool get isInitialized => _isInitialized && _controller != null;

  @override
  bool get isStreaming => isInitialized && _controller!.value.isInitialized;

  @override
  bool get isHttpsRequired => false;

  @override
  String? get errorMessage => _errorMessage;

  @override
  bool get isFlashOn => _isFlashOn;

  @override
  Future<void> initialize() async {
    _errorMessage = null;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _errorMessage = 'No camera available on this device.';
        onStateChanged();
        return;
      }

      // Default to back camera
      _selectedCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      await _initController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      _errorMessage = 'Camera initialization failed: $e';
      onStateChanged();
    }
  }

  Future<void> _initController(CameraDescription camera) async {
    await _controller?.dispose();
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      _controller = controller;
      _isInitialized = true;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to start camera: $e';
    }
    onStateChanged();
  }

  @override
  Widget buildPreview() {
    if (!isStreaming) return const SizedBox.shrink();
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize?.height ?? 1,
          height: _controller!.value.previewSize?.width ?? 1,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  @override
  Future<Uint8List?> captureFrame() async {
    if (!isStreaming) return null;
    try {
      final file = await _controller!.takePicture();
      return await file.readAsBytes();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initController(_cameras[_selectedCameraIndex]);
  }

  @override
  Future<void> toggleFlash() async {
    if (!isStreaming) return;
    try {
      _isFlashOn = !_isFlashOn;
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      onStateChanged();
    } catch (_) {}
  }

  @override
  void openHttpsMode() {}

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}

ScannerCameraController createScannerCameraController({
  required VoidCallback onStateChanged,
}) =>
    NativeScannerCameraController(onStateChanged: onStateChanged);
