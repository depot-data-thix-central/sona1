// lib/presentation/thix_market/pages/product_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';

import '../providers/market_providers.dart';
import '../checkout/checkout_page.dart';
import '../cart/cart_provider.dart';

class _MarketColors {
  static const redDark = Color(0xFF5C0E12);
  static const red = Color(0xFFD81E2C);
  static const gold = Color(0xFFF0A93B);
  static const lightBg = Color(0xFFF7F7FA);
  static const pureWhite = Color(0xFFFFFFFF);
  static const darkText = Color(0xFF1A1A1A);
  static const mutedText = Color(0xFF8A8A8F);
  static const cardBorder = Color(0xFFE5E7EB);
  static const successGreen = Color(0xFF00B074);
}

final productDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, productId) async {
  final db = ref.read(supabaseClientProvider);
  final prod =
      await db.from('products').select().eq('id', productId).maybeSingle();

  if (prod == null) throw Exception('Produit introuvable');

  Map<String, dynamic> shop = {};
  if (prod['shop_id'] != null) {
    final s =
        await db.from('shops').select().eq('id', prod['shop_id']).maybeSingle();
    if (s != null) shop = s;
  }

  List<Map<String, dynamic>> reviews = [];
  try {
    final r = await db
        .from('reviews')
        .select('*, user:users(name, avatar)')
        .eq('product_id', productId)
        .order('created_at', ascending: false)
        .limit(20);
    reviews = List<Map<String, dynamic>>.from(r);
  } catch (_) {}

  double rating = 0;
  if (reviews.isNotEmpty) {
    double sum = 0;
    for (final rev in reviews) {
      sum += (rev['rating'] as num).toDouble();
    }
    rating = sum / reviews.length;
  }

  return {
    ...prod,
    'shop': shop,
    'reviews': reviews,
    'reviews_count': reviews.length,
    'rating': rating,
  };
});

final storeProductsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, shopId) async {
  final db = ref.read(supabaseClientProvider);
  final res =
      await db.from('products').select().eq('shop_id', shopId).limit(10);
  return List<Map<String, dynamic>>.from(res);
});

final isFavoriteProvider =
    FutureProvider.family<bool, String>((ref, productId) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (uid == null) return false;
  final res = await db
      .from('wishlist')
      .select()
      .match({'user_id': uid, 'product_id': productId}).maybeSingle();
  return res != null;
});

class ProductDetailPage extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailPage({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _qty = 1;
  String? _variant;
  String? _colorSel;
  bool _adding = false;
  int _imgIndex = 0;

  String _t(BuildContext context, String fr, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'fr' ? fr : en;
  }

  Future<void> _toggleFav(bool currentlyFav) async {
    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(context, 'Veuillez vous connecter', 'Please log in')),
        ),
      );
      return;
    }
    try {
      if (!currentlyFav) {
        await db.from('wishlist').insert({
          'user_id': uid,
          'product_id': widget.productId,
        });
      } else {
        await db.from('wishlist').delete().match({
          'user_id': uid,
          'product_id': widget.productId,
        });
      }
      ref.invalidate(isFavoriteProvider(widget.productId));
    } catch (e) {
      debugPrint('fav error $e');
    }
  }

  Future<void> _addToCart({int maxStock = 0}) async {
    if (maxStock <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t(context, 'Rupture de stock', 'Out of stock')),
            backgroundColor: _MarketColors.red,
          ),
        );
      }
      return;
    }

    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(context, 'Veuillez vous connecter', 'Please log in')),
        ),
      );
      return;
    }

    setState(() => _adding = true);

    try {
      final existing = await db
          .from('cart')
          .select()
          .match({'user_id': uid, 'product_id': widget.productId})
          .maybeSingle();

      if (existing != null) {
        int cur = existing['quantity'] != null
            ? (existing['quantity'] as num).toInt()
            : 0;
        final newQty = cur + _qty;
        if (newQty > maxStock) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _t(context, 'Stock limité à $maxStock',
                      'Stock limited to $maxStock'),
                ),
                backgroundColor: _MarketColors.red,
              ),
            );
          }
          return;
        }
        await db
            .from('cart')
            .update({'quantity': newQty}).eq('id', existing['id']);
      } else {
        if (_qty > maxStock) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _t(context, 'Stock limité à $maxStock',
                      'Stock limited to $maxStock'),
                ),
                backgroundColor: _MarketColors.red,
              ),
            );
          }
          return;
        }
        await db.from('cart').insert({
          'user_id': uid,
          'product_id': widget.productId,
          'quantity': _qty,
          'variant': _variant,
          'color': _colorSel,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t(context, 'Ajouté au panier !', 'Added to cart!')),
            backgroundColor: _MarketColors.successGreen,
          ),
        );
      }
      ref.invalidate(cartProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: _MarketColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _buyNow(int stock) async {
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(context, 'Rupture de stock', 'Out of stock')),
        ),
      );
      return;
    }
    await _addToCart(maxStock: stock);
    if (mounted) {
      try {
        context.push('/market/checkout');
      } catch (_) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CheckoutPage()),
        );
      }
    }
  }

  void _openChat(Map<String, dynamic> product) {
    final shop = product['shop'] as Map<String, dynamic>?;
    final shopId = product['shop_id'];

    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_t(context, 'Boutique indisponible', 'Store unavailable')),
        ),
      );
      return;
    }

    String name = shop?['name']?.toString() ?? 'Vendeur';
    String? avatar = shop?['logo_url']?.toString();
    context.push(
      '/market/chat/$shopId',
      extra: {'title': name, 'userName': name, 'userAvatar': avatar},
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(productDetailProvider(widget.productId));
    final favAsync = ref.watch(isFavoriteProvider(widget.productId));

    return detailAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _MarketColors.pureWhite,
        body: Center(
          child: CircularProgressIndicator(color: _MarketColors.red),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text('Erreur $e')),
      ),
      data: (product) {
        final imagesRaw = product['images'] as List?;
        List<String> images = [];
        if (imagesRaw != null && imagesRaw.isNotEmpty) {
          images = imagesRaw.map((e) => e.toString()).toList();
        } else if (product['image_url'] != null) {
          images = [product['image_url'].toString()];
        } else {
          images = [''];
        }

        bool hasDiscount = product['discount_price'] != null &&
            (product['discount_price'] as num) < (product['price'] as num);

        String currency = product['currency']?.toString() ?? 'CDF';
        String symbol =
            currency == 'USD' ? '\$' : (currency == 'EUR' ? '€' : currency);

        int stock =
            product['stock'] != null ? (product['stock'] as num).toInt() : 0;
        bool available = stock > 0;

        List variants =
            product['variants'] is List ? product['variants'] as List : [];
        List colors =
            product['colors'] is List ? product['colors'] as List : [];
        List reviews =
            product['reviews'] is List ? product['reviews'] as List : [];
        bool isFav = favAsync.valueOrNull ?? false;
        final shopId = product['shop_id']?.toString();
        final shop = product['shop'] as Map<String, dynamic>?;

        return Scaffold(
          backgroundColor: _MarketColors.lightBg,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 380,
                pinned: true,
                backgroundColor: _MarketColors.pureWhite,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _circleBtn(
                    Icons.arrow_back_rounded,
                    () => context.pop(),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: _circleBtn(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      () => _toggleFav(isFav),
                      color:
                          isFav ? _MarketColors.red : _MarketColors.darkText,
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      Container(color: _MarketColors.pureWhite),
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 400,
                          viewportFraction: 1,
                          enableInfiniteScroll: images.length > 1,
                          onPageChanged: (i, _) =>
                              setState(() => _imgIndex = i),
                        ),
                        items: images
                            .map(
                              (img) => Image.network(
                                img,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: _MarketColors.red,
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    size: 50,
                                    color: _MarketColors.mutedText,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      if (images.length > 1)
                        Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: images.asMap().entries.map((e) {
                              final active = _imgIndex == e.key;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: active ? 24 : 8,
                                height: 6,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: active
                                      ? _MarketColors.red
                                      : _MarketColors.cardBorder,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== PRIX + TITRE =====
                    Container(
                      color: _MarketColors.pureWhite,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${(hasDiscount ? product['discount_price'] : product['price']).toString()} $symbol',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: _MarketColors.darkText,
                                ),
                              ),
                              if (hasDiscount)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 8, bottom: 4),
                                  child: Text(
                                    '${product['price'].toString()} $symbol',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      decoration: TextDecoration.lineThrough,
                                      color: _MarketColors.mutedText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            product['title']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _MarketColors.darkText,
                              height: 1.3,
                            ),
                          ),
                          // ===== BANDEAU RUPTURE DE STOCK =====
                          if (!available) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _MarketColors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.remove_shopping_cart_rounded,
                                    size: 16,
                                    color: _MarketColors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _t(context, 'Rupture de stock',
                                        'Out of stock'),
                                    style: const TextStyle(
                                      color: _MarketColors.red,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              RatingBar.builder(
                                initialRating:
                                    (product['rating'] as num).toDouble(),
                                minRating: 1,
                                direction: Axis.horizontal,
                                allowHalfRating: true,
                                itemCount: 5,
                                itemSize: 14,
                                ignoreGestures: true,
                                itemBuilder: (_, __) => const Icon(
                                  Icons.star_rounded,
                                  color: _MarketColors.gold,
                                ),
                                onRatingUpdate: (_) {},
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${product['reviews_count']} ${_t(context, 'avis', 'reviews')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: _MarketColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ===== VARIANTES + QUANTITÉ =====
                    Container(
                      color: _MarketColors.pureWhite,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (variants.isNotEmpty) _buildVariants(variants),
                          if (variants.isNotEmpty && colors.isNotEmpty)
                            const SizedBox(height: 16),
                          if (colors.isNotEmpty) _buildColors(colors),
                          if (variants.isNotEmpty || colors.isNotEmpty)
                            const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(
                                _t(context, 'Quantité', 'Quantity'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _MarketColors.darkText,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  color: _MarketColors.lightBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _MarketColors.cardBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _qtyBtn(Icons.remove_rounded, () {
                                      if (_qty > 1) setState(() => _qty--);
                                    }),
                                    SizedBox(
                                      width: 40,
                                      child: Center(
                                        child: Text(
                                          '$_qty',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: _MarketColors.darkText,
                                          ),
                                        ),
                                      ),
                                    ),
                                    _qtyBtn(Icons.add_rounded, () {
                                      if (_qty < stock) {
                                        setState(() => _qty++);
                                      }
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ===== BOUTIQUE =====
                    if (shop != null && shop.isNotEmpty)
                      Container(
                        color: _MarketColors.pureWhite,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _MarketColors.cardBorder,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      shop['logo_url']?.toString() ?? '',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.storefront_rounded,
                                        color: _MarketColors.mutedText,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        shop['name']?.toString() ??
                                            _t(context, 'Boutique Partenaire',
                                                'Partner Store'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: _MarketColors.darkText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_t(context, 'Partenaire vérifié', 'Verified Partner')} • ${shop['city'] ?? ''}',
                                        style: const TextStyle(
                                          color: _MarketColors.mutedText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        context.push('/market/shop/$shopId'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _MarketColors.darkText,
                                      side: const BorderSide(
                                        color: _MarketColors.darkText,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: Text(
                                      _t(context, 'Plus de produits',
                                          'More products'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        context.push('/market/shop/$shopId'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _MarketColors.darkText,
                                      side: const BorderSide(
                                        color: _MarketColors.darkText,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: Text(
                                      _t(context, 'Profil vendeur',
                                          'Store profile'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 10),

                    // ===== DÉTAILS + AVIS =====
                    Container(
                      color: _MarketColors.pureWhite,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(context, 'Détails du produit', 'Product details'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _MarketColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            product['description']?.toString() ?? '',
                            style: const TextStyle(
                              height: 1.5,
                              color: _MarketColors.mutedText,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(color: _MarketColors.cardBorder),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _t(context, 'Avis clients', 'Customer reviews'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _MarketColors.darkText,
                                ),
                              ),
                              if (reviews.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _showAllReviews(reviews),
                                  child: Text(
                                    _t(context, 'Voir tout', 'See all'),
                                    style: const TextStyle(
                                      color: _MarketColors.red,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (reviews.isEmpty)
                            Text(
                              _t(context, 'Aucun avis pour le moment.',
                                  'No reviews yet.'),
                              style: const TextStyle(
                                color: _MarketColors.mutedText,
                                fontSize: 13,
                              ),
                            )
                          else
                            ...reviews.take(3).map((r) => _reviewCard(r)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ],
          ),

          // ===== BOTTOM BAR =====
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: _MarketColors.pureWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.push('/market/shop/$shopId'),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_rounded,
                            color: _MarketColors.darkText, size: 22),
                        SizedBox(height: 2),
                        Text(
                          'Store',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => _openChat(product),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: _MarketColors.darkText,
                          width: 1.5,
                        ),
                        foregroundColor: _MarketColors.darkText,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Chat now',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed:
                          available && !_adding ? () => _buyNow(stock) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            available ? const Color(0xFFD0391A) : Colors.grey,
                        disabledBackgroundColor: Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: _adding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              available
                                  ? 'Buy now'
                                  : _t(context, 'Rupture de stock',
                                      'Out of stock'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
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

  Widget _circleBtn(IconData icon, VoidCallback onTap,
      {Color color = _MarketColors.darkText}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _MarketColors.pureWhite.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: _MarketColors.darkText),
      ),
    );
  }

  Widget _buildVariants(List list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(context, 'Taille / Modèle', 'Size / Model'),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: _MarketColors.darkText,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: list.map((v) {
            final label = v is String ? v : v['name'].toString();
            final sel = _variant == label;
            return _chip(label, sel, () => setState(() => _variant = sel ? null : label));
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildColors(List list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(context, 'Couleurs', 'Colors'),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: _MarketColors.darkText,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: list.map((c) {
            final label = c is String ? c : c['name'].toString();
            final sel = _colorSel == label;
            return _chip(label, sel, () => setState(() => _colorSel = sel ? null : label));
          }).toList(),
        ),
      ],
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? _MarketColors.red.withOpacity(0.1) : _MarketColors.lightBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? _MarketColors.red : _MarketColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
            fontSize: 13,
            color: sel ? _MarketColors.red : _MarketColors.darkText,
          ),
        ),
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review) {
    final user = review['user'] as Map?;
    String name =
        user?['name']?.toString() ?? _t(context, 'Client vérifié', 'Verified Customer');
    String? avatar = user?['avatar']?.toString();

    double rating =
        review['rating'] != null ? (review['rating'] as num).toDouble() : 0;
    String comment = review['comment']?.toString() ?? '';

    String date = '';
    if (review['created_at'] != null) {
      try {
        date = DateFormat('dd/MM/yyyy')
            .format(DateTime.parse(review['created_at'].toString()));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _MarketColors.lightBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _MarketColors.cardBorder,
                backgroundImage:
                    avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
                    ? const Icon(Icons.person_rounded,
                        size: 16, color: _MarketColors.mutedText)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _MarketColors.darkText,
                      ),
                    ),
                    RatingBar.builder(
                      initialRating: rating,
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 10,
                      ignoreGestures: true,
                      itemBuilder: (context, _) =>
                          const Icon(Icons.star_rounded, color: _MarketColors.gold),
                      onRatingUpdate: (_) {},
                    ),
                  ],
                ),
              ),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 11,
                  color: _MarketColors.mutedText,
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                comment,
                style: const TextStyle(
                  height: 1.4,
                  fontSize: 13,
                  color: _MarketColors.darkText,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAllReviews(List reviews) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _MarketColors.pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text(
                        _t(context, 'Tous les avis', 'All reviews'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _MarketColors.darkText,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: _MarketColors.lightBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: _MarketColors.darkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) =>
                        _reviewCard(reviews[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
