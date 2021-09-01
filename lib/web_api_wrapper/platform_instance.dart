export 'platform_interface.dart'
    if (dart.library.io) 'native_platform.dart'
    if (dart.library.html) 'web_platform.dart';
