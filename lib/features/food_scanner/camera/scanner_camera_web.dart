import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'scanner_camera_platform_interface.dart';

class WebScannerCameraController implements ScannerCameraController {
  final VoidCallback onStateChanged;
  static int _viewCounter = 0;
  String _viewType = '';

  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  bool _isInitialized = false;
  bool _isHttpsRequired = false;
  String? _errorMessage;
  bool _isUsingRearCamera = true;
  bool _isFlashOn = false;

  WebScannerCameraController({required this.onStateChanged});

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isStreaming => _videoElement != null && _isInitialized;

  @override
  bool get isHttpsRequired => _isHttpsRequired;

  @override
  String? get errorMessage => _errorMessage;

  @override
  bool get isFlashOn => _isFlashOn;

  @override
  Future<void> initialize() async {
    _errorMessage = null;

    // Check secure context for Safari / Chrome on mobile
    final isSecure = html.window.isSecureContext ?? false;
    final hostname = html.window.location.hostname ?? '';
    final isLocal = hostname == 'localhost' || hostname == '127.0.0.1';

    if (!isSecure && !isLocal) {
      _isHttpsRequired = true;
      _errorMessage =
          'The live camera needs a secure https address. Open the app from its https link.';
      onStateChanged();
      return;
    }

    if (html.window.navigator.mediaDevices == null) {
      _errorMessage =
          'Camera API is not supported or was blocked by Safari permissions.';
      onStateChanged();
      return;
    }

    try {
      final constraints = {
        'video': {
          'facingMode': _isUsingRearCamera ? {'ideal': 'environment'} : 'user',
          'width': {'ideal': 1920},
          'height': {'ideal': 1080},
        },
        'audio': false,
      };

      final stream =
          await html.window.navigator.mediaDevices!.getUserMedia(constraints);
      _mediaStream = stream;

      _videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..setAttribute('webkit-playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      _videoElement!.srcObject = stream;
      await _videoElement!.play();

      // A NEW view id each time: re-using an id would keep showing the old
      // (stopped) video element after switching camera or coming back.
      final video = _videoElement!;
      _viewType = 'nutri_ai_camera_view_${_viewCounter++}';
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => video,
      );

      _isInitialized = true;
      _isHttpsRequired = false;
      _errorMessage = null;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('notallowederror') ||
          errorStr.contains('permission denied')) {
        _errorMessage =
            'Camera permission was denied in Safari. Tap the "aA" icon in Safari address bar and allow camera access.';
      } else if (errorStr.contains('notfounderror')) {
        _errorMessage = 'No camera device found on this device.';
      } else {
        _errorMessage = 'Failed to activate live camera: $e';
      }
    }

    onStateChanged();
  }

  @override
  Widget buildPreview() {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }
    return SizedBox.expand(
      child: HtmlElementView(key: ValueKey(_viewType), viewType: _viewType),
    );
  }

  @override
  Future<Uint8List?> captureFrame() async {
    if (_videoElement == null || _videoElement!.videoWidth == 0) {
      return null;
    }

    // Downscale to at most 1600 px: plenty for food recognition, much faster
    // to upload on mobile data.
    final srcW = _videoElement!.videoWidth;
    final srcH = _videoElement!.videoHeight;
    const maxSide = 1600;
    final scale = (srcW > srcH ? srcW : srcH) > maxSide ? maxSide / (srcW > srcH ? srcW : srcH) : 1.0;
    final width = (srcW * scale).round();
    final height = (srcH * scale).round();

    final canvas = html.CanvasElement(width: width, height: height);
    canvas.context2D.drawImageScaled(_videoElement!, 0, 0, width, height);

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    final base64Data = dataUrl.split(',').last;
    return base64Decode(base64Data);
  }

  @override
  Future<void> switchCamera() async {
    _isUsingRearCamera = !_isUsingRearCamera;
    disposeStream();
    await initialize();
  }

  @override
  Future<void> toggleFlash() async {
    try {
      final track = _mediaStream?.getVideoTracks().firstOrNull;
      if (track != null) {
        _isFlashOn = !_isFlashOn;
        // Apply torch constraint if supported by device
        track.applyConstraints({
          'advanced': [
            {'torch': _isFlashOn}
          ]
        });
        onStateChanged();
      }
    } catch (_) {}
  }

  @override
  void openHttpsMode() {
    try {
      final loc = html.window.location;
      if (loc.protocol == 'http:') {
        html.window.location.href = loc.href.replaceFirst('http:', 'https:');
      }
    } catch (_) {}
  }

  void disposeStream() {
    _mediaStream?.getTracks().forEach((track) {
      try {
        track.stop();
      } catch (_) {}
    });
    _mediaStream = null;
    _videoElement?.pause();
    _videoElement?.srcObject = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    disposeStream();
    _videoElement = null;
  }
}

ScannerCameraController createScannerCameraController({
  required VoidCallback onStateChanged,
}) =>
    WebScannerCameraController(onStateChanged: onStateChanged);
