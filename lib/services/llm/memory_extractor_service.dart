import 'dart:async';
import '../../core/network/network_logger.dart';
import '../../features/chat/data/models/chat_message.dart';
import '../../features/settings/data/models/api_keys_model.dart';
import 'llm_service_factory.dart';

/// Asynchronously extracts core user facts, preferences, and long-term memories
/// in the background without blocking the UI or the main streaming pipeline.
/// Author: FamAn
class MemoryExtractorService {
  final LlmServiceFactory _llmFactory;

  MemoryExtractorService(this._llmFactory);

  /// Analyzes recent conversation messages and returns novel memory notes to persist.
  Future<List<String>> extractNewMemories({
    required List<ChatMessage> recentMessages,
    required List<String> existingNotes,
    required ApiKeysModel apiKeys,
  }) async {
    if (recentMessages.length < 2) return const [];

    // Filter to predominantly user messages to identify user facts
    final userTexts = recentMessages
        .where((m) => m.isUser && m.content.trim().isNotEmpty)
        .map((m) => m.content.trim())
        .toList();

    if (userTexts.isEmpty) return const [];

    // Choose fastest provider available (Groq with fast LPU, or Gemini Flash)
    String providerName = '';
    String apiKey = '';
    String? model;

    if (apiKeys.groqKey.trim().isNotEmpty) {
      providerName = 'groq';
      apiKey = apiKeys.groqKey.trim();
      model = 'llama-3.1-8b-instant';
    } else if (apiKeys.geminiKey.trim().isNotEmpty) {
      providerName = 'gemini';
      apiKey = apiKeys.geminiKey.trim();
      model = 'gemini-2.5-flash';
    } else if (apiKeys.openRouterKey.trim().isNotEmpty) {
      providerName = 'openrouter';
      apiKey = apiKeys.openRouterKey.trim();
    } else {
      return const [];
    }

    final existingListStr = existingNotes.isEmpty
        ? '(Chưa có thông tin nào)'
        : existingNotes.map((n) => '- $n').join('\n');

    final transcriptSnippet = recentMessages
        .map((m) => '${m.isUser ? "Người dùng" : "AI"}: ${m.content}')
        .join('\n');

    const systemPrompt = '''Bạn là một chuyên gia trích xuất thực thể và thông tin cá nhân người dùng.
Nhiệm vụ: Trích xuất thông tin cá nhân, sở thích, mục tiêu, hoàn cảnh sống mới của người dùng (nếu có).
Quy tắc:
1. Chỉ trích xuất TỐI ĐA 1-2 sự kiện quan trọng ngắn gọn (ví dụ: "- Người dùng là kỹ sư phần mềm", "- Người dùng thích cà phê đen").
2. Tuyệt đối KHÔNG trích xuất lại các thông tin đã có trong danh sách ghi nhớ cũ.
3. KHÔNG trích xuất các câu chào xã giao, hỏi đáp thông thường hay quan điểm chung.
4. Nếu không có thông tin cá nhân mới nào cần lưu, chỉ trả về duy nhất từ: NONE.
5. Mỗi thông tin mới bắt đầu bằng "- ".''';

    final promptQuery = '''[Danh sách ghi nhớ cũ]:
$existingListStr

[Đoạn hội thoại vừa diễn ra]:
$transcriptSnippet

Hãy trích xuất thông tin mới nếu có (hoặc trả về NONE):''';

    try {
      final provider = _llmFactory.getProvider(providerName);
      final stream = provider.streamChat(
        history: [
          ChatMessage(
            id: 'memory_extract_prompt',
            content: promptQuery,
            isUser: true,
            timestamp: DateTime.now(),
          ),
        ],
        systemPrompt: systemPrompt,
        apiKey: apiKey,
        model: model,
      );

      final buffer = StringBuffer();
      await for (final token in stream) {
        buffer.write(token);
      }

      final result = buffer.toString().trim();
      if (result.isEmpty || result.toUpperCase().contains('NONE')) {
        return const [];
      }

      final lines = result.split('\n');
      final newNotes = <String>[];

      for (final rawLine in lines) {
        var line = rawLine.trim();
        if (line.startsWith('- ') || line.startsWith('* ')) {
          line = line.substring(2).trim();
        }
        if (line.isNotEmpty && line.length >= 4 && line.length <= 120) {
          // Avoid duplicate or near-duplicate notes
          final lower = line.toLowerCase();
          final isDupe = existingNotes.any((e) => e.toLowerCase() == lower);
          if (!isDupe && !newNotes.contains(line)) {
            newNotes.add(line);
          }
        }
      }

      return newNotes;
    } catch (e) {
      NetworkLogger.logError(
        service: 'MemoryExtractor',
        endpoint: 'background_extraction',
        error: e,
      );
      return const [];
    }
  }
}
