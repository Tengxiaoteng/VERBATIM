import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 自动粘贴失败时的备用弹窗 — 毛玻璃风格，带复制动画
class ResultPopup extends StatefulWidget {
  final String text;
  final VoidCallback onDismiss;

  const ResultPopup({super.key, required this.text, required this.onDismiss});

  @override
  State<ResultPopup> createState() => _ResultPopupState();
}

class _ResultPopupState extends State<ResultPopup> {
  bool _copied = false;

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _copied = false);
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(10),
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
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 状态行
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppTheme.successGreen.withValues(
                                  alpha: 0.28,
                                ),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.successGreen,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  '识别完成',
                                  style: TextStyle(
                                    color: AppTheme.successGreen,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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
                                  color: const Color(0x1A2060C8),
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
                      const SizedBox(height: 12),

                      // 识别文字
                      SelectableText(
                        widget.text,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 14),

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
                                        fontSize: 12.5,
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
