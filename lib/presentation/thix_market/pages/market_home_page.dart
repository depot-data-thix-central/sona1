// lib/presentation/thix_market/pages/market_home_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/market_colors.dart';
import '../l10n/market_strings.dart';
import '../providers/market_providers.dart';
import '../providers/featured_products_provider.dart';
import '../widgets/products/product_card.dart';
import '../widgets/market/flash_sale_timer.dart';

class MarketHomePage extends ConsumerStatefulWidget {
  const MarketHomePage({super.key});
  @override
  ConsumerState<MarketHomePage> createState() => _MarketHomePageState();
}

class _MarketHomePageState extends ConsumerState<MarketHomePage> {
  final ScrollController _scroll = ScrollController();
  final PageController _bannerCtrl = PageController(viewportFraction: 0.94);
  Timer? _bannerTimer;
  Timer? _expiryTicker; // recalcule les ventes flash expirées toutes les 30s
  bool _bannerReady = false;
  int _currentBanner = 0;
  int _selectedNav = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _expiryTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 700) {
      ref.read(forYouProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _bannerCtrl.dispose();
    _bannerTimer?.cancel();
    _expiryTicker?.cancel();
    super.dispose();
  }

  void _safeNavigate(String name, String path) {
    try {
      context.pushNamed(name);
    } catch (_) {
      try {
        context.push(path);
      } catch (_) {}
    }
  }

  void _startBannerAuto(int count) {
    if (_bannerReady) return;
    if (count <= 1) return;
    _bannerReady = true;
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_bannerCtrl.hasClients) return;
      _currentBanner = (_currentBanner + 1) % count;
      _bannerCtrl.animateToPage(_currentBanner, duration: const Duration(milliseconds: 700), curve: Curves.easeOutCubic);
      if (mounted) setState(() {});
    });
  }

  String? _extractImage(Map<String, dynamic> p) {
    if (p['image_url'] != null && p['image_url'].toString().isNotEmpty) return p['image_url'].toString();
    if (p['images'] is List && (p['images'] as List).isNotEmpty) return (p['images'] as List).first.toString();
    return null;
  }

  String _greetingName(MarketStrings t) {
    final user = Supabase.instance.client.auth.currentUser;
    final full = user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'];
    if (full != null && (full as String).trim().isNotEmpty) return full.trim().split(' ').first;
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return t.client;
  }

  void _showComing(String feature) {
    final t = context.mkt;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.comingSoon(feature)), backgroundColor: MarketColors.gold));
  }

  // --------------------------------------------------------
  // MIXAGE INTELLIGENT — l'ordre de "Tous les produits" varie
  // par utilisateur et par jour (seed = user_id + date du jour),
  // mais reste stable pendant la session et à la pagination.
  // --------------------------------------------------------
  int _stableHash(String input) {
    var hash = 0;
    for (final unit in input.codeUnits) {
      hash = 0x1fffffff & (hash + unit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= (hash >> 11);
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash;
  }

  String _mixSeed() {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    final day = DateTime.now().toIso8601String().substring(0, 10);
    return '$uid-$day';
  }

  List<Map<String, dynamic>> _smartMix(List<Map<String, dynamic>> items) {
    final seed = _mixSeed();
    final scored = items.map((p) {
      final id = p['id']?.toString() ?? Random().nextInt(999999).toString();
      return MapEntry(_stableHash('$seed-$id'), p);
    }).toList();
    scored.sort((a, b) => a.key.compareTo(b.key));
    return scored.map((e) => e.value).toList();
  }

  bool _isExpired(Map<String, dynamic> p) {
    final exp = p['expires_at'];
    if (exp == null) return false;
    final dt = DateTime.tryParse(exp.toString());
    if (dt == null) return false;
    return !dt.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.mkt;
    final featuredAsync = ref.watch(featuredProductsProvider);
    final flashAsync = ref.watch(flashSalesProvider);
    final forYouAsync = ref.watch(forYouProvider);
    final all = ref.watch(allMarketProductsProvider);
    final hasMore = ref.read(forYouProvider.notifier).hasMore;
    final mixedAll = _smartMix(all);

    featuredAsync.whenData((b) => WidgetsBinding.instance.addPostFrameCallback((_) => _startBannerAuto(b.length)));

    return Scaffold(
      backgroundColor: MarketColors.lightBg,
      body: RefreshIndicator(
        color: MarketColors.red,
        onRefresh: () async {
          ref.invalidate(featuredProductsProvider);
          ref.invalidate(flashSalesProvider);
          ref.invalidate(featuredShopsProvider);
          await ref.read(forYouProvider.notifier).refresh();
        },
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(child: _buildTopBar(t)),
            SliverToBoxAdapter(child: _buildHero(featuredAsync, t)),
            SliverToBoxAdapter(child: _buildFeaturedStrip(featuredAsync, t)),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(child: _buildTrustBadges(t)),
            SliverToBoxAdapter(child: _buildSearchBar(t)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildSupermarketSection(t)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildPromoBannersRow(t)),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(child: _buildB2BTools(t)),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(child: _buildFlashSaleSection(flashAsync, t)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildSectionHeader(t.allProducts)),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            _buildGrid(forYouAsync, mixedAll, hasMore, t),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(t),
    );
  }

  Widget _buildTopBar(MarketStrings t) {
    return Container(
      color: MarketColors.white,
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.white, Color(0xFFFFF6F6)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MarketColors.cardBorder),
                ),
                child: const Icon(Icons.shopping_bag_rounded, color: MarketColors.red, size: 20)),
            const SizedBox(width: 9),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(
                  text: const TextSpan(children: [
                TextSpan(text: 'THIX ', style: TextStyle(color: MarketColors.red, fontWeight: FontWeight.w900, fontSize: 17)),
                TextSpan(text: 'MARKET', style: TextStyle(color: MarketColors.gold, fontWeight: FontWeight.w900, fontSize: 17)),
              ])),
              Text(t.appTagline, style: const TextStyle(color: MarketColors.mutedText, fontSize: 10.5)),
            ]),
          ]),
          Row(children: [
            InkWell(
                onTap: () => context.push('/market/notifications'),
                child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: MarketColors.cardBorder)),
                    child: const Icon(Icons.notifications_none_rounded, size: 18))),
            const SizedBox(width: 8),
            InkWell(
                onTap: () => context.push('/user/dashboard'),
                child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [MarketColors.red, MarketColors.redDark]), shape: BoxShape.circle),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 18))),
          ]),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // HERO BANNER — reconstruit, connecté directement à
  // featuredProductsProvider. Aucun mockup : si aucun produit
  // n'est marqué "vedette", la section est simplement masquée.
  // --------------------------------------------------------
  Widget _buildHero(AsyncValue<List<Map<String, dynamic>>> async, MarketStrings t) {
    return async.when(
      loading: () => const SizedBox(height: 210, child: Center(child: CircularProgressIndicator(color: MarketColors.red))),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return _buildHeroContent(products, t);
      },
    );
  }

  Widget _buildHeroContent(List<Map<String, dynamic>> products, MarketStrings t) {
    return Column(children: [
      SizedBox(
        height: 210,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification) {
              _bannerTimer?.cancel();
              _bannerReady = false;
            } else if (n is ScrollEndNotification) {
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) _startBannerAuto(products.length);
              });
            }
            return false;
          },
          child: PageView.builder(
            controller: _bannerCtrl,
            itemCount: products.length,
            onPageChanged: (i) => setState(() => _currentBanner = i),
            itemBuilder: (_, index) {
              final p = products[index];
              final imageUrl = _extractImage(p);
              final title = (p['title'] ?? '').toString();
              final subtitle = (p['description'] ?? '').toString();
              final id = p['id']?.toString() ?? '';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => context.push('/market/product/$id'),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [MarketColors.redDark, MarketColors.red]),
                      image: imageUrl != null
                          ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.55), BlendMode.darken))
                          : null,
                      boxShadow: [BoxShadow(color: MarketColors.red.withOpacity(0.22), blurRadius: 16, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (index == 0)
                          Text('${t.greeting}, ${_greetingName(t)} 👋', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 7),
                        Text(title.isEmpty ? '—' : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.2)),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          SizedBox(width: 210, child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
                        ],
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(gradient: const LinearGradient(colors: [MarketColors.gold, Color(0xFFC9862B)]), borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.visibility_rounded, size: 14, color: MarketColors.redDark),
                            const SizedBox(width: 6),
                            Text(t.viewOffer, style: const TextStyle(color: MarketColors.redDark, fontWeight: FontWeight.w800, fontSize: 11.5)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(products.length, (i) {
            final a = i == _currentBanner;
            return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 5,
                width: a ? 16 : 5,
                decoration: BoxDecoration(color: a ? MarketColors.red : Colors.grey.shade300, borderRadius: BorderRadius.circular(10)));
          })),
      const SizedBox(height: 4),
    ]);
  }

  Widget _buildFeaturedStrip(AsyncValue<List<Map<String, dynamic>>> async, MarketStrings t) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return _AutoScrollProductStrip(products: products, badgeType: _StripBadge.featured, title: t.featuredProducts, icon: Icons.star_rounded);
      },
    );
  }

  Widget _buildTrustBadges(MarketStrings t) {
    return Container(
      color: MarketColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _trustItem(Icons.lock_outline_rounded, t.securePayment),
          _trustItem(Icons.verified_user_outlined, t.verifiedSellers),
          _trustItem(Icons.local_shipping_outlined, t.reliableDelivery),
          _trustItem(Icons.headset_mic_outlined, t.support247),
        ],
      ),
    );
  }

  Widget _trustItem(IconData icon, String label) {
    return Row(children: [
      Icon(icon, size: 13, color: MarketColors.red),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildSearchBar(MarketStrings t) {
    return Container(
      color: MarketColors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Row(children: [
        Expanded(
            child: GestureDetector(
                onTap: () => context.push('/market/search'),
                child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: MarketColors.cardBorder, width: 1.2)),
                    child: Row(children: [
                      const Icon(Icons.search_rounded, size: 18, color: MarketColors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t.searchHint, style: const TextStyle(fontSize: 11.5, color: MarketColors.mutedText))),
                    ])))),
        const SizedBox(width: 8),
        InkWell(
            onTap: () => context.push('/market/search'),
            child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [MarketColors.red, MarketColors.redDark]), borderRadius: BorderRadius.circular(22)),
                child: Center(child: Text(t.search, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5))))),
      ]),
    );
  }

  Widget _buildSupermarketSection(MarketStrings t) {
    final shopsAsync = ref.watch(featuredShopsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t.homeSupermarkets, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
          GestureDetector(onTap: () => _safeNavigate('marketShops', '/market/shops'), child: Text(t.seeAll, style: const TextStyle(color: MarketColors.red, fontSize: 11, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 14),
        shopsAsync.when(
          loading: () => const SizedBox(height: 58, child: Center(child: CircularProgressIndicator(color: MarketColors.red))),
          error: (_, __) => const SizedBox.shrink(),
          data: (shops) {
            if (shops.isEmpty) return Text(t.noSupermarket, style: const TextStyle(color: MarketColors.mutedText, fontSize: 11));
            return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: shops.take(4).map((s) {
                  return GestureDetector(
                      onTap: () => context.push('/market/shop/${s['id']}'),
                      child: Column(children: [
                        Container(
                            height: 56,
                            width: 56,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [MarketColors.red, MarketColors.redDark]),
                                image: s['logo_url'] != null ? DecorationImage(image: NetworkImage(s['logo_url']), fit: BoxFit.cover) : null),
                            child: s['logo_url'] == null ? const Icon(Icons.storefront_rounded, color: Colors.white, size: 24) : null),
                        const SizedBox(height: 6),
                        Text((s['name'] ?? 'Shop').toString(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ]));
                }).toList());
          },
        ),
      ]),
    );
  }

  Widget _buildPromoBannersRow(MarketStrings t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(
            child: GestureDetector(
                onTap: () => _safeNavigate('marketFlashSales', '/market/flash-sales'),
                child: Container(
                    height: 130,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [MarketColors.redDark, MarketColors.red]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: MarketColors.red.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 6))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.exclusiveOffers, style: const TextStyle(color: MarketColors.gold, fontWeight: FontWeight.w800, fontSize: 9)),
                      const SizedBox(height: 5),
                      Text(t.upTo50, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                      Text(t.onPremiumSelection, style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
                      const Spacer(),
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(gradient: const LinearGradient(colors: [MarketColors.gold, Color(0xFFC9862B)]), borderRadius: BorderRadius.circular(8)),
                          child: Text(t.discover, style: const TextStyle(color: MarketColors.redDark, fontWeight: FontWeight.w800, fontSize: 10))),
                    ])))),
        const SizedBox(width: 10),
        Expanded(
            child: GestureDetector(
                onTap: () => _safeNavigate('vendorDashboard', '/market/vendor/dashboard'),
                child: Container(
                    height: 130,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [MarketColors.creamBg, Colors.white]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.sellWithThix, style: const TextStyle(color: Color(0xFFC9862B), fontWeight: FontWeight.w800, fontSize: 9)),
                      const SizedBox(height: 5),
                      Text(t.growBusiness, style: const TextStyle(color: MarketColors.darkText, fontWeight: FontWeight.w900, fontSize: 13, height: 1.15)),
                      const Spacer(),
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(gradient: const LinearGradient(colors: [MarketColors.gold, Color(0xFFC9862B)]), borderRadius: BorderRadius.circular(8)),
                          child: Text(t.start, style: const TextStyle(color: MarketColors.redDark, fontWeight: FontWeight.w800, fontSize: 10))),
                    ])))),
      ]),
    );
  }

  Widget _buildB2BTools(MarketStrings t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: MarketColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _b2bItem(Icons.compare_arrows_rounded, t.compare, () => _safeNavigate('marketProductComparator', '/market/compare')),
            _b2bItem(Icons.notifications_active_rounded, t.priceAlert, () => _safeNavigate('marketPriceAlerts', '/market/price-alerts')),
            _b2bItem(Icons.request_quote_rounded, t.b2bQuote, () => _showComing(t.b2bQuote)),
            _b2bItem(Icons.favorite_rounded, t.wishlist, () => _safeNavigate('marketWishlist', '/market/wishlist')),
          ],
        ),
      ),
    );
  }

  Widget _b2bItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
            padding: const EdgeInsets.all(3),
            child: Column(children: [Icon(icon, color: MarketColors.red, size: 21), const SizedBox(height: 5), Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800))])));
  }

  // --------------------------------------------------------
  // OFFRES FLASH — auto-scroll continu identique au hero (même
  // logique, même cadence). Les produits dont le compte à rebours
  // est arrivé à zéro sont retirés de cette bande et redescendent
  // naturellement dans "Tous les produits" ci-dessous.
  // --------------------------------------------------------
  Widget _buildFlashSaleSection(AsyncValue<List<Map<String, dynamic>>> async, MarketStrings t) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final active = list.where((p) => !_isExpired(p)).toList();
        if (active.isEmpty) return const SizedBox.shrink();

        DateTime? timerEnd;
        for (final p in active) {
          final dt = DateTime.tryParse(p['expires_at']?.toString() ?? '');
          if (dt != null && (timerEnd == null || dt.isBefore(timerEnd))) timerEnd = dt;
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (timerEnd != null)
            Container(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [MarketColors.redDark, MarketColors.red])),
              padding: const EdgeInsets.symmetric(vertical: 7),
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
                      child: FlashSaleTimer(endTime: timerEnd!),
                    ),
                  ),
                  Expanded(child: ClipRect(child: _MarqueeText(text: t.flashSaleBannerText))),
                ],
              ),
            ),
          _AutoScrollProductStrip(products: active, badgeType: _StripBadge.flash, title: t.flashOffers, icon: Icons.bolt_rounded, liveLabel: t.live),
        ]);
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)));
  }

  Widget _buildGrid(AsyncValue<List<Map<String, dynamic>>> forYouAsync, List<Map<String, dynamic>> mixedAll, bool hasMore, MarketStrings t) {
    return forYouAsync.when(
      loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator(color: MarketColors.red)))),
      error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('${t.error}: $e'))),
      data: (_) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.6),
          delegate: SliverChildBuilderDelegate((_, i) {
            if (i >= mixedAll.length) return const Center(child: CircularProgressIndicator(color: MarketColors.red));
            return ProductCard(product: mixedAll[i]);
          }, childCount: mixedAll.length + (hasMore ? 1 : 0)),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(MarketStrings t) {
    return Container(
      color: MarketColors.white,
      padding: const EdgeInsets.only(top: 6),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _navItem(Icons.home_rounded, t.home, 0),
                _navItem(Icons.receipt_long_rounded, t.orders, 1),
                const SizedBox(width: 58),
                _navItem(Icons.favorite_rounded, t.wishlist, 3),
                _navItem(Icons.notifications_active_rounded, t.alerts, 4),
              ]),
              Positioned(
                  top: -18,
                  child: GestureDetector(
                      onTap: () => context.push('/market/cart'),
                      child: Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [MarketColors.red, MarketColors.redDark]),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3.5),
                              boxShadow: [BoxShadow(color: MarketColors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
                          child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 23)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final sel = _selectedNav == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedNav = index);
        if (index == 0) _scroll.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        if (index == 1) context.push('/market/orders');
        if (index == 3) context.push('/market/wishlist');
        if (index == 4) context.push('/market/price-alerts');
      },
      child: Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: sel ? MarketColors.red : MarketColors.mutedText, size: 22),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, style: TextStyle(fontSize: 9, color: sel ? MarketColors.red : MarketColors.mutedText, fontWeight: sel ? FontWeight.w800 : FontWeight.w500)),
          ])),
    );
  }
}

enum _StripBadge { flash, featured, none }

class _AutoScrollProductStrip extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final _StripBadge badgeType;
  final String title;
  final IconData icon;
  final String? liveLabel;

  const _AutoScrollProductStrip({
    required this.products,
    required this.badgeType,
    required this.title,
    required this.icon,
    this.liveLabel,
  });

  @override
  State<_AutoScrollProductStrip> createState() => _AutoScrollProductStripState();
}

class _AutoScrollProductStripState extends State<_AutoScrollProductStrip> {
  final ScrollController _ctrl = ScrollController();
  Timer? _timer;
  bool _paused = false;
  static const double _step = 1.1;
  static const Duration _tick = Duration(milliseconds: 16);

  bool get _active => widget.products.length > 4;

  @override
  void initState() {
    super.initState();
    if (_active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void didUpdateWidget(covariant _AutoScrollProductStrip old) {
    super.didUpdateWidget(old);
    // Un produit a expiré / la liste a changé : on relance proprement.
    if (old.products.length != widget.products.length) {
      _timer?.cancel();
      if (_active) WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  void _start() {
    _timer = Timer.periodic(_tick, (_) {
      if (!_ctrl.hasClients || _paused) return;
      final maxExt = _ctrl.position.maxScrollExtent;
      final next = _ctrl.offset + _step;
      _ctrl.jumpTo(next >= maxExt ? 0 : next);
    });
  }

  void _pause() => _paused = true;
  void _resumeAfterDelay() => Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _paused = false;
      });

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Icon(widget.icon, color: MarketColors.gold, size: 19),
          const SizedBox(width: 5),
          Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
          if (_active && widget.liveLabel != null) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(color: MarketColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(7)),
              child: Text(widget.liveLabel!, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: MarketColors.gold)),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 200,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (!_active) return false;
            if (n is ScrollStartNotification) {
              _pause();
            } else if (n is ScrollEndNotification) {
              _resumeAfterDelay();
            }
            return false;
          },
          child: ListView.separated(
            controller: _ctrl,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => ProductCard(
              product: widget.products[i],
              variant: ProductCardVariant.horizontal,
              width: 132,
              isFlashSale: widget.badgeType == _StripBadge.flash,
              isFeatured: widget.badgeType == _StripBadge.featured,
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }
}

class _MarqueeText extends StatefulWidget {
  final String text;
  const _MarqueeText({required this.text});
  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  late final ScrollController _ctrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_ctrl.hasClients) return;
      final maxScroll = _ctrl.position.maxScrollExtent;
      final current = _ctrl.offset;
      _ctrl.jumpTo(current >= maxScroll ? 0 : current + 2.0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: ListView.builder(
        controller: _ctrl,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Text(widget.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
        ),
      ),
    );
  }
}
