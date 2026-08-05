import 'package:flutter/material.dart';

/// ============================================================================
/// STABLE THEME LAYER (backward-compatible)
/// ----------------------------------------------------------------------------
/// This file intentionally keeps legacy class names used across old pages:
/// - LearningCyberColors
/// - LearningCyberGradients
/// - InstitutionalColors
/// - DarkModeColors (with success)
///
/// It prevents compile breaks after refactors by preserving public API.
/// ============================================================================

@immutable
class LearningCyberColors {
  const LearningCyberColors._();

  // Base surfaces
  static const Color bg0 = Color(0xFF070B14);
  static const Color panel = Color(0xFF101A2B);
  static const Color panelHi = Color(0xFF162238);
  static const Color stroke = Color(0xFF2A3A57);

  // Text
  static const Color text = Color(0xFFEAF2FF);
  static const Color textDim = Color(0xFF9CB0D2);

  // Accents
  static const Color neonCyan = Color(0xFF22E7FF);
  static const Color neonViolet = Color(0xFF8B5CF6);
  static const Color electricBlue = Color(0xFF2F80FF);

  // Feedback / utility
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color black = Colors.black;
  static const Color white = Colors.white;
}

@immutable
class LearningCyberGradients {
  const LearningCyberGradients._();

  static Gradient background() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFF050912),
        Color(0xFF0A1222),
        Color(0xFF101A2B),
      ],
      stops: <double>[0.0, 0.45, 1.0],
    );
  }

  static Gradient glowBlue() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0x3322E7FF),
        Color(0x1A2F80FF),
      ],
    );
  }

  static Gradient glowViolet() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0x338B5CF6),
        Color(0x1A22E7FF),
      ],
    );
  }
}

@immutable
class InstitutionalColors {
  const InstitutionalColors._();

  static const Color civicBlue = Color(0xFF1565C0);
  static const Color civicBlueSoft = Color(0xFF4F8FD8);
  static const Color navy = Color(0xFF0C2340);
  static const Color navy2 = Color(0xFF163A63);
}

@immutable
class AdminCyberColors {
  const AdminCyberColors._();

  static const Color black = LearningCyberColors.black;
  static const Color panel = LearningCyberColors.panel;
  static const Color panelHi = LearningCyberColors.panelHi;
  static const Color stroke = LearningCyberColors.stroke;
  static const Color text = LearningCyberColors.text;
  static const Color textDim = LearningCyberColors.textDim;
  static const Color neonCyan = LearningCyberColors.neonCyan;
  static const Color neonViolet = LearningCyberColors.neonViolet;
  static const Color electricBlue = LearningCyberColors.electricBlue;
  static const Color success = LearningCyberColors.success;
  static const Color danger = LearningCyberColors.danger;
}

@immutable
class AdminCyberGradients {
  const AdminCyberGradients._();

  static Gradient glowBlue() => LearningCyberGradients.glowBlue();
  static Gradient glowViolet() => LearningCyberGradients.glowViolet();
}

@immutable
class MarketColors {
  const MarketColors._();

  static const Color bg = Color(0xFFF8FAFC);
  static const Color stroke = Color(0xFFE2E8F0);
  static const Color ink = Color(0xFF0F172A);
  static const Color grayText = Color(0xFF64748B);
  static const Color orange = Color(0xFFF59E0B);
  static const Color orangeDeep = Color(0xFFEA580C);
}

// ==================== AJOUT THIX HOME COLORS ====================
@immutable
class ThixHomeColors {
  const ThixHomeColors._();

  // Couleurs principales THIX MARKET
  static const Color primary = Color(0xFFE5592F);
  static const Color primaryLight = Color(0xFFFF6B35);
  static const Color primaryDark = Color(0xFFC44A1F);
  static const Color secondary = Color(0xFF2196F3);

  // Surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;

  // Textes
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  // Bordures
  static const Color border = Color(0xFFE5E7EB);

  // Feedback
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Couleurs spécifiques aux stories et autres composants
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color darkNavy = Color(0xFF0A1929);

  // Alias pratiques
  static const Color marketPrimary = primary;
  static const Color marketBackground = background;
  static const Color marketTextPrimary = textPrimary;
}
// ==================== FIN AJOUT ====================

@immutable
class LightModeColors {
  const LightModeColors._();

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color divider = Color(0xFFE2E8F0);
  static const Color hint = Color(0xFF94A3B8);
  static const Color primary = InstitutionalColors.civicBlue;
  static const Color secondary = InstitutionalColors.civicBlueSoft;
  static const Color accent = Color(0xFF0EA5E9);
  static const Color primaryText = Color(0xFF0F172A);
  static const Color secondaryText = Color(0xFF475569);
  static const Color onSurface = Color(0xFF111827);
  static const Color success = LearningCyberColors.success;
  static const Color error = LearningCyberColors.danger;
  static const Color emergencyRed = Color(0xFFDC2626);
  static const Color cyberDarkBlue = DarkModeColors.cyberDarkBlue;
  static const Color metalGold = Color(0xFFD4AF37);
  static const Color metalGoldSoft = Color(0xFFE8D89A);
  static const Color metalGoldDeep = Color(0xFF9A7A1C);
}

@immutable
class DarkModeColors {
  const DarkModeColors._();

  static const Color background = LearningCyberColors.bg0;
  static const Color primary = Color(0xFF0B1220);
  static const Color cyberDarkBlue = Color(0xFF0D1B2A);
  static const Color emergencyRed = Color(0xFFEF4444);

  // Required by existing pages (fixes "Member not found: success")
  static const Color success = Color(0xFF22C55E);
  static const Color metalGold = Color(0xFFD4AF37);
  static const Color metalGoldSoft = Color(0xFFE8D89A);
  static const Color metalGoldDeep = Color(0xFF9A7A1C);

  // Optional aliases for consistency
  static const Color text = LearningCyberColors.text;
  static const Color textDim = LearningCyberColors.textDim;
  static const Color danger = LearningCyberColors.danger;
}

@immutable
class EmergencyMedicalSheetColors {
  const EmergencyMedicalSheetColors._();

  static const Color stroke = Color(0xFF1E3A8A);
}

@immutable
class EmergencyMedicalSheetGradients {
  const EmergencyMedicalSheetGradients._();

  static Gradient background() {
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        Color(0xFF0B1220),
        Color(0xFF111C34),
      ],
    );
  }
}

@immutable
class EmergencyUrgencyScaleColors {
  const EmergencyUrgencyScaleColors._();

  static const Color stable = Color(0xFF22C55E);
  static const Color moderate = Color(0xFFF59E0B);
  static const Color urgent = Color(0xFFF97316);
  static const Color critical = Color(0xFFEF4444);
}

@immutable
class EmergencyUrgentColors {
  const EmergencyUrgentColors._();

  static const Color bg0 = LearningCyberColors.bg0;
  static const Color bg1 = DarkModeColors.primary;
  static const Color panel = LearningCyberColors.panel;
  static const Color card = LearningCyberColors.panelHi;
  static const Color stroke = LearningCyberColors.stroke;
  static const Color text = LearningCyberColors.text;
  static const Color textDim = LearningCyberColors.textDim;
  static const Color danger = LearningCyberColors.danger;
  static const Color amber = Color(0xFFF59E0B);
  static const Color cyan = LearningCyberColors.neonCyan;
  static const Color medicalBlue = Color(0xFF38BDF8);
  static const Color fireOrange = Color(0xFFF97316);
  static const Color safetyGreen = LearningCyberColors.success;
  static const Color violet = LearningCyberColors.neonViolet;

  static Color scrim() => const Color(0xCC020617);
}

@immutable
class EmergencyUrgentGradients {
  const EmergencyUrgentGradients._();

  static Gradient background() {
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        EmergencyUrgentColors.bg0,
        EmergencyUrgentColors.bg1,
      ],
    );
  }

  static Gradient panel() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        EmergencyUrgentColors.panel,
        EmergencyUrgentColors.card,
      ],
    );
  }
}

/// Optional central app theme.
/// Safe defaults for Material 3.
@immutable
class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final ThemeData base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: LearningCyberColors.bg0,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: LearningCyberColors.neonCyan,
        secondary: LearningCyberColors.electricBlue,
        surface: LearningCyberColors.panel,
        error: LearningCyberColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: LearningCyberColors.bg0,
        foregroundColor: LearningCyberColors.text,
        elevation: 0,
      ),
    );
  }

  static ThemeData get light {
    final ThemeData base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.light,
        primary: InstitutionalColors.civicBlue,
        secondary: InstitutionalColors.civicBlueSoft,
        error: LearningCyberColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF111827),
        elevation: 0,
      ),
    );
  }
}

ThemeData get lightTheme => AppTheme.light;
ThemeData get darkTheme => AppTheme.dark;

// =============================================================================
// SPACING
// =============================================================================

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double sm2 = 12.0;
  static const double md = 16.0;
  static const double md2 = 20.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
}

// =============================================================================
// RADIUS
// =============================================================================

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 9999.0;
}

// =============================================================================
// CONTEXT EXTENSIONS
// =============================================================================

extension ThixThemeX on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

// =============================================================================
// TEXTSTYLE EXTENSIONS (.semiBold / .bold)
// =============================================================================

extension ThixTextStyleX on TextStyle {
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);
}
