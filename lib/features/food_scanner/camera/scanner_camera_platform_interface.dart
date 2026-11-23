import 'dart:typed_data';
import 'package:flutter/widgets.dart';

abstract class ScannerCameraController {
  bool get isInitialized;
  bool get isStreaming;
  bool get isHttpsRequired;
  String? get errorMessage;
  bool get isFlashOn;

  Future<void> initialize();
  Widget buildPreview();
  Future<Uint8List?> captureFrame();
  Future<void> switchCamera();
  Future<void> toggleFlash();
  void openHttpsMode();
  void dispose();
}
