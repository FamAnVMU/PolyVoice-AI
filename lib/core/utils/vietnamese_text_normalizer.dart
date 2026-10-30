/// A comprehensive text normalizer for human-like Vietnamese speech synthesis.
///
/// Converts abbreviations, numbers, dates, currency, math symbols, and English
/// loanwords into natural phonetics. Adds conversational breath pauses at punctuation
/// marks to eliminate the monotonic "rap" tempo of raw TTS engines.
class VietnameseTextNormalizer {
  // Common Vietnamese abbreviations
  static final Map<String, String> _abbreviations = {
    'AI': 'trí tuệ nhân tạo',
    'TP.HCM': 'Thành phố Hồ Chí Minh',
    'TPHCM': 'Thành phố Hồ Chí Minh',
    'TP. HCM': 'Thành phố Hồ Chí Minh',
    'HN': 'Hà Nội',
    'ĐHQG': 'Đại học Quốc gia',
    'ĐH': 'Đại học',
    'PGS.TS': 'Phó giáo sư Tiến sĩ',
    'PGS. TS': 'Phó giáo sư Tiến sĩ',
    'PGS': 'Phó giáo sư',
    'GS.TS': 'Giáo sư Tiến sĩ',
    'GS': 'Giáo sư',
    'TS.': 'Tiến sĩ',
    'TS': 'Tiến sĩ',
    'ThS.': 'Thạc sĩ',
    'ThS': 'Thạc sĩ',
    'BS.': 'Bác sĩ',
    'BS': 'Bác sĩ',
    'CNTT': 'Công nghệ thông tin',
    'KHTN': 'Khoa học Tự nhiên',
    'KHXH': 'Khoa học Xã hội',
    'BHYT': 'Bảo hiểm y tế',
    'BHXH': 'Bảo hiểm xã hội',
    'CMND': 'Chứng minh nhân dân',
    'CCCD': 'Căn cước công dân',
    'UBND': 'Ủy ban nhân dân',
    'HĐND': 'Hội đồng nhân dân',
    'CSKH': 'Chăm sóc khách hàng',
    'STT': 'chuyển giọng nói thành văn bản',
    'TTS': 'chuyển văn bản thành giọng nói',
    'API': 'a-pi',
    'URL': 'u-rờ-lờ',
    'ID': 'ai-đi',
    'CEO': 'si-i-ô',
    'VIP': 'víp',
    'BYOK': 'tự dùng khóa cá nhân',
    'OK': 'ô kê',
    'Ok': 'ô kê',
    'ok': 'ô kê',
    'App': 'áp',
    'app': 'áp',
    'Web': 'uép',
    'web': 'uép',
    'Link': 'linh',
    'link': 'linh',
    'File': 'phai-ồ',
    'file': 'phai-ồ',
    'Chat': 'chát',
    'chat': 'chát',
    'Bot': 'bót',
    'bot': 'bót',
    'Online': 'on-lai',
    'online': 'on-lai',
    'Offline': 'ọp-lai',
    'offline': 'ọp-lai',
    'Video': 'vi-đê-ô',
    'video': 'vi-đê-ô',
    'Audio': 'ô-đi-ô',
    'audio': 'ô-đi-ô',
  };

  // Units of measurement
  static final Map<String, String> _units = {
    'km/h': 'ki lô mét trên giờ',
    'km/g': 'ki lô mét trên giờ',
    'm/s': 'mét trên giây',
    'km': 'ki lô mét',
    'cm': 'xen ti mét',
    'mm': 'mi li mét',
    'm': 'mét',
    'kg': 'ki lô gam',
    'g': 'gam',
    'mg': 'mi li gam',
    'l': 'lít',
    'ml': 'mi li lít',
    'GB': 'gi ga bai',
    'MB': 'mê ga bai',
    'KB': 'ki lô bai',
    'TB': 'tê ra bai',
    'GHz': 'ghi ga héc',
    'MHz': 'mê ga héc',
    'Hz': 'héc',
    'kW': 'ki lô oát',
    'W': 'oát',
    'V': 'vôn',
    'A': 'am pe',
    'USD': 'đô la Mỹ',
    'EUR': 'ơ rô',
    'VND': 'đồng',
    'VNĐ': 'đồng',
    'đ': 'đồng',
    '%': 'phần trăm',
    '°C': 'độ xê',
    '°F': 'độ ép',
  };

  /// Main entry point: normalizes text into natural, easy-to-pronounce Vietnamese speech.
  static String normalize(String rawText, {bool addPauses = true}) {
    if (rawText.trim().isEmpty) return '';

    String text = rawText;

    // 1. Strip Markdown formatting (bold, italics, links, code fences, headers)
    text = _stripMarkdown(text);

    // 2. Expand Dates: e.g., 30/10/2026 or 30-10-2026 -> ngày 30 tháng 10 năm 2026
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})\b'),
      (m) => 'ngày ${m[1]} tháng ${m[2]} năm ${m[3]}',
    );

    // 3. Expand Times: e.g., 18:30 or 08:45 -> 18 giờ 30 phút
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{1,2}):(\d{2})\b'),
      (m) => '${m[1]} giờ ${m[2]} phút',
    );

    // 4. Currency and Percentage with numbers
    // e.g., $50 -> 50 đô la Mỹ, 100k -> 100 nghìn, 50% -> 50 phần trăm
    text = text.replaceAllMapped(
      RegExp(r'\$(\d+([.,]\d+)?)'),
      (m) => '${m[1]} đô la Mỹ',
    );

    text = text.replaceAllMapped(
      RegExp(r'(\d+([.,]\d+)?)\s*k\b', caseSensitive: false),
      (m) => '${m[1]} nghìn',
    );

    // 5. Expand Units with attached numbers (e.g., 100km/h, 50kg, 20%)
    for (final entry in _units.entries) {
      final unitPattern = RegExp(
        r'(\d+([.,]\d+)?)\s*' + RegExp.escape(entry.key) + r'(?=[^\w]|$)',
      );
      text = text.replaceAllMapped(
        unitPattern,
        (m) => '${m[1]} ${entry.value}',
      );
    }

    // 6. Expand Abbreviations
    for (final entry in _abbreviations.entries) {
      final abbrPattern = RegExp(
        r'(^|[^\w])' + RegExp.escape(entry.key) + r'(?=[^\w]|$)',
      );
      text = text.replaceAllMapped(
        abbrPattern,
        (m) => '${m[1]}${entry.value}',
      );
    }

    // 7. Convert remaining digits to Vietnamese words for natural tone
    text = _convertNumbersToWords(text);

    // 8. Pace regulation & natural conversational pausing
    if (addPauses) {
      text = _injectConversationalPauses(text);
    }

    // Clean multiple spaces and return
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Removes Markdown formatting to prevent TTS reading raw symbols
  static String _stripMarkdown(String input) {
    var out = input;
    // Remove code blocks ```...```
    out = out.replaceAll(RegExp(r'```[\s\S]*?```'), ' đoạn mã ');
    // Remove inline code `...`
    out = out.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    // Remove Markdown links [text](url) -> text
    out = out.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');
    // Remove bold/italic **text**, *text*, __text__, _text_
    out = out.replaceAll(RegExp(r'[*_]{1,3}([^*_]+)[*_]{1,3}'), r'$1');
    // Remove headers #, ##, ###
    out = out.replaceAll(RegExp(r'^[#]{1,6}\s+', multiLine: true), '');
    // Clean bullet points: - item, * item, 1. item -> item with a pause
    out = out.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), ', ');
    out = out.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), ', bước ');
    return out;
  }

  /// Injects conversational breath pauses at punctuation boundaries
  /// to eliminate monotonic rapid-fire speech.
  static String _injectConversationalPauses(String text) {
    var out = text;

    // Expand ellipses ... into a thoughtful pause
    out = out.replaceAll(RegExp(r'\.{3,}'), '... , ');

    // Ensure space after commas, semicolons, colons
    out = out.replaceAllMapped(RegExp(r'([,;:—–])([^\s])'), (m) => '${m[1]} ${m[2]}');

    // Emphasize question intonation
    out = out.replaceAllMapped(RegExp(r'\?+'), (m) => '? , ');

    // Emphasize exclamation
    out = out.replaceAllMapped(RegExp(r'!+'), (m) => '! , ');

    return out;
  }

  /// Converts isolated numerical digits into written Vietnamese words
  static String _convertNumbersToWords(String text) {
    return text.replaceAllMapped(RegExp(r'\b\d+\b'), (m) {
      final numStr = m[0]!;
      // For years like 2026, convert nicely
      if (numStr.length == 4 && (numStr.startsWith('19') || numStr.startsWith('20'))) {
        return _readNumber(int.tryParse(numStr) ?? 0);
      }
      final n = int.tryParse(numStr);
      if (n != null && n >= 0 && n <= 999999999) {
        return _readNumber(n);
      }
      return numStr;
    });
  }

  /// Vietnamese number-to-words algorithm (0 to 999,999,999)
  static String _readNumber(int n) {
    if (n == 0) return 'không';

    final digits = ['không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín'];
    final units = ['', 'nghìn', 'triệu', 'tỷ'];

    String readThreeDigits(int num, bool isHighestGroup) {
      final h = num ~/ 100;
      final t = (num % 100) ~/ 10;
      final o = num % 10;

      final parts = <String>[];

      if (h > 0 || !isHighestGroup) {
        parts.add('${digits[h]} trăm');
      }

      if (t > 1) {
        parts.add('${digits[t]} mươi');
        if (o == 1) {
          parts.add('mốt');
        } else if (o == 5) {
          parts.add('lăm');
        } else if (o > 0) {
          parts.add(digits[o]);
        }
      } else if (t == 1) {
        parts.add('mười');
        if (o == 5) {
          parts.add('lăm');
        } else if (o > 0) {
          parts.add(digits[o]);
        }
      } else if (t == 0 && o > 0) {
        if (h > 0 || !isHighestGroup) {
          parts.add('lẻ ${digits[o]}');
        } else {
          parts.add(digits[o]);
        }
      }

      return parts.join(' ');
    }

    final groups = <int>[];
    var temp = n;
    while (temp > 0) {
      groups.add(temp % 1000);
      temp ~/= 1000;
    }

    final resultParts = <String>[];
    for (int i = groups.length - 1; i >= 0; i--) {
      final g = groups[i];
      if (g > 0) {
        final groupText = readThreeDigits(g, i == groups.length - 1);
        final unit = units[i];
        if (unit.isNotEmpty) {
          resultParts.add('$groupText $unit');
        } else {
          resultParts.add(groupText);
        }
      }
    }

    return resultParts.join(' ').trim();
  }
}
