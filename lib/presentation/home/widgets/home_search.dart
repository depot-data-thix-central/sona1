// lib/presentation/home/widgets/home_search.dart
import 'package:flutter/material.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class HomeSearch extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final VoidCallback onVerify;

  const HomeSearch({
    super.key,
    required this.controller,
    required this.isSearching,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      height: ThixPolicy.searchBarHeight, // Utilise la policy ! (48)
      padding: const EdgeInsets.only(left: ThixPolicy.s16, right: ThixPolicy.s6),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
          const SizedBox(width: ThixPolicy.s8),
          
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isSearching,
              textAlignVertical: TextAlignVertical.center,
              style: ThixPolicy.bodyMediumStyle,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                hintText: 'THIX ID...',
                hintStyle: ThixPolicy.bodySmallStyle,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          
          const SizedBox(width: ThixPolicy.s8),
          
          GestureDetector(
            onTap: isSearching ? null : onVerify,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
              decoration: BoxDecoration(
                gradient: ThixPolicy.brandGradient,
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.t('home_verify_btn'),
                style: const TextStyle(color: ThixPolicy.onBrand, fontWeight: ThixPolicy.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
