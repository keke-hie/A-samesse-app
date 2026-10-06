import 'package:flutter/material.dart';

/// Palette A'samesse : bordeaux velours, rose poudré et touches or.
/// Toute couleur de l'interface doit venir d'ici (ou du thème), jamais d'un
/// `Color(0x…)` écrit dans un écran.
abstract final class AppColor {
  // Marque
  static const Color primary = Color(0xFF8B2635);
  static const Color primaryDark = Color(0xFF6B1B27);
  static const Color primaryLight = Color(0xFFA63D4E);
  static const Color primarySoft = Color(0xFFF4DEE1);

  // Or / champagne
  static const Color gold = Color(0xFFC5A880);
  static const Color goldDark = Color(0xFFA8895E);
  static const Color goldLight = Color(0xFFF6F1EA);

  // Fonds
  static const Color background = Color(0xFFF9EAE5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color darkPill = Color(0xFF1E1E1E);

  // Bordures
  static const Color border = Color(0xFFEFE2DE);
  static const Color divider = Color(0xFFECE4E1);

  // Textes
  static const Color textPrimary = Color(0xFF1E1E1E);
  static const Color textSecondary = Color(0xFF6E6E6E);
  static const Color textMuted = Color(0xFF9E9E9E);

  // Statuts
  static const Color success = Color(0xFF2E7D32);
  static const Color successSoft = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFF9E6A16);
  static const Color danger = Color(0xFFB42332);
  static const Color dangerSoft = Color(0xFFFDECEE);
  static const Color ratingStar = Color(0xFFFFB800);
}
