// lib/presentation/thix_info/thix_info_home.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 1. Import Riverpod
import 'package:go_router/go_router.dart';
import '../../providers/news_provider.dart';
import '../../models/news_article.dart';

const _kGold = Color(0xFFFFB800);
const _kGoldLight = Color(0xFFFFF4D9);
const _kBlue = Color(0xFF0B3D91);
const _kBg = Color(0xFFF7F8FB);
const Color _kWhite = Colors.white;
const _kDark = Color(0xFF101840);
const _kMuted = Color(0xFF8A8FA8);
const _kBorder = Color(0xFFECEEF4);
const _kRed = Color(0xFFE0263A);

Color _catColor(String cat) {
  switch (cat.toLowerCase()) {
    case 'politique':
      return const Color(0xFF3B5BDB);
    case 'economie':
    case 'économie':
      return const Color(0xFF2F9E44);
    case 'tech':
      return const Color(0xFF7048E8);
    case 'sport':
      return const Color(0xFFF08C00);
    case 'societe':
    case 'société':
      return const Color(0xFF0C8599);
    default:
      return _kBlue;
  }
}

// 2. Remplacement par ConsumerStatefulWidget
class ThixInfoHome extends ConsumerStatefulWidget {
  const ThixInfoHome({super.key});

  @override
  ConsumerState<ThixInfoHome> createState() => _ThixInfoHomeState();
}

class _ThixInfoHomeState extends ConsumerState<ThixInfoHome> {
  String _cat = 'featured';

  final PageController _pageCtrl = PageController();
  final ScrollController _breakingCtrl = ScrollController();

  Timer? _timer;
  Timer? _breakingTimer;
  int _page = 0;

  final List<Map<String, String>> cats = const [
    {'slug': 'featured', 'name': 'À la une'},
    {'slug': 'politique', 'name': 'Politique'},
    {'slug': 'economie', 'name': 'Économie'},
    {'slug': 'societe', 'name': 'Société'},
    {'slug': 'tech', 'name': 'Tech'},
    {'slug': 'sport', 'name': 'Sport'},
    {'slug': 'culture', 'name': 'Culture'},
    {'slug': 'international', 'name': 'International'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 3. ref.read au lieu de context.read
      ref.read(newsProvider).fetchArticles(category: 'all');
      ref.read(newsProvider).loadSavedArticles();
      _startAuto();
      _startBreakingScroll();
    });
  }

  void _startAuto() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (!mounted) return;
        // 4. ref.read utilisé pour les timers
        final list = ref
            .read(newsProvider)
            .articles
            .where((e) => e.isFeatured)
            .toList();
        if (list.isEmpty) return;
        if (!_pageCtrl.hasClients) return;
        _page = (_page + 1) % list.length;
        _pageCtrl.animateToPage(
          _page,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  void _startBreakingScroll() {
    _breakingTimer?.cancel();
    _breakingTimer = Timer.periodic(
      const Duration(milliseconds: 30),
      (_) {
        if (!mounted) return;
        if (!_breakingCtrl.hasClients) return;
        final maxExtent = _breakingCtrl.position.maxScrollExtent;
        if (maxExtent <= 0) return;
        double next = _breakingCtrl.offset + 1.4;
        if (next >= maxExtent) {
          next = 0;
        }
        _breakingCtrl.jumpTo(next);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breakingTimer?.cancel();
    _pageCtrl.dispose();
    _breakingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 5. ref.watch écoute les changements
    final prov = ref.watch(newsProvider);

    final featured = prov.articles
        .where((e) => e.isFeatured)
        .toList();

    final breaking = prov.articles
        .where((e) => e.isBreaking)
        .toList();

    final recents = prov.articles;

    final videos = prov.articles
        .where((e) => e.videoUrl != null && e.videoUrl!.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: _kBg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _top(),
          _search(),
          _cats(),
          if (breaking.isNotEmpty) _breakingBar(breaking),
          const SizedBox(height: 8),
          featured.isNotEmpty ? _featuredAuto(featured) : _loadBox(),
          const SizedBox(height: 10),
          _quick(),
          const SizedBox(height: 14),
          _titleRow('Actualités récentes'),
          _recentCompact(recents, prov), // Passage de prov pour optimiser Riverpod
          const SizedBox(height: 10),
          _titleRow('Vidéos à la une'),
          _videoWithInfos(videos, prov),
          const SizedBox(height: 14),
          _titleRow("Toute l'actualité"),
          _allNewsList(recents, prov),
          const SizedBox(height: 90),
        ],
      ),
      bottomNavigationBar: _bottom(),
    );
  }

  Widget _top() {
    return Container(
      color: _kWhite,
      padding: const EdgeInsets.fromLTRB(12, 44, 12, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, size: 20, color: _kDark),
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kGold,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.newspaper,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'THIX ',
                        style: TextStyle(
                          color: _kDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      TextSpan(
                        text: 'INFO',
                        style: TextStyle(
                          color: _kGold,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  "L'information vraie, partout.",
                  style: TextStyle(fontSize: 9, color: _kMuted),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none, size: 22, color: _kDark),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: _kRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push('/admin'),
            child: Container(
              width: 34,
              height: 34,
              color: _kWhite,
              child: CircleAvatar(
                backgroundColor: _kBg,
                radius: 17,
                child: const Icon(Icons.person, size: 18, color: _kMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _search() {
    return Container(
      color: _kWhite,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: const Row(
          children: [
            Icon(Icons.search, size: 18, color: _kMuted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Rechercher une actualité, un sujet...',
                style: TextStyle(fontSize: 11, color: _kMuted),
              ),
            ),
            Icon(Icons.tune, size: 16, color: _kMuted),
          ],
        ),
      ),
    );
  }

  Widget _cats() {
    return Container(
      color: _kWhite,
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          itemCount: cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, i) {
            final c = cats[i];
            final sel = _cat == c['slug'];
            return GestureDetector(
              onTap: () {
                setState(() => _cat = c['slug']!);
                if (c['slug'] == 'featured') {
                  ref.read(newsProvider).fetchArticles(category: 'all');
                } else {
                  ref.read(newsProvider).fetchArticles(category: c['slug']!);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? _kGold : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  c['name']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                    color: sel ? _kDark : _kMuted,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _breakingBar(List<NewsArticle> list) {
    return Container(
      height: 34,
      color: _kRed,
      child: ListView.builder(
        controller: _breakingCtrl,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: list.length * 40,
        itemBuilder: (_, i) {
          final a = list[i % list.length];
          return GestureDetector(
            onTap: () => context.push('/thix-info/article/${a.id}'),
            child: Padding(
              padding: const EdgeInsets.only(right: 22),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'BREAKING',
                      style: TextStyle(
                        color: _kRed,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    a.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '- ${a.summary ?? ''}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _featuredAuto(List<NewsArticle> list) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (v) => setState(() => _page = v),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final a = list[i];
              return GestureDetector(
                onTap: () => context.push('/thix-info/article/${a.id}'),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _kWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: a.imageUrl != null
                            ? Image.network(a.imageUrl!, fit: BoxFit.cover)
                            : Container(color: _kBlue),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                              colors: [
                                Colors.black.withOpacity(0.75),
                                Colors.black.withOpacity(0.05),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 14,
                        top: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _kGold,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'À LA UNE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: _kDark,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              a.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              a.summary ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 11,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 3),
                                const Text(
                                  'Récemment',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.remove_red_eye_outlined,
                                  size: 11,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${a.viewsCount} vues',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 30,
                              child: ElevatedButton.icon(
                                onPressed: () => context
                                    .push('/thix-info/article/${a.id}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kGold,
                                  foregroundColor: _kDark,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                icon: const Text(
                                  "Lire l'article",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                label: const Icon(
                                  Icons.arrow_forward,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 6,
          child: Row(
            children: List.generate(list.length, (i) {
              final active = i == _page;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: active ? 14 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: active ? _kGold : Colors.white70,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _quick() {
    final items = [
      {
        'icon': Icons.article,
        'label': 'Fil Info',
        'bg': const Color(0xFFE7F1FF),
        'fg': const Color(0xFF1971C2),
      },
      {
        'icon': Icons.play_circle,
        'label': 'Vidéos',
        'bg': const Color(0xFFFFE3E3),
        'fg': const Color(0xFFE03131),
      },
      {
        'icon': Icons.headset,
        'label': 'Podcasts',
        'bg': const Color(0xFFF3E8FF),
        'fg': const Color(0xFF7048E8),
      },
      {
        'icon': Icons.menu_book,
        'label': 'Magazines',
        'bg': const Color(0xFFFFF0E0),
        'fg': const Color(0xFFF08C00),
      },
      {
        'icon': Icons.notifications,
        'label': 'Alertes',
        'bg': const Color(0xFFE6FCF5),
        'fg': const Color(0xFF12B886),
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((it) {
          return Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: it['bg'] as Color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  it['icon'] as IconData,
                  size: 17,
                  color: it['fg'] as Color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                it['label'] as String,
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _titleRow(String t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            t,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _kDark,
            ),
          ),
          const Text(
            'Voir tout',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF9A7B11),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // 6. On accepte le prov en paramètre pour éviter de relire le context/ref dans le builder
  Widget _recentCompact(List<NewsArticle> list, NewsProvider prov) {
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Aucune actualité',
            style: TextStyle(fontSize: 11, color: _kMuted),
          ),
        ),
      );
    }

    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: list.length > 8 ? 8 : list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final a = list[i];
          return GestureDetector(
            onTap: () => context.push('/thix-info/article/${a.id}'),
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                color: _kWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        height: 90,
                        width: 160,
                        child: a.imageUrl != null
                            ? Image.network(a.imageUrl!, fit: BoxFit.cover)
                            : Container(
                                color: _kGoldLight,
                                child: const Icon(Icons.image, size: 16),
                              ),
                      ),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _catColor(a.category),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            a.category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _engagementRow(a, prov), // On passe prov
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _videoWithInfos(List<NewsArticle> list, NewsProvider prov) {
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(
          child: Text(
            'Aucune vidéo',
            style: TextStyle(fontSize: 11, color: _kMuted),
          ),
        ),
      );
    }

    return SizedBox(
      height: 168,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final v = list[i];
          return GestureDetector(
            onTap: () => context.push('/thix-info/article/${v.id}'),
            child: Container(
              width: 158,
              decoration: BoxDecoration(
                color: _kWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        height: 90,
                        width: 158,
                        child: v.imageUrl != null
                            ? Image.network(v.imageUrl!, fit: BoxFit.cover)
                            : Container(color: Colors.black12),
                      ),
                      const Positioned.fill(
                        child: Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'VIDEO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _engagementRow(v, prov), // On passe prov
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _allNewsList(List<NewsArticle> list, NewsProvider prov) {
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Aucune actualité publiée',
            style: TextStyle(fontSize: 11, color: _kMuted),
          ),
        ),
      );
    }

    return Column(
      children: list.map((a) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: GestureDetector(
            onTap: () => context.push('/thix-info/article/${a.id}'),
            child: Container(
              decoration: BoxDecoration(
                color: _kWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 150,
                    child: a.imageUrl != null
                        ? Image.network(a.imageUrl!, fit: BoxFit.cover)
                        : Container(
                            color: _kGoldLight,
                            child: const Icon(Icons.image, size: 18),
                          ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _catColor(a.category),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              a.category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            a.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            a.summary ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: _kMuted,
                            ),
                          ),
                          const Spacer(),
                          _engagementRow(a, prov), // On passe prov
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Ligne vues + favori réutilisée : lit 'prov' passé en paramètre
  Widget _engagementRow(NewsArticle a, NewsProvider prov) {
    final isSaved = prov.savedArticles.any((s) => s.id == a.id);

    return Row(
      children: [
        const Icon(Icons.remove_red_eye_outlined, size: 12, color: _kMuted),
        const SizedBox(width: 3),
        Text(
          '${a.viewsCount}',
          style: const TextStyle(fontSize: 8, color: _kMuted),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            // Actions asynchrones déclenchées par ref.read
            if (isSaved) {
              ref.read(newsProvider).unsaveArticle(a.id);
            } else {
              ref.read(newsProvider).saveArticle(a.id);
            }
          },
          child: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_border,
            size: 15,
            color: isSaved ? _kGold : _kMuted,
          ),
        ),
      ],
    );
  }

  Widget _loadBox() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: 120,
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _bottom() {
    final items = [
      {'icon': Icons.home, 'label': 'Accueil'},
      {'icon': Icons.grid_view, 'label': 'Catégories'},
      {'icon': Icons.newspaper, 'label': 'Fil Info'},
      {'icon': Icons.bookmark_border, 'label': 'Favoris'},
      {'icon': Icons.person_outline, 'label': 'Profil'},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = i == 2;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active)
                CircleAvatar(
                  backgroundColor: _kGold,
                  radius: 18,
                  child: Icon(
                    items[i]['icon'] as IconData,
                    color: Colors.white,
                    size: 16,
                  ),
                )
              else
                Icon(
                  items[i]['icon'] as IconData,
                  color: _kMuted,
                  size: 20,
                ),
              const SizedBox(height: 2),
              Text(
                items[i]['label'] as String,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? _kGold : _kMuted,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
