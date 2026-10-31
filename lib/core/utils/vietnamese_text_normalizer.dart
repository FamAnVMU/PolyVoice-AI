/// A comprehensive text normalizer for human-like Vietnamese speech synthesis.
///
/// Converts abbreviations, numbers, dates, currency, math symbols, and English
/// loanwords into natural phonetics. Adds conversational breath pauses at punctuation
/// marks to eliminate the monotonic "rap" tempo of raw TTS engines.
class VietnameseTextNormalizer {
  // Common Vietnamese abbreviations & acronyms
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
    'Facebook': 'phây-búc',
    'Google': 'gú-gồ',
    'YouTube': 'diu-túp',
    'Zalo': 'da-lô',
    'TikTok': 'tóp-tóp',
    'Email': 'i-meo',
    'Password': 'pát-guốc',
    'Wi-Fi': 'oai-phai',
    'Wifi': 'oai-phai',
    'Bluetooth': 'bờ-lu-tút',
    'Smartphone': 'xì-mát-phôn',
    'Laptop': 'láp-tóp',
    'PC': 'pi-xi',
    'Update': 'úp-đết',
    'Fix': 'phích',
    'Bug': 'bấc',
    'Check': 'chếch',
    'Deadline': 'đét-lai',
    'Task': 'tát',
    'Team': 'tim',
    'Meeting': 'mít-ting',
    'Post': 'pốt',
    'Like': 'lai',
    'Share': 'se',
    'Follow': 'pho-lâu',
    'Game': 'gêm',
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

  // Precompiled regex for maximum throughput and zero GC allocation in streaming TTS
  static final RegExp _dateRegex = RegExp(r'\b(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})\b');
  static final RegExp _timeRegex = RegExp(r'\b(\d{1,2}):(\d{2})\b');
  static final RegExp _dollarRegex = RegExp(r'\$(\d+([.,]\d+)?)');
  static final RegExp _kCurrencyRegex = RegExp(r'(\d+([.,]\d+)?)\s*k\b', caseSensitive: false);
  static final RegExp _multiSpaceRegex = RegExp(r'\s+');
  static final RegExp _codeBlockRegex = RegExp(r'```[\s\S]*?```');
  static final RegExp _inlineCodeRegex = RegExp(r'`([^`]+)`');
  static final RegExp _markdownLinkRegex = RegExp(r'\[([^\]]+)\]\([^\)]+\)');
  static final RegExp _boldItalicRegex = RegExp(r'[*_]{1,3}([^*_]+)[*_]{1,3}');
  static final RegExp _headerRegex = RegExp(r'^[#]{1,6}\s+', multiLine: true);
  static final RegExp _bulletDashRegex = RegExp(r'^\s*[-*+]\s+', multiLine: true);
  static final RegExp _numberedStepRegex = RegExp(r'^\s*\d+\.\s+', multiLine: true);
  static final RegExp _ellipsisRegex = RegExp(r'\.{3,}');
  static final RegExp _punctSpacingRegex = RegExp(r'([,;:—–])([^\s])');
  static final RegExp _questionMarkRegex = RegExp(r'\?+');
  static final RegExp _exclamationMarkRegex = RegExp(r'!+');
  static final RegExp _isolatedDigitsRegex = RegExp(r'\b\d+\b');

  static final List<MapEntry<RegExp, String>> _compiledUnits = _units.entries.map((entry) {
    return MapEntry(
      RegExp(r'(\d+([.,]\d+)?)\s*' + RegExp.escape(entry.key) + r'(?=[^\w]|$)'),
      entry.value,
    );
  }).toList();

  static final List<MapEntry<RegExp, String>> _compiledAbbreviations = _abbreviations.entries.map((entry) {
    return MapEntry(
      RegExp(r'(^|[^\w])' + RegExp.escape(entry.key) + r'(?=[^\w]|$)'),
      entry.value,
    );
  }).toList();

  /// Main entry point: normalizes text into natural, easy-to-pronounce Vietnamese speech.
  static String normalize(
    String rawText, {
    String emotion = 'natural',
    bool addPauses = true,
  }) {
    if (rawText.trim().isEmpty) return '';

    String text = rawText;

    // 1. Strip Markdown formatting (bold, italics, links, code fences, headers)
    text = _stripMarkdown(text);

    // 2. Expand Dates: e.g., 30/10/2026 or 30-10-2026 -> ngày 30 tháng 10 năm 2026
    text = text.replaceAllMapped(
      _dateRegex,
      (m) => 'ngày ${m[1]} tháng ${m[2]} năm ${m[3]}',
    );

    // 3. Expand Times: e.g., 18:30 or 08:45 -> 18 giờ 30 phút
    text = text.replaceAllMapped(
      _timeRegex,
      (m) => '${m[1]} giờ ${m[2]} phút',
    );

    // 4. Currency and Percentage with numbers
    text = text.replaceAllMapped(
      _dollarRegex,
      (m) => '${m[1]} đô la Mỹ',
    );

    text = text.replaceAllMapped(
      _kCurrencyRegex,
      (m) => '${m[1]} nghìn',
    );

    // 5. Expand Units with attached numbers (precompiled)
    for (final entry in _compiledUnits) {
      text = text.replaceAllMapped(
        entry.key,
        (m) => '${m[1]} ${entry.value}',
      );
    }

    // 6. Expand Abbreviations (precompiled)
    for (final entry in _compiledAbbreviations) {
      text = text.replaceAllMapped(
        entry.key,
        (m) => '${m[1]}${entry.value}',
      );
    }

    // 7. Convert remaining isolated digits to Vietnamese words
    text = _convertNumbersToWords(text);

    // 8. Pace regulation & natural conversational pausing
    if (addPauses) {
      text = _injectConversationalPauses(text, emotion: emotion);
    }

    // Clean multiple spaces and return
    return text.replaceAll(_multiSpaceRegex, ' ').trim();
  }

  /// Removes Markdown formatting to prevent TTS reading raw symbols
  static String _stripMarkdown(String input) {
    var out = input;
    out = out.replaceAll(_codeBlockRegex, ' đoạn mã ');
    out = out.replaceAll(_inlineCodeRegex, r'$1');
    out = out.replaceAll(_markdownLinkRegex, r'$1');
    out = out.replaceAll(_boldItalicRegex, r'$1');
    out = out.replaceAll(_headerRegex, '');
    out = out.replaceAll(_bulletDashRegex, ', ');
    out = out.replaceAll(_numberedStepRegex, ', bước ');
    return out;
  }

  /// Injects conversational breath pauses at punctuation and logical conjunctions
  static String _injectConversationalPauses(String text, {String emotion = 'natural'}) {
    var out = text;

    // Expand ellipses ... into a thoughtful pause
    out = out.replaceAll(_ellipsisRegex, '... , ');

    // Ensure space after commas, semicolons, colons
    out = out.replaceAllMapped(_punctSpacingRegex, (m) => '${m[1]} ${m[2]}');

    // Emphasize question intonation
    out = out.replaceAllMapped(_questionMarkRegex, (m) => '? , ');

    // Emphasize exclamation
    out = out.replaceAllMapped(_exclamationMarkRegex, (m) => '! , ');

    // Inject breathing micro-pauses at natural Vietnamese discourse markers
    const markers = [
      'Tuy nhiên,',
      'Do đó,',
      'Bởi vì,',
      'Mặt khác,',
      'Hơn nữa,',
      'Đặc biệt là,',
      'Cụ thể là,',
      'Tóm lại,',
      'Chính vì vậy,',
      'Ví dụ như,',
    ];
    for (final marker in markers) {
      out = out.replaceAll(marker, '$marker , ');
    }

    // Emotion-specific pause adjustment
    if (emotion == 'storytelling') {
      out = out.replaceAll('. ', '... , ');
    } else if (emotion == 'calm' || emotion == 'empathetic') {
      out = out.replaceAll(', ', ', , ');
    }

    return out;
  }

  /// Converts isolated numerical digits into written Vietnamese words
  static String _convertNumbersToWords(String text) {
    return text.replaceAllMapped(_isolatedDigitsRegex, (m) {
      final numStr = m[0]!;
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
