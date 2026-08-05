// lib/presentation/thix_money/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/nav.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _Service {
  final String label;
  final Color color;
  final IconData icon;
  final String? route;
  const _Service({required this.label, required this.color, required this.icon, this.route});
}

// Courbe "colline" du bas de la section claire (comme sur la photo)
class _HillClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(size.width * 0.35, size.height, size.width * 0.65, size.height - 30);
    path.quadraticBezierTo(size.width * 0.85, size.height - 55, size.width, size.height - 20);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  // ─── PALETTE (Charte du design de référence) ───
  static const Color bgLight = Color(0xFFF5F5F3);
  static const Color darkBg = Color(0xFF1C1C1E);
  static const Color darkCard = Color(0xFF2A2A2E);
  static const Color accentLime = Color(0xFFD4FF3D);
  static const Color textDark = Color(0xFF16161A);
  static const Color textGrey = Color(0xFF8E8E93);

  final PageController _cardController = PageController(viewportFraction: 0.88);
  int _cardPage = 0;
  bool _balanceVisible = true;

  // ─── TES VRAIS SERVICES (inchangés) ───
  static const List<_Service> _services = [
    _Service(label: 'Crédit', color: Color(0xFF1E3A8A), icon: Icons.bolt_outlined, route: AppRoutes.thixMoneyLoans),
    _Service(label: 'Assurance', color: Color(0xFF0F766E), icon: Icons.security_outlined, route: null),
    _Service(label: 'Épargne', color: Color(0xFFB45309), icon: Icons.savings_outlined, route: AppRoutes.thixMoneySavings),
    _Service(label: 'Change', color: Color(0xFF6D28D9), icon: Icons.currency_exchange_outlined, route: null),
    _Service(label: 'Marchand', color: Color(0xFFC2410C), icon: Icons.storefront_outlined, route: AppRoutes.thixMarket),
    _Service(label: 'Dons', color: Color(0xFFBE123C), icon: Icons.favorite_border_rounded, route: null),
    _Service(label: 'Tontine', color: Color(0xFF0369A1), icon: Icons.groups_outlined, route: AppRoutes.thixMoneyTontines),
    _Service(label: 'Éducation', color: Color(0xFF0E7490), icon: Icons.school_outlined, route: AppRoutes.education),
    _Service(label: 'Virement', color: Color(0xFF1D4ED8), icon: Icons.language_outlined, route: AppRoutes.thixMoneySend),
    _Service(label: 'Microfinance', color: Color(0xFF15803D), icon: Icons.account_balance_outlined, route: AppRoutes.thixMoneyLoans),
    _Service(label: 'Investir', color: Color(0xFFB45309), icon: Icons.show_chart_rounded, route: AppRoutes.thixMoneyInvestments),
    _Service(label: 'Planifier', color: Color(0xFF0F172A), icon: Icons.calendar_month_outlined, route: AppRoutes.thixMoneySavings),
  ];

  // ─── DONNÉES RÉELLES SUPABASE ───
  Future<Map<String, dynamic>> _getRealDashboardData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return {'name': 'Utilisateur', 'balance_fc': 0.0, 'balance_usd': 0.0, 'thix_id': '', 'avatar_url': null};
    }

    final profileRes = await Supabase.instance.client
        .from('profiles')
        .select('first_name, full_name, avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    final name = profileRes?['first_name'] ?? profileRes?['full_name'] ?? 'Utilisateur';
    final avatarUrl = profileRes?['avatar_url'] as String?;

    // Thix ID + solde (FC et USD) proviennent tous deux du wallet enregistré en base
    final walletRes = await Supabase.instance.client
        .from('wallets')
        .select('balance, balance_usd, thix_id')
        .eq('user_id', user.id)
        .maybeSingle();

    final balanceFc = (walletRes?['balance'] ?? 0.0).toDouble();
    final balanceUsd = (walletRes?['balance_usd'] ?? 0.0).toDouble();
    final thixId = walletRes?['thix_id'] ?? '';

    return {
      'name': name,
      'balance_fc': balanceFc,
      'balance_usd': balanceUsd,
      'thix_id': thixId,
      'avatar_url': avatarUrl,
    };
  }

  String _formatAmount(double value) {
    final str = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i != 0 && (str.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  // Formate le Thix ID enregistré en base comme un numéro de carte (groupes de 4)
  String _formatThixId(String thixId) {
    if (thixId.isEmpty) return '•••• •••• •••• ••••';
    final clean = thixId.replaceAll(RegExp(r'\s+'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i != 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getRealDashboardData(),
        builder: (context, snapshot) {
          final data = snapshot.data ??
              {'name': '...', 'balance_fc': 0.0, 'balance_usd': 0.0, 'thix_id': '', 'avatar_url': null};
          final thixId = data['thix_id'] as String;

          return Column(
            children: [
              // ─── SECTION CLAIRE — Bonjour / Search / Favorites / Cards ───
              ClipPath(
                clipper: _HillClipper(),
                child: Container(
                  width: double.infinity,
                  color: bgLight,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(data['name'], data['avatar_url']),
                          const SizedBox(height: 20),
                          _buildSearchBar(),
                          const SizedBox(height: 28),
                          const Text(
                            'Favorites',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark),
                          ),
                          const SizedBox(height: 16),
                          _buildServiceFavorites(),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Cards',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textDark),
                              ),
                              InkWell(
                                onTap: () => context.push('/thix-money/cards/add'),
                                child: const Text(
                                  '+ ADD MORE',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textGrey, letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ─── SECTION SOMBRE — carte(s) + boutons + dots ───
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: darkBg,
                  child: Column(
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -70),
                        child: SizedBox(
                          height: 260,
                          child: PageView(
                            controller: _cardController,
                            onPageChanged: (i) => setState(() => _cardPage = i),
                            children: [
                              _buildBalanceCard(
                                thixId: thixId,
                                balanceFc: data['balance_fc'] as double,
                                balanceUsd: data['balance_usd'] as double,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -30),
                        child: _buildDotsIndicator(1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // BARRE DU HAUT (Bonjour + avatar)
  // ==========================================
  Widget _buildTopBar(String name, String? avatarUrl) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Bonjour, $name',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textDark),
        ),
        InkWell(
          onTap: () => context.push('/account'),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: darkBg,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? const Icon(Icons.person, color: Colors.white70)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return InkWell(
      onTap: () => context.push('/thix-money/search'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Rechercher', style: TextStyle(color: textGrey, fontSize: 14)),
            Icon(Icons.search_rounded, color: textGrey, size: 20),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // FAVORITES — tes services THIX MONEY, petits cercles sombres
  // ==========================================
  Widget _buildServiceFavorites() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final s = _services[index];
          final bool enabled = s.route != null;
          return InkWell(
            onTap: enabled
                ? () => context.push(s.route!)
                : () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${s.label} — bientôt disponible')),
                    ),
            borderRadius: BorderRadius.circular(32),
            child: Opacity(
              opacity: enabled ? 1.0 : 0.5,
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(color: darkBg, shape: BoxShape.circle),
                    child: Icon(s.icon, color: s.color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(s.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textDark)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // CARTE DE SOLDE — Thix ID en numéro de carte,
  // solde FC + USD toujours petit,
  // pill lime en bas avec les 4 actions (aucune oubliée)
  // ==========================================
  Widget _buildBalanceCard({
    required String thixId,
    required double balanceFc,
    required double balanceUsd,
  }) {
    final actions = [
      {'label': 'Top Up', 'icon': Icons.add_card_outlined, 'route': '/thix-money/topup'},
      {'label': 'Envoyer', 'icon': Icons.north_east_rounded, 'route': AppRoutes.thixMoneySend},
      {'label': 'Retrait', 'icon': Icons.south_west_rounded, 'route': '/thix-money/request'},
      {'label': 'Historique', 'icon': Icons.history_rounded, 'route': '/thix-money/history'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [darkCard, darkBg],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 22, height: 22, decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle)),
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: Container(width: 22, height: 22, decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), shape: BoxShape.circle)),
                        ),
                      ],
                    ),
                    Text(
                      'THIX ID',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      _balanceVisible ? '${_formatAmount(balanceFc)} FC' : '•••••• FC',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.white38, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      _balanceVisible ? '\$ ${balanceUsd.toStringAsFixed(2)}' : '•••• \$',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                      child: Icon(
                        _balanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.white38,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  _formatThixId(thixId),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.5),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          // ─── PILL LIME EN BAS DE CARTE — les 4 actions ───
          Positioned(
            bottom: -26,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: accentLime,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: actions.map((a) {
                  return InkWell(
                    onTap: () => context.push(a['route'] as String),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(a['icon'] as IconData, color: textDark, size: 20),
                          const SizedBox(height: 2),
                          Text(
                            a['label'] as String,
                            style: const TextStyle(color: textDark, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotsIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == _cardPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? accentLime : Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
