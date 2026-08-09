// lib/presentation/home/widgets/home_quick_actions.dart
import 'package:flutter/material.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/design_system/thix_policy.dart';

class HomeQuickActions extends StatelessWidget {
  final VoidCallback onScanTap;
  final VoidCallback onDocumentTap;
  final VoidCallback onChatTap;
  final VoidCallback onSecurityTap;

  const HomeQuickActions({
    super.key,
    required this.onScanTap,
    required this.onDocumentTap,
    required this.onChatTap,
    required this.onSecurityTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Row(
      children: [
        Expanded(child: Center(child: _QuickActionItem(icon: Icons.smart_toy_rounded, label: l10n.t('quickThixIA'), accent: ThixPolicy.primaryDeep, onTap: onScanTap))),
        Expanded(child: Center(child: _QuickActionItem(icon: Icons.folder_shared_rounded, label: 'THIX DOC', accent: ThixPolicy.domainLearning, onTap: onDocumentTap))),
        Expanded(child: Center(child: _QuickActionItem(icon: Icons.forum_rounded, label: l10n.t('quickChat'), accent: ThixPolicy.domainNetwork, onTap: onChatTap))),
        Expanded(child: Center(child: _QuickActionItem(icon: Icons.emergency_rounded, label: 'THIX SOS', accent: ThixPolicy.danger, onTap: onSecurityTap))),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  // ... (Garde ton code existant de _QuickActionItem et _PressableScale ici)
}
