import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 毛玻璃卡片组件 — 用于所有面板/卡片的基础容器
class GlassCard extends StatelessWidget {
  final Widget child;
  final double blurIntensity;
  final double borderRadius;
  final double fillOpacity;
  final double borderOpacity;
  final bool showTopHighlight;
  final bool showGlow;
  final Color? glowColor;
  final EdgeInsets? padding;

  const GlassCard({
    super.key,
    required this.child,
    this.blurIntensity = 12,
    this.borderRadius = AppTheme.radiusMD,
    this.fillOpacity = 0.65,
    this.borderOpacity = 0.10,
    this.showTopHighlight = true,
    this.showGlow = false,
    this.glowColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Color.fromRGBO(32, 96, 200, borderOpacity),
          width: 0.8,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: (glowColor ?? AppTheme.accentGlow).withValues(
                    alpha: 0.15,
                  ),
                  blurRadius: 24,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 0.8),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurIntensity,
                sigmaY: blurIntensity,
              ),
              child: Container(
                width: double.infinity,
                color: Color.fromRGBO(255, 255, 255, fillOpacity),
                padding: padding ?? const EdgeInsets.all(14),
                child: child,
              ),
            ),
            // 顶部高光线
            if (showTopHighlight)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0x3DFFFFFF),
                        Color(0x3DFFFFFF),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.2, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
