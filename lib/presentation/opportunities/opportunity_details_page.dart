import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/external_link_service.dart';
import 'package:thix_id/services/opportunity_service.dart';
import 'package:thix_id/theme.dart';

class OpportunityDetailsPage extends StatelessWidget {
  final String opportunityId;
  final bool applied;
  const OpportunityDetailsPage({super.key, required this.opportunityId, required this.applied});

  @override
  Widget build(BuildContext context) {
    final service = OpportunityService();
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FutureBuilder(
          future: service.fetchOpportunity(opportunityId),
          builder: (context, snap) {
            final opp = snap.data;
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (opp == null) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    _TopBar(opportunityId: opportunityId),
                    const Spacer(),
                    Text('Opportunité introuvable.', style: context.textStyles.titleMedium?.copyWith(color: context.theme.colorScheme.onSurface)),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: () => context.go(AppRoutes.opportunities), child: const Text('Retour'))),
                    const Spacer(),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hero(opp: opp),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopBar(opportunityId: opportunityId),
                        const SizedBox(height: AppSpacing.md),
                        Text(opp.title, style: context.textStyles.headlineSmall?.copyWith(color: context.theme.colorScheme.onSurface, fontWeight: FontWeight.w900)),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _Pill(icon: Icons.apartment_rounded, label: opp.organizer),
                            _Pill(icon: Icons.place_rounded, label: opp.location),
                            _Pill(icon: Icons.emoji_events_rounded, label: opp.rewardLabel),
                            _Pill(icon: Icons.schedule_rounded, label: opp.deadlineLabel),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _SectionTitle('Description'),
                        const SizedBox(height: AppSpacing.sm),
                        Text(opp.description, style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.secondaryText, height: 1.55)),
                        const SizedBox(height: AppSpacing.lg),
                        _SectionTitle('Éligibilité'),
                        const SizedBox(height: AppSpacing.sm),
                        ...opp.eligibility.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 18, color: LightModeColors.success),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(child: Text(e, style: context.textStyles.bodyMedium?.copyWith(color: context.theme.colorScheme.onSurface))),
                                ],
                              ),
                            )),
                        const SizedBox(height: AppSpacing.xl),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: applied
                                ? null
                                : () async {
                                    final url = opp.applyUrl;
                                    if (url == null || url.trim().isEmpty) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Lien de candidature indisponible.")),
                                      );
                                      return;
                                    }
                                    final ok = await ExternalLinkService.open(url);
                                    if (!context.mounted) return;
                                    if (!ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Impossible d’ouvrir le lien.")),
                                      );
                                    }
                                  },
                            icon: Icon(applied ? Icons.verified_rounded : Icons.send_rounded),
                            label: Text(applied ? 'Lien ouvert' : 'Postuler (lien externe)'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (!applied)
                          Text(
                            'Tu seras redirigé vers le site officiel pour finaliser la candidature.',
                            style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String opportunityId;
  const _TopBar({required this.opportunityId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: () => context.go(AppRoutes.opportunities), icon: const Icon(Icons.arrow_back_ios_new_rounded)),
        Expanded(child: Text('THIX Opportunités', style: context.textStyles.titleLarge?.copyWith(color: context.theme.colorScheme.onSurface, fontWeight: FontWeight.w900))),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final OpportunityItem opp;
  const _Hero({required this.opp});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (opp.imageAssetPath != null)
            (opp.imageAssetPath!.startsWith('http') ? Image.network(opp.imageAssetPath!, fit: BoxFit.cover) : Image.asset(opp.imageAssetPath!, fit: BoxFit.cover))
          else
            Container(color: LightModeColors.secondary),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [context.theme.colorScheme.primary, context.theme.colorScheme.primary.withValues(alpha: 0.45), Colors.transparent],
                stops: const [0, 0.6, 1],
              ),
            ),
          ),
          Positioned(
            bottom: AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(color: LightModeColors.accent, borderRadius: BorderRadius.circular(AppRadius.full)),
                  child: Text(opp.category.toUpperCase(), style: context.textStyles.labelSmall?.copyWith(color: const Color(0xFF0A2F5C), fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    opp.rewardLabel,
                    style: context.textStyles.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: context.theme.colorScheme.surface, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: context.theme.dividerColor)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: LightModeColors.accent),
          const SizedBox(width: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Text(label, style: context.textStyles.labelMedium?.copyWith(color: context.theme.colorScheme.onSurface, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: context.textStyles.titleMedium?.copyWith(color: context.theme.colorScheme.onSurface, fontWeight: FontWeight.w900));
  }
}

extension _ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}
