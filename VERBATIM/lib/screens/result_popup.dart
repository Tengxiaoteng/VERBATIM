import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 自动粘贴失败时的备用弹窗 — 毛玻璃风格，带复制动画
class ResultPopup extends StatefulWidget {
  final String rawText;
  final String processedText;
  final String modeTitle;
  final bool structured;
  final VoidCallback onDismiss;

  const ResultPopup({
    super.key,
    required this.rawText,
    required this.processedText,
    required this.modeTitle,
    required this.structured,
    required this.onDismiss,
  });

  @override
  State<ResultPopup> createState() => _ResultPopupState();
}

class _ResultPopupState extends State<ResultPopup> {
  bool _copied = false;

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.processedText));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _copied = false);
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final sceneLabel = widget.structured ? '场景 B' : '场景 A';
    final resultLabel = widget.structured ? '结构化输出：' : '粘贴结果：';

    return Center(
      child: Container(
        margin: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(color: AppTheme.borderDefault, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentGlow.withValues(alpha: 0.12),
              blurRadius: 28,
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG - 0.8),
          child: Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  color: const Color(0xC8EAF0F9),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 状态行
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1D59),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sceneLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.modeTitle,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          // 关闭按钮
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: widget.onDismiss,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(0x142060C8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 11,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0x0F2060C8),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppTheme.borderSubtle,
                                    width: 0.8,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '你说：',
                                      style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: SelectableText(
                                          '「${widget.rawText}」',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            color: Color(0xFF586179),
                                            height: 1.55,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: widget.structured
                                      ? const Color(0xFF0D0F14)
                                      : const Color(0xFFF1F4FA),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: widget.structured
                                        ? const Color(0x401F7AE0)
                                        : AppTheme.borderSubtle,
                                    width: 0.8,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      resultLabel,
                                      style: TextStyle(
                                        color: widget.structured
                                            ? const Color(0x80FFFFFF)
                                            : AppTheme.textMuted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: SelectableText(
                                          widget.processedText,
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: widget.structured
                                                ? Colors.white
                                                : AppTheme.textPrimary,
                                            height: 1.55,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 操作按钮行
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: _copied ? null : _handleCopy,
                              child: AnimatedContainer(
                                duration: AppTheme.dNormal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  gradient: _copied
                                      ? null
                                      : const LinearGradient(
                                          colors: [
                                            AppTheme.accentPrimary,
                                            AppTheme.accentSecondary,
                                          ],
                                        ),
                                  color: _copied
                                      ? AppTheme.successGreen.withValues(
                                          alpha: 0.18,
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSM,
                                  ),
                                  border: _copied
                                      ? Border.all(
                                          color: AppTheme.successGreen
                                              .withValues(alpha: 0.35),
                                          width: 0.8,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _copied
                                          ? Icons.check_rounded
                                          : Icons.copy_rounded,
                                      size: 13,
                                      color: _copied
                                          ? AppTheme.successGreen
                                          : Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _copied ? '已复制' : '复制',
                                      style: TextStyle(
                                        color: _copied
                                            ? AppTheme.successGreen
                                            : Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // 顶部高光
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
      ),
    );
  }
}
