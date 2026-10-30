import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFFA29BFE);
  static const Color primaryDark = Color(0xFF4834D4);

  // Accents for Voice Orb / Visualizer
  static const Color accentCyan = Color(0xFF00CEC9);
  static const Color accentPink = Color(0xFFFD79A8);
  static const Color accentPurple = Color(0xFF8E44AD);
  static const Color accentNeon = Color(0xFF00FFA3);

  // Dark Theme Backgrounds & Surfaces
  static const Color darkBackground = Color(0xFF0D0E15);
  static const Color darkSurface = Color(0xFF161824);
  static const Color darkCard = Color(0xFF1F2235);
  static const Color darkCardBorder = Color(0xFF2C3049);

  // Light Theme Backgrounds & Surfaces
  static const Color lightBackground = Color(0xFFF8F9FE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F3FB);
  static const Color lightCardBorder = Color(0xFFE2E6F2);

  // Text Colors
  static const Color textPrimaryDark = Color(0xFFF1F2F6);
  static const Color textSecondaryDark = Color(0xFFA4B0BE);
  static const Color textPrimaryLight = Color(0xFF2D3436);
  static const Color textSecondaryLight = Color(0xFF636E72);

  // Status Colors
  static const Color success = Color(0xFF2ED573);
  static const Color warning = Color(0xFFFFA502);
  static const Color error = Color(0xFFFF4757);

  // Orb State Gradients
  static const List<Color> orbIdleGradient = [
    Color(0xFF6C5CE7),
    Color(0xFF00CEC9),
  ];

  static const List<Color> orbListeningGradient = [
    Color(0xFF00FFA3),
    Color(0xFF00CEC9),
  ];

  static const List<Color> orbThinkingGradient = [
    Color(0xFFFFA502),
    Color(0xFFFF4757),
  ];

  static const List<Color> orbSpeakingGradient = [
    Color(0xFFFD79A8),
    Color(0xFF6C5CE7),
    Color(0xFF00CEC9),
  ];
}
