import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 280×80px 录音悬浮条 — 毛玻璃风格，随状态切换边框颜色
class RecordingOverlay extends StatefulWidget {
  final bool isRecording;
  final bool isProcessing;
  final int recordSeconds;
  final String? errorMessage;

  const RecordingOverlay({
    super.key,
    required this.isRecording,
    required this.isProcessing,
    required this.recordSeconds,
    this.errorMessage,
  });

  @override
  State<RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<RecordingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color _borderColor() {
    if (widget.errorMessage != null) {
      return AppTheme.recordingRed.withValues(alpha: 0.75);
    }
    if (widget.isRecording) {
      return AppTheme.recordingRed.withValues(alpha: 0.65);
    }
    if (widget.isProcessing) {
      return AppTheme.accentPrimary.withValues(alpha: 0.65);
    }
    return const Color(0x142060C8);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: AppTheme.dNormal,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(color: _borderColor(), width: 1.0),
          boxShadow: widget.isRecording
              ? [
                  BoxShadow(
                    color: AppTheme.recordingRed.withValues(alpha: 0.12),
                    blurRadius: 20,
                    spreadRadius: -2,
                  ),
                ]
              : widget.isProcessing
              ? [
                  BoxShadow(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.10),
                    blurRadius: 20,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL - 1),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Stack(
              children: [
                Container(
                  color: const Color(0xC8EAF0F9),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  child: widget.errorMessage != null
                      ? _buildError()
                      : widget.isProcessing
                      ? _buildProcessing()
                      : _buildRecording(),
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
                          Color(0x26FFFFFF),
                          Color(0x26FFFFFF),
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
      ),
    );
  }

  Widget _buildRecording() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPulseIndicator(),
        const SizedBox(width: 14),
        const Text(
          '录音中',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _fmt(widget.recordSeconds),
          style: const TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 14,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildPulseIndicator() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final outerScale = Tween<double>(begin: 0.5, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
          ),
        );
        final outerOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
          ),
        );
        final midScale = Tween<double>(begin: 0.5, end: 0.72).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.1, 0.65, curve: Curves.easeOut),
          ),
        );
        final midOpacity = Tween<double>(begin: 0.45, end: 0.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.1, 0.65),
          ),
        );

        return SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 外层脉冲圆
              Opacity(
                opacity: outerOpacity.value,
                child: Transform.scale(
                  scale: outerScale.value,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.recordingRed.withValues(alpha: 0.22),
                    ),
                  ),
                ),
              ),
              // 中层脉冲圆
              Opacity(
                opacity: midOpacity.value,
                child: Transform.scale(
                  scale: midScale.value,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.recordingRed.withValues(alpha: 0.38),
                    ),
                  ),
                ),
              ),
              // 实心核心点
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.recordingRed,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProcessing() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppTheme.accentPrimary,
          ),
        ),
        SizedBox(width: 14),
        Text(
          '识别中',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppTheme.recordingRed,
          size: 15,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            widget.errorMessage!,
            style: const TextStyle(color: AppTheme.recordingRed, fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

/// 模式切换提示条
class ModeSwitchOverlay extends StatelessWidget {
  final String message;

  const ModeSwitchOverlay({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(child: ModeSwitchHintCard(message: message));
  }
}

/// 模式切换提示卡片（可在浮窗或页面右下角复用）
class ModeSwitchHintCard extends StatelessWidget {
  final String message;

  const ModeSwitchHintCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: AppTheme.accentPrimary.withValues(alpha: 0.4),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentPrimary.withValues(alpha: 0.14),
            blurRadius: 20,
            spreadRadius: -3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL - 1),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            color: const Color(0xCCEAF0F9),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
