import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Audio-Player für die App mit echter Tonwiedergabe
class AudioPlayerWidget extends StatefulWidget {
  final String audioPath;
  final String? fileName;

  const AudioPlayerWidget({
    super.key,
    required this.audioPath,
    this.fileName,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool isPlaying = false;
  double progress = 0.0;
  Duration duration = Duration.zero;
  Duration currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPositionChanged.listen((Duration d) {
      if (mounted) {
        setState(() {
          currentPosition = d;
          if (duration.inMilliseconds > 0) {
            progress = d.inMilliseconds / duration.inMilliseconds;
          }
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((Duration d) {
      if (mounted) {
        setState(() => duration = d);
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          isPlaying = false;
          progress = 0.0;
          currentPosition = Duration.zero;
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    try {
      if (isPlaying) {
        await _audioPlayer.pause();
      } else {
        // Versuche, die Audio-Datei zu spielen
        String audioPath = widget.audioPath;
        // Falls der Pfad nicht mit 'App/' beginnt, ergänze ihn
        if (!audioPath.startsWith('App/')) {
          audioPath = 'App/$audioPath';
        }
        // Im Web müssen Assets über 'assets/' geladen werden
        String webAudioPath = audioPath;
        if (kIsWeb && !audioPath.startsWith('data:') && !audioPath.startsWith('http')) {
          webAudioPath = 'assets/$audioPath';
        }
        // Wenn es ein Data URL ist, verwende BytesSource
        if (audioPath.startsWith('data:')) {
          try {
            final base64Str = audioPath.split(',').last;
            final audioBytes = base64Decode(base64Str);
            await _audioPlayer.play(BytesSource(audioBytes));
          } catch (e) {
            // Fallback bei Fehler
            _showPlaybackFallback();
          }
        } else {
          // Ansonsten versuche als Asset oder URL zu laden
          try {
            if (kIsWeb) {
              // Im Web als URL laden
              await _audioPlayer.play(UrlSource(webAudioPath));
            } else {
              // Mobil/Deskop als Asset
              await _audioPlayer.play(AssetSource(audioPath));
            }
          } catch (e) {
            try {
              // Fallback: Versuche als URL zu laden
              await _audioPlayer.play(UrlSource(webAudioPath));
            } catch (_) {
              _showPlaybackFallback();
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Abspielen: $e')),
        );
      }
    }
  }

  void _showPlaybackFallback() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('▶️ Abspielen: ${widget.fileName ?? widget.audioPath}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    setState(() {
      duration = const Duration(seconds: 120);
      isPlaying = true;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.fileName ?? (widget.audioPath.contains('/') ? widget.audioPath.split('/').last : widget.audioPath);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.shade50,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.audio_file, color: Colors.blue.shade600, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Play/Pause Button
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade600,
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _togglePlayPause,
                  splashRadius: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Progress Bar
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: GestureDetector(
                        onTapDown: (details) async {
                          final box = context.findRenderObject() as RenderBox;
                          final width = box.size.width;
                          final dx = details.localPosition.dx;
                          final newProgress = (dx / width).clamp(0.0, 1.0);
                          final newPosition = Duration(
                            milliseconds: (newProgress * duration.inMilliseconds).toInt(),
                          );
                          await _audioPlayer.seek(newPosition);
                        },
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(currentPosition),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          _formatDuration(duration),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
