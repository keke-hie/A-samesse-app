import 'package:flutter/material.dart';

class AppColor {
  // Couleur principale & Accent (Harmonisées avec le bordeaux/rose poudré des maquettes)
  static const Color primary = Color(0xFF8B2635); // Bordeaux velours élégant
  static const Color accent = Color(0xFF8B2635);

  // Arrière-plans (Exactement le rose poudré/blush pastel des maquettes)
  static const Color background = Color(0xFFF9EAE5); // Fond blush rose poudré épuré
  static const Color cardBackground = Color(0xFFFFFFFF); // Cartes blanches ultra-clean
  static const Color inputBackground = Color(0xFFFFFFFF); // Blanc propre pour les champs
  static const Color surface = Color(0xFFFFFFFF);
  static const Color darkPill = Color(0xFF1E1E1E); // Capsule noire (All, Cart summary)

  // Variantes Bordeaux / Luxe
  static const Color primaryDark = Color(0xFF6B1B27);
  static const Color primaryLight = Color(0xFFA63D4E);
  static const Color primarySoft = Color(0xFFF4DEE1);

  // Touches Or / Champagne & Accents
  static const Color gold = Color(0xFFC5A880);
  static const Color goldDark = Color(0xFFA8895E);
  static const Color goldLight = Color(0xFFF6F1EA);

  // Bordures & Ombres
  static const Color border = Color(0xFFEFE8E5);
  static const Color borderLight = Color(0xFFF6F0EE);
  static const Color divider = Color(0xFFECE4E1);

  // Textes
  static const Color textPrimary = Color(0xFF1E1E1E);
  static const Color textSecondary = Color(0xFF6E6E6E);
  static const Color textMuted = Color(0xFF9E9E9E);
  static const Color textBrand = Color(0xFFA53333); // Utilisé pour login_screen.dart

  // Statuts & Badges
  static const Color success = Color(0xFF2E7D32);
  static const Color ratingStar = Color(0xFFFFB800);
}

// Alias pour éviter les erreurs si un fichier utilise 'AppColors' avec un S
typedef AppColors = AppColor;