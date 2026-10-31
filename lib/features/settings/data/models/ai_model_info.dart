import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

class AiModelInfo extends Equatable {
  final String id;
  final String name;
  final String provider;
  final String providerName;
  final String description;
  final String contextLength;
  final bool isRecommended;
  final bool isReasoning;
  final String tag;

  const AiModelInfo({
    required this.id,
    required this.name,
    required this.provider,
    required this.providerName,
    required this.description,
    required this.contextLength,
    this.isRecommended = false,
    this.isReasoning = false,
    this.tag = 'Standard',
  });

  @override
  List<Object?> get props => [
        id,
        name,
        provider,
        providerName,
        description,
        contextLength,
        isRecommended,
        isReasoning,
        tag,
      ];
}

class AiModelCatalog {
  static const List<AiModelInfo> allModels = [
    // ----------------------------------------------------
    // GOOGLE GEMINI
    // ----------------------------------------------------
    AiModelInfo(
      id: 'gemini-2.5-flash',
      name: 'Gemini 2.5 Flash',
      provider: AppConstants.providerGemini,
      providerName: 'Google Gemini',
      description: 'Mô hình đa phương thức thế hệ mới nhất của Google. Tốc độ cực nhanh, phản hồi tự nhiên và hỗ trợ ngữ cảnh lớn.',
      contextLength: '1M tokens',
      isRecommended: true,
      tag: 'Khuyên dùng • Tốc độ',
    ),
    AiModelInfo(
      id: 'gemini-2.5-pro',
      name: 'Gemini 2.5 Pro',
      provider: AppConstants.providerGemini,
      providerName: 'Google Gemini',
      description: 'Mô hình suy luận cao cấp nhất của Google, giải quyết các tác vụ tư duy phức tạp, lập trình và sáng tạo chiều sâu.',
      contextLength: '2M tokens',
      isReasoning: true,
      tag: 'Flagship • Suy luận',
    ),
    AiModelInfo(
      id: 'gemini-2.0-flash',
      name: 'Gemini 2.0 Flash',
      provider: AppConstants.providerGemini,
      providerName: 'Google Gemini',
      description: 'Phiên bản Flash 2.0 tối ưu hóa độ trễ thấp, phản hồi gần như tức thì cho đàm thoại giọng nói thời gian thực.',
      contextLength: '1M tokens',
      tag: 'Siêu tốc độ',
    ),
    AiModelInfo(
      id: 'gemini-1.5-flash',
      name: 'Gemini 1.5 Flash',
      provider: AppConstants.providerGemini,
      providerName: 'Google Gemini',
      description: 'Mô hình Flash 1.5 ổn định, chi phí tiết kiệm và cân bằng tốt giữa tốc độ và độ chính xác.',
      contextLength: '1M tokens',
      tag: 'Tiết kiệm',
    ),
    AiModelInfo(
      id: 'gemini-1.5-pro',
      name: 'Gemini 1.5 Pro',
      provider: AppConstants.providerGemini,
      providerName: 'Google Gemini',
      description: 'Mô hình Pro 1.5 xử lý ngữ cảnh cực lớn, phân tích tài liệu và dữ liệu chi tiết.',
      contextLength: '2M tokens',
      tag: 'Ngữ cảnh lớn',
    ),

    // ----------------------------------------------------
    // OPENAI (CHATGPT API)
    // ----------------------------------------------------
    AiModelInfo(
      id: 'gpt-4o',
      name: 'GPT-4o (Omni)',
      provider: AppConstants.providerOpenAi,
      providerName: 'OpenAI',
      description: 'Flagship omni thông minh nhất của OpenAI. Khả năng hiểu ngôn ngữ tiếng Việt xuất sắc, xử lý logic và phong cách tự nhiên.',
      contextLength: '128k tokens',
      isRecommended: true,
      tag: 'Flagship • Thông minh',
    ),
    AiModelInfo(
      id: 'gpt-4o-mini',
      name: 'GPT-4o Mini',
      provider: AppConstants.providerOpenAi,
      providerName: 'OpenAI',
      description: 'Mô hình gọn nhẹ của GPT-4o, tốc độ vượt trội, chi phí cực kỳ tiết kiệm, phù hợp cho đàm thoại hàng ngày.',
      contextLength: '128k tokens',
      tag: 'Nhanh & Tiết kiệm',
    ),
    AiModelInfo(
      id: 'o3-mini',
      name: 'o3-mini (Reasoning)',
      provider: AppConstants.providerOpenAi,
      providerName: 'OpenAI',
      description: 'Mô hình suy luận chuyên sâu thế hệ mới của OpenAI, tư duy từng bước cho bài toán logic, toán học và kỹ thuật.',
      contextLength: '200k tokens',
      isReasoning: true,
      tag: 'Suy luận logic',
    ),
    AiModelInfo(
      id: 'o1',
      name: 'o1 (Deep Reasoning)',
      provider: AppConstants.providerOpenAi,
      providerName: 'OpenAI',
      description: 'Đỉnh cao suy luận khoa học và lập trình của OpenAI, phân tích chuyên sâu trước khi đưa ra câu trả lời.',
      contextLength: '200k tokens',
      isReasoning: true,
      tag: 'Suy luận sâu',
    ),
    AiModelInfo(
      id: 'gpt-4-turbo',
      name: 'GPT-4 Turbo',
      provider: AppConstants.providerOpenAi,
      providerName: 'OpenAI',
      description: 'Mô hình GPT-4 kinh điển với cơ sở tri thức rộng và khả năng tuân thủ nghiêm ngặt chỉ dẫn hệ thống.',
      contextLength: '128k tokens',
      tag: 'Tiêu chuẩn',
    ),

    // ----------------------------------------------------
    // ANTHROPIC CLAUDE
    // ----------------------------------------------------
    AiModelInfo(
      id: 'claude-3-7-sonnet-20250219',
      name: 'Claude 3.7 Sonnet',
      provider: AppConstants.providerAnthropic,
      providerName: 'Anthropic',
      description: 'Mô hình tiên tiến nhất của Anthropic, kết hợp khả năng tư duy lai (hybrid reasoning) và văn phong trò chuyện mượt mà.',
      contextLength: '200k tokens',
      isRecommended: true,
      isReasoning: true,
      tag: 'Mới nhất • Đỉnh cao',
    ),
    AiModelInfo(
      id: 'claude-3-5-sonnet-20241022',
      name: 'Claude 3.5 Sonnet',
      provider: AppConstants.providerAnthropic,
      providerName: 'Anthropic',
      description: 'Mô hình Claude được đánh giá cao nhất về năng lực lập trình, phân tích văn bản và thấu hiểu cảm xúc con người.',
      contextLength: '200k tokens',
      tag: 'Khuyên dùng',
    ),
    AiModelInfo(
      id: 'claude-3-5-haiku-20241022',
      name: 'Claude 3.5 Haiku',
      provider: AppConstants.providerAnthropic,
      providerName: 'Anthropic',
      description: 'Tốc độ phản hồi nhanh như chớp của Anthropic, lý tưởng cho các câu hỏi ngắn và tương tác giọng nói liên tục.',
      contextLength: '200k tokens',
      tag: 'Tốc độ tức thì',
    ),
    AiModelInfo(
      id: 'claude-3-opus-20240229',
      name: 'Claude 3 Opus',
      provider: AppConstants.providerAnthropic,
      providerName: 'Anthropic',
      description: 'Mô hình tư duy chuyên sâu cao cấp cho các bài tiểu luận, nghiên cứu tài liệu và văn phong trang trọng.',
      contextLength: '200k tokens',
      tag: 'Chuyên sâu',
    ),

    // ----------------------------------------------------
    // GROQ CLOUD
    // ----------------------------------------------------
    AiModelInfo(
      id: 'llama-3.3-70b-versatile',
      name: 'Llama 3.3 70B (Groq)',
      provider: AppConstants.providerGroq,
      providerName: 'Groq Cloud',
      description: 'Chạy trên bộ xử lý Groq LPU với tốc độ lên đến 300+ token/giây. Thông minh tương đương GPT-4 với độ trễ tối thiểu.',
      contextLength: '128k tokens',
      isRecommended: true,
      tag: 'Siêu tốc 300 t/s',
    ),
    AiModelInfo(
      id: 'llama-3.1-8b-instant',
      name: 'Llama 3.1 8B (Groq)',
      provider: AppConstants.providerGroq,
      providerName: 'Groq Cloud',
      description: 'Mô hình siêu nhẹ với tốc độ phản hồi gần như tức thì, tiêu hao ít token nhất.',
      contextLength: '128k tokens',
      tag: 'Cực nhanh',
    ),
    AiModelInfo(
      id: 'mixtral-8x7b-32768',
      name: 'Mixtral 8x7B (Groq)',
      provider: AppConstants.providerGroq,
      providerName: 'Groq Cloud',
      description: 'Kiến trúc hỗn hợp chuyên gia (MoE) của Mistral AI chạy cực nhanh trên phần cứng Groq.',
      contextLength: '32k tokens',
      tag: 'Đa nhiệm',
    ),

    // ----------------------------------------------------
    // OPENROUTER & CUSTOM OPENAI-COMPATIBLE
    // ----------------------------------------------------
    AiModelInfo(
      id: 'deepseek/deepseek-r1',
      name: 'DeepSeek R1',
      provider: AppConstants.providerOpenRouter,
      providerName: 'OpenRouter',
      description: 'Mô hình suy luận mã nguồn mở số 1 thế giới hiện nay, hiển thị toàn bộ chuỗi tư duy (Chain of Thought).',
      contextLength: '64k tokens',
      isReasoning: true,
      tag: 'Suy luận mã nguồn mở',
    ),
    AiModelInfo(
      id: 'meta-llama/llama-3.3-70b-instruct',
      name: 'Meta Llama 3.3 70B',
      provider: AppConstants.providerOpenRouter,
      providerName: 'OpenRouter',
      description: 'Llama 3.3 70B thông qua cổng định tuyến OpenRouter, hỗ trợ đa dạng nhà cung cấp hosting.',
      contextLength: '128k tokens',
      isRecommended: true,
      tag: 'Linh hoạt',
    ),
    AiModelInfo(
      id: 'google/gemini-2.0-flash-001',
      name: 'Gemini 2.0 Flash (OpenRouter)',
      provider: AppConstants.providerOpenRouter,
      providerName: 'OpenRouter',
      description: 'Sử dụng Gemini 2.0 Flash thông qua tài khoản OpenRouter duy nhất.',
      contextLength: '1M tokens',
      tag: 'Đa năng',
    ),

    // ----------------------------------------------------
    // AI LOCAL (ON-DEVICE / OLLAMA / LOCAL SERVER)
    // ----------------------------------------------------
    AiModelInfo(
      id: 'qwen2.5:1.5b',
      name: 'Qwen 2.5 1.5B Local',
      provider: AppConstants.providerLocal,
      providerName: 'AI Local',
      description: 'Mô hình nhỏ gọn chạy trực tiếp trên thiết bị hoặc qua Ollama/LocalAI. Hỗ trợ tiếng Việt xuất sắc, yêu cầu RAM từ 3GB - 4GB.',
      contextLength: '32k tokens',
      isRecommended: true,
      tag: '100% Offline • Riêng tư',
    ),
    AiModelInfo(
      id: 'qwen2.5:0.5b',
      name: 'Qwen 2.5 0.5B Local',
      provider: AppConstants.providerLocal,
      providerName: 'AI Local',
      description: 'Mô hình siêu nhẹ (< 400MB) chạy được trên hầu hết mọi điện thoại thông minh, không cần kết nối mạng.',
      contextLength: '32k tokens',
      tag: 'Siêu nhẹ < 400MB',
    ),
    AiModelInfo(
      id: 'smollm2:1.7b',
      name: 'SmolLM2 1.7B Local',
      provider: AppConstants.providerLocal,
      providerName: 'AI Local',
      description: 'Mô hình học máy nhỏ gọn từ HuggingFace, tối ưu hóa để hội thoại nhanh trên thiết bị cá nhân.',
      contextLength: '8k tokens',
      tag: 'HuggingFace',
    ),
    AiModelInfo(
      id: 'gemma2:2b',
      name: 'Gemma 2 2B Local',
      provider: AppConstants.providerLocal,
      providerName: 'AI Local',
      description: 'Mô hình nguồn mở thế hệ 2 của Google DeepMind, độ chính xác cao cho điện thoại có từ 4GB - 6GB RAM.',
      contextLength: '8k tokens',
      tag: 'Google On-Device',
    ),
    AiModelInfo(
      id: 'llama3.2:1b',
      name: 'Llama 3.2 1B Local',
      provider: AppConstants.providerLocal,
      providerName: 'AI Local',
      description: 'Mô hình tối ưu di động của Meta AI, nhẹ và chạy mượt mà không cần GPU rời.',
      contextLength: '128k tokens',
      tag: 'Meta On-Device',
    ),
    AiModelInfo(
      id: 'llama3.2:3b',
      name: 'Llama 3.2 3B Local',
      provider: AppConstants.providerLocal,
      providerName: 'AI Local',
      description: 'Mô hình 3 tỷ tham số chất lượng cao của Meta, khuyến nghị cho thiết bị từ 6GB - 8GB RAM.',
      contextLength: '128k tokens',
      tag: 'Hiệu năng cao',
    ),
  ];

  static List<AiModelInfo> getModelsForProvider(String provider) {
    return allModels.where((m) => m.provider == provider).toList();
  }

  static AiModelInfo? getModelById(String id) {
    try {
      return allModels.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  static String getDefaultModelForProvider(String provider) {
    switch (provider) {
      case AppConstants.providerOpenAi:
        return AppConstants.defaultOpenAiModel;
      case AppConstants.providerAnthropic:
        return AppConstants.defaultAnthropicModel;
      case AppConstants.providerGroq:
        return AppConstants.defaultGroqModel;
      case AppConstants.providerOpenRouter:
        return AppConstants.defaultOpenRouterModel;
      case AppConstants.providerLocal:
        return AppConstants.defaultLocalModel;
      case AppConstants.providerGemini:
      default:
        return AppConstants.defaultGeminiModel;
    }
  }
}
