import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 高级毛玻璃风格开关，替代 Material Switch
class GlassSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const GlassSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onChanged != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: AppTheme.dNormal,
          width: 36,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: value
                ? const LinearGradient(
                    colors: [AppTheme.accentPrimary, AppTheme.accentSecondary],
                  )
                : null,
            color: value ? null : const Color(0x18000000),
            border: Border.all(
              color: value
                  ? AppTheme.accentPrimary.withValues(alpha: 0.5)
                  : const Color(0x1A2060C8),
              width: 0.8,
            ),
          ),
          child: AnimatedAlign(
            duration: AppTheme.dNormal,
            alignment:
                value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
