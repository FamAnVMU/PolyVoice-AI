import 'dart:developer' as developer;

/// Safe structured network diagnostics logger for PolyVoice AI.
/// Strictly redacts sensitive credentials (API keys, authorization headers).
class NetworkLogger {
  static final List<String> _recentLogs = [];
  static const int _maxLogs = 60;

  /// Returns the recent in-memory diagnostic logs (safe for display/debugging).
  static List<String> get recentLogs => List.unmodifiable(_recentLogs);

  /// Redact API keys, tokens, and authorization parameters from URLs and text.
  static String sanitize(String input) {
    if (input.isEmpty) return input;
    var sanitized = input;

    // Redact query parameter key=...
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(key=)([A-Za-z0-9_-]{8,})', caseSensitive: false),
      (match) => '${match.group(1)}[REDACTED_KEY]',
    );

    // Redact Bearer tokens
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(Bearer\s+)([A-Za-z0-9_.-]{8,})', caseSensitive: false),
      (match) => '${match.group(1)}[REDACTED_TOKEN]',
    );

    // Redact common API key prefixes
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b(AIza[0-9A-Za-z-_]{35}|gsk_[0-9A-Za-z-_]{40,}|sk-or-[0-9A-Za-z-_]{40,}|sk-[0-9A-Za-z-_]{30,})\b'),
      (_) => '[REDACTED_API_KEY]',
    );

    return sanitized;
  }

  /// Log an outgoing HTTP/Streaming request.
  static void logRequest({
    required String service,
    required String endpoint,
    String method = 'POST',
  }) {
    final cleanEndpoint = sanitize(endpoint);
    final logLine = '[REQUEST] [$service] $method $cleanEndpoint';
    _record(logLine);
    developer.log(logLine, name: 'PolyVoice.Network');
  }

  /// Log a successful HTTP/Streaming response.
  static void logResponse({
    required String service,
    required String endpoint,
    required int statusCode,
    int? durationMs,
  }) {
    final cleanEndpoint = sanitize(endpoint);
    final durationStr = durationMs != null ? ' (${durationMs}ms)' : '';
    final logLine = '[RESPONSE] [$service] HTTP $statusCode$durationStr -> $cleanEndpoint';
    _record(logLine);
    developer.log(logLine, name: 'PolyVoice.Network');
  }

  /// Log a network or API failure with sanitized diagnostics.
  static void logError({
    required String service,
    required String endpoint,
    required dynamic error,
    int? statusCode,
    int? durationMs,
  }) {
    final cleanEndpoint = sanitize(endpoint);
    final cleanError = sanitize(error.toString());
    final statusStr = statusCode != null ? ' HTTP $statusCode' : '';
    final durationStr = durationMs != null ? ' (${durationMs}ms)' : '';
    final logLine = '[ERROR] [$service]$statusStr$durationStr on $cleanEndpoint: $cleanError';
    _record(logLine);
    developer.log(logLine, name: 'PolyVoice.Network', level: 900);
  }

  /// Transform an exception into a clear, actionable Vietnamese user-facing message.
  static String formatUserMessage(
    dynamic error, {
    required String service,
    String? model,
    int? statusCode,
  }) {
    final raw = sanitize(error.toString());
    final lower = raw.toLowerCase();

    if (statusCode == 401 || lower.contains('401') || lower.contains('unauthorized')) {
      return 'Khóa $service API Key không hợp lệ hoặc chưa được kích hoạt. Vui lòng kiểm tra lại trong Settings.';
    }

    if (statusCode == 403 || lower.contains('403') || lower.contains('permission_denied')) {
      return 'Tài khoản hoặc khóa $service không có quyền truy cập mô hình này. Vui lòng kiểm tra quyền hạn API Key.';
    }

    if (statusCode == 404 || lower.contains('404') || lower.contains('not found')) {
      final modelStr = model != null ? ' "$model"' : '';
      return 'Mô hình$modelStr không tồn tại trên $service (404). Vui lòng kiểm tra lại tên Model Identifier trong Settings.';
    }

    if (statusCode == 429 || lower.contains('429') || lower.contains('rate limit') || lower.contains('quota')) {
      return 'Đã vượt quá hạn mức gọi API (Rate Limit / Quota) của $service. Vui lòng thử lại sau giây lát.';
    }

    if (statusCode == 400 || lower.contains('400') || lower.contains('bad request')) {
      return 'Yêu cầu không hợp lệ ($service 400): $raw';
    }

    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Hết thời gian chờ phản hồi từ máy chủ $service (Timeout). Vui lòng thử lại.';
    }

    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection error')) {
      return 'Không thể kết nối đến máy chủ $service. Vui lòng kiểm tra kết nối Internet trên thiết bị của bạn.';
    }

    // Strip class name wrapper like NetworkFailure(...) or Exception: ...
    var cleanMsg = raw;
    if (cleanMsg.startsWith('Exception: ')) {
      cleanMsg = cleanMsg.substring(11);
    }
    final regexWrapper = RegExp(r'^[A-Za-z]+Failure\((.*)\)$');
    final match = regexWrapper.firstMatch(cleanMsg);
    if (match != null && match.group(1) != null) {
      cleanMsg = match.group(1)!;
    }

    return cleanMsg;
  }

  static void _record(String line) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _recentLogs.add('[$timestamp] $line');
    if (_recentLogs.length > _maxLogs) {
      _recentLogs.removeAt(0);
    }
  }
}
