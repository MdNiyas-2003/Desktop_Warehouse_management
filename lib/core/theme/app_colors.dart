import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF4F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF8FAFD);
  static const Color navy = Color(0xFF0E1A3A);
  static const Color navyDeep = Color(0xFF071127);
  static const Color primary = Color(0xFF2E5BFF);
  static const Color primarySoft = Color(0xFFE8EEFF);
  static const Color accent = Color(0xFFFFB547);
  static const Color success = Color(0xFF2BC48A);
  static const Color warning = Color(0xFFFFB547);
  static const Color danger = Color(0xFFFF5F6D);
  static const Color text = Color(0xFF172033);
  static const Color textMuted = Color(0xFF6E7B94);
  static const Color border = Color(0xFFE5EBF4);
  static const Color shadow = Color(0x1A0B1020);
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF152A64), Color(0xFF08122E)],
  );
  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E5BFF), Color(0xFF56A8FF)],
  );
}