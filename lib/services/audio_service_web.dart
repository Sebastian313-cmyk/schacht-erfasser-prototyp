// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:async';
// ...existing code...
import 'package:flutter/foundation.dart';

/// Web implementation of audio recording
class AudioServiceWeb {
  static Future<String?> recordAudio() async {
    try {
      // Request microphone permission
      final mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});
      
      if (mediaStream == null) {
        debugPrint('[AudioServiceWeb] No media stream available');
        return null;
      }

      final mediaRecorder = html.MediaRecorder(mediaStream);
      final chunks = <html.Blob>[];
      
      final completer = Completer<String?>();
      
      mediaRecorder.addEventListener('dataavailable', (event) {
        final blob = js_util.getProperty(event, 'data') as html.Blob;
        if (blob.size > 0) {
          chunks.add(blob);
        }
      });
      
      mediaRecorder.addEventListener('stop', (event) async {
        // Stop all tracks
        for (final track in mediaStream.getTracks()) {
          track.stop();
        }
        
        if (chunks.isEmpty) {
          completer.complete(null);
          return;
        }
        
        // Combine all chunks into one blob
        final blob = html.Blob(chunks, 'audio/webm');
        
        // Convert blob to base64
        final reader = html.FileReader();
        reader.readAsDataUrl(blob);
        
        reader.onLoadEnd.listen((e) {
          final dataUrl = reader.result as String?;
          completer.complete(dataUrl);
        });
        
        reader.onError.listen((e) {
          debugPrint('[AudioServiceWeb] FileReader error: $e');
          completer.complete(null);
        });
      });
      
      // Start recording
      mediaRecorder.start();
      debugPrint('[AudioServiceWeb] Recording started');
      
      // Record for 30 seconds max, or until stopped
      await Future.delayed(const Duration(seconds: 30));
      
      if (mediaRecorder.state == 'recording') {
        mediaRecorder.stop();
        debugPrint('[AudioServiceWeb] Recording stopped (timeout)');
      }
      
      return await completer.future;
      
    } catch (e) {
      debugPrint('[AudioServiceWeb] Error recording: $e');
      return null;
    }
  }
  
  /// Show a dialog to record audio with stop button
  static Future<String?> showRecordDialog() async {
    // Create modal overlay
    final overlay = html.DivElement()
      ..style.position = 'fixed'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = 'rgba(0,0,0,0.5)'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.zIndex = '9999';
    
    final dialog = html.DivElement()
      ..style.backgroundColor = 'white'
      ..style.padding = '20px'
      ..style.borderRadius = '8px'
      ..style.textAlign = 'center'
      ..style.minWidth = '300px';
    
    final title = html.HeadingElement.h2()
      ..text = '🎤 Audio aufnehmen'
      ..style.margin = '0 0 20px 0';
    
    final status = html.DivElement()
      ..text = 'Aufnahme läuft...'
      ..style.margin = '20px 0'
      ..style.fontSize = '18px'
      ..style.color = 'red';
    
    final stopButton = html.ButtonElement()
      ..text = 'Stopp'
      ..style.padding = '10px 20px'
      ..style.fontSize = '16px'
      ..style.backgroundColor = '#dc3545'
      ..style.color = 'white'
      ..style.border = 'none'
      ..style.borderRadius = '4px'
      ..style.cursor = 'pointer';
    
    final cancelButton = html.ButtonElement()
      ..text = 'Abbrechen'
      ..style.padding = '10px 20px'
      ..style.fontSize = '16px'
      ..style.marginLeft = '10px'
      ..style.backgroundColor = '#6c757d'
      ..style.color = 'white'
      ..style.border = 'none'
      ..style.borderRadius = '4px'
      ..style.cursor = 'pointer';
    
    dialog.children.addAll([title, status, stopButton, cancelButton]);
    overlay.children.add(dialog);
    html.document.body?.children.add(overlay);
    
    final completer = Completer<String?>();
    html.MediaRecorder? mediaRecorder;
    html.MediaStream? mediaStream;
    final chunks = <html.Blob>[];
    
    try {
      mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});
      
      if (mediaStream == null) {
        overlay.remove();
        return null;
      }
      
      mediaRecorder = html.MediaRecorder(mediaStream);
      
      mediaRecorder.addEventListener('dataavailable', (event) {
        final blob = js_util.getProperty(event, 'data') as html.Blob;
        if (blob.size > 0) {
          chunks.add(blob);
        }
      });
      
      mediaRecorder.addEventListener('stop', (event) async {
        for (final track in mediaStream!.getTracks()) {
          track.stop();
        }
        
        overlay.remove();
        
        if (chunks.isEmpty) {
          completer.complete(null);
          return;
        }
        
        final blob = html.Blob(chunks, 'audio/webm');
        final reader = html.FileReader();
        reader.readAsDataUrl(blob);
        
        reader.onLoadEnd.listen((e) {
          completer.complete(reader.result as String?);
        });
        
        reader.onError.listen((e) {
          completer.complete(null);
        });
      });
      
      stopButton.onClick.listen((event) {
        if (mediaRecorder?.state == 'recording') {
          mediaRecorder?.stop();
        }
      });
      
      cancelButton.onClick.listen((event) {
        if (mediaRecorder?.state == 'recording') {
          mediaRecorder?.stop();
        }
        for (final track in mediaStream!.getTracks()) {
          track.stop();
        }
        overlay.remove();
        completer.complete(null);
      });
      
      mediaRecorder.start();
      debugPrint('[AudioServiceWeb] Recording started via dialog');
      
    } catch (e) {
      debugPrint('[AudioServiceWeb] Error in dialog: $e');
      overlay.remove();
      for (final track in mediaStream?.getTracks() ?? []) {
        track.stop();
      }
      return null;
    }
    
    return await completer.future;
  }
}
