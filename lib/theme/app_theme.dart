import 'package:flutter/material.dart';

/// 设计 token 体系 — 对标 Claude 设计语言
/// 暖灰中性色、克制的强调色使用、清晰的字体层级

// ── 间距 ──────────────────────────────────────────
abstract class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

// ── 圆角 ──────────────────────────────────────────
abstract class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double full = 999;
}

// ── 课程表专用尺寸 ──────────────────────────────────
abstract class ScheduleDim {
  static const double periodHeight = 58;
  static const double timeColumnWidth = 48;
  static const double dayHeaderHeight = 30;
  static const double weekChipWidth = 42;
  static const double courseCardRadius = 8;
}

/// 构建浅色主题
ThemeData buildLightTheme(Color seed, {bool useSystemFont = false}) {
  final cs = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );

  // 用暖色覆盖 Material 3 默认的冷蓝灰表面
  final warmCs = cs.copyWith(
    surface: const Color(0xFFFDFDFC), // 米白纸张背景
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFF7F6F3),
    surfaceContainer: const Color(0xFFF2EFEA),
    surfaceContainerHigh: const Color(0xFFECEAE4),
    surfaceContainerHighest: const Color(0xFFE6E3DB),
    onSurface: const Color(0xFF1C1B1F),
    onSurfaceVariant: const Color(0xFF6B6B6B),
    outline: const Color(0xFFBDBDBD),
    outlineVariant: const Color(0xFFE0E0E0),
  );

  return _buildTheme(warmCs, useSystemFont);
}

/// 构建深色主题
ThemeData buildDarkTheme(Color seed, {bool useSystemFont = false}) {
  final cs = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

  final warmCs = cs.copyWith(
    surface: const Color(0xFF141413),
    surfaceContainerLowest: const Color(0xFF0F0F0E),
    surfaceContainerLow: const Color(0xFF1C1C1A),
    surfaceContainer: const Color(0xFF242422),
    surfaceContainerHigh: const Color(0xFF2E2E2B),
    surfaceContainerHighest: const Color(0xFF393936),
    onSurface: const Color(0xFFE5E5E2),
    onSurfaceVariant: const Color(0xFF9E9E9B),
    outline: const Color(0xFF525250),
    outlineVariant: const Color(0xFF3A3A38),
  );

  return _buildTheme(warmCs, useSystemFont);
}

ThemeData _buildTheme(ColorScheme cs, bool useSystemFont) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    brightness: cs.brightness,
    scaffoldBackgroundColor: cs.surface,
    fontFamily: useSystemFont ? null : 'Newsreader',
    fontFamilyFallback: useSystemFont ? null : const <String>['LXGWWenKai'],

    // ── AppBar ──
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      titleTextStyle: useSystemFont
          ? TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              letterSpacing: -0.2,
            )
          : TextStyle(
              fontFamily: 'Newsreader',
              fontFamilyFallback: const <String>['LXGWWenKai'],
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              letterSpacing: -0.2,
            ),
    ),

    // ── Card ──
    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── 输入框 ──
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md,
      ),
    ),

    // ── 底部弹窗 ──
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      showDragHandle: true,
    ),

    // ── 对话框 ──
    dialogTheme: DialogThemeData(
      backgroundColor: cs.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),

    // ── ListTile ──
    listTileTheme: ListTileThemeData(
      iconColor: cs.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg),
    ),

    // ── Divider ──
    dividerTheme: DividerThemeData(
      color: cs.outlineVariant,
      thickness: 0.5,
      space: 0,
    ),

    // ── Chip ──
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      side: BorderSide(color: cs.outlineVariant),
    ),

    // ── SegmentedButton ──
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    ),

    // ── FloatingActionButton ──
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),

    // ── SnackBar ──
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cs.inverseSurface,
      contentTextStyle: TextStyle(color: cs.onInverseSurface, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
  );
}
