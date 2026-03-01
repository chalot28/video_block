import 'package:flutter/foundation.dart';

class VideoSource {
  const VideoSource({required this.uri, required this.isFile});

  final String uri;
  final bool isFile;
}

class VideoService {
  final ValueNotifier<VideoSource?> activeSource = ValueNotifier<VideoSource?>(null);

  void setNetworkUrl(String url) {
    activeSource.value = VideoSource(uri: url, isFile: false);
  }

  void setFilePath(String path) {
    activeSource.value = VideoSource(uri: path, isFile: true);
  }

  void clear() {
    activeSource.value = null;
  }

  void dispose() {
    activeSource.dispose();
  }
}
