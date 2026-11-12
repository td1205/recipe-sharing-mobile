import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xfff5f6f1);
  static const olive = Color(0xff343b20);
  static const oliveSoft = Color(0xff667044);
  static const lime = Color(0xffd9e88f);
  static const limeStrong = Color(0xffc9dc68);
  static const limeSurface = Color(0xfff2f6df);
  static const inkMuted = Color(0xff626657);
  static const outline = Color(0xffdfe2d4);
  static const darkSurface = Color(0xff15180f);
  static const white = Color(0xffffffff);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const smMd = 12.0;
  static const md = 16.0;
  static const mdLg = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;
}

abstract final class AppRadii {
  static const small = 12.0;
  static const medium = 18.0;
  static const large = 26.0;
  static const pill = 999.0;
}

abstract final class AppShadows {
  static const soft = <BoxShadow>[
    BoxShadow(color: Color(0x140F1706), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.olive,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.lime,
      onPrimaryContainer: AppColors.olive,
      secondary: AppColors.oliveSoft,
      surface: AppColors.white,
      onSurface: AppColors.olive,
      outline: AppColors.outline,
      surfaceContainerLow: AppColors.limeSurface,
      error: Color(0xffba1a1a),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.olive,
          height: 1.08,
          letterSpacing: -1.0,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.olive,
          height: 1.15,
          letterSpacing: -0.4,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.olive,
          height: 1.2,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          height: 1.45,
          color: AppColors.inkMuted,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          height: 1.4,
          color: AppColors.inkMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: AppColors.oliveSoft, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: AppColors.inkMuted),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.olive,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.lime,
        side: const BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.outline),
    );
  }
}
