import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../services/adblock_service.dart';
import '../services/video_service.dart';
import '../utils/constants.dart';
import '../utils/video_controller_factory.dart';
import 'controls.dart';
import 'pip_window.dart';

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({super.key});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  final TextEditingController _urlController =
      TextEditingController(text: AppConstants.defaultVideoUrl);
  final VideoService _videoService = VideoService();
  final AdBlockService _adBlockService = AdBlockService(enabled: true);

  VideoPlayerController? _controller;
  bool _isFullscreen = false;
  bool _isPipMode = false;
  bool _isMuted = false;
  bool _isBuffering = false;
  String? _errorText;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadFromUrl();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _videoService.dispose();
    final controller = _controller;
    controller?.removeListener(_onControllerChanged);
    controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (!mounted || controller == null) {
      return;
    }

    final value = controller.value;
    setState(() {
      _position = value.position;
      _duration = value.duration;
      _isBuffering = value.isBuffering;
      _isMuted = value.volume == 0;
    });
  }

  Future<void> _replaceController(VideoPlayerController next) async {
    final previous = _controller;
    previous?.removeListener(_onControllerChanged);
    await previous?.dispose();

    next.addListener(_onControllerChanged);

    setState(() {
      _controller = next;
      _errorText = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _isBuffering = true;
      _isPipMode = false;
    });

    try {
      await next.initialize();
      await next.play();
      _onControllerChanged();
    } catch (error) {
      next.removeListener(_onControllerChanged);
      await next.dispose();

      if (!mounted) {
        return;
      }

      setState(() {
        _controller = null;
        _errorText = 'Không thể phát video: $error';
        _isBuffering = false;
      });
    }
  }

  Future<void> _loadFromUrl() async {
    final input = _urlController.text.trim();
    final uri = Uri.tryParse(input);

    if (uri == null || !uri.hasScheme) {
      setState(() {
        _errorText = 'URL không hợp lệ.';
      });
      return;
    }

    if (_adBlockService.shouldBlockUri(uri)) {
      setState(() {
        _errorText = 'URL bị chặn bởi bộ lọc quảng cáo.';
      });
      return;
    }

    _videoService.setNetworkUrl(input);
    await _replaceController(VideoPlayerController.networkUrl(uri));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.isEmpty) {
      return;
    }

    final path = result.files.single.path;
    if (path == null || path.isEmpty) {
      setState(() {
        _errorText = 'Nền tảng hiện tại không trả về đường dẫn file hợp lệ.';
      });
      return;
    }

    try {
      final controller = createFileController(path);
      _videoService.setFilePath(path);
      await _replaceController(controller);
    } on UnsupportedError catch (error) {
      setState(() {
        _errorText = error.message?.toString() ?? 'Không hỗ trợ phát file cục bộ.';
      });
    } catch (error) {
      setState(() {
        _errorText = 'Không thể mở file video: $error';
      });
    }
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final nextMuted = !_isMuted;
    await controller.setVolume(nextMuted ? 0 : 1);
    _onControllerChanged();
  }

  Future<void> _seek(Duration position) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    await controller.seekTo(position);
  }

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;

    setState(() {
      _isFullscreen = next;
    });

    if (next) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Widget _buildVideoSurface() {
    final controller = _controller;

    if (controller == null) {
      return _emptyState();
    }

    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _errorText ?? 'Nhập URL hoặc chọn file để bắt đầu phát video.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildSourceBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black87,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: 'Video URL (MP4/HLS...)',
                    filled: true,
                    fillColor: Colors.black54,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loadFromUrl,
                child: const Text('Load URL'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _pickFile,
                child: const Text('Pick File'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Ad-block'),
              const SizedBox(width: 8),
              Switch(
                value: _adBlockService.enabled,
                onChanged: (value) {
                  setState(() {
                    _adBlockService.enabled = value;
                  });
                },
              ),
              const Spacer(),
              ValueListenableBuilder<VideoSource?>(
                valueListenable: _videoService.activeSource,
                builder: (context, source, child) {
                  final label = source == null
                      ? 'No source'
                      : source.isFile
                          ? 'File source'
                          : 'URL source';
                  return Text(label, style: const TextStyle(color: Colors.white70));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isPlaying = controller?.value.isPlaying ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (!_isFullscreen) _buildSourceBar(),
                Expanded(
                  child: _isPipMode
                      ? const Center(
                          child: Text(
                            'Video đang chạy ở mini-window.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : _buildVideoSurface(),
                ),
                if (controller != null && !_isPipMode)
                  VideoControls(
                    isPlaying: isPlaying,
                    isMuted: _isMuted,
                    isBuffering: _isBuffering,
                    duration: _duration,
                    position: _position,
                    onSeek: _seek,
                    onTogglePlayPause: _togglePlayPause,
                    onToggleMute: _toggleMute,
                    onToggleFullscreen: _toggleFullscreen,
                    onTogglePip: () {
                      setState(() {
                        _isPipMode = true;
                      });
                    },
                  ),
              ],
            ),
            if (_isPipMode && controller != null)
              PipWindow(
                onClose: () {
                  setState(() {
                    _isPipMode = false;
                  });
                },
                child: _buildVideoSurface(),
              ),
          ],
        ),
      ),
    );
  }
}
