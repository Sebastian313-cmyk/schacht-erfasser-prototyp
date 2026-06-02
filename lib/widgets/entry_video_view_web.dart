// ignore_for_file: avoid_web_libraries_in_flutter
// ignore: deprecated_member_use
import 'dart:html' as html;
// ignore: depend_on_referenced_packages
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Widget buildVideoPlayer(String dataUrl) {
  if (!kIsWeb) {
    return SizedBox(width: 800, height: 600, child: Center(child: Text('Video nur im Web')));
  }
  return _HtmlVideoPlayer(dataUrl: dataUrl);
}

class _HtmlVideoPlayer extends StatefulWidget {
  final String dataUrl;
  const _HtmlVideoPlayer({required this.dataUrl});

  @override
  State<_HtmlVideoPlayer> createState() => _HtmlVideoPlayerState();
}

class _HtmlVideoPlayerState extends State<_HtmlVideoPlayer> {
  late final String _viewType;
  static final Set<String> _registered = <String>{};

  @override
  void initState() {
    super.initState();
    _viewType = 'entry-video-${widget.dataUrl.hashCode}';
    if (!_registered.contains(_viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final video = html.VideoElement()
          ..src = _resolveSrc(widget.dataUrl)
          ..controls = true
          ..autoplay = true
          ..loop = true
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..preload = 'metadata';
        video.setAttribute('playsinline', 'true');

        // Versuche direkt abzuspielen; falls Browser blockt, bleiben Controls sichtbar.
        video.onCanPlay.listen((_) {
          video.play().catchError((_) {});
        });
        return video;
      });
      _registered.add(_viewType);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 800,
      height: 600,
      child: HtmlElementView(viewType: _viewType),
    );
  }

  String _resolveSrc(String value) {
    final normalized = value.replaceAll('\\', '/');
    if (normalized.startsWith('data:') || normalized.startsWith('http')) return normalized;
    if (normalized.startsWith('assets/')) return normalized;
    // Annahme: Asset-Pfade (z. B. App/ES/ES_Video.mp4) werden unter assets/ bereitgestellt
    return 'assets/$normalized';
  }
}
