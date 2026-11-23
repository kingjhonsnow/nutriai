import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'scanner_camera_platform_interface.dart';

class StubScannerCameraController implements ScannerCameraController {
  final VoidCallback onStateChanged;

  StubScannerCameraController({required this.onStateChanged});

  @override
  bool get isInitialized => true;

  @override
  bool get isStreaming => false;

  @override
  bool get isHttpsRequired => false;

  @override
  String? get errorMessage => null;

  @override
  bool get isFlashOn => false;

  @override
  Future<void> initialize() async {
    onStateChanged();
  }

  @override
  Widget buildPreview() {
    return const SizedBox.shrink();
  }

  @override
  Future<Uint8List?> captureFrame() async {
    return null;
  }

  @override
  Future<void> switchCamera() async {}

  @override
  Future<void> toggleFlash() async {}

  @override
  void openHttpsMode() {}

  @override
  void dispose() {}
}

ScannerCameraController createScannerCameraController({
  required VoidCallback onStateChanged,
}) =>
    StubScannerCameraController(onStateChanged: onStateChanged);
