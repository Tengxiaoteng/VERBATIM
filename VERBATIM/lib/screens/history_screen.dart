import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/history_entry.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  final List<HistoryEntry> entries;
  final VoidCallback onBack;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function() onClearAll;

  const HistoryScreen({
    super.key,
    required this.entries,
    required this.onBack,
    required this.onDelete,
    required this.onClearAll,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _copiedId;

  List<HistoryEntry> get _sorted =>
      [...widget.entries].reversed.toList();

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '今天 ${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';
    } else if (diff.inDays == 1) {
      return '昨天 ${_pad(dt.hour)}:${_pad(dt.minute)}';
    } else if (diff.inDays < 7) {
      const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      return '周${weekdays[dt.weekday - 1]} ${_pad(dt.hour)}:${_pad(dt.minute)}';
    } else {
      return '${dt.month}/${dt.day} ${_pad(dt.hour)}:${_pad(dt.minute)}';
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    return '${seconds ~/ 60}m${seconds % 60}s';
  }

  void _copyText(HistoryEntry entry) {
    final text = entry.processedText.isNotEmpty
        ? entry.processedText
        : entry.rawText;
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copiedId = entry.id);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedId = null);
    });
  }

  void _showDeleteConfirm(HistoryEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFE2E8F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          side: const BorderSide(color: AppTheme.borderDefault, width: 0.8),
        ),
        title: const Text(
          '删除记录',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: const Text(
          '确定删除这条记录？',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              '取消',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete(entry.id);
            },
            child: const Text(
              '删除',
              style: TextStyle(color: AppTheme.recordingRed),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFE2E8F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          side: const BorderSide(color: AppTheme.borderDefault, width: 0.8),
        ),
        title: const Text(
          '清空历史',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: const Text(
          '确定清空所有历史记录？此操作不可撤销。',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              '取消',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onClearAll();
            },
            child: const Text(
              '清空',
              style: TextStyle(color: AppTheme.recordingRed),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: _buildPanel());
  }

  Widget _buildPanel() {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderDefault, width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppTheme.borderDefault,
                ),
                Expanded(child: _buildList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onBack,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0x0D2060C8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.borderSubtle,
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.accentGradient.createShader(bounds),
            child: const Icon(
              Icons.history_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '历史记录',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (widget.entries.isNotEmpty)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _showClearConfirm,
                child: const Text(
                  '清空',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final entries = _sorted;
    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 44,
              color: AppTheme.borderDefault,
            ),
            SizedBox(height: 12),
            Text(
              '暂无历史记录',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13.5),
            ),
            SizedBox(height: 5),
            Text(
              '按下快捷键开始录音后会自动保存',
              style: TextStyle(color: AppTheme.borderDefault, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _buildEntryCard(entries[index]),
    );
  }

  Widget _buildEntryCard(HistoryEntry entry) {
    final displayText = entry.processedText.isNotEmpty
        ? entry.processedText
        : entry.rawText;
    final hasProcessed = entry.processedText.isNotEmpty &&
        entry.processedText != entry.rawText;
    final isCopied = _copiedId == entry.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x0A2060C8),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部行：时间 + 时长 + 操作按钮
          Row(
            children: [
              Text(
                _formatTime(entry.timestamp),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              if (entry.durationSeconds > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x0D2060C8),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppTheme.borderSubtle,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    _formatDuration(entry.durationSeconds),
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              if (hasProcessed) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppTheme.accentPrimary.withValues(alpha: 0.22),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      color: AppTheme.accentPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // 复制按钮
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _copyText(entry),
                  child: Icon(
                    isCopied
                        ? Icons.check_rounded
                        : Icons.copy_rounded,
                    size: 14,
                    color: isCopied
                        ? AppTheme.successGreen
                        : AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 删除按钮
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _showDeleteConfirm(entry),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 14,
                    color: AppTheme.borderDefault,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 主文字
          Text(
            displayText,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          // 原文预览（AI处理后才显示）
          if (hasProcessed) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 0.5, color: AppTheme.borderSubtle),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '原文  ',
                  style: TextStyle(
                    color: AppTheme.borderDefault,
                    fontSize: 10.5,
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.rawText,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
