import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta de NEUROPLAN AI. Cambiar un color aquí lo cambia en toda la app.
class AppColors {
  AppColors._();

  /// Fondo de las pantallas.
  static const Color fondo = Color(0xFF0F0F1B);

  /// Fondo que se ve a los lados cuando la app se abre en una pantalla ancha.
  static const Color fondoExterior = Color(0xFF0A0A13);

  /// Tarjetas y barras.
  static const Color superficie = Color(0xFF1B1B2F);

  /// Elementos que deben destacar sobre una tarjeta: avisos, diálogos, chips.
  static const Color superficieAlta = Color(0xFF26264A);

  /// Líneas y bordes.
  static const Color borde = Color(0xFF2E2E4F);

  /// Color de la marca.
  static const Color primario = Color(0xFF8C7CFF);

  static const Color textoPrincipal = Color(0xFFF2F1FA);
  static const Color textoSecundario = Color(0xFFBDBBD6);
  static const Color textoTenue = Color(0xFF8F8DAA);
}

class AppTheme {
  AppTheme._();

  /// Ancho máximo de la app en pantallas anchas (computador).
  static const double anchoMaximo = 820;

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C6CF0),
      brightness: Brightness.dark,
    );

    final scheme = base.copyWith(
      surface: AppColors.fondo,
      surfaceContainer: AppColors.superficie,
      surfaceContainerHigh: AppColors.superficieAlta,
      surfaceContainerHighest: AppColors.superficie,
      primary: AppColors.primario,
      onSurface: AppColors.textoPrincipal,
      onSurfaceVariant: AppColors.textoSecundario,
      outline: AppColors.borde,
      outlineVariant: AppColors.borde,
    );

    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(
      bodyColor: AppColors.textoPrincipal,
      displayColor: AppColors.textoPrincipal,
    );

    final bordeSuave = BorderSide(color: AppColors.borde);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.fondo,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: AppColors.borde,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.fondo,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textoPrincipal,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.superficie,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: bordeSuave,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.superficie,
        hintStyle: const TextStyle(color: AppColors.textoTenue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: bordeSuave,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primario, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primario,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primario,
          side: BorderSide(color: AppColors.primario.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primario),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.superficie,
        selectedColor: AppColors.primario.withValues(alpha: 0.28),
        side: bordeSuave,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textoPrincipal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.superficieAlta,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textoPrincipal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: bordeSuave,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.superficie,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: AppColors.superficieAlta,
        surfaceTintColor: Colors.transparent,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textoPrincipal,
        ),
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.superficie,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primario.withValues(alpha: 0.24),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final seleccionado = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w400,
            color: seleccionado ? AppColors.primario : AppColors.textoSecundario,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final seleccionado = states.contains(WidgetState.selected);
          return IconThemeData(
            color: seleccionado ? AppColors.primario : AppColors.textoSecundario,
          );
        }),
      ),
    );
  }
}
