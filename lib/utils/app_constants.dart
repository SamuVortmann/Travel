// lib/utils/app_constants.dart
// Fonte central de cores, ícones, formatadores e widgets compartilhados.

import 'package:flutter/material.dart';

// ─── Cores ────────────────────────────────────────────────────────────────────
const kGreen = Color(0xFF2E9E50);
const kGreenLight = Color(0xFFE6F4EC);
const kGreenBorder = Color(0xFFB5D9C2);
const kGreenDark = Color(0xFF1A7038);
const kBg = Color(0xFFF2F2F7);
const kCard = Color(0xFFFFFFFF);
const kBorder = Color(0xFFE5E5EA);
const kBorderLight = Color(0xFFF0F0F5);
const kTextPrimary = Color(0xFF1C1C1E);
const kTextSecondary = Color(0xFF6C6C70);
const kTextTertiary = Color(0xFFAEAEB2);
const kRed = Color(0xFFFF3B30);

// ─── Mapa de ícones ───────────────────────────────────────────────────────────
const Map<String, IconData> kIconMap = {
  'photo_album': Icons.photo_album_outlined,
  'snowflake': Icons.ac_unit,
  'wb_sunny': Icons.wb_sunny_outlined,
  'eco': Icons.eco_outlined,
  'local_florist': Icons.local_florist_outlined,
  'beach_access': Icons.beach_access_outlined,
  'hiking': Icons.hiking_outlined,
  'restaurant': Icons.restaurant_outlined,
  'favorite': Icons.favorite_outline,
  'star': Icons.star_outline,
  'flight': Icons.flight_outlined,
  'camera': Icons.camera_alt_outlined,
  'home': Icons.home_outlined,
  'music_note': Icons.music_note_outlined,
  'sports': Icons.sports_outlined,
  'pets': Icons.pets_outlined,
};

IconData iconFromString(String name) =>
    kIconMap[name] ?? Icons.photo_album_outlined;

// ─── Utilitários de cores ─────────────────────────────────────────────────────
Color hexToColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return kGreen;
  }
}

// ─── Formatadores de data ─────────────────────────────────────────────────────
const _m = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];
const _mF = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

String formatDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  return '${dt.day} ${_m[dt.month - 1]} ${dt.year}';
}

String formatDateShort(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  return '${dt.day} ${_m[dt.month - 1]}';
}

String formatDateTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${_m[dt.month - 1]} ${dt.year} · $h:$m';
}

String formatMonthYear(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  return '${_mF[dt.month - 1]} ${dt.year}';
}

// ─── Humor ────────────────────────────────────────────────────────────────────
const kMoods = ['😊', '😄', '😐', '😢', '😍'];
const kMoodLabels = ['Feliz', 'Muito feliz', 'Neutro', 'Triste', 'Apaixonado'];

// ─── Barras de aviso ──────────────────────────────────────────────────────────
void showSuccess(BuildContext ctx, String msg) =>
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );

void showError(BuildContext ctx, String msg) =>
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );

// ─── Widgets compartilhados ───────────────────────────────────────────────────
/// Exibe uma mensagem padronizada quando uma tela não possui conteúdo.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: kTextTertiary),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: kTextSecondary),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}
