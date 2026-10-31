/// A high-performance streaming sentence chunker designed for real-time, low-latency TTS playback.
/// Author: FamAn
///
/// Features:
/// 1. Abbreviation Protection: Avoids splitting on Vietnamese & international honorifics/abbreviations
///    (e.g., TS., ThS., PGS., GS., Tp., TP., Mr., Mrs., Dr., St., No., vs., etc.).
/// 2. Decimal & Thousand Separator Protection: Preserves numbers like 3.14, 10.000, 1.5, 50.000đ.
/// 3. Dynamic Threshold (40 - 150 chars): Emits completed sentences early at terminal punctuation (., !, ?, \n).
///    If a sentence is long (> 75 chars), safely splits at clause boundaries (,, ;, :, -) to minimize TTFA.
class SentenceChunker {
  final StringBuffer _buffer = StringBuffer();

  static const int minChunkLength = 40;
  static const int softClauseThreshold = 75;
  static const int maxChunkLength = 150;

  // Terminal sentence delimiters (Western, Vietnamese, CJK)
  static final RegExp _terminalDelimiterRegex = RegExp(r'([\.\!\?\n\r\。\！\？]+)');

  // Secondary clause delimiters for long sentences (> 75 chars)
  static final RegExp _clauseDelimiterRegex = RegExp(r'([\,;\:—]|(\s\-\s))');

  // Common abbreviations in Vietnamese and English (matched case-insensitively before a period)
  static final Set<String> _protectedAbbreviations = {
    'ts', 'ths', 'pgs', 'gs', 'tp', 'bs', 'kts', 'cn', 'th',
    'mr', 'mrs', 'ms', 'dr', 'prof', 'st', 'no', 'vs', 'etc',
    'approx', 'dept', 'jr', 'sr', 'e.g', 'i.e', 'v.v', 'v..v', 'vv',
  };

  /// Ingests a new token and returns any completed chunks ready for TTS synthesis.
  List<String> processToken(String token) {
    _buffer.write(token);
    final String current = _buffer.toString();
    final List<String> completedChunks = [];

    int searchStart = 0;
    while (true) {
      final match = _terminalDelimiterRegex.firstMatch(current.substring(searchStart));
      if (match == null) {
        // No terminal punctuation found; check if buffer exceeded soft clause or max length threshold
        if (current.length >= softClauseThreshold) {
          final clauseMatch = _findClauseBreak(current, softClauseThreshold);
          if (clauseMatch != null) {
            completedChunks.add(current.substring(0, clauseMatch).trim());
            _buffer.clear();
            _buffer.write(current.substring(clauseMatch).trimLeft());
            return [...completedChunks, ...processToken('')];
          }
        }

        // Hard cap split at whitespace if buffer exceeds maxChunkLength
        if (current.length >= maxChunkLength) {
          final spaceIdx = current.lastIndexOf(' ', maxChunkLength);
          final splitPoint = (spaceIdx > minChunkLength) ? spaceIdx : maxChunkLength;
          completedChunks.add(current.substring(0, splitPoint).trim());
          _buffer.clear();
          _buffer.write(current.substring(splitPoint).trimLeft());
          return [...completedChunks, ...processToken('')];
        }

        break;
      }

      final int matchIndex = searchStart + match.start;
      final int delimiterEnd = searchStart + match.end;
      final String matchedDelimiter = match.group(1) ?? '';

      // Safeguard against splitting streaming ellipsis prematurely: if '..' is at buffer tail, wait for potential 3rd dot
      if (matchedDelimiter == '..' && delimiterEnd == current.length) {
        break;
      }

      // Check 1: Decimal & thousand separator protection (e.g., 3.14 or 10.000)
      if (matchedDelimiter == '.' && matchIndex > 0 && matchIndex < current.length - 1) {
        final prevChar = current[matchIndex - 1];
        final nextChar = current[matchIndex + 1];
        if (_isDigit(prevChar) && _isDigit(nextChar)) {
          searchStart = delimiterEnd;
          continue;
        }
      }

      // Check 2: Abbreviation protection (e.g., "TS. Nguyễn", "Mr. Smith", "Tp. HCM")
      if (matchedDelimiter == '.' && matchIndex > 0) {
        final precedingWord = _extractPrecedingWord(current, matchIndex);
        if (_protectedAbbreviations.contains(precedingWord.toLowerCase())) {
          searchStart = delimiterEnd;
          continue;
        }
      }

      // Valid terminal boundary identified
      final String candidate = current.substring(0, delimiterEnd).trim();
      if (candidate.isNotEmpty) {
        completedChunks.add(candidate);
      }

      final String remainder = current.substring(delimiterEnd).trimLeft();
      _buffer.clear();
      _buffer.write(remainder);

      // Recursively process any remaining text in buffer
      return [...completedChunks, ...processToken('')];
    }

    return completedChunks;
  }

  /// Finds a clause delimiter index suitable for early chunking when buffer is long.
  int? _findClauseBreak(String text, int searchFrom) {
    final match = _clauseDelimiterRegex.firstMatch(text.substring(minChunkLength));
    if (match != null) {
      final index = minChunkLength + match.end;
      if (index <= maxChunkLength) {
        return index;
      }
    }
    return null;
  }

  /// Extracts the word immediately preceding a delimiter index.
  static String _extractPrecedingWord(String text, int delimiterIndex) {
    int start = delimiterIndex - 1;
    while (start >= 0 && _isWordChar(text[start])) {
      start--;
    }
    return text.substring(start + 1, delimiterIndex);
  }

  static bool _isDigit(String s) {
    if (s.isEmpty) return false;
    final code = s.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  static bool _isWordChar(String char) {
    if (char.isEmpty) return false;
    return char != ' ' &&
        char != '\t' &&
        char != '\n' &&
        char != '\r' &&
        char != ',' &&
        char != ';' &&
        char != ':' &&
        char != '(' &&
        char != ')' &&
        char != '[' &&
        char != ']' &&
        char != '"' &&
        char != '\'' &&
        char != '“' &&
        char != '”';
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
}
