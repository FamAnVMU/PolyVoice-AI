import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/errors/failures.dart';
import '../../core/network/network_logger.dart';

/// Free, studio-quality Neural Text-to-Speech service powered by Microsoft Edge Read Aloud endpoint.
///
/// Provides ultra-natural Vietnamese voices:
/// - vi-VN-HoaiMyNeural (Female - Warm, expressive, standard television broadcaster tone)
/// - vi-VN-NamMinhNeural (Male - Deep, clear, resonant standard broadcast tone)
///
/// Features:
/// - 100% Free with zero API key required and no monthly token cost.
/// - Built-in disk caching for instant 0ms playback of repeated sentences.
/// - Full SSML prosody support (pacing, pitch, volume).
class EdgeTtsService {
  static const String _trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const String _defaultFemaleVoice = 'vi-VN-HoaiMyNeural';
  static const String _defaultMaleVoice = 'vi-VN-NamMinhNeural';
  static const _uuid = Uuid();

  /// Generates the dynamic Sec-MS-GEC anti-abuse token based on Windows epoch and SHA-256.
  static String _generateSecMsGec() {
    // Windows file time epoch skew: seconds between 1601-01-01 and 1970-01-01
    const int epochSkew = 11644473600;
    final int currentTime = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + epochSkew;
    // Round down to 5-minute interval (300 seconds)
    final int roundedTime = (currentTime ~/ 300) * 300;
    final String rawString = '$roundedTime$_trustedClientToken';
    final digest = sha256.convert(utf8.encode(rawString));
    return digest.toString().toUpperCase();
  }

  /// Synthesizes [text] into high-fidelity neural MP3 audio using Edge TTS WebSocket.
  Future<String> synthesizeSpeech({
    required String text,
    String? voiceName,
    double rate = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
    String gender = 'female',
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      throw const TtsFailure('Text for Edge-TTS synthesis cannot be empty.');
    }

    // Resolve voice name
    final targetVoice = voiceName ?? (gender == 'male' ? _defaultMaleVoice : _defaultFemaleVoice);

    // 1. Check disk cache
    final tempDir = await getTemporaryDirectory();
    final cacheKey = md5.convert(utf8.encode('edge-$targetVoice-$rate-$pitch-$volume-$cleanText')).toString();
    final cacheFile = File('${tempDir.path}/edge_tts_$cacheKey.mp3');

    if (await cacheFile.exists() && await cacheFile.length() > 500) {
      return cacheFile.path;
    }

    final stopwatch = Stopwatch()..start();
    final connectionId = _uuid.v4().replaceAll('-', '');
    final requestId = _uuid.v4().replaceAll('-', '');
    final secMsGec = _generateSecMsGec();

    final wsUri = Uri.parse(
      'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1'
      '?TrustedClientToken=$_trustedClientToken'
      '&Sec-MS-GEC=$secMsGec'
      '&Sec-MS-GEC-Version=1-143.0.3650.75'
      '&ConnectionId=$connectionId',
    );

    final headers = {
      'Pragma': 'no-cache',
      'Cache-Control': 'no-cache',
      'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0',
    };

    NetworkLogger.logRequest(
      service: 'EdgeTTS',
      endpoint: wsUri.toString(),
    );

    WebSocket? webSocket;
    final audioBytesBuilder = BytesBuilder(copy: false);
    final completer = Completer<String>();

    try {
      webSocket = await WebSocket.connect(
        wsUri.toString(),
        headers: headers,
      ).timeout(const Duration(seconds: 12));

      // 1. Send speech.config
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final configMessage =
          'X-Timestamp:$timestamp\r\n'
          'Content-Type:application/json; charset=utf-8\r\n'
          'Path:speech.config\r\n\r\n'
          '{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}';
      webSocket.add(configMessage);

      // 2. Format SSML with conversational pacing
      final ratePercent = ((rate - 1.0) * 100).round();
      final rateStr = '${ratePercent >= 0 ? '+' : ''}$ratePercent%';

      final pitchHz = ((pitch - 1.0) * 50).round();
      final pitchStr = '${pitchHz >= 0 ? '+' : ''}${pitchHz}Hz';

      final volumePercent = ((volume - 1.0) * 100).round();
      final volumeStr = '${volumePercent >= 0 ? '+' : ''}$volumePercent%';

      final escapedText = cleanText
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&apos;');

      final ssml =
          '<speak version=\'1.0\' xmlns=\'http://www.w3.org/2001/10/synthesis\' xml:lang=\'vi-VN\'>'
          '<voice name=\'$targetVoice\'>'
          '<prosody pitch=\'$pitchStr\' rate=\'$rateStr\' volume=\'$volumeStr\'>'
          '$escapedText'
          '</prosody>'
          '</voice>'
          '</speak>';

      final ssmlMessage =
          'X-RequestId:$requestId\r\n'
          'Content-Type:application/ssml+xml\r\n'
          'X-Timestamp:$timestamp\r\n'
          'Path:ssml\r\n\r\n'
          '$ssml';
      webSocket.add(ssmlMessage);

      // 3. Listen for audio chunks and turn.end
      late StreamSubscription subscription;
      subscription = webSocket.listen(
        (data) {
          if (data is String) {
            if (data.contains('Path:turn.end')) {
              subscription.cancel();
              webSocket?.close();

              final allBytes = audioBytesBuilder.toBytes();
              if (allBytes.isNotEmpty) {
                cacheFile.writeAsBytes(allBytes, flush: true).then((savedFile) {
                  NetworkLogger.logResponse(
                    service: 'EdgeTTS',
                    endpoint: wsUri.toString(),
                    statusCode: 200,
                    durationMs: stopwatch.elapsedMilliseconds,
                  );
                  if (!completer.isCompleted) completer.complete(savedFile.path);
                }).catchError((err) {
                  if (!completer.isCompleted) completer.completeError(TtsFailure('Failed to cache audio: $err'));
                });
              } else {
                if (!completer.isCompleted) completer.completeError(const TtsFailure('Edge-TTS returned empty audio stream.'));
              }
            }
          } else if (data is List<int>) {
            // Binary frame parsing: 2-byte header length, then text header, then raw audio bytes
            if (data.length > 2) {
              final headerLen = (data[0] << 8) | data[1];
              if (data.length > 2 + headerLen) {
                final audioData = data.sublist(2 + headerLen);
                audioBytesBuilder.add(audioData);
              }
            }
          }
        },
        onError: (e) {
          NetworkLogger.logError(
            service: 'EdgeTTS',
            endpoint: wsUri.toString(),
            error: e,
            durationMs: stopwatch.elapsedMilliseconds,
          );
          if (!completer.isCompleted) completer.completeError(TtsFailure('Edge-TTS socket error: $e'));
        },
        onDone: () {
          if (!completer.isCompleted) {
            final allBytes = audioBytesBuilder.toBytes();
            if (allBytes.isNotEmpty) {
              cacheFile.writeAsBytes(allBytes, flush: true).then((savedFile) {
                completer.complete(savedFile.path);
              }).catchError((err) {
                completer.completeError(TtsFailure('Failed to cache audio: $err'));
              });
            } else {
              completer.completeError(const TtsFailure('Edge-TTS stream finished without audio payload.'));
            }
          }
        },
        cancelOnError: true,
      );

      return await completer.future.timeout(const Duration(seconds: 25), onTimeout: () {
        subscription.cancel();
        webSocket?.close();
        throw const TtsFailure('Edge-TTS synthesis timed out after 25s.');
      });
    } catch (e) {
      NetworkLogger.logError(
        service: 'EdgeTTS',
        endpoint: wsUri.toString(),
        error: e,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      throw TtsFailure('Edge-TTS synthesis failed: $e');
    }
  }
}
