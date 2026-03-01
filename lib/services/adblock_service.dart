import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../utils/constants.dart';

class AdBlockService {
  bool enabled;

  AdBlockService({this.enabled = true});

  bool shouldBlockUri(Uri? uri) {
    if (!enabled || uri == null) {
      return false;
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    final blockedHost = AppConstants.adHostFilters.any(
      (domain) => host == domain || host.endsWith('.$domain'),
    );

    if (blockedHost) {
      return true;
    }

    return AppConstants.adPathKeywords.any(path.contains);
  }

  Future<WebResourceResponse?> interceptRequest(WebResourceRequest request) async {
    try {
      if (!enabled) {
        return null;
      }

      if (shouldBlockUri(request.url)) {
        final data = Uint8List.fromList(utf8.encode(''));
        return WebResourceResponse(
          contentType: 'text/plain',
          contentEncoding: 'utf-8',
          statusCode: 403,
          reasonPhrase: 'Blocked by ad filter',
          data: data,
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
