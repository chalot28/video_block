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

    final isAllowListed = AppConstants.videoHostAllowList.any(
      (domain) => host == domain || host.endsWith('.$domain'),
    );

    if (isAllowListed) {
      return false;
    }

    final blockedHost = AppConstants.adHostFilters.any(
      (domain) => host == domain || host.endsWith('.$domain'),
    );

    if (blockedHost) {
      return true;
    }

    return AppConstants.adPathKeywords.any(path.contains);
  }

  bool shouldBlockRequestUrl(String url) {
    final uri = Uri.tryParse(url);
    return shouldBlockUri(uri);
  }
}
