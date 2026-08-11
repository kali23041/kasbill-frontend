import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Handles ratnex://payment/success and ratnex://payment/cancel deep links.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  final _controller = StreamController<Uri>.broadcast();

  Stream<Uri> get links => _controller.stream;

  Future<void> start() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _controller.add(initial);
    } catch (e) {
      debugPrint('DeepLink initial: $e');
    }
    await _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      _controller.add,
      onError: (e) => debugPrint('DeepLink stream: $e'),
    );
  }

  static bool isPaymentSuccess(Uri uri) {
    if (uri.scheme != 'ratnex') return false;
    return uri.host == 'payment' &&
        (uri.path == '/success' || uri.pathSegments.contains('success'));
  }

  static bool isPaymentCancel(Uri uri) {
    if (uri.scheme != 'ratnex') return false;
    return uri.host == 'payment' &&
        (uri.path == '/cancel' || uri.pathSegments.contains('cancel'));
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
