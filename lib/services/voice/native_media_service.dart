import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class AudioQualityReport {
  final bool isValid;
  final String format;
  final double durationSeconds;
  final int fileSizeBytes;
  final int qualityScore; // 0 - 100
  final String qualityLabel; // 'Xuất sắc', 'Tốt', 'Chấp nhận được', 'Kém'
  final String recommendation;

  const AudioQualityReport({
    required this.isValid,
    required this.format,
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.qualityScore,
    required this.qualityLabel,
    required this.recommendation,
  });
}

class NativeMediaService {
  static const MethodChannel _channel = MethodChannel('com.polyvoice.polyvoice_ai/media_native');
  Function()? _onAudioCompleted;

  NativeMediaService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAudioPlaybackCompleted') {
        _onAudioCompleted?.call();
      }
    });
  }

  /// Launches the system file picker to select an audio or video file.
  Future<String?> pickMediaFile({String type = 'audio'}) async {
    try {
      final String? path = await _channel.invokeMethod<String>('pickMediaFile', {'type': type});
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the audio track from a video container (MP4, MOV, MKV) into an M4A audio file.
  Future<String?> extractAudioFromVideo({
    required String videoPath,
    required String outputPath,
  }) async {
    try {
      final String? result = await _channel.invokeMethod<String>(
        'extractAudioFromVideo',
        {
          'videoPath': videoPath,
          'outputPath': outputPath,
        },
      );
      return result;
    } catch (e) {
      throw Exception('Không thể trích xuất âm thanh từ video: $e');
    }
  }

  /// Plays a local audio file through hardware media player.
  Future<bool> playAudio(String filePath, {Function()? onCompleted}) async {
    _onAudioCompleted = onCompleted;
    try {
      final bool? success = await _channel.invokeMethod<bool>('playAudio', {'filePath': filePath});
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Stops any currently playing audio file immediately.
  Future<void> stopAudio() async {
    try {
      await _channel.invokeMethod('stopAudio');
    } catch (_) {}
  }

  /// Checks if media player is actively outputting sound.
  Future<bool> isAudioPlaying() async {
    try {
      final bool? isPlaying = await _channel.invokeMethod<bool>('isAudioPlaying');
      return isPlaying ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Extracts duration, MIME type, and size of the audio file.
  Future<Map<String, dynamic>> getAudioMetadata(String filePath) async {
    try {
      final dynamic raw = await _channel.invokeMethod('getAudioMetadata', {'filePath': filePath});
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    final file = File(filePath);
    return {
      'durationMs': 0,
      'mimeType': 'audio/mpeg',
      'hasAudio': true,
      'fileSizeBytes': file.existsSync() ? file.lengthSync() : 0,
    };
  }

  /// Evaluates audio quality, format, length, and suitability for voice cloning.
  Future<AudioQualityReport> analyzeAudioQuality(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const AudioQualityReport(
        isValid: false,
        format: 'unknown',
        durationSeconds: 0,
        fileSizeBytes: 0,
        qualityScore: 0,
        qualityLabel: 'Không hợp lệ',
        recommendation: 'File không tồn tại trên thiết bị.',
      );
    }

    final meta = await getAudioMetadata(filePath);
    final durationMs = (meta['durationMs'] as num?)?.toDouble() ?? 0.0;
    final durationSec = durationMs / 1000.0;
    final fileSizeBytes = (meta['fileSizeBytes'] as num?)?.toInt() ?? file.lengthSync();
    final ext = filePath.split('.').last.toLowerCase();

    int score = 50;
    String rec = '';

    // Duration scoring: 10s - 120s is ideal for high-fidelity voice cloning
    if (durationSec >= 15 && durationSec <= 90) {
      score += 30;
      rec = 'Độ dài tối ưu cho chất lượng mẫu giọng nói rõ nét.';
    } else if (durationSec >= 5 && durationSec < 15) {
      score += 15;
      rec = 'Độ dài vừa đủ, nên dùng bản thu trên 15 giây để đạt độ biểu cảm cao nhất.';
    } else if (durationSec > 90) {
      score += 20;
      rec = 'Bản thu phong phú, hệ thống sẽ tự chọn lọc các đoạn âm thanh tốt nhất.';
    } else {
      score -= 20;
      rec = 'Bản thu quá ngắn (dưới 5 giây), có thể ảnh hưởng đến độ tự nhiên.';
    }

    // Format scoring: lossless or standard uncompressed / aac
    if (ext == 'wav' || ext == 'm4a' || ext == 'aac' || ext == 'mp3') {
      score += 20;
    } else {
      score += 10;
    }

    // Size check: over 50KB means legitimate audio stream
    if (fileSizeBytes > 50 * 1024) {
      score = score.clamp(10, 100);
    } else {
      score = 20;
      rec = 'Dung lượng file quá nhỏ, vui lòng kiểm tra lại chất lượng bản thu.';
    }

    String label = 'Tốt';
    if (score >= 85) {
      label = 'Xuất sắc';
    } else if (score >= 70) {
      label = 'Tốt';
    } else if (score >= 50) {
      label = 'Chấp nhận được';
    } else {
      label = 'Kém';
    }

    return AudioQualityReport(
      isValid: score >= 40,
      format: ext.toUpperCase(),
      durationSeconds: durationSec,
      fileSizeBytes: fileSizeBytes,
      qualityScore: score,
      qualityLabel: label,
      recommendation: rec,
    );
  }
}
