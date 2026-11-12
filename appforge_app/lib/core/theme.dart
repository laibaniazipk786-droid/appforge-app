import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';

Color hexColor(String? hex, [Color fallback = Colors.transparent]) {
  if (hex == null || hex.isEmpty) return fallback;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// Extra colors from the builder that Material's ColorScheme has no slot for.
class AppColors extends ThemeExtension<AppColors> {
  final Color price;
  final Color sale;
  final Color muted;
  final Color border;
  final Color onPrimary;
  final Color appBarBg;
  final Color appBarFg;

  const AppColors({
    required this.price,
    required this.sale,
    required this.muted,
    required this.border,
    required this.onPrimary,
    required this.appBarBg,
    required this.appBarFg,
  });

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      AppColors(
        price: Theme.of(context).colorScheme.primary,
        sale: Theme.of(context).colorScheme.secondary,
        muted: Colors.grey,
        border: Colors.black12,
        onPrimary: Colors.white,
        appBarBg: Colors.white,
        appBarFg: Colors.black87,
      );

  @override
  AppColors copyWith({Color? price, Color? sale, Color? muted, Color? border, Color? onPrimary, Color? appBarBg, Color? appBarFg}) => AppColors(
        price: price ?? this.price,
        sale: sale ?? this.sale,
        muted: muted ?? this.muted,
        border: border ?? this.border,
        onPrimary: onPrimary ?? this.onPrimary,
        appBarBg: appBarBg ?? this.appBarBg,
        appBarFg: appBarFg ?? this.appBarFg,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      price: Color.lerp(price, other.price, t)!,
      sale: Color.lerp(sale, other.sale, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      appBarBg: Color.lerp(appBarBg, other.appBarBg, t)!,
      appBarFg: Color.lerp(appBarFg, other.appBarFg, t)!,
    );
  }
}

/// Builds the Material theme from the colors chosen in the builder (light or dark palette).
ThemeData buildTheme(AppSettings s, {bool dark = false}) {
  final d = s.dark;
  String pick(String darkKey, String light) {
    final v = toStr(d[darkKey]);
    return dark && v.isNotEmpty ? v : light;
  }

  final primary = hexColor(pick('primary_color', s.primaryColor), const Color(0xFF4F46E5));
  final onPrimary = hexColor(s.onPrimaryColor, Colors.white);
  final secondary = hexColor(pick('secondary_color', s.secondaryColor), const Color(0xFFF59E0B));
  final background = hexColor(pick('background_color', s.backgroundColor), dark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC));
  final surface = hexColor(pick('surface_color', s.surfaceColor), dark ? const Color(0xFF151E2E) : Colors.white);
  final text = hexColor(pick('text_color', s.textColor), dark ? const Color(0xFFE5E7EB) : const Color(0xFF0F172A));
  final muted = hexColor(pick('muted_color', s.mutedColor), const Color(0xFF64748B));
  final border = hexColor(pick('border_color', s.borderColor), dark ? const Color(0xFF263244) : const Color(0xFFE2E8F0));
  final ab = s.appBar;
  final appBarBg = hexColor(pick('appbar_bg_color', ab.bgColor), surface);
  final appBarFg = hexColor(pick('appbar_fg_color', ab.fgColor), text);
  final navBg = hexColor(pick('nav_bg_color', s.navBgColor), surface);
  final navActive = hexColor(s.navActiveColor, primary);
  final navInactive = hexColor(pick('nav_inactive_color', s.navInactiveColor), const Color(0xFF94A3B8));
  final radius = BorderRadius.circular(s.cardRadius);

  final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: dark ? Brightness.dark : Brightness.light).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    secondary: secondary,
    surface: surface,
    onSurface: text,
    outline: border,
    outlineVariant: border,
  );

  TextTheme textTheme;
  try {
    textTheme = GoogleFonts.getTextTheme(s.fontFamily, (dark ? ThemeData.dark() : ThemeData.light()).textTheme);
  } catch (_) {
    textTheme = (dark ? ThemeData.dark() : ThemeData.light()).textTheme;
  }
  textTheme = textTheme.apply(bodyColor: text, displayColor: text);

  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    textTheme: textTheme,
    dividerColor: border,
    dividerTheme: DividerThemeData(color: border),
    extensions: [
      AppColors(
        price: hexColor(s.priceColor, primary),
        sale: hexColor(s.saleColor, secondary),
        muted: muted,
        border: border,
        onPrimary: onPrimary,
        appBarBg: appBarBg,
        appBarFg: appBarFg,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBg,
      foregroundColor: appBarFg,
      iconTheme: IconThemeData(color: appBarFg),
      actionsIconTheme: IconThemeData(color: appBarFg),
      elevation: ab.shadow ? 3 : 0,
      shadowColor: Colors.black26,
      scrolledUnderElevation: ab.shadow ? 3 : 0.5,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 18, color: appBarFg),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        minimumSize: const Size(64, 50),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(64, 50),
        side: BorderSide(color: primary),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primary)),
    chipTheme: ChipThemeData(side: BorderSide(color: border)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: primary, width: 1.5)),
      hintStyle: TextStyle(color: muted),
    ),
    badgeTheme: BadgeThemeData(backgroundColor: secondary, textColor: Colors.white),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: navBg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: navActive.withOpacity(0.12),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? navActive : navInactive),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? navActive : navInactive,
        ),
      ),
    ),
  );
}
