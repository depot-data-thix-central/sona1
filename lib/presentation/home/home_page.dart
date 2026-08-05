// lib/presentation/home/home_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/common/full_screen_message.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/notification_service.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/widgets/language_sheet.dart';
import 'package:thix_id/l10n/locale_controller.dart';

// ============================================================================
// CONSTANTES DE DESIGN
// ============================================================================
class AppColors {
  static const Color primaryBlue = Color(0xFF1877F2);
  static const Color darkNavy = Color(0xFF111827);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrayBg = Color(0xFFF0F2F5);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color goldBadge = Color(0xFFFBBF24);
  static const Color successGreen = Color(0xFF059669);
  static const Color dangerRed = Color(0xFFFF3B30);
  static const Color darkText = Color(0xFF111827);
  static const Color shadowLight = Color(0x0F000000);
  static const Color shadowSecondary = Color(0x0A000000);
  static const Color premiumSoftStart = Color(0xFFEAF2FF);
  static const Color premiumSoftEnd = Color(0xFFFFFFFF);
  static const Color premiumAccent = Color(0xFF0B3B8F);
  static const Color domainMedia = Color(0xFF7C3AED);
  static const Color domainMarket = Color(0xFFF97316);
  static const Color domainLearning = Color(0xFF2563EB);
  static const Color domainJobs = Color(0xFF16A34A);
  static const Color domainInfo = Color(0xFF0284C7);
  static const Color domainOpportunity = Color(0xFFF59E0B);
  static const Color domainEvents = Color(0xFFEF4444);
  static const Color domainNetwork = Color(0xFF4F46E5);
  static const Color domainHealth = Color(0xFFE11D48);
  static const Color domainMoney = Color(0xFF059669);
  static const Color domainGov = Color(0xFF334155);
  static const Color domainReservation = Color(0xFF0D9488);
}
class AppSpacing {
  static const double xs = 4; static const double s = 8; static const double m = 12; static const double l = 16; static const double xl = 20; static const double xxl = 24; static const double xxxl = 28; static const double huge = 32;
}
class AppRadius {
  static const double searchBar = 24; static const double mainCard = 22; static const double serviceCard = 18; static const double button = 14; static const double bottomNav = 30; static const double avatar = 50; static const double qrContainer = 16;
}
class AppShadows {
  static List<BoxShadow> main = [BoxShadow(color: AppColors.shadowLight, blurRadius: 20, offset: const Offset(0, 4))];
  static List<BoxShadow> secondary = [BoxShadow(color: AppColors.shadowSecondary, blurRadius: 8, offset: const Offset(0, 2))];
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class HomePagePremium extends StatefulWidget {
  const HomePagePremium({super.key});
  @override State<HomePagePremium> createState() => _HomePagePremiumState();
}
class _HomePagePremiumState extends State<HomePagePremium> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  late AnimationController _animationController;
  final PageController _headlinesController = PageController();
  final _counters = NotificationCountersService();
  final _profileService = ProfileService();
  static final RegExp _uidLikeRegex = RegExp(r'^[A-Za-z0-9_-]{20,}$');

  @override void initState() { super.initState(); _animationController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this); WidgetsBinding.instance.addPostFrameCallback((_) { if (!mounted) return; _animationController.forward(); }); }
  @override void dispose() { _searchController.dispose(); _animationController.dispose(); _headlinesController.dispose(); super.dispose(); }

  Future<void> _handleHomeSearchVerify() async {
    final l10n = AppLocalizations.of(context);
    final raw = _searchController.text.trim();
    if (raw.isEmpty) { await FullScreenMessage.showError(context, title: l10n.t('home_required_id_title'), message: l10n.t('home_required_id_msg')); return; }
    final normalized = ThixIdService.normalize(raw);
    final isThix = normalized.startsWith('THIX-');
    final isUid = _uidLikeRegex.hasMatch(raw);
    if (!isThix && !isUid) { await FullScreenMessage.showError(context, title: l10n.t('home_invalid_id_title'), message: l10n.t('home_invalid_id_msg')); return; }
    setState(() => _searching = true);
    try {
      ThixProfile? profile;
      if (isThix) { profile = await _profileService.fetchPublicProfileByThixId(normalized); } else { profile = await _profileService.fetchPublicProfileByUserId(raw); }
      if (!mounted) return;
      if (profile == null) { await FullScreenMessage.showError(context, title: l10n.t('home_profile_not_found_title'), message: l10n.t('home_profile_not_found_msg')); return; }
      final thix = profile.thixId.trim().toUpperCase();
      if (thix.isNotEmpty) { context.push('${AppRoutes.publicProfile}?thixId=$thix'); } else { await ThixIdentitySheets.showVerifySheet(context, initialUidOrThixId: profile.userId); }
    } catch (e) { if (!mounted) return; await FullScreenMessage.showError(context, title: l10n.t('home_verify_error_title'), message: l10n.t('home_verify_error_msg')); } finally { if (mounted) { setState(() => _searching = false); } }
  }

  // --- NAVIGATION PROFIL ---
  void _onProfileTap() {
    HapticFeedback.mediumImpact();
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      context.push(AppRoutes.login);
    } else {
      // Dashboard est dans la branche 3 du shell → go() pour basculer de branche
      context.go(AppRoutes.userDashboard);
    }
  }

  Future<void> _openThixAi() async { final auth = context.read<AuthController>(); if (auth.isAuthenticated) { context.push('/thix_ia'); return; } context.push(AppRoutes.login); }
  // Chat est dans la branche 2 → go() pour basculer de branche sans créer de doublon
  Future<void> _openThixChat() async { final auth = context.read<AuthController>(); if (auth.isAuthenticated) { context.go(AppRoutes.chat); } else { context.push(AppRoutes.login); } }
  
  Future<void> _openEmergency() async { 
    final auth = context.read<AuthController>(); 
    if (auth.isAuthenticated) { 
      context.push('/thix-urgent'); 
      return; 
    } 
    if (!mounted) return; 
    context.push(AppRoutes.login); 
  }
  
  void _openDocumentVault() { final auth = context.read<AuthController>(); if (auth.isAuthenticated) { context.push(AppRoutes.vault); } else { context.push(AppRoutes.login); } }
  void _openScanQr() => ThixIdentitySheets.showQrScanSheet(context);
  void _openMiniApps() { final l10n = AppLocalizations.of(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('home_mini_apps_coming_soon')))); }

  Future<void> _handleRequestAccount(BuildContext context) async {
    final auth = context.read<AuthController>();
    final res = await showModalBottomSheet<_AccountRequestChoice>(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => const AccountRequestSheet());
    switch (res) { case _AccountRequestChoice.personal: if (auth.isAuthenticated) { await auth.signOut(); } if (context.mounted) { context.push(AppRoutes.personalReg); } return; case null: return; }
  }

  void _handleServiceTap(String serviceKey) {
    switch (serviceKey) {
      case 'thixMedia': context.push(AppRoutes.thixMedia); break;
      case 'thixMarket': context.push(AppRoutes.thixMarket); break;
      case 'formations': context.push(AppRoutes.trainingHome); break;
      case 'emplois': context.push(AppRoutes.jobs); break;
      case 'thixInfo': context.push(AppRoutes.thixInfo); break;
      case 'opportunites': context.push(AppRoutes.opportunities); break;
      case 'evenements': context.push('/thix-event'); break;
      // Réseau Pro est dans la branche 1 → go() pour basculer sans empiler
      case 'reseauPro': context.go(AppRoutes.network); break;
      case 'thixSante': context.push(AppRoutes.thixSante); break;
      case 'thixMoney': context.push(AppRoutes.thixMoney); break;
      case 'monPays': context.push(AppRoutes.monPays); break;
      case 'reservation': context.push(AppRoutes.reservation); break;
      case 'thixUrgent': context.push(AppRoutes.thixUrgent); break;
      default: break;
    }
  }

  @override Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final safeTop = MediaQuery.paddingOf(context).top;
    final displayName = (auth.currentUser?.displayName.trim().isNotEmpty ?? false) ? auth.currentUser!.displayName.trim() : (auth.currentUser?.email.trim().isNotEmpty ?? false) ? auth.currentUser!.email.trim() : 'Bonjour';
    final photoUrl = auth.currentUser?.photoUrl;
    final badgeCountsStream = auth.currentUser == null ? Stream.value(SectionBadgeCounts.zero) : _counters.streamCounts(auth.currentUser!.id);
    
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      body: Stack(children: [
        const _HomeSoftBackground(),
        CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverPersistentHeader(pinned: true, delegate: _PinnedHeaderDelegate(safeTop: safeTop, displayName: displayName, photoUrl: photoUrl, isAuthenticated: auth.isAuthenticated, onProfileTap: _onProfileTap, onAccountRequest: () => _handleRequestAccount(context))),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.m)),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl), child: _SearchBarOverlay(controller: _searchController, isSearching: _searching, onVerify: _handleHomeSearchVerify))),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.m)),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl), child: _HeadlinesCarousel(controller: _headlinesController, uid: auth.currentUser?.id, onThixInfoTap: () => context.push(AppRoutes.thixInfo), onOpportunityTap: () => context.push(AppRoutes.opportunities)))),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.m)),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl), child: _QuickActionsRow(onScanTap: _openThixAi, onDocumentTap: _openDocumentVault, onChatTap: _openThixChat, onSecurityTap: _openEmergency))),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s)),
          SliverToBoxAdapter(child: StreamBuilder<SectionBadgeCounts>(stream: badgeCountsStream, builder: (context, snap) { final counts = snap.data ?? SectionBadgeCounts.zero; return _ServicesConstellation(counts: counts, onServiceTap: _handleServiceTap, onHomeTap: () => context.go(AppRoutes.home), onMiniAppsTap: _openMiniApps, onDocumentsTap: _openDocumentVault, onProfileTap: _onProfileTap, onScanTap: _openScanQr); })),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s)),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl), child: _PremiumStatusCard())),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.m)),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl), child: _PersonalisedSection())),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl + 24)),
        ]),
        if (_searching) Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.4), child: const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)))),
      ]),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double safeTop; final String displayName; final String? photoUrl; final bool isAuthenticated; final VoidCallback onProfileTap; final VoidCallback onAccountRequest;
  _PinnedHeaderDelegate({required this.safeTop, required this.displayName, required this.photoUrl, required this.isAuthenticated, required this.onProfileTap, required this.onAccountRequest});
  double _headerExtent() => safeTop + 92; @override double get maxExtent => _headerExtent(); @override double get minExtent => _headerExtent();
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) { return Container(decoration: BoxDecoration(color: AppColors.lightGrayBg, boxShadow: overlapsContent ? [const BoxShadow(color: AppColors.shadowSecondary, blurRadius: 14, offset: Offset(0, 8))] : null), child: _PremiumHeader(safeTop: safeTop, displayName: displayName, photoUrl: photoUrl, isAuthenticated: isAuthenticated, onProfileTap: onProfileTap, onAccountRequest: onAccountRequest)); }
  @override bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) { return safeTop != oldDelegate.safeTop || displayName != oldDelegate.displayName || photoUrl != oldDelegate.photoUrl || isAuthenticated != oldDelegate.isAuthenticated; }
}

// BACKGROUND
class _HomeSoftBackground extends StatelessWidget { const _HomeSoftBackground(); @override Widget build(BuildContext context) { return IgnorePointer(child: RepaintBoundary(child: Stack(children: [Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF7F9FF), AppColors.lightGrayBg])))), Positioned(top: -220, right: -180, child: _SoftBlob(size: 420, colors: const [Color(0x2A003BFF), Color(0x1400214F)])), Positioned(top: -120, left: -220, child: _SoftBlob(size: 360, colors: const [Color(0x1F003BFF), Color(0x1200214F)]))]))); } }
class _SoftBlob extends StatelessWidget { final double size; final List<Color> colors; const _SoftBlob({required this.size, required this.colors}); @override Widget build(BuildContext context) { return ClipOval(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(width: size, height: size, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors))))); } }

// HEADER
class _PremiumHeader extends StatelessWidget {
  final double safeTop; final String displayName; final String? photoUrl; final bool isAuthenticated; final VoidCallback onProfileTap; final VoidCallback onAccountRequest;
  const _PremiumHeader({required this.safeTop, required this.displayName, required this.photoUrl, required this.isAuthenticated, required this.onProfileTap, required this.onAccountRequest});
  @override Widget build(BuildContext context) {
    final trimmedPhoto = (photoUrl ?? '').trim();
    final localeCode = context.select<LocaleController, String>((c) => c.locale.languageCode);
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, safeTop + 10, AppSpacing.xl, 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        // RETRAIT du GestureDetector sur le texte d'accueil
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            const _RotatingGreeting(),
            Row(children: [Flexible(child: Text(displayName, style: const TextStyle(color: AppColors.darkText, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: -0.3), overflow: TextOverflow.ellipsis))])
          ]),
        ),
        Row(children: [
          Material(color: Colors.white, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: () { HapticFeedback.lightImpact(); showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const LanguageSheet()); }, child: Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: AppColors.cardBorder), boxShadow: AppShadows.secondary), child: Stack(alignment: Alignment.center, children: [const Icon(Icons.language_rounded, size: 20, color: AppColors.premiumAccent), Positioned(right: 2, bottom: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), decoration: BoxDecoration(color: AppColors.premiumAccent, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1)), child: Text(localeCode.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900))))])))),
          const SizedBox(width: 10),
          // CLIC UNIQUEMENT SUR L'AVATAR
          GestureDetector(
            onTap: onProfileTap, 
            child: Container(
              width: 40, height: 40, 
              padding: const EdgeInsets.all(2), 
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                color: Colors.white, 
                border: Border.all(color: AppColors.primaryBlue, width: 2), 
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))]
              ), 
              child: ClipOval(
                child: trimmedPhoto.isNotEmpty 
                  ? Image.network(trimmedPhoto, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.lightGrayBg, child: const Icon(Icons.person_rounded))) 
                  : Container(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1), 
                      child: const Icon(Icons.person_rounded, color: AppColors.primaryBlue)
                    )
              )
            ),
          ),
        ])
      ]),
    );
  }
}

class _RotatingGreeting extends StatefulWidget { const _RotatingGreeting(); @override State<_RotatingGreeting> createState() => _RotatingGreetingState(); }
class _RotatingGreetingState extends State<_RotatingGreeting> { static const List<Map<String, String>> _greetings = [{'lang': 'Lingala', 'text': 'Mbote'}, {'lang': 'Kiswahili', 'text': 'Jambo'}, {'lang': 'Tshiluba', 'text': 'Moyo'}, {'lang': 'Kikongo', 'text': 'Mbote'}]; int _index = 0; Timer? _timer; @override void initState() { super.initState(); _timer = Timer.periodic(const Duration(seconds: 3), (_) { if (!mounted) return; setState(() => _index = (_index + 1) % _greetings.length); }); } @override void dispose() { _timer?.cancel(); super.dispose(); } @override Widget build(BuildContext context) { final g = _greetings[_index]; return SizedBox(height: 15, child: AnimatedSwitcher(duration: const Duration(milliseconds: 380), transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim), child: child)), child: Row(key: ValueKey(g['lang']), mainAxisSize: MainAxisSize.min, children: [Text(g['text']!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(width: 5), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: AppColors.goldBadge.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)), child: Text(g['lang']!, style: const TextStyle(color: AppColors.premiumAccent, fontSize: 8, fontWeight: FontWeight.w900)))]))); } }

// SEARCH BAR 
class _SearchBarOverlay extends StatefulWidget { final TextEditingController controller; final bool isSearching; final VoidCallback onVerify; const _SearchBarOverlay({required this.controller, required this.isSearching, required this.onVerify}); @override State<_SearchBarOverlay> createState() => _SearchBarOverlayState(); }
class _SearchBarOverlayState extends State<_SearchBarOverlay> {
  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 58, padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: AppShadows.secondary),
      child: Row(children: [
        const Icon(Icons.search_rounded, size: 22, color: AppColors.textSecondary), const SizedBox(width: 10),
        Expanded(child: TextField(controller: widget.controller, enabled: !widget.isSearching, textAlignVertical: TextAlignVertical.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkText), decoration: InputDecoration(isDense: true, border: InputBorder.none, hintText: 'THIX ID...', hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14), contentPadding: EdgeInsets.zero))),
        const SizedBox(width: 8),
        GestureDetector(onTap: widget.isSearching ? null : widget.onVerify, child: Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1877F2), Color(0xFF0B3B8F)]), borderRadius: BorderRadius.circular(20)), alignment: Alignment.center, child: Text(l10n.t('home_verify_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)))),
        IconButton(onPressed: () {}, icon: const Icon(Icons.tune_rounded, size: 22, color: AppColors.textSecondary)),
      ]),
    );
  }
}
class _PremiumStatusCard extends StatelessWidget { @override Widget build(BuildContext context) { final l10n = AppLocalizations.of(context); return Container(height: 84, decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.premiumSoftStart, AppColors.premiumSoftEnd]), border: Border.all(color: AppColors.cardBorder, width: 0.7), borderRadius: BorderRadius.circular(AppRadius.mainCard), boxShadow: AppShadows.main), padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.l), child: Row(children: [const Icon(Icons.stars_rounded, color: AppColors.premiumAccent, size: 26), const SizedBox(width: AppSpacing.m), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(l10n.t('home_premium_member'), style: const TextStyle(color: AppColors.darkText, fontSize: 14, fontWeight: FontWeight.w800)), Text(l10n.t('home_trust_score', params: {'score': '98'}), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))])), Container(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s), decoration: BoxDecoration(color: AppColors.darkText, borderRadius: BorderRadius.circular(AppRadius.button)), child: Text(l10n.t('home_view_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)))])); } }

// QUICK ACTIONS 
class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onScanTap; final VoidCallback onDocumentTap; final VoidCallback onChatTap; final VoidCallback onSecurityTap;
  const _QuickActionsRow({required this.onScanTap, required this.onDocumentTap, required this.onChatTap, required this.onSecurityTap});
  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(children: [
      Expanded(child: Center(child: _QuickActionItem(icon: Icons.smart_toy_rounded, label: l10n.t('quickThixIA'), accent: AppColors.premiumAccent, onTap: onScanTap))),
      Expanded(child: Center(child: _QuickActionItem(icon: Icons.folder_shared_rounded, label: 'THIX DOC', accent: AppColors.domainLearning, onTap: onDocumentTap))),
      Expanded(child: Center(child: _QuickActionItem(icon: Icons.forum_rounded, label: l10n.t('quickChat'), accent: AppColors.domainNetwork, onTap: onChatTap))),
      Expanded(child: Center(child: _QuickActionItem(icon: Icons.emergency_rounded, label: 'THIX SOS', accent: AppColors.dangerRed, onTap: onSecurityTap))),
    ]);
  }
}
class _QuickActionItem extends StatelessWidget { final IconData icon; final String label; final Color accent; final VoidCallback onTap; const _QuickActionItem({required this.icon, required this.label, required this.accent, required this.onTap}); @override Widget build(BuildContext context) { return _PressableScale(onTap: onTap, child: SizedBox(width: 64, child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle, border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2), boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 10, offset: const Offset(0, 4))]), alignment: Alignment.center, child: Icon(icon, size: 20, color: accent)), const SizedBox(height: 4), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: accent == AppColors.dangerRed ? AppColors.dangerRed : AppColors.darkText, height: 1.1), textAlign: TextAlign.center)]))); } }
class _PressableScale extends StatefulWidget { final Widget child; final VoidCallback onTap; const _PressableScale({required this.child, required this.onTap}); @override State<_PressableScale> createState() => _PressableScaleState(); }
class _PressableScaleState extends State<_PressableScale> { bool _pressed = false; void _setPressed(bool v) { if (_pressed == v) return; setState(() => _pressed = v); } @override Widget build(BuildContext context) { return GestureDetector(onTap: widget.onTap, onTapDown: (_) => _setPressed(true), onTapCancel: () => _setPressed(false), onTapUp: (_) => _setPressed(false), child: AnimatedScale(scale: _pressed ? 0.96 : 1.0, duration: const Duration(milliseconds: 120), curve: Curves.easeOut, child: AnimatedOpacity(opacity: _pressed ? 0.92 : 1.0, duration: const Duration(milliseconds: 120), curve: Curves.easeOut, child: widget.child))); } }

class _ServiceNodeData { final String key; final IconData icon; final String title; final Color color; final int? badge; const _ServiceNodeData({required this.key, required this.icon, required this.title, required this.color, this.badge}); }
class _HubMenuItemData { final IconData icon; final String label; final VoidCallback onTap; const _HubMenuItemData({required this.icon, required this.label, required this.onTap}); }
class _ServicesConstellation extends StatefulWidget { final SectionBadgeCounts counts; final void Function(String key) onServiceTap; final VoidCallback onHomeTap; final VoidCallback onMiniAppsTap; final VoidCallback onDocumentsTap; final VoidCallback onProfileTap; final VoidCallback onScanTap; const _ServicesConstellation({required this.counts, required this.onServiceTap, required this.onHomeTap, required this.onMiniAppsTap, required this.onDocumentsTap, required this.onProfileTap, required this.onScanTap}); @override State<_ServicesConstellation> createState() => _ServicesConstellationState(); }
class _ServicesConstellationState extends State<_ServicesConstellation> with TickerProviderStateMixin {
  late final AnimationController _shineController; late final AnimationController _pulseController; bool _menuExpanded = false; Timer? _collapseTimer;
  static const double _stageHeight = 360; static const double _hubRadius = 34; static const double _hubMenuRadius = 58; static const double _hubMenuNodeSize = 30;
  @override void initState() { super.initState(); _shineController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat(); _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true); }
  @override void dispose() { _shineController.dispose(); _pulseController.dispose(); _collapseTimer?.cancel(); super.dispose(); }
  void _armAutoCollapse() { _collapseTimer?.cancel(); _collapseTimer = Timer(const Duration(seconds: 10), () { if (mounted) setState(() => _menuExpanded = false); }); }
  void _toggleHubMenu() { HapticFeedback.mediumImpact(); setState(() => _menuExpanded = !_menuExpanded); if (_menuExpanded) { _armAutoCollapse(); } else { _collapseTimer?.cancel(); } }
  void _runHubItem(VoidCallback action) { _collapseTimer?.cancel(); setState(() => _menuExpanded = false); action(); }
  
  List<_ServiceNodeData> _nodes(AppLocalizations l10n) {
    final c = widget.counts;
    return [
      _ServiceNodeData(key: 'thixMedia', icon: Icons.play_circle_filled, title: 'TDIA', color: AppColors.domainMedia),
      _ServiceNodeData(key: 'thixMarket', icon: Icons.storefront_rounded, title: l10n.t('serviceMarket'), color: AppColors.domainMarket),
      _ServiceNodeData(key: 'formations', icon: Icons.school_rounded, title: l10n.t('serviceFormations'), color: AppColors.domainLearning, badge: c.formations),
      _ServiceNodeData(key: 'emplois', icon: Icons.work_rounded, title: l10n.t('serviceEmplois'), color: AppColors.domainJobs, badge: c.jobs),
      _ServiceNodeData(key: 'thixInfo', icon: Icons.newspaper_rounded, title: 'THIX MEDIA', color: AppColors.domainInfo, badge: c.info),
      _ServiceNodeData(key: 'opportunites', icon: Icons.lightbulb_rounded, title: l10n.t('serviceOpportunites'), color: AppColors.domainOpportunity),
      _ServiceNodeData(key: 'evenements', icon: Icons.event_rounded, title: l10n.t('serviceEvenements'), color: AppColors.domainEvents, badge: c.events),
      _ServiceNodeData(key: 'reseauPro', icon: Icons.groups_rounded, title: l10n.t('serviceReseauPro'), color: AppColors.domainNetwork),
      _ServiceNodeData(key: 'thixSante', icon: Icons.local_hospital_rounded, title: l10n.t('serviceSante'), color: AppColors.domainHealth),
      _ServiceNodeData(key: 'thixMoney', icon: Icons.account_balance_wallet_rounded, title: l10n.t('serviceMoney'), color: AppColors.domainMoney),
      _ServiceNodeData(key: 'monPays', icon: Icons.flag, title: l10n.t('serviceMonPays'), color: AppColors.domainGov),
      _ServiceNodeData(key: 'reservation', icon: Icons.confirmation_number_rounded, title: l10n.t('serviceReservation'), color: AppColors.domainReservation)
    ];
  }

  Offset _polar(Offset center, double angleDeg, double radius) { final rad = angleDeg * math.pi / 180; return center + Offset(radius * math.cos(rad), radius * math.sin(rad)); }
  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nodes = _nodes(l10n);
    final hubItems = <_HubMenuItemData>[_HubMenuItemData(icon: Icons.home_filled, label: l10n.t('hub_home'), onTap: () => _runHubItem(widget.onHomeTap)), _HubMenuItemData(icon: Icons.apps_rounded, label: l10n.t('hub_mini_apps'), onTap: () => _runHubItem(widget.onMiniAppsTap)), _HubMenuItemData(icon: Icons.folder_rounded, label: l10n.t('hub_documents'), onTap: () => _runHubItem(widget.onDocumentsTap)), _HubMenuItemData(icon: Icons.person_outline_rounded, label: l10n.t('hub_profile'), onTap: () => _runHubItem(widget.onProfileTap)), _HubMenuItemData(icon: Icons.qr_code_scanner_rounded, label: l10n.t('hub_scan_qr'), onTap: () => _runHubItem(widget.onScanTap))];
    return Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.hub_rounded, size: 15, color: AppColors.textSecondary), const SizedBox(width: 6), Text(l10n.t('servicesTitle'), style: const TextStyle(color: AppColors.darkText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: -0.2))]), const SizedBox(height: 4), SizedBox(height: _stageHeight, child: LayoutBuilder(builder: (context, constraints) { final w = constraints.maxWidth; final center = Offset(w / 2, _stageHeight / 2 - 6); final maxR = math.min(w / 2 - 34, 148.0); final nodeCount = nodes.length; final positions = <Offset>[]; for (var i = 0; i < nodeCount; i++) { final angle = -90.0 + (i * (360.0 / nodeCount)); final radius = i.isEven ? maxR : maxR * 0.70; positions.add(_polar(center, angle, radius)); } final hubPositions = <Offset>[]; for (var i = 0; i < hubItems.length; i++) { final angle = -90.0 + (i * (360.0 / hubItems.length)); hubPositions.add(_polar(center, angle, _hubMenuRadius)); } return AnimatedBuilder(animation: Listenable.merge([_shineController, _pulseController]), builder: (context, _) { return Stack(clipBehavior: Clip.none, children: [Positioned(left: center.dx - 130, top: center.dy - 130, child: IgnorePointer(child: Container(width: 260, height: 260, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.goldBadge.withValues(alpha: 0.10), Colors.transparent]))))), Positioned.fill(child: CustomPaint(painter: _RadialBranchesPainter(center: center, nodeOffsets: positions, shineProgress: _shineController.value))), for (var i = 0; i < nodes.length; i++) Positioned(left: positions[i].dx - 30, top: positions[i].dy - 30, child: _ConstellationNode(data: nodes[i], onTap: () => widget.onServiceTap(nodes[i].key))), for (var i = 0; i < hubItems.length; i++) Positioned(left: hubPositions[i].dx - (_hubMenuNodeSize / 2), top: hubPositions[i].dy - (_hubMenuNodeSize / 2), child: _HubSatelliteButton(visible: _menuExpanded, order: i, size: _hubMenuNodeSize, icon: hubItems[i].icon, label: hubItems[i].label, onTap: hubItems[i].onTap)), Positioned(left: center.dx - _hubRadius, top: center.dy - _hubRadius, child: GestureDetector(onTap: _toggleHubMenu, child: Transform.scale(scale: 1.0 + (_pulseController.value * 0.05), child: AnimatedRotation(turns: _menuExpanded ? 0.125 : 0, duration: const Duration(milliseconds: 220), child: Container(width: _hubRadius * 2, height: _hubRadius * 2, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.goldBadge, AppColors.premiumAccent]), boxShadow: [BoxShadow(color: AppColors.goldBadge.withValues(alpha: 0.45), blurRadius: 22, spreadRadius: 1), BoxShadow(color: AppColors.premiumAccent.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))], border: Border.all(color: Colors.white, width: 2.4)), alignment: Alignment.center, child: Icon(_menuExpanded ? Icons.close_rounded : Icons.grid_view_rounded, color: Colors.white, size: 26))))))]); }); }))]));
  }
}
class _HubSatelliteButton extends StatelessWidget { final bool visible; final int order; final double size; final IconData icon; final String label; final VoidCallback onTap; const _HubSatelliteButton({required this.visible, required this.order, required this.size, required this.icon, required this.label, required this.onTap}); @override Widget build(BuildContext context) { return AnimatedScale(scale: visible ? 1.0 : 0.4, duration: Duration(milliseconds: 180 + order * 30), curve: Curves.easeOutBack, child: AnimatedOpacity(opacity: visible ? 1 : 0, duration: Duration(milliseconds: 150 + order * 30), child: IgnorePointer(ignoring: !visible, child: Tooltip(message: label, child: GestureDetector(onTap: onTap, child: Container(width: size, height: size, decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.premiumAccent.withValues(alpha: 0.35), width: 1.2), boxShadow: AppShadows.secondary), alignment: Alignment.center, child: Icon(icon, size: 15, color: AppColors.premiumAccent))))))); } }
class _RadialBranchesPainter extends CustomPainter { final Offset center; final List<Offset> nodeOffsets; final double shineProgress; _RadialBranchesPainter({required this.center, required this.nodeOffsets, required this.shineProgress}); @override void paint(Canvas canvas, Size size) { for (var i = 0; i < nodeOffsets.length; i++) { final end = nodeOffsets[i]; final basePaint = Paint()..shader = LinearGradient(colors: [AppColors.goldBadge.withValues(alpha: 0.38), AppColors.premiumAccent.withValues(alpha: 0.30)]).createShader(Rect.fromPoints(center, end))..strokeWidth = 1.4..strokeCap = StrokeCap.round..style = PaintingStyle.stroke; canvas.drawLine(center, end, basePaint); final phase = i / nodeOffsets.length; final t = (shineProgress + phase) % 1.0; final shinePos = Offset.lerp(center, end, t)!; for (var trail = 1; trail <= 4; trail++) { final trailT = t - (trail * 0.03); if (trailT < 0) continue; final trailPos = Offset.lerp(center, end, trailT)!; final alpha = (0.28 - trail * 0.06).clamp(0.0, 0.28); canvas.drawCircle(trailPos, 2.4 - (trail * 0.3), Paint()..color = Colors.white.withValues(alpha: alpha)); } canvas.drawCircle(shinePos, 7, Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.85), AppColors.goldBadge.withValues(alpha: 0.0)]).createShader(Rect.fromCircle(center: shinePos, radius: 7))); canvas.drawCircle(shinePos, 2.0, Paint()..color = Colors.white); } } @override bool shouldRepaint(covariant _RadialBranchesPainter oldDelegate) => true; }
class _ConstellationNode extends StatefulWidget { final _ServiceNodeData data; final VoidCallback onTap; const _ConstellationNode({required this.data, required this.onTap}); @override State<_ConstellationNode> createState() => _ConstellationNodeState(); }
class _ConstellationNodeState extends State<_ConstellationNode> with SingleTickerProviderStateMixin { late AnimationController _controller; late Animation<double> _scale; @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 140)); _scale = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)); } @override void dispose() { _controller.dispose(); super.dispose(); } @override Widget build(BuildContext context) { final d = widget.data; return GestureDetector(onTapDown: (_) => _controller.forward(), onTapUp: (_) { _controller.reverse(); widget.onTap(); }, onTapCancel: () => _controller.reverse(), child: ScaleTransition(scale: _scale, child: SizedBox(width: 60, child: Column(mainAxisSize: MainAxisSize.min, children: [Stack(clipBehavior: Clip.none, children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle, border: Border.all(color: d.color.withValues(alpha: 0.35), width: 1.2), boxShadow: [BoxShadow(color: d.color.withValues(alpha: 0.22), blurRadius: 10, offset: const Offset(0, 4))]), alignment: Alignment.center, child: Icon(d.icon, color: d.color, size: 20)), if (d.badge != null && d.badge! > 0) Positioned(top: -4, right: -6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5), decoration: BoxDecoration(color: AppColors.dangerRed, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 1.2)), child: Text('${d.badge}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))))]), const SizedBox(height: 4), Text(d.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.darkText, height: 1.1))])))); } }

// HEADLINES CAROUSEL
class _HeadlinesCarousel extends StatefulWidget { final PageController controller; final String? uid; final VoidCallback onThixInfoTap; final VoidCallback onOpportunityTap; const _HeadlinesCarousel({required this.controller, required this.uid, required this.onThixInfoTap, required this.onOpportunityTap}); @override State<_HeadlinesCarousel> createState() => _HeadlinesCarouselState(); }
class _HeadlinesCarouselState extends State<_HeadlinesCarousel> { late final Stream<List<Map<String, dynamic>>> _articlesStream; late final Stream<List<Map<String, dynamic>>> _opportunitiesStream; Stream<List<Map<String, dynamic>>>? _priorityNotifStream; Timer? _autoTimer; int _cardCount = 0; static const double _bannerHeight = 150; @override void initState() { super.initState(); final client = Supabase.instance.client; try { _articlesStream = client.from('thix_info_articles').stream(primaryKey: ['id']).eq('is_featured', true).order('created_at', ascending: false).limit(5); } catch (_) { _articlesStream = Stream.value(const <Map<String, dynamic>>[]); } try { _opportunitiesStream = client.from('opportunities').stream(primaryKey: ['id']).eq('is_featured', true).order('created_at', ascending: false).limit(5); } catch (_) { _opportunitiesStream = Stream.value(const <Map<String, dynamic>>[]); } final uid = widget.uid; if (uid != null && uid.trim().isNotEmpty) { try { _priorityNotifStream = client.from('notifications').stream(primaryKey: ['id']).eq('user_id', uid).order('created_at', ascending: false).limit(5); } catch (_) { _priorityNotifStream = null; } } _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) { if (!widget.controller.hasClients || _cardCount <= 1) return; final current = widget.controller.page?.round() ?? 0; final next = (current + 1) % _cardCount; widget.controller.animateToPage(next, duration: const Duration(milliseconds: 550), curve: Curves.easeInOutCubic); }); } @override void dispose() { _autoTimer?.cancel(); super.dispose(); } @override Widget build(BuildContext context) { final l10n = AppLocalizations.of(context); return StreamBuilder<List<Map<String, dynamic>>>(stream: _priorityNotifStream, builder: (context, notifSnap) { final notifs = (notifSnap.data ?? const <Map<String, dynamic>>[]).where((n) => (n['priority'] == true) || (n['is_priority'] == true)).toList(growable: false); final priorityNotif = notifs.isEmpty ? null : notifs.first; return StreamBuilder<List<Map<String, dynamic>>>(stream: _articlesStream, builder: (context, articleSnap) { final articles = articleSnap.data ?? const <Map<String, dynamic>>[]; return StreamBuilder<List<Map<String, dynamic>>>(stream: _opportunitiesStream, builder: (context, oppSnap) { final opportunities = oppSnap.data ?? const <Map<String, dynamic>>[]; final cards = <Widget>[]; if (priorityNotif != null) { cards.add(_HeadlineBanner(label: l10n.t('home_headline_notif_priority'), title: (priorityNotif['title'] as String?) ?? (priorityNotif['message'] as String?) ?? l10n.t('home_headline_new_notif'), imageUrl: priorityNotif['image_url'] as String?, icon: Icons.priority_high_rounded, accent: AppColors.dangerRed, height: _bannerHeight, onTap: () => NotificationsSheet.show(context))); } for (final a in articles) { cards.add(_HeadlineBanner(label: l10n.t('home_headline_thixinfo_label'), title: (a['title'] as String?) ?? l10n.t('home_headline_thixinfo_article'), imageUrl: a['image_url'] as String?, icon: Icons.newspaper_rounded, accent: AppColors.domainInfo, height: _bannerHeight, onTap: widget.onThixInfoTap)); } for (final o in opportunities) { cards.add(_HeadlineBanner(label: l10n.t('home_headline_opportunity_label'), title: (o['title'] as String?) ?? l10n.t('home_headline_new_opportunity'), imageUrl: o['image_url'] as String?, icon: Icons.lightbulb_rounded, accent: AppColors.domainOpportunity, height: _bannerHeight, onTap: widget.onOpportunityTap)); } if (cards.isEmpty) { cards.addAll([_HeadlineBanner(label: l10n.t('home_headline_thixinfo_label'), title: l10n.t('home_headline_thixinfo_default'), icon: Icons.newspaper_rounded, accent: AppColors.domainInfo, height: _bannerHeight, onTap: widget.onThixInfoTap), _HeadlineBanner(label: l10n.t('home_headline_opportunity_label'), title: l10n.t('home_headline_opportunity_default'), icon: Icons.lightbulb_rounded, accent: AppColors.domainOpportunity, height: _bannerHeight, onTap: widget.onOpportunityTap)]); } _cardCount = cards.length; return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [SizedBox(height: _bannerHeight, child: PageView(controller: widget.controller, children: cards)), if (cards.length > 1) ...[const SizedBox(height: 8), _CarouselDots(controller: widget.controller, count: cards.length)]]); }); }); }); } }
class _CarouselDots extends StatefulWidget { final PageController controller; final int count; const _CarouselDots({required this.controller, required this.count}); @override State<_CarouselDots> createState() => _CarouselDotsState(); }
class _CarouselDotsState extends State<_CarouselDots> { int _page = 0; @override void initState() { super.initState(); widget.controller.addListener(_onScroll); } void _onScroll() { if (!widget.controller.hasClients) return; final p = widget.controller.page?.round() ?? 0; if (p != _page && mounted) setState(() => _page = p); } @override void dispose() { widget.controller.removeListener(_onScroll); super.dispose(); } @override Widget build(BuildContext context) { final activePage = widget.count == 0 ? 0 : _page.clamp(0, widget.count - 1); return Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(widget.count, (i) { final active = i == activePage; return AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 3), width: active ? 16 : 6, height: 6, decoration: BoxDecoration(color: active ? AppColors.premiumAccent : AppColors.cardBorder, borderRadius: BorderRadius.circular(3))); })); } }
class _HeadlineBanner extends StatelessWidget { final String label; final String title; final IconData icon; final Color accent; final String? imageUrl; final double height; final VoidCallback onTap; const _HeadlineBanner({required this.label, required this.title, required this.icon, required this.accent, required this.height, this.imageUrl, required this.onTap}); @override Widget build(BuildContext context) { final hasImage = (imageUrl ?? '').trim().isNotEmpty; return GestureDetector(onTap: onTap, child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.mainCard), child: Container(height: height, decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), boxShadow: AppShadows.main), child: Stack(fit: StackFit.expand, children: [if (hasImage) Image.network(imageUrl!.trim(), fit: BoxFit.cover, loadingBuilder: (context, child, progress) { if (progress == null) return child; return Container(color: accent.withValues(alpha: 0.10), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: accent)))); }, errorBuilder: (_, __, ___) => Container(color: accent.withValues(alpha: 0.14), alignment: Alignment.center, child: Icon(icon, color: accent, size: 40))) else Container(color: accent.withValues(alpha: 0.14), alignment: Alignment.center, child: Icon(icon, color: accent, size: 40)), Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: hasImage ? 0.55 : 0.25)], stops: const [0.35, 1.0])))), Positioned(left: AppSpacing.l, right: AppSpacing.l, bottom: AppSpacing.m, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))), const SizedBox(height: 6), Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, height: 1.15), maxLines: 2, overflow: TextOverflow.ellipsis)])), Positioned(right: AppSpacing.m, top: AppSpacing.m, child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), shape: BoxShape.circle), child: const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.darkText)))])))); } }
class _PersonalisedSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.t('home_personalised_title'), style: const TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
      const SizedBox(height: AppSpacing.m),
      Row(children: [
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _MiniRoundAction(icon: Icons.favorite_rounded, label: 'Mariage', accent: Color(0xFFE25A6A), onTap: () => context.push('/thix-weeding')))),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _MiniRoundAction(icon: Icons.shopping_cart_rounded, label: l10n.t('home_mini_buy'), onTap: () {}))),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _MiniRoundAction(icon: Icons.shield_rounded, label: l10n.t('home_mini_secure'), onTap: () {}))),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _MiniRoundAction(icon: Icons.local_atm_rounded, label: l10n.t('home_mini_cash_out'), onTap: () {}))),
      ])
    ]);
  }
}
class _MiniRoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const _MiniRoundAction({required this.icon, required this.label, this.accent = AppColors.darkText, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isWedding = label == 'Mariage';
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: isWedding ? Color(0xFFFFF0F2) : AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: isWedding ? Color(0xFFE25A6A).withValues(alpha: 0.4) : AppColors.cardBorder, width: 0.8),
            boxShadow: AppShadows.secondary,
          ),
          child: Icon(icon, size: 20, color: isWedding ? Color(0xFFE25A6A) : AppColors.darkText),
          // Si tu veux utiliser le PNG transparent que je viens de générer:
          // child: Padding(padding: EdgeInsets.all(10), child: Image.asset('assets/wedding_logo.png')),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: isWedding ? Color(0xFFE25A6A) : AppColors.textSecondary, fontSize: 11, fontWeight: isWedding ? FontWeight.w800 : FontWeight.w700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)
      ]),
    );
  }
}
enum _AccountRequestChoice { personal }

class AccountRequestSheet extends StatelessWidget { 
  const AccountRequestSheet({super.key}); 
  @override 
  Widget build(BuildContext context) { 
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white, 
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))
      ), 
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl), 
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Container(width: 35, height: 4, decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2))), 
            const SizedBox(height: AppSpacing.l), 
            Text(l10n.t('account_request_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.darkText)), 
            const SizedBox(height: AppSpacing.xl), 
            _OptionButton(
              icon: Icons.person_outline, 
              title: l10n.t('account_personal'), 
              subtitle: l10n.t('account_personal_desc'), 
              onTap: () { 
                Navigator.pop(context, _AccountRequestChoice.personal); 
              }
            ), 
            const SizedBox(height: AppSpacing.m)
          ]
        )
      )
    ); 
  } 
}

class _OptionButton extends StatelessWidget { 
  final IconData icon; 
  final String title; 
  final String subtitle; 
  final VoidCallback onTap; 
  const _OptionButton({required this.icon, required this.title, required this.subtitle, required this.onTap}); 
  @override 
  Widget build(BuildContext context) { 
    return GestureDetector(
      onTap: onTap, 
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.m), 
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.cardBorder), 
          borderRadius: BorderRadius.circular(14), 
          color: AppColors.lightGrayBg
        ), 
        child: Row(
          children: [
            Container(
              width: 38, 
              height: 38, 
              decoration: BoxDecoration(
                color: AppColors.darkText.withValues(alpha: 0.06), 
                borderRadius: BorderRadius.circular(10)
              ), 
              child: Icon(icon, color: AppColors.darkText, size: 20)
            ), 
            const SizedBox(width: AppSpacing.m), 
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkText)), 
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))
                ]
              )
            ), 
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textSecondary)
          ]
        )
      )
    ); 
  } 
}
