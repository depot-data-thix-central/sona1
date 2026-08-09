// lib/presentation/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/common/full_screen_message.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// THIX DESIGN SYSTEM v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

// WIDGETS
import 'widgets/home_background.dart';
import 'widgets/home_header_delegate.dart';
import 'widgets/home_search.dart';
import 'widgets/home_headlines_carousel.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_services_constellation.dart';
import 'widgets/home_premium_card.dart';
import 'widgets/home_personalised.dart';
import 'widgets/account_request_sheet.dart';

class HomePagePremium extends StatefulWidget {
  const HomePagePremium({super.key});

  @override
  State<HomePagePremium> createState() => _HomePagePremiumState();
}

class _HomePagePremiumState extends State<HomePagePremium> {
  final TextEditingController _searchController = TextEditingController();
  final PageController _headlinesController = PageController();
  final NotificationCountersService _counters = NotificationCountersService();
  final ProfileService _profileService = ProfileService();
  
  static final RegExp _uidLikeRegex = RegExp(r'^[A-Za-z0-9-]{20,}$');
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _headlinesController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGIQUE MÉTIER (Maintenue intacte)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _handleHomeSearchVerify() async {
    final l10n = AppLocalizations.of(context);
    final raw = _searchController.text.trim();
    
    if (raw.isEmpty) { 
      await FullScreenMessage.showError(context, title: l10n.t('home_required_id_title'), message: l10n.t('home_required_id_msg')); 
      return; 
    }
    
    final normalized = ThixIdService.normalize(raw);
    final isThix = normalized.startsWith('THIX-');
    final isUid = _uidLikeRegex.hasMatch(raw);
    
    if (!isThix && !isUid) { 
      await FullScreenMessage.showError(context, title: l10n.t('home_invalid_id_title'), message: l10n.t('home_invalid_id_msg')); 
      return; 
    }
    
    setState(() => _searching = true);
    
    try {
      ThixProfile? profile;
      if (isThix) { 
        profile = await _profileService.fetchPublicProfileByThixId(normalized); 
      } else { 
        profile = await _profileService.fetchPublicProfileByUserId(raw); 
      }
      
      if (!mounted) return;
      if (profile == null) { 
        await FullScreenMessage.showError(context, title: l10n.t('home_profile_not_found_title'), message: l10n.t('home_profile_not_found_msg')); 
        return; 
      }
      
      final thix = profile.thixId.trim().toUpperCase();
      if (thix.isNotEmpty) { 
        context.push('${AppRoutes.publicProfile}?thixId=$thix'); 
      } else { 
        await ThixIdentitySheets.showVerifySheet(context, initialUidOrThixId: profile.userId); 
      }
    } catch (e) { 
      if (!mounted) return; 
      await FullScreenMessage.showError(context, title: l10n.t('home_verify_error_title'), message: l10n.t('home_verify_error_msg')); 
    } finally { 
      if (mounted) setState(() => _searching = false); 
    }
  }

  void _onProfileTap() {
    HapticFeedback.mediumImpact();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) { 
      context.push(AppRoutes.login); 
    } else { 
      context.go(AppRoutes.userDashboard); 
    } 
  }

  // ... (Garde ici toutes tes autres fonctions de navigation : _openThixAi, _openEmergency, _handleServiceTap, etc.) ...
  void _openThixChat() { /* ... */ }
  void _openDocumentVault() { /* ... */ }
  void _openEmergency() { /* ... */ }
  void _handleServiceTap(String serviceKey) { /* ... */ }
  void _openScanQr() => ThixIdentitySheets.showQrScanSheet(context);
  void _openMiniApps() { /* ... */ }

  Future<void> _handleRequestAccount() async {
    final auth = context.read<AuthController>();
    final res = await showModalBottomSheet<AccountRequestChoice>(
      context: context, 
      backgroundColor: Colors.transparent, 
      isScrollControlled: true, 
      builder: () => const AccountRequestSheet()
    );
    // Logique existante...
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI ORCHESTRATION
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final safeTop = MediaQuery.paddingOf(context).top;
    
    final displayName = (auth.currentUser?.displayName.trim().isNotEmpty ?? false) 
        ? auth.currentUser!.displayName.trim() 
        : (auth.currentUser?.email.trim().isNotEmpty ?? false) 
            ? auth.currentUser!.email.trim() 
            : 'Bonjour';
            
    final photoUrl = auth.currentUser?.photoUrl;
    final badgeCountsStream = auth.currentUser == null 
        ? Stream.value(SectionBadgeCounts.zero) 
        : _counters.streamCounts(auth.currentUser!.id);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      body: Stack(
        children: [
          // 1. FOND DE PAGE
          const HomeSoftBackground(),
          
          // 2. CONTENU SCROLLABLE
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // HEADER PERSISTANT
              SliverPersistentHeader(
                pinned: true,
                delegate: HomeHeaderDelegate(
                  safeTop: safeTop,
                  displayName: displayName,
                  photoUrl: photoUrl,
                  isAuthenticated: auth.isAuthenticated,
                  badgeCountsStream: badgeCountsStream,
                  onProfileTap: _onProfileTap,
                  onAccountRequest: _handleRequestAccount,
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),
              
              // BARRE DE RECHERCHE THIX ID
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                  child: HomeSearch(
                    controller: _searchController,
                    isSearching: _searching,
                    onVerify: _handleHomeSearchVerify,
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),
              
              // ACTUALITÉS / HEADLINES
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                  child: HomeHeadlinesCarousel(
                    controller: _headlinesController,
                    uid: auth.currentUser?.id,
                    onThixInfoTap: () => context.push(AppRoutes.thixInfo),
                    onOpportunityTap: () => context.push(AppRoutes.opportunities),
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),
              
              // ACTIONS RAPIDES
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                  child: HomeQuickActions(
                    onScanTap: _openThixAi,
                    onDocumentTap: _openDocumentVault,
                    onChatTap: _openThixChat,
                    onSecurityTap: _openEmergency,
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s8)),
              
              // CONSTELLATION DES SERVICES
              SliverToBoxAdapter(
                child: StreamBuilder<SectionBadgeCounts>(
                  stream: badgeCountsStream,
                  builder: (context, snap) {
                    final counts = snap.data ?? SectionBadgeCounts.zero;
                    return HomeServicesConstellation(
                      counts: counts,
                      onServiceTap: _handleServiceTap,
                      onHomeTap: () => context.go(AppRoutes.home),
                      onMiniAppsTap: _openMiniApps,
                      onDocumentsTap: _openDocumentVault,
                      onProfileTap: _onProfileTap,
                      onScanTap: _openScanQr,
                    );
                  },
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s8)),
              
              // CARTE PREMIUM / TRUST SCORE
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                  child: HomePremiumCard(),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),
              
              // SECTION PERSONNALISÉE
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                  child: HomePersonalised(),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          
          // 3. OVERLAY DE CHARGEMENT
          if (_searching)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: const Center(
                  child: CircularProgressIndicator(color: ThixPolicy.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
