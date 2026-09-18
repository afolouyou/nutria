import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class _Plan {
  final String name;
  final String tagline;
  final IconData icon;
  final Color color;
  final String price;
  final String period;
  final String badgeLabel;
  final bool current;
  final bool highlighted;
  final List<({String text, bool included})> features;

  const _Plan({
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.price,
    required this.period,
    required this.badgeLabel,
    required this.current,
    required this.highlighted,
    required this.features,
  });
}

Future<void> showPlansPopup(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final surface = isDark ? AppColors.darkSurface : Colors.white;

      final plans = [
        _Plan(
          name: 'Grátis',
          tagline: 'Para começar com os pés no chão',
          icon: Icons.eco,
          color: isDark ? AppColors.greenDark : AppColors.green,
          price: 'Grátis',
          period: '',
          badgeLabel: '',
          current: true,
          highlighted: false,
          features: const [
            (text: 'Dispensa online', included: true),
            (text: 'Chat com 7 mensagens por dia', included: true),
            (text: 'Consulta de carboidrato e nutrição', included: true),
            (text: 'Registre compras e uso', included: true),
            (text: 'Com anúncios', included: true),
            (text: 'Receita com desconto da despensa', included: false),
            (text: 'Cardápio semanal', included: false),
          ],
        ),
        _Plan(
          name: 'Folha',
          tagline: 'Para quem cozinha com o que tem',
          icon: Icons.restaurant_menu,
          color: AppColors.orange,
          price: 'R\$ 9,99',
          period: '/mês',
          badgeLabel: 'MAIS POPULAR',
          current: false,
          highlighted: true,
          features: const [
            (text: 'Tudo do Grátis', included: true),
            (text: 'Receita com o que tem na despensa', included: true),
            (text: 'Desconto automático na despensa', included: true),
            (text: '3 receitas por semana', included: true),
            (text: 'Sem anúncios', included: true),
            (text: 'Cardápio semanal', included: false),
          ],
        ),
        _Plan(
          name: 'Laranja',
          tagline: 'A experiência completa do NutrIA',
          icon: Icons.diamond,
          color: isDark ? AppColors.goldDark : AppColors.gold,
          price: 'R\$ 14,99',
          period: '/mês',
          badgeLabel: '',
          current: false,
          highlighted: false,
          features: const [
            (text: 'Tudo do Folha', included: true),
            (text: 'Cardápio semanal automático', included: true),
            (text: '1 cardápio por semana', included: true),
            (text: 'Chat sem limites', included: true),
            (text: 'Receitas com a despensa', included: true),
            (text: 'Sem anúncios', included: true),
          ],
        ),
      ];

      return Dialog(
        backgroundColor: surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - v)),
                child: child,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(ctx),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      children: [
                        for (final plan in plans)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PlanCard(
                              plan: plan,
                              onChoose: () => _onChoose(context, ctx, plan),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _onChoose(BuildContext context, BuildContext dialogCtx, _Plan plan) {
  Navigator.pop(dialogCtx);
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Plano ${plan.name} disponível em breve!'),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
}

Widget _buildHeader(BuildContext ctx) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 16, 12, 18),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF15561D), Color(0xFF1B6A26)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planos NutrIA',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Escolha o plano ideal para o seu dia a dia',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xCCFFFFFF),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 19, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Pagamentos disponíveis em breve',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final VoidCallback onChoose;

  const _PlanCard({required this.plan, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface2 = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final cardColor = plan.highlighted
        ? Color.alphaBlend(plan.color.withValues(alpha: isDark ? 0.10 : 0.06), surface2)
        : surface2;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: plan.highlighted || plan.current
              ? plan.color.withValues(alpha: plan.current ? 0.45 : 0.8)
              : border,
          width: plan.highlighted ? 1.6 : 1.2,
        ),
        boxShadow: plan.highlighted
            ? [
                BoxShadow(
                  color: plan.color.withValues(alpha: isDark ? 0.22 : 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: plan.color.withValues(alpha: isDark ? 0.18 : 0.13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(plan.icon, color: plan.color, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan.name,
                              style: GoogleFonts.poppins(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (plan.badgeLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: plan.color,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                plan.badgeLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.05,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.tagline,
                        style: GoogleFonts.poppins(fontSize: 11.5, color: muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: plan.price,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: plan.color,
                        ),
                      ),
                      if (plan.period.isNotEmpty)
                        TextSpan(
                          text: plan.period,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: border.withValues(alpha: 0.7)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                for (final feature in plan.features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _FeatureRow(
                      label: feature.text,
                      included: feature.included,
                      muted: muted,
                      textColor: text,
                      color: plan.color,
                    ),
                  ),
                const SizedBox(height: 8),
                _buildCta(context, muted, border),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCta(BuildContext context, Color muted, Color border) {
    if (plan.current) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: Icon(Icons.check_circle, size: 17, color: muted),
          label: Text(
            'Seu plano atual',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: border, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onChoose,
        style: ElevatedButton.styleFrom(
          backgroundColor: plan.color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          'Quero o ${plan.name}',
          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;
  final bool included;
  final Color muted;
  final Color textColor;
  final Color color;

  const _FeatureRow({
    required this.label,
    required this.included,
    required this.muted,
    required this.textColor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = included ? color : muted.withValues(alpha: 0.5);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            included ? Icons.check_circle : Icons.cancel_outlined,
            size: 16,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: included ? textColor : muted.withValues(alpha: 0.7),
              decoration: included ? null : TextDecoration.lineThrough,
              decorationColor: muted.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}
