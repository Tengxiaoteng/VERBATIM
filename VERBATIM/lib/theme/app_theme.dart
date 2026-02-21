import 'package:flutter/material.dart';

/// VERBATIM 全局设计系统 — 蓝色浅色风格（匹配 Logo 配色）
class AppTheme {
  AppTheme._();

  // ── 背景色 ─────────────────────────────────────────────────────────
  static const Color backgroundDeep = Color(0xFFE2E8F5); // 冷蓝深灰
  static const Color backgroundBase = Color(0xFFEAEFF9); // 冷蓝基础
  static const Color backgroundMid  = Color(0xFFF1F5FC); // 冷蓝浅白

  // ── 玻璃层 ─────────────────────────────────────────────────────────
  static const Color glassFill     = Color(0x66FFFFFF); // 40% 白色玻璃填充
  static const Color borderDefault = Color(0x1A2060C8); // 10% 皇家蓝边框
  static const Color borderSubtle  = Color(0x0D2060C8); // 5% 皇家蓝边框
  static const Color topHighlight  = Color(0x60FFFFFF); // 38% 白色高光

  // ── 主色调（Logo 蓝） ──────────────────────────────────────────────
  static const Color accentPrimary   = Color(0xFF2060C8); // 皇家蓝
  static const Color accentSecondary = Color(0xFF4A9FE8); // 天蓝
  static const Color accentGlow      = Color(0x402060C8); // 25% 皇家蓝发光

  // ── 语义色 ─────────────────────────────────────────────────────────
  static const Color recordingRed  = Color(0xFFFF4757);
  static const Color recordingGlow = Color(0x40FF4757);
  static const Color successGreen  = Color(0xFF2ECC71);
  static const Color warningOrange = Color(0xFFF39C12);

  // ── 文字色（深海军蓝 on 浅色背景） ────────────────────────────────
  static const Color textPrimary   = Color(0xFF0F1D59); // 深海军蓝
  static const Color textSecondary = Color(0xB3182766); // 70% 深蓝
  static const Color textTertiary  = Color(0x80253580); // 50% 中蓝
  static const Color textMuted     = Color(0x4D3A4E9A); // 30% 蓝灰

  // ── 圆角 ───────────────────────────────────────────────────────────
  static const double radiusSM = 10.0;
  static const double radiusMD = 14.0;
  static const double radiusLG = 18.0;
  static const double radiusXL = 24.0;

  // ── 动画时长 ───────────────────────────────────────────────────────
  static const Duration dFast   = Duration(milliseconds: 150);
  static const Duration dNormal = Duration(milliseconds: 220);
  static const Duration dSlow   = Duration(milliseconds: 350);

  // ── 渐变 ───────────────────────────────────────────────────────────
  /// 主背景渐变 (面板/向导/历史窗口使用)
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xF0EAF0F9), Color(0xEBF1F5FC), Color(0xF0E2E8F5)],
    stops: [0.0, 0.55, 1.0],
  );

  /// 强调色渐变 (按钮/活跃状态)
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentPrimary, accentSecondary],
  );

  // ── 文字样式 ───────────────────────────────────────────────────────
  static const TextStyle display = TextStyle(
    color: textPrimary,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    color: textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w300,
    letterSpacing: -0.5,
  );

  static const TextStyle h3 = TextStyle(
    color: textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body = TextStyle(
    color: textSecondary,
    fontSize: 13,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    color: textTertiary,
    fontSize: 12,
    height: 1.4,
  );

  static const TextStyle sectionLabel = TextStyle(
    color: Color(0xB32060C8), // accentPrimary 70%
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.9,
  );

  static const TextStyle monoText = TextStyle(
    color: textSecondary,
    fontSize: 11,
    fontFamily: 'monospace',
    height: 1.4,
  );

  // ── ThemeData ──────────────────────────────────────────────────────
  static ThemeData themeData() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.light(
        primary: accentPrimary,
        secondary: accentSecondary,
        surface: backgroundMid,
        error: recordingRed,
      ),
      dividerTheme: const DividerThemeData(
        color: borderDefault,
        thickness: 0.5,
        space: 1,
      ),
    );
  }
}
