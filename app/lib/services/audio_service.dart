import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();
  static bool _isRecording = false;
  static String? _currentRecordPath;

  static bool get isRecording => _isRecording;
  static AudioPlayer get player => _player;

  /// Check and request microphone permission natively via recorder
  static Future<bool> requestPermission() async {
    return await _recorder.hasPermission();
  }

  /// Amplitude monitoring stream for Voice Activity Detection (VAD)
  static Stream<Amplitude> onAmplitudeChanged(Duration interval) {
    return _recorder.onAmplitudeChanged(interval);
  }

  /// Get current amplitude in dBFS
  static Future<Amplitude> getAmplitude() async {
    return await _recorder.getAmplitude();
  }

  /// Start recording voice note / call speech
  static Future<bool> startRecording() async {
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        return false;
      }

      final tempDir = Directory.systemTemp;
      _currentRecordPath = '${tempDir.path}/mira_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: _currentRecordPath!,
      );

      _isRecording = true;
      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return base64 encoded audio
  static Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;
      final path = await _recorder.stop();
      _isRecording = false;

      final filePath = path ?? _currentRecordPath;
      if (filePath == null) return null;

      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        try {
          await file.delete();
        } catch (_) {}
        return base64Encode(bytes);
      }
      return null;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording without saving
  static Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        final path = await _recorder.stop();
        _isRecording = false;
        if (path != null) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      }
    } catch (_) {
      _isRecording = false;
    }
  }

  /// Play audio from base64 string or URL
  static Future<void> playAudio(String audioSource) async {
    try {
      await _player.stop();
      if (audioSource.startsWith('data:audio') || !audioSource.startsWith('http')) {
        final base64Data = audioSource.contains(',') ? audioSource.split(',').last : audioSource;
        final bytes = base64Decode(base64Data);
        await _player.play(BytesSource(bytes));
      } else {
        await _player.play(UrlSource(audioSource));
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  /// Play audio and wait until playback finishes or completes
  static Future<void> playAudioAndWait(String audioSource) async {
    try {
      await playAudio(audioSource);
      final completer = Completer<void>();
      late StreamSubscription sub;
      sub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
        sub.cancel();
      });

      // Wait for audio to complete or safety timeout (e.g. 25 seconds)
      await completer.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          sub.cancel();
        },
      );
    } catch (e) {
      debugPrint('Error in playAudioAndWait: $e');
    }
  }

  /// Stop playing audio
  static Future<void> stopAudio() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}
