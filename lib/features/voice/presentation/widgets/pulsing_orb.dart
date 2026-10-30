import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/pipeline/voice_pipeline_coordinator.dart';

class PulsingOrb extends StatefulWidget {
  final PipelineStatus status;
  final VoidCallback onTap;

  const PulsingOrb({
    super.key,
    required this.status,
    required this.onTap,
  });

  @override
  State<PulsingOrb> createState() => _PulsingOrbState();
}

class _PulsingOrbState extends State<PulsingOrb> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  List<Color> get _currentGradients {
    switch (widget.status) {
      case PipelineStatus.listening:
        return AppColors.orbListeningGradient;
      case PipelineStatus.thinking:
        return AppColors.orbThinkingGradient;
      case PipelineStatus.speaking:
        return AppColors.orbSpeakingGradient;
      case PipelineStatus.error:
        return [AppColors.error, const Color(0xFFFF7675)];
      case PipelineStatus.idle:
      default:
        return AppColors.orbIdleGradient;
    }
  }

  String get _statusLabel {
    switch (widget.status) {
      case PipelineStatus.listening:
        return 'Listening...';
      case PipelineStatus.thinking:
        return 'Thinking...';
      case PipelineStatus.speaking:
        return 'Speaking...';
      case PipelineStatus.error:
        return 'Tap to retry';
      case PipelineStatus.idle:
      default:
        return 'Tap orb to talk';
    }
  }

  IconData get _centerIcon {
    switch (widget.status) {
      case PipelineStatus.listening:
        return Icons.mic;
      case PipelineStatus.thinking:
        return Icons.auto_awesome;
      case PipelineStatus.speaking:
        return Icons.graphic_eq_rounded;
      case PipelineStatus.error:
        return Icons.refresh;
      case PipelineStatus.idle:
      default:
        return Icons.mic_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: 260,
            height: 260,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _pulseController,
                _rotationController,
                _rippleController,
              ]),
              builder: (context, child) {
                final pulse = _pulseController.value;
                final rotation = _rotationController.value * 2 * math.pi;
                final ripple = _rippleController.value;
                final isSpeakingOrListening = widget.status == PipelineStatus.speaking ||
                    widget.status == PipelineStatus.listening;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Ripple 1
                    if (isSpeakingOrListening)
                      Container(
                        width: 170 + (ripple * 90),
                        height: 170 + (ripple * 90),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _currentGradients.first.withValues(
                              alpha: (1.0 - ripple) * 0.4,
                            ),
                            width: 2,
                          ),
                        ),
                      ),

                    // Outer Ripple 2
                    if (isSpeakingOrListening)
                      Container(
                        width: 170 + (((ripple + 0.5) % 1.0) * 80),
                        height: 170 + (((ripple + 0.5) % 1.0) * 80),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _currentGradients.last.withValues(
                              alpha: (1.0 - ((ripple + 0.5) % 1.0)) * 0.3,
                            ),
                            width: 1.5,
                          ),
                        ),
                      ),

                    // Soft Glowing Aura
                    Container(
                      width: 180 + (pulse * 25),
                      height: 180 + (pulse * 25),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _currentGradients.first.withValues(alpha: 0.35 + (pulse * 0.2)),
                            blurRadius: 40 + (pulse * 20),
                            spreadRadius: 10 + (pulse * 10),
                          ),
                        ],
                      ),
                    ),

                    // Rotating Core Orb
                    Transform.rotate(
                      angle: rotation,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              ..._currentGradients,
                              _currentGradients.first,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Inner Shimmer Core
                    Container(
                      width: 135,
                      height: 135,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                          stops: const [0.2, 1.0],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          _centerIcon,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Status Pill Badge
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: _currentGradients.first.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _currentGradients.first.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            _statusLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _currentGradients.first,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
