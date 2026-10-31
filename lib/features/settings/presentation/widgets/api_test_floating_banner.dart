import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

class ApiTestFloatingBanner extends StatefulWidget {
  const ApiTestFloatingBanner({super.key});

  @override
  State<ApiTestFloatingBanner> createState() => _ApiTestFloatingBannerState();
}

class _ApiTestFloatingBannerState extends State<ApiTestFloatingBanner> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;
  String? _lastNotificationId;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _scheduleAutoDismiss(ApiNotification notif) {
    _autoDismissTimer?.cancel();
    if (notif.type != ApiNotificationType.checking) {
      _autoDismissTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          _animController.reverse().then((_) {
            if (mounted) {
              context.read<SettingsBloc>().add(DismissApiNotificationEvent());
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsBloc, SettingsState>(
      listenWhen: (prev, curr) => prev.activeNotification != curr.activeNotification,
      listener: (context, state) {
        final notif = state.activeNotification;
        if (notif != null) {
          if (_lastNotificationId != notif.id) {
            _lastNotificationId = notif.id;
            _animController.forward(from: 0.0);
          }
          _scheduleAutoDismiss(notif);
        } else {
          _animController.reverse();
        }
      },
      builder: (context, state) {
        final notif = state.activeNotification;
        if (notif == null) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;

        Color bannerColor;
        Color borderColor;
        IconData bannerIcon;
        Color iconColor;

        switch (notif.type) {
          case ApiNotificationType.checking:
            bannerColor = isDark ? const Color(0xFF1E2433) : const Color(0xFFF0F5FF);
            borderColor = AppColors.primaryLight;
            bannerIcon = Icons.sync_rounded;
            iconColor = AppColors.primaryLight;
            break;
          case ApiNotificationType.success:
            bannerColor = isDark ? const Color(0xFF142E20) : const Color(0xFFE8F8EE);
            borderColor = AppColors.success;
            bannerIcon = Icons.check_circle_rounded;
            iconColor = AppColors.success;
            break;
          case ApiNotificationType.error:
            bannerColor = isDark ? const Color(0xFF331A1D) : const Color(0xFFFDF0F1);
            borderColor = AppColors.error;
            bannerIcon = Icons.error_rounded;
            iconColor = AppColors.error;
            break;
          case ApiNotificationType.warning:
            bannerColor = isDark ? const Color(0xFF332712) : const Color(0xFFFFF9ED);
            borderColor = AppColors.warning;
            bannerIcon = Icons.warning_amber_rounded;
            iconColor = AppColors.warning;
            break;
        }

        return Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: bannerColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: notif.type == ApiNotificationType.checking
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                                ),
                              )
                            : Icon(bannerIcon, color: iconColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notif.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: borderColor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    notif.providerName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: borderColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              notif.message,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black54,
                                height: 1.35,
                              ),
                            ),
                            if (notif.modelTested != null && notif.type == ApiNotificationType.success) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Mô hình xác thực: ${notif.modelTested}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: borderColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        onPressed: () {
                          _animController.reverse().then((_) {
                            context.read<SettingsBloc>().add(DismissApiNotificationEvent());
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
