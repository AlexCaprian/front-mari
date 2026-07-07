import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Uma extensão de tema customizada para fornecer cores semânticas adicionais
/// (como positivo/verde e negativo/vermelho) e sombras de alto contraste.
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color? positiveColor;
  final Color? negativeColor;
  final List<BoxShadow>? premiumShadow;

  const AppThemeExtension({
    required this.positiveColor,
    required this.negativeColor,
    required this.premiumShadow,
  });

  @override
  AppThemeExtension copyWith({
    Color? positiveColor,
    Color? negativeColor,
    List<BoxShadow>? premiumShadow,
  }) {
    return AppThemeExtension(
      positiveColor: positiveColor ?? this.positiveColor,
      negativeColor: negativeColor ?? this.negativeColor,
      premiumShadow: premiumShadow ?? this.premiumShadow,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      positiveColor: Color.lerp(positiveColor, other.positiveColor, t),
      negativeColor: Color.lerp(negativeColor, other.negativeColor, t),
      premiumShadow: other.premiumShadow,
    );
  }
}

/// Classe principal que define as diretrizes visuais, fontes, cores e sombras da aplicação.
class AppTheme {
  // Paleta de Cores Coerente e Premium
  static const Color primaryColor = Color(0xFF6F35A5); // Roxo de Destaque
  static const Color primaryLightColor = Color(
    0xFFF1E6FF,
  ); // Roxo Claro para Fundos
  static const Color backgroundColor = Colors.white; // Fundo Branco Absoluto
  static const Color textColor = Color(
    0xFF111111,
  ); // Preto de Alto Contraste para legibilidade

  // Cores Semânticas
  static const Color positiveColor = Color.fromARGB(
    255,
    54,
    221,
    66,
  ); // Verde Positivo (Alto Contraste)
  static const Color negativeColor = Color.fromARGB(
    255,
    255,
    69,
    69,
  ); // Vermelho Negativo (Alto Contraste)

  // Sombras com Excelente Contraste (Cria profundidade clara com preto sem parecer sujo)
  static List<BoxShadow> get contrastShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      blurRadius: 10,
      spreadRadius: 1,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 3,
      spreadRadius: -1,
      offset: const Offset(0, 2),
    ),
  ];

  /// Definição do Tema Claro da Aplicação
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,

      // Esquema de Cores Material Design 3
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: primaryColor,
        onSecondary: Colors.white,
        error: negativeColor,
        onError: Colors.white,
        surface: backgroundColor,
        onSurface: textColor,
      ),

      // Tipografia (Inter) com cor preta de alto contraste forçada em todas as variantes
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textColor),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textColor),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: textColor),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Estilo Global da AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0, // Impede mudança de cor ao rolar
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Estilo dos Cartões (Cards) com foco nas sombras de bom contraste
      cardTheme: CardThemeData(
        color: backgroundColor,
        elevation:
            0, // Usaremos decoração manual para obter a sombra exata da extensão se necessário, ou podemos usar a sombra padrão
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.black.withValues(
              alpha: 0.08,
            ), // Delicada linha limitadora
            width: 1.5,
          ),
        ),
      ),

      // Estilo dos Botões Elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Estilo dos Botões com Borda (Outlined)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Configuração do Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // Extensão de Cores Personalizadas para acesso direto no código
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtension(
          positiveColor: positiveColor,
          negativeColor: negativeColor,
          premiumShadow: contrastShadow,
        ),
      ],
    );
  }
}
