// lib/presentation/home/widgets/home_premium_card.dart
import 'package:flutter/material.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class HomePremiumCard extends StatelessWidget {
  const HomePremiumCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      height: 84,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF2FF), Colors.white],
        ),
        border: Border.all(color: ThixPolicy.border, width: 0.7),
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        boxShadow: ThixPolicy.shadowCard(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20, vertical: ThixPolicy.s16),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: ThixPolicy.primaryDeep, size: 26),
          const SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.t('home_premium_member'),
                  style: const TextStyle(color: ThixPolicy.textMain, fontSize: 14, fontWeight: FontWeight.w800),
                ),
                Text(
                  l10n.t('home_trust_score', params: {'score': '98'}),
                  style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12, vertical: ThixPolicy.s8),
            decoration: BoxDecoration(
              color: ThixPolicy.textMain,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              l10n.t('home_view_btn'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
