import 'package:flutter/material.dart';

import 'player/video_player_widget.dart';
import 'utils/constants.dart';

void main() {
  runApp(const VideoBlockApp());
}

class VideoBlockApp extends StatelessWidget {
  const VideoBlockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const VideoPlayerWidget(),
    );
  }
}
