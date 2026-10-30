/// A streaming sentence chunker designed for low-latency TTS playback.
///
/// It buffers incoming streaming LLM tokens and yields complete sentences as soon
/// as sentence boundaries (., !, ?, \n, 。, ！, ？) are detected, allowing the TTS
/// engine to speak the first sentence while subsequent tokens continue streaming.
class SentenceChunker {
  final StringBuffer _buffer = StringBuffer();

  // Delimiters indicating sentence endings in Western and CJK languages
  static final RegExp _delimiterRegex = RegExp(r'([\.\!\?\n\r\。\！\？]+)');

  /// Ingests a new token and returns any completed sentences found so far.
  List<String> processToken(String token) {
    _buffer.write(token);
    final String current = _buffer.toString();
    final List<String> completedSentences = [];

    int searchStart = 0;
    while (true) {
      final match = _delimiterRegex.firstMatch(current.substring(searchStart));
      if (match == null) break;

      final int matchIndex = searchStart + match.start;
      final int delimiterEnd = searchStart + match.end;

      // Ensure we don't break on decimals (e.g., "3.14")
      if (match.group(1) == '.' &&
          matchIndex > 0 &&
          matchIndex < current.length - 1) {
        final prevChar = current[matchIndex - 1];
        final nextChar = current[matchIndex + 1];
        if (_isDigit(prevChar) && _isDigit(nextChar)) {
          searchStart = delimiterEnd;
          continue;
        }
      }

      // We have a confirmed sentence boundary
      final String sentence = current.substring(0, delimiterEnd).trim();
      if (sentence.isNotEmpty) {
        completedSentences.add(sentence);
      }

      // Keep whatever is remaining in the buffer
      final String remainder = current.substring(delimiterEnd);
      _buffer.clear();
      _buffer.write(remainder);

      // Start search again on the new buffer
      return [...completedSentences, ...processToken('')];
    }

    return completedSentences;
  }

  /// Flushes any remaining text left in the buffer when the LLM stream ends.
  String? flush() {
    final String remaining = _buffer.toString().trim();
    _buffer.clear();
    return remaining.isNotEmpty ? remaining : null;
  }

  /// Resets the chunker buffer (e.g., when a user interrupts or cancels).
  void reset() {
    _buffer.clear();
  }

  static bool _isDigit(String s) {
    if (s.isEmpty) return false;
    final code = s.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
}
