import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MEMBER AVATAR
///
/// A circular avatar with a derived color and the member's initials.
/// Used across the Expenses tab, Balances tab, and the Add Expense sheet.
///
/// The color is derived from [colorIndex] (0–9), cycling through a curated
/// palette that works well in both light and dark modes.
/// ─────────────────────────────────────────────────────────────────────────────

// 10-color palette — indices match Member.colorIndex
const _kMemberColors = [
  Color(0xFF4A6CF7), // indigo
  Color(0xFF22C55E), // green
  Color(0xFFF59E0B), // amber
  Color(0xFFEF4444), // red
  Color(0xFF8B5CF6), // violet
  Color(0xFF06B6D4), // cyan
  Color(0xFFEC4899), // pink
  Color(0xFF14B8A6), // teal
  Color(0xFFF97316), // orange
  Color(0xFF6366F1), // purple
];

Color memberColor(int colorIndex) =>
    _kMemberColors[colorIndex.clamp(0, 9)];

/// Circular avatar showing initials + background color derived from colorIndex.
class MemberAvatar extends StatelessWidget {
  final String name;
  final int colorIndex;
  final double size;
  final double fontSize;

  const MemberAvatar({
    super.key,
    required this.name,
    required this.colorIndex,
    this.size = 36,
    this.fontSize = 13,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = memberColor(colorIndex);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.25 : 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: isDark ? color.withOpacity(0.9) : color,
        ),
      ),
    );
  }
}

/// A compact, selectable chip for member multi-select (used in Add Expense).
class MemberSelectChip extends StatelessWidget {
  final String name;
  final int colorIndex;
  final bool isSelected;
  final VoidCallback onTap;

  const MemberSelectChip({
    super.key,
    required this.name,
    required this.colorIndex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = memberColor(colorIndex);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(isDark ? 0.25 : 0.12)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
