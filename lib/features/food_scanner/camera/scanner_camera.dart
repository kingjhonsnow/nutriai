export 'scanner_camera_platform_interface.dart';
export 'scanner_camera_stub.dart'
    if (dart.library.html) 'scanner_camera_web.dart'
    if (dart.library.io) 'scanner_camera_io.dart';
