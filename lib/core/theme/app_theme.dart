import 'package:flutter/material.dart';

import '../constants/app_color.dart';

/// Thème unique de l'application. Les écrans s'appuient sur les composants
/// Material (Card, FilledButton, ChoiceChip, NavigationBar…) qui prennent
/// automatiquement ce style : pas de style ad hoc dans les écrans.
abstract final class AppTheme {
  static const _radius = 14.0;
  static const _pill = StadiumBorder();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColor.primary,
      primary: AppColor.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColor.primarySoft,
      onPrimaryContainer: AppColor.primaryDark,
      secondary: AppColor.gold,
      secondaryContainer: AppColor.goldLight,
      onSecondaryContainer: AppColor.textPrimary,
      surface: AppColor.surface,
      onSurface: AppColor.textPrimary,
      onSurfaceVariant: AppColor.textSecondary,
      outline: AppColor.border,
      outlineVariant: AppColor.divider,
      error: AppColor.danger,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme.apply(
      bodyColor: AppColor.textPrimary,
      displayColor: AppColor.textPrimary,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: const BorderSide(color: AppColor.border),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColor.background,
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColor.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColor.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: AppColor.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColor.border),
        ),
      ),
      listTileTheme: const ListTileThemeData(iconColor: AppColor.primary),
      dividerTheme: const DividerThemeData(color: AppColor.divider, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColor.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColor.primary, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColor.danger),
        ),
        hintStyle: const TextStyle(color: AppColor.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColor.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: _pill,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: _pill,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColor.primary,
          side: const BorderSide(color: AppColor.border),
          minimumSize: const Size(64, 46),
          shape: _pill,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColor.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColor.textPrimary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColor.primary,
        foregroundColor: Colors.white,
        shape: _pill,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColor.surface,
        selectedColor: AppColor.primary,
        disabledColor: AppColor.divider,
        side: const BorderSide(color: AppColor.border),
        shape: _pill,
        showCheckmark: false,
        labelStyle: WidgetStateTextStyle.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                )
              : const TextStyle(
                  color: AppColor.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColor.surface,
          selectedBackgroundColor: AppColor.primarySoft,
          selectedForegroundColor: AppColor.primaryDark,
          side: const BorderSide(color: AppColor.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColor.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColor.primarySoft,
        elevation: 0,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColor.primary
                : AppColor.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColor.primary
                : AppColor.textSecondary,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColor.primary : null,
        ),
      ),
      badgeTheme: const BadgeThemeData(backgroundColor: AppColor.primary),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColor.primary,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColor.background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColor.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColor.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: AppColor.gold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
    );
  }
}
