import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/voice/elevenlabs_service.dart';
import '../../../../services/voice/native_media_service.dart';
import '../../data/models/voice_model.dart';

class CreateCustomVoiceDialog extends StatefulWidget {
  final String elevenLabsApiKey;
  final Function(VoiceModel voice) onVoiceCreated;

  const CreateCustomVoiceDialog({
    super.key,
    required this.elevenLabsApiKey,
    required this.onVoiceCreated,
  });

  @override
  State<CreateCustomVoiceDialog> createState() => _CreateCustomVoiceDialogState();
}

class _CreateCustomVoiceDialogState extends State<CreateCustomVoiceDialog> {
  final NativeMediaService _mediaService = NativeMediaService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ElevenLabsService _elevenLabsService = ElevenLabsService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _gender = 'female';
  String _accent = 'north';
  String _category = 'gentle';
  bool _useElevenLabs = false;
  bool _hasConsent = false;

  String? _selectedFilePath;
  bool _isExtracting = false;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  bool _isPlayingSample = false;
  bool _isSubmitting = false;
  AudioQualityReport? _qualityReport;

  @override
  void initState() {
    super.initState();
    _useElevenLabs = widget.elevenLabsApiKey.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _mediaService.stopAudio();
    super.dispose();
  }

  Future<void> _pickFile() async {
    await _stopAudio();
    final pickedPath = await _mediaService.pickMediaFile(type: 'all');
    if (pickedPath == null || pickedPath.isEmpty) return;

    final ext = pickedPath.split('.').last.toLowerCase();
    final isVideo = ['mp4', 'mov', 'mkv', '3gp', 'avi'].contains(ext);

    String finalAudioPath = pickedPath;

    if (isVideo) {
      setState(() {
        _isExtracting = true;
      });

      try {
        final tempDir = await getTemporaryDirectory();
        final outAudioPath =
            '${tempDir.path}/extracted_${DateTime.now().millisecondsSinceEpoch}.m4a';

        final extracted = await _mediaService.extractAudioFromVideo(
          videoPath: pickedPath,
          outputPath: outAudioPath,
        );

        if (extracted != null && File(extracted).existsSync()) {
          finalAudioPath = extracted;
        } else {
          throw Exception('Trích xuất âm thanh thất bại');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi tách audio từ video: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() => _isExtracting = false);
        return;
      } finally {
        if (mounted) setState(() => _isExtracting = false);
      }
    }

    final report = await _mediaService.analyzeAudioQuality(finalAudioPath);
    setState(() {
      _selectedFilePath = finalAudioPath;
      _qualityReport = report;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = 'Giọng ${ext.toUpperCase()} (${report.durationSeconds.toInt()}s)';
      }
    });
  }

  Future<void> _toggleRecording() async {
    await _stopAudio();

    if (_isRecording) {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null && File(path).existsSync()) {
        final report = await _mediaService.analyzeAudioQuality(path);
        setState(() {
          _selectedFilePath = path;
          _qualityReport = report;
          if (_nameController.text.trim().isEmpty) {
            _nameController.text = 'Giọng thu trực tiếp (${report.durationSeconds.toInt()}s)';
          }
        });
      }
    } else {
      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng cấp quyền Microphone để ghi âm.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/live_clone_${DateTime.now().millisecondsSinceEpoch}.m4a';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      );

      await _audioRecorder.start(config, path: path);

      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
        _selectedFilePath = null;
        _qualityReport = null;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordSeconds++;
        });
        if (_recordSeconds >= 60) {
          _toggleRecording();
        }
      });
    }
  }

  Future<void> _toggleAudioPreview() async {
    if (_selectedFilePath == null) return;

    if (_isPlayingSample) {
      await _stopAudio();
    } else {
      setState(() => _isPlayingSample = true);
      await _mediaService.playAudio(
        _selectedFilePath!,
        onCompleted: () {
          if (mounted) setState(() => _isPlayingSample = false);
        },
      );
    }
  }

  Future<void> _stopAudio() async {
    await _mediaService.stopAudio();
    if (mounted) setState(() => _isPlayingSample = false);
  }

  Future<void> _createVoice() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên cho giọng nói cá nhân.')),
      );
      return;
    }

    if (_selectedFilePath == null || !File(_selectedFilePath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn file âm thanh hoặc ghi âm mẫu giọng.')),
      );
      return;
    }

    if (!_hasConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng xác nhận quyền sở hữu hoặc sự đồng ý của chủ sở hữu giọng nói.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? remoteVoiceId;
      String engine = 'custom';

      if (_useElevenLabs && widget.elevenLabsApiKey.trim().isNotEmpty) {
        // Voice Cloning via ElevenLabs Instant Voice Cloning
        remoteVoiceId = await _elevenLabsService.cloneVoice(
          name: name,
          description: _descController.text.trim().isNotEmpty
              ? _descController.text.trim()
              : 'PolyVoice AI Custom Voice',
          audioFile: File(_selectedFilePath!),
          apiKey: widget.elevenLabsApiKey.trim(),
        );
        engine = 'elevenlabs';
      }

      final newVoice = VoiceModel(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : 'Giọng nói cá nhân tạo từ mẫu âm thanh ${_qualityReport?.format ?? "Audio"}',
        gender: _gender,
        accent: _accent,
        category: _category,
        engineType: engine,
        remoteVoiceId: remoteVoiceId,
        referenceAudioPath: _selectedFilePath,
        isCustom: true,
        createdAt: DateTime.now(),
        defaultSpeed: 0.88,
        defaultPitch: _gender == 'female' ? 1.05 : 0.96,
        emotionPreset: 'natural',
        sampleText: 'Xin chào! Đây là giọng nói cá nhân của mình, rất vui được trò chuyện cùng bạn.',
      );

      widget.onVoiceCreated(newVoice);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Đã tạo thành công giọng nói "$name"!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.darkCard,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentPink.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.record_voice_over, color: AppColors.accentPink, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tạo Giọng Nói Cá Nhân',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Audio Input Method Tabs
              const Text(
                '1. CHỌN MẪU ÂM THANH / VIDEO THAM CHIẾU',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isExtracting || _isRecording ? null : _pickFile,
                      icon: _isExtracting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file, size: 18),
                      label: Text(_isExtracting ? 'Đang tách audio...' : 'Chọn File (Audio/Video)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isExtracting ? null : _toggleRecording,
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 18),
                      label: Text(_isRecording ? 'Dừng (${_recordSeconds}s)' : 'Ghi âm trực tiếp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRecording ? AppColors.error : AppColors.accentPink,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Audio Quality Report Card
              if (_qualityReport != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _qualityReport!.isValid
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _qualityReport!.isValid
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _qualityReport!.isValid ? Icons.check_circle : Icons.warning_amber_rounded,
                                color: _qualityReport!.isValid ? AppColors.success : AppColors.warning,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Chất lượng: ${_qualityReport!.qualityLabel} (${_qualityReport!.qualityScore}%)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _qualityReport!.isValid ? AppColors.success : AppColors.warning,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              _isPlayingSample ? Icons.stop_circle : Icons.play_circle_fill,
                              color: AppColors.accentCyan,
                              size: 26,
                            ),
                            tooltip: 'Nghe lại mẫu vừa chọn',
                            onPressed: _toggleAudioPreview,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Định dạng: ${_qualityReport!.format} • Thời lượng: ${_qualityReport!.durationSeconds.toStringAsFixed(1)}s • Dung lượng: ${(_qualityReport!.fileSizeBytes / 1024).toStringAsFixed(0)} KB',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      if (_qualityReport!.recommendation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '💡 ${_qualityReport!.recommendation}',
                          style: const TextStyle(fontSize: 11, color: Colors.white70, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Voice Details
              const Text(
                '2. THÔNG TIN GIỌNG NÓI',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Tên giọng nói (VD: Minh Quân, Giọng Đọc Của Tôi)',
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _descController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Mô tả đặc điểm (VD: Trầm ấm, điềm tĩnh, đọc tin tức)',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 12),

              // Gender & Accent Dropdowns
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(labelText: 'Giới tính'),
                      dropdownColor: AppColors.darkCard,
                      items: const [
                        DropdownMenuItem(value: 'female', child: Text('Nữ')),
                        DropdownMenuItem(value: 'male', child: Text('Nam')),
                        DropdownMenuItem(value: 'neutral', child: Text('Trung tính')),
                      ],
                      onChanged: (val) => setState(() => _gender = val!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _accent,
                      decoration: const InputDecoration(labelText: 'Vùng miền'),
                      dropdownColor: AppColors.darkCard,
                      items: const [
                        DropdownMenuItem(value: 'north', child: Text('Bắc (Hà Nội)')),
                        DropdownMenuItem(value: 'south', child: Text('Nam (Sài Gòn)')),
                        DropdownMenuItem(value: 'central', child: Text('Miền Trung')),
                        DropdownMenuItem(value: 'intl', child: Text('Quốc tế')),
                      ],
                      onChanged: (val) => setState(() => _accent = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Engine Choice
              if (widget.elevenLabsApiKey.trim().isNotEmpty) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sử dụng ElevenLabs AI Cloning', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Nhân bản giọng nói siêu chân thực qua API cá nhân.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _useElevenLabs,
                  onChanged: (val) => setState(() => _useElevenLabs = val),
                ),
                const SizedBox(height: 8),
              ],

              // Consent Checkbox (Legal & Safety requirement)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _hasConsent,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _hasConsent = val ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        'Tôi cam kết sở hữu hoặc đã có sự đồng ý hợp pháp của chủ sở hữu giọng nói này. PolyVoice AI cam kết bảo vệ dữ liệu âm thanh cá nhân.',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Submit & Cancel
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _createVoice,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.add_task),
                    label: Text(_isSubmitting ? 'Đang khởi tạo...' : 'Tạo giọng nói'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
