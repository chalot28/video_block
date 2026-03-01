import 'dart:math' as math;

import 'package:flutter/material.dart';

class VideoControls extends StatelessWidget {
  const VideoControls({
    super.key,
    required this.isPlaying,
    required this.isMuted,
    required this.isBuffering,
    required this.duration,
    required this.position,
    required this.onSeek,
    required this.onTogglePlayPause,
    required this.onToggleMute,
    required this.onToggleFullscreen,
    required this.onTogglePip,
  });

  final bool isPlaying;
  final bool isMuted;
  final bool isBuffering;
  final Duration duration;
  final Duration position;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onTogglePip;

  @override
  Widget build(BuildContext context) {
    final maxMs = math.max(duration.inMilliseconds.toDouble(), 1).toDouble();
    final currentMs = math.min(position.inMilliseconds.toDouble(), maxMs).toDouble();

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: currentMs,
            min: 0,
            max: maxMs,
            onChanged: duration.inMilliseconds == 0
                ? null
                : (value) => onSeek(Duration(milliseconds: value.toInt())),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onTogglePlayPause,
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                onPressed: onToggleMute,
                icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
              ),
              IconButton(
                onPressed: onTogglePip,
                icon: const Icon(Icons.picture_in_picture_alt_outlined),
              ),
              IconButton(
                onPressed: onToggleFullscreen,
                icon: const Icon(Icons.fullscreen),
              ),
              const Spacer(),
              Text(
                '${_format(position)} / ${_format(duration)}',
                style: const TextStyle(fontSize: 12),
              ),
              if (isBuffering) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }
}
