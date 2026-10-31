import 'package:flutter/material.dart';

/// 一套可整体切换的颜色表。浅色值与历史版本完全一致；
/// 深色值是同层级的降亮度映射，供系统深色模式使用。
class AppPalette {
  const AppPalette({
    required this.paper,
    required this.surface,
    required this.ink,
    required this.onInk,
    required this.onInkMuted,
    required this.muted,
    required this.line,
    required this.softFill,
    required this.positive,
    required this.positiveFill,
    required this.negative,
    required this.negativeFill,
    required this.warning,
    required this.warningFill,
  });

  final Color paper;
  final Color surface;
  final Color ink;
  final Color onInk;
  final Color onInkMuted;
  final Color muted;
  final Color line;
  final Color softFill;
  final Color positive;
  final Color positiveFill;
  final Color negative;
  final Color negativeFill;
  final Color warning;
  final Color warningFill;

  static const light = AppPalette(
    paper: Color(0xFFF4F3EF),
    surface: Color(0xFFFCFBF8),
    ink: Color(0xFF171715),
    onInk: Colors.white,
    onInkMuted: Color(0xFFBDBDB7),
    muted: Color(0xFF74746E),
    line: Color(0xFFD9D8D1),
    softFill: Color(0xFFEAE9E3),
    positive: Color(0xFF216E4E),
    positiveFill: Color(0xFFE1EFE7),
    negative: Color(0xFFAA2E25),
    negativeFill: Color(0xFFF7E2E0),
    warning: Color(0xFF765A16),
    warningFill: Color(0xFFF1E7CD),
  );

  static const dark = AppPalette(
    paper: Color(0xFF121210),
    surface: Color(0xFF1C1C19),
    ink: Color(0xFFE6E5DE),
    onInk: Color(0xFF171715),
    onInkMuted: Color(0xFF8F8E85),
    muted: Color(0xFF9A9990),
    line: Color(0xFF34342E),
    softFill: Color(0xFF27271F),
    positive: Color(0xFF82C99C),
    positiveFill: Color(0xFF20342A),
    negative: Color(0xFFE59087),
    negativeFill: Color(0xFF3A2421),
    warning: Color(0xFFD9BD70),
    warningFill: Color(0xFF372F1C),
  );
}

/// 全局当前色表。`KuangshuatiApp` 的 builder 会在每次主题重建时
/// 按系统深浅模式同步它；页面代码仍统一读 `AppColors.xxx`。
abstract final class AppColors {
  static AppPalette current = AppPalette.light;

  /// 当前是否深色主题。
  ///
  /// 题库里的公式图是白底黑字导出的灰度图（实测最亮像素仅 #585858），
  /// 直接放在深色底上会和背景融在一起，分母基本看不清，
  /// 所以深色模式下需要给这类图做反色/提亮。
  static bool get isDark => current == AppPalette.dark;

  static Color get paper => current.paper;
  static Color get surface => current.surface;
  static Color get ink => current.ink;
  static Color get onInk => current.onInk;
  static Color get onInkMuted => current.onInkMuted;
  static Color get muted => current.muted;
  static Color get line => current.line;
  static Color get softFill => current.softFill;
  static Color get positive => current.positive;
  static Color get positiveFill => current.positiveFill;
  static Color get negative => current.negative;
  static Color get negativeFill => current.negativeFill;
  static Color get warning => current.warning;
  static Color get warningFill => current.warningFill;
}

ThemeData buildAppTheme({bool dark = false}) {
  final palette = dark ? AppPalette.dark : AppPalette.light;
  final scheme = dark
      ? ColorScheme.dark(
          primary: palette.ink,
          onPrimary: palette.onInk,
          secondary: palette.ink,
          onSecondary: palette.onInk,
          surface: palette.surface,
          onSurface: palette.ink,
          error: palette.negative,
          onError: palette.onInk,
          outline: palette.line,
          outlineVariant: palette.softFill,
        )
      : ColorScheme.light(
          primary: palette.ink,
          onPrimary: palette.onInk,
          secondary: palette.ink,
          onSecondary: palette.onInk,
          surface: palette.surface,
          onSurface: palette.ink,
          error: palette.negative,
          onError: palette.onInk,
          outline: palette.line,
          outlineVariant: palette.softFill,
        );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.paper,
    visualDensity: VisualDensity.standard,
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: TextStyle(
        color: palette.ink,
        fontSize: 34,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        color: palette.ink,
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        color: palette.ink,
        fontSize: 21,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: palette.ink,
        fontSize: 18,
        height: 1.35,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: palette.ink,
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        color: palette.ink,
        fontSize: 16,
        height: 1.65,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        color: palette.ink,
        fontSize: 14,
        height: 1.55,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        color: palette.muted,
        fontSize: 12,
        height: 1.45,
        letterSpacing: 0,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.paper,
      foregroundColor: palette.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: palette.ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      // 不写死高度：NavigationBar 的标签会跟着系统字号放大，
      // 固定 68 在 1.3 倍字号下会把“首页”下半个字裁掉。
      height: null,
      backgroundColor: palette.surface,
      indicatorColor: palette.ink,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          // 标签落在指示器药丸之外，底色是 surface，不是 ink。
          // 选中态用 onInk（墨底上的反白字）会变成深灰字配深灰底，
          // 在深色模式下几乎看不见；改用 ink 保持对比。
          color: states.contains(WidgetState.selected)
              ? palette.ink
              : palette.muted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? palette.onInk
              : palette.muted,
          size: 21,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        backgroundColor: palette.ink,
        foregroundColor: palette.onInk,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        foregroundColor: palette.ink,
        side: BorderSide(color: palette.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: palette.muted, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: palette.ink, width: 1.4),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: palette.line,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.ink,
      contentTextStyle: TextStyle(color: palette.onInk, fontSize: 13),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
    ).copyWith(backgroundColor: palette.surface),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
