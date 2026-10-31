/// Sanitizes streaming tokens from LLMs by:
/// 1. Stripping hidden reasoning/thought blocks: <think>...</think>, <thought>...</thought>, etc.
/// 2. Eliminating technical draft prefixes like "Draft response:", "Draft:", "Thinking:", etc.
/// 3. Preserving genuine conversational content and programming code.
class StreamResponseSanitizer {
  bool _insideThoughtTag = false;
  bool _checkedLeadingDraft = false;
  final StringBuffer _initialBuffer = StringBuffer();

  // Pattern matching thought tags from DeepSeek R1, Qwen, Gemini Thinking, etc.
  static final RegExp _openTagRegex =
      RegExp(r'<(think|thought|reasoning|scratchpad)>', caseSensitive: false);
  static final RegExp _closeTagRegex =
      RegExp(r'</(think|thought|reasoning|scratchpad)>', caseSensitive: false);

  // Pattern matching internal draft prefixes at the very start of a response
  static final RegExp _leadingDraftRegex = RegExp(
    r'^\s*(\*\*|\[)?(Draft response|Draft|Thinking Process|Thinking|Internal Thoughts|Bản nháp|Suy nghĩ)(\*\*|\])?\s*[:\-–—]?\s*',
    caseSensitive: false,
  );

  /// Ingests a raw streaming chunk and yields clean, user-facing text tokens.
  List<String> processChunk(String rawChunk) {
    if (rawChunk.isEmpty) return [];

    final List<String> result = [];
    String text = rawChunk;

    int i = 0;
    while (i < text.length) {
      if (_insideThoughtTag) {
        final match = _closeTagRegex.firstMatch(text.substring(i));
        if (match != null) {
          i += match.end;
          _insideThoughtTag = false;
        } else {
          // Entire remainder of chunk is inside thought block; skip
          break;
        }
      } else {
        final match = _openTagRegex.firstMatch(text.substring(i));
        if (match != null) {
          final openIdx = i + match.start;
          if (openIdx > i) {
            final visible = text.substring(i, openIdx);
            final clean = _filterLeadingDraftIfNeeded(visible);
            if (clean.isNotEmpty) result.add(clean);
          }
          i += match.end;
          _insideThoughtTag = true;
        } else {
          final visible = text.substring(i);
          final clean = _filterLeadingDraftIfNeeded(visible);
          if (clean.isNotEmpty) result.add(clean);
          break;
        }
      }
    }

    return result;
  }

  String _filterLeadingDraftIfNeeded(String text) {
    if (_checkedLeadingDraft) return text;

    _initialBuffer.write(text);
    final accumulated = _initialBuffer.toString();

    if (_leadingDraftRegex.hasMatch(accumulated)) {
      final stripped = accumulated.replaceFirst(_leadingDraftRegex, '');
      _checkedLeadingDraft = true;
      _initialBuffer.clear();
      return stripped;
    } else if (accumulated.length >= 40) {
      _checkedLeadingDraft = true;
      final out = accumulated;
      _initialBuffer.clear();
      return out;
    }

    // Buffer slightly until we have enough characters to inspect the opening prefix
    return '';
  }

  /// Flushes any pending initial buffered text when the stream ends.
  String? flush() {
    if (!_checkedLeadingDraft && _initialBuffer.isNotEmpty) {
      _checkedLeadingDraft = true;
      final out = _initialBuffer.toString().replaceFirst(_leadingDraftRegex, '');
      _initialBuffer.clear();
      return out.isNotEmpty ? out : null;
    }
    return null;
  }

  /// Resets the sanitizer for a new stream session.
  void reset() {
    _insideThoughtTag = false;
    _checkedLeadingDraft = false;
    _initialBuffer.clear();
  }
}
