import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Widget buildVideoPlayer(String dataUrl) {
  return _NativeVideoPlayer(dataUrl: dataUrl);
}

class _NativeVideoPlayer extends StatefulWidget {
  final String dataUrl;
  const _NativeVideoPlayer({required this.dataUrl});

  @override
  State<_NativeVideoPlayer> createState() => _NativeVideoPlayerState();
}

class _NativeVideoPlayerState extends State<_NativeVideoPlayer> {
  VideoPlayerController? _controller;
  File? _tempFile;
  Future<void>? _init;

  @override
  void initState() {
    super.initState();
    _init = _setupController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _tempFile?.delete().ignore();
    super.dispose();
  }

  Future<void> _setupController() async {
    final src = widget.dataUrl.replaceAll('\\', '/');
    if (src.startsWith('data:')) {
      final base64Part = src.split(',').last;
      final bytes = base64Decode(base64Part);
      final file = await _writeTemp(bytes, '.mp4');
      _tempFile = file;
      _controller = VideoPlayerController.file(file);
    } else if (src.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(src));
    } else {
      // Asset-Pfad relativ zum assets/-Ordner
      final assetPath = src.startsWith('assets/') ? src : 'assets/$src';
      _controller = VideoPlayerController.asset(assetPath);
    }
    await _controller!.initialize();
    _controller!.setLooping(true);
    await _controller!.play();
    if (mounted) setState(() {});
  }

  Future<File> _writeTemp(List<int> bytes, String ext) async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/entry_video_${DateTime.now().microsecondsSinceEpoch}$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 800,
      height: 600,
      child: FutureBuilder<void>(
        future: _init,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller == null || !_controller!.value.isInitialized) {
            return const Center(child: Text('Video kann nicht geladen werden'));
          }
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
              _PlayPauseOverlay(controller: _controller!),
              VideoProgressIndicator(_controller!, allowScrubbing: true),
            ],
          );
        },
      ),
    );
  }
}

class _PlayPauseOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  const _PlayPauseOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            reverseDuration: const Duration(milliseconds: 100),
            child: controller.value.isPlaying
                ? const SizedBox.shrink()
                : Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(Icons.play_arrow, color: Colors.white, size: 64),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
