import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// Receita card inspirado no template "Recipe Page" (Frontend Mentor).
class RecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final EdgeInsetsGeometry? margin;

  const RecipeCard({super.key, required this.recipe, this.margin});

  static const _nutmeg = Color(0xFF854632);
  static const _raspberry = Color(0xFF6E2050);
  static const _rose = Color(0xFFF9F0F5);
  static const _eggshell = Color(0xFFF3E5D8);
  static const _lightGrey = Color(0xFFEDE7E0);
  static const _wenge = Color(0xFF5F574E);
  static const _charcoal = Color(0xFF302D2C);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface2 : Colors.white;
    final body = isDark ? AppColors.darkText : _wenge;
    final bodyMuted = isDark ? AppColors.darkMuted : _wenge.withValues(alpha: 0.75);
    final heading = isDark ? _lighten(_nutmeg) : _nutmeg;
    final raspberry = isDark ? _lighten(_raspberry) : _raspberry;
    final roseBg = isDark ? const Color(0xFF34222C) : _rose;
    final divider = isDark ? AppColors.darkBorder : _lightGrey;

    final name = _str(recipe['name']) ?? 'Receita';
    final description = _str(recipe['description']);
    final ingredients = _stringList(recipe['ingredients']);
    final steps = _stringList(recipe['steps']);
    final nutrition = _nutritionList(recipe['nutrition']);
    final image = _str(recipe['image']);
    final source = _str(recipe['source']);
    final sourceUrl = _str(recipe['source_url']);

    final prep = _int(recipe['prep_min']);
    final cook = _int(recipe['cook_min']);
    final total = _int(recipe['total_min']) ?? (prep != null || cook != null ? (prep ?? 0) + (cook ?? 0) : null);
    final servings = _int(recipe['servings']);

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(image: image, name: name, isDark: isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.youngSerif(fontSize: 22, color: isDark ? AppColors.darkText : _charcoal, height: 1.2),
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.outfit(fontSize: 13.5, height: 1.45, color: bodyMuted),
                  ),
                ],
                const SizedBox(height: 12),
                _MetaBar(prep: prep, cook: cook, total: total, servings: servings, isDark: isDark),
                if (total != null || servings != null) ...[
                  const SizedBox(height: 12),
                  _PrepBox(
                    prep: prep,
                    cook: cook,
                    total: total,
                    servings: servings,
                    raspberry: raspberry,
                    roseBg: roseBg,
                    body: body,
                    isDark: isDark,
                  ),
                ],
                if (ingredients.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionTitle('Ingredientes', heading),
                  const SizedBox(height: 8),
                  ...ingredients.map((i) => _IngredientRow(i, raspberry, body)),
                ],
                if (steps.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionTitle('Modo de preparo', heading),
                  const SizedBox(height: 8),
                  ...steps.asMap().entries.map(
                        (e) => _StepRow(index: e.key, step: e.value, nutmeg: _nutmeg, body: body, isDark: isDark),
                      ),
                ],
                if (nutrition.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionTitle('Nutrição', heading),
                  _NutritionTable(nutrition: nutrition, nutmeg: heading, divider: divider, body: body),
                ],
                if (source != null && source.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  if (sourceUrl != null && sourceUrl.isNotEmpty)
                    GestureDetector(
                      onTap: () => _openLink(context, sourceUrl),
                      onLongPress: () => _copyLink(context, sourceUrl),
                      child: Row(
                        children: [
                          const Icon(Icons.open_in_new, size: 13, color: _wenge),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Fonte: $source — toque para abrir',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: bodyMuted,
                                decoration: TextDecoration.underline,
                                decorationColor: bodyMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.public, size: 13, color: _wenge),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Fonte: $source',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontSize: 11.5, color: bodyMuted),
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _lighten(Color c) {
    final hsl = HSLColor.fromColor(c);
    final h = hsl.withLightness((hsl.lightness * 2 + hsl.lightness).clamp(0.0, 1.0));
    return h.toColor();
  }

  static Future<void> _openLink(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      _showSnack(messenger, 'Link inválido.');
      return;
    }
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) _showSnack(messenger, 'Não consegui abrir o link.');
  }

  static Future<void> _copyLink(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: url));
    _showSnack(messenger, 'Link copiado.');
  }

  static void _showSnack(ScaffoldMessengerState? messenger, String message) {
    messenger
      ?..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ));
  }

  static String? _str(dynamic v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  static int? _int(dynamic v) => v is num ? v.round() : null;

  static List<String> _stringList(dynamic v) {
    if (v is List) return v.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return const [];
  }

  static List<Map<String, String>> _nutritionList(dynamic v) {
    if (v is! List) return const [];
    return v
        .whereType<Map>()
        .map((m) => {
              'label': (m['label'] ?? '').toString(),
              'value': (m['value'] ?? '').toString(),
            })
        .where((m) => m['label']!.isNotEmpty)
        .toList();
  }
}

class _Hero extends StatelessWidget {
  final String? image;
  final String name;
  final bool isDark;
  const _Hero({this.image, required this.name, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF3A2A22), Color(0xFF2A1F38)]
              : const [RecipeCard._eggshell, Color(0xFFF9F0F5)],
        ),
      ),
      child: Center(
        child: Text('🍽', style: TextStyle(fontSize: 52, color: Colors.black.withValues(alpha: 0.28))),
      ),
    );

    if (image == null) return fallback;

    return SizedBox(
      height: 150,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            image!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return fallback;
            },
          ),
        ],
      ),
    );
  }
}

class _MetaBar extends StatelessWidget {
  final int? prep;
  final int? cook;
  final int? total;
  final int? servings;
  final bool isDark;
  const _MetaBar({this.prep, this.cook, this.total, this.servings, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    void chip(IconData icon, String label) {
      items.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF24201E) : RecipeCard._rose,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: RecipeCard._nutmeg),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkText : RecipeCard._charcoal)),
        ]),
      ));
    }

    if (total != null) chip(Icons.timer_outlined, '$total min');
    if (prep != null) chip(Icons.timer, '${prep}min prep');
    if (cook != null) chip(Icons.local_fire_department_outlined, '${cook}min coz');
    if (servings != null) chip(Icons.people_outline, '$servings porções');

    return Wrap(spacing: 6, runSpacing: 6, children: items);
  }
}

class _PrepBox extends StatelessWidget {
  final int? prep;
  final int? cook;
  final int? total;
  final int? servings;
  final Color raspberry;
  final Color roseBg;
  final Color body;
  final bool isDark;
  const _PrepBox({this.prep, this.cook, this.total, this.servings, required this.raspberry, required this.roseBg, required this.body, required this.isDark});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text(label, style: GoogleFonts.outfit(fontSize: 12.5, color: isDark ? AppColors.darkMuted : const Color(0xFF6F5F56))),
              const SizedBox(width: 8),
              Text(value, style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: body)),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: roseBg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.schedule, size: 15, color: raspberry),
            const SizedBox(width: 6),
            Text('Tempo de preparo', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700, color: raspberry)),
          ]),
          const SizedBox(height: 8),
          if (total != null) row('Total:', '$total minutos'),
          if (prep != null) row('Preparo:', '$prep minutos'),
          if (cook != null) row('Cozimento:', '$cook minutos'),
          if (servings != null) row('Rendimento:', '$servings porções'),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionTitle(this.title, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: GoogleFonts.youngSerif(fontSize: 18, color: color));
  }
}

class _IngredientRow extends StatelessWidget {
  final String ingredient;
  final Color bullet;
  final Color body;
  const _IngredientRow(this.ingredient, this.bullet, this.body);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.5),
            child: Container(width: 5, height: 5, decoration: BoxDecoration(color: bullet, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ingredient,
              style: GoogleFonts.outfit(fontSize: 13.5, height: 1.4, color: body),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String step;
  final Color nutmeg;
  final Color body;
  final bool isDark;
  const _StepRow({required this.index, required this.step, required this.nutmeg, required this.body, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: nutmeg.withValues(alpha: isDark ? 0.75 : 1), shape: BoxShape.circle),
            child: Text('${index + 1}', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(step, style: GoogleFonts.outfit(fontSize: 13.5, height: 1.4, color: body)),
          ),
        ],
      ),
    );
  }
}

class _NutritionTable extends StatelessWidget {
  final List<Map<String, String>> nutrition;
  final Color nutmeg;
  final Color divider;
  final Color body;
  const _NutritionTable({required this.nutrition, required this.nutmeg, required this.divider, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < nutrition.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(nutrition[i]['label']!, style: GoogleFonts.outfit(fontSize: 13.5, color: body)),
                ),
                Text(nutrition[i]['value'] ?? '', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700, color: nutmeg)),
              ],
            ),
          ),
          if (i < nutrition.length - 1) Divider(height: 1, thickness: 1, color: divider),
        ],
      ],
    );
  }
}