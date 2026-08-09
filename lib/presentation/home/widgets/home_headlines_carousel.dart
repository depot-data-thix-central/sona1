// lib/presentation/home/widgets/home_headlines_carousel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';


class HomeHeadlinesCarousel extends StatefulWidget {
  final PageController controller;
  final String? uid;
  final VoidCallback onThixInfoTap;
  final VoidCallback onOpportunityTap;

  const HomeHeadlinesCarousel({
    super.key,
    required this.controller,
    required this.uid,
    required this.onThixInfoTap,
    required this.onOpportunityTap,
  });

  @override
  State<HomeHeadlinesCarousel> createState() => _HomeHeadlinesCarouselState();
}

class _HomeHeadlinesCarouselState extends State<HomeHeadlinesCarousel> {
  late final Stream<List<Map<String, dynamic>>> _articlesStream;
  late final Stream<List<Map<String, dynamic>>> _opportunitiesStream;
  Stream<List<Map<String, dynamic>>>? _priorityNotifStream;
  
  Timer? _autoTimer;
  int _cardCount = 0;
  static const double _bannerHeight = 150;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    
    try {
      _articlesStream = client.from('thix_info_articles')
          .stream(primaryKey: ['id']).eq('is_featured', true).order('created_at', ascending: false).limit(5);
    } catch (e) {
      _articlesStream = Stream.value(const <Map<String, dynamic>>[]);
    }
    
    try {
      _opportunitiesStream = client.from('opportunities')
          .stream(primaryKey: ['id']).eq('is_featured', true).order('created_at', ascending: false).limit(5);
    } catch (e) {
      _opportunitiesStream = Stream.value(const <Map<String, dynamic>>[]);
    }
    
    final uid = widget.uid;
    if (uid != null && uid.trim().isNotEmpty) {
      try {
        _priorityNotifStream = client.from('notifications')
            .stream(primaryKey: ['id']).eq('user_id', uid).order('created_at', ascending: false).limit(5);
      } catch (e) {
        _priorityNotifStream = null;
      }
    }
    
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!widget.controller.hasClients || _cardCount <= 1) return;
      final current = widget.controller.page?.round() ?? 0;
      final next = (current + 1) % _cardCount;
      widget.controller.animateToPage(next, duration: const Duration(milliseconds: 550), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _priorityNotifStream,
      builder: (context, notifSnap) {
        final notifs = (notifSnap.data ?? const <Map<String, dynamic>>[])
            .where((n) => (n['priority'] == true) || (n['is_priority'] == true)).toList(growable: false);
        final priorityNotif = notifs.isEmpty ? null : notifs.first;
        
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _articlesStream,
          builder: (context, articleSnap) {
            final articles = articleSnap.data ?? const <Map<String, dynamic>>[];
            
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _opportunitiesStream,
              builder: (context, oppSnap) {
                final opportunities = oppSnap.data ?? const <Map<String, dynamic>>[];
                final cards = <Widget>[];
                
                if (priorityNotif != null) {
                  cards.add(_HeadlineBanner(
                    label: l10n.t('home_headline_notif_priority'),
                    title: (priorityNotif['title'] as String?) ?? (priorityNotif['message'] as String?) ?? l10n.t('home_headline_new_notif'),
                    imageUrl: priorityNotif['image_url'] as String?,
                    icon: Icons.priority_high_rounded,
                    accent: ThixPolicy.danger,
                    height: _bannerHeight,
                    onTap: () => NotificationsSheet.show(context),
                  ));
                }
                
                for (final a in articles) {
                  cards.add(_HeadlineBanner(
                    label: l10n.t('home_headline_thixinfo_label'),
                    title: (a['title'] as String?) ?? l10n.t('home_headline_thixinfo_article'),
                    imageUrl: a['image_url'] as String?,
                    icon: Icons.newspaper_rounded,
                    accent: ThixPolicy.domainInfo,
                    height: _bannerHeight,
                    onTap: widget.onThixInfoTap,
                  ));
                }
                
                for (final o in opportunities) {
                  cards.add(_HeadlineBanner(
                    label: l10n.t('home_headline_opportunity_label'),
                    title: (o['title'] as String?) ?? l10n.t('home_headline_new_opportunity'),
                    imageUrl: o['image_url'] as String?,
                    icon: Icons.lightbulb_rounded,
                    accent: ThixPolicy.domainOpportunity,
                    height: _bannerHeight,
                    onTap: widget.onOpportunityTap,
                  ));
                }
                
                if (cards.isEmpty) {
                  cards.addAll([
                    _HeadlineBanner(
                      label: l10n.t('home_headline_thixinfo_label'),
                      title: l10n.t('home_headline_thixinfo_default'),
                      icon: Icons.newspaper_rounded,
                      accent: ThixPolicy.domainInfo,
                      height: _bannerHeight,
                      onTap: widget.onThixInfoTap,
                    ),
                    _HeadlineBanner(
                      label: l10n.t('home_headline_opportunity_label'),
                      title: l10n.t('home_headline_opportunity_default'),
                      icon: Icons.lightbulb_rounded,
                      accent: ThixPolicy.domainOpportunity,
                      height: _bannerHeight,
                      onTap: widget.onOpportunityTap,
                    )
                  ]);
                }
                
                _cardCount = cards.length;
                
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: _bannerHeight, child: PageView(controller: widget.controller, children: cards)),
                    if (cards.length > 1) ...[
                      const SizedBox(height: 8),
                      _CarouselDots(controller: widget.controller, count: cards.length),
                    ]
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CarouselDots extends StatefulWidget {
  final PageController controller;
  final int count;
  const _CarouselDots({required this.controller, required this.count});
  @override State<_CarouselDots> createState() => _CarouselDotsState();
}

class _CarouselDotsState extends State<_CarouselDots> {
  int _page = 0;
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final p = widget.controller.page?.round() ?? 0;
    if (p != _page && mounted) setState(() => _page = p);
  }
  
  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final activePage = widget.count == 0 ? 0 : _page.clamp(0, widget.count - 1);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.count, (i) {
        final active = i == activePage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? ThixPolicy.premiumAccent : ThixPolicy.border,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _HeadlineBanner extends StatelessWidget {
  final String label;
  final String title;
  final IconData icon;
  final Color accent;
  final String? imageUrl;
  final double height;
  final VoidCallback onTap;

  const _HeadlineBanner({
    required this.label,
    required this.title,
    required this.icon,
    required this.accent,
    required this.height,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = (imageUrl ?? '').trim().isNotEmpty;
    
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        child: Container(
          height: height,
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), boxShadow: ThixPolicy.shadowCard()),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.network(
                  imageUrl!.trim(),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: accent.withValues(alpha: 0.10),
                      child: Center(
                        child: SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: accent),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: accent.withValues(alpha: 0.14),
                    alignment: Alignment.center,
                    child: Icon(icon, color: accent, size: 40),
                  ),
                )
              else
                Container(
                  color: accent.withValues(alpha: 0.14),
                  alignment: Alignment.center,
                  child: Icon(icon, color: accent, size: 40),
                ),
                
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: hasImage ? 0.55 : 0.25),
                      ],
                      stops: const [0.35, 1.0],
                    ),
                  ),
                ),
              ),
              
              Positioned(
                left: ThixPolicy.s16,
                right: ThixPolicy.s16,
                bottom: ThixPolicy.s12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, height: 1.15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              Positioned(
                right: ThixPolicy.s12,
                top: ThixPolicy.s12,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_right_rounded, size: 18, color: ThixPolicy.textMain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
