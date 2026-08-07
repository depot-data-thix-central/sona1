// lib/presentation/network/profile_page.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/presentation/network/widgets/post_card.dart'; // Pour réutiliser ta belle PostCard !

// ─── PALETTE DE COULEURS THIX PRO ───
class _ThixColors {
  static const bg = Color(0xFFF5F8FA);
  static const white = Color(0xFFFFFFFF);
  static const primary = Color(0xFF2D6CDF);
  static const primaryDeep = Color(0xFF123B7A);
  static const navyDeep = Color(0xFF0A1F44);
  static const gold = Color(0xFFE3B23C);
  static const textDark = Color(0xFF10192E);
  static const textSecondary = Color(0xFF7386A8);
  static const red = Color(0xFFE5484D);

  static const gradientGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, Color(0xFFF3D999)],
  );
}

class ProfilePage extends ConsumerStatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});
  
  @override 
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final ScrollController _scrollController = ScrollController();
  int _selectedTab = 0;
  bool _isGridView = false; // Par défaut en liste pour mieux voir les posts
  bool _isUploadingMedia = false;

  final _tabs = ['Publications', 'Médias', 'Audios'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }
  
  @override 
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      final uid = widget.userId ?? Supabase.instance.client.auth.currentUser!.id;
      ref.read(userPostsProvider(uid).notifier).loadMore();
    }
  }

  // ─── LOGIQUE DE MODIFICATION DE PROFIL (Entreprise) ───
  Future<void> _updateProfileImage(String bucket) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.isNotEmpty) {
        setState(() => _isUploadingMedia = true);
        
        final bytes = result.files.first.bytes!;
        final ext = result.files.first.extension ?? 'jpg';
        
        final ns = ref.read(networkServiceProvider);
        final url = await ns.uploadImageBytes(bytes, fileExtension: ext, bucket: bucket);
        
        if (url != null) {
          // Mise à jour de la table profiles
          await Supabase.instance.client.from('profiles').update({
            bucket == 'avatars' ? 'avatar_url' : 'cover_url': url
          }).eq('id', ns.currentUserId);
          
          final uid = widget.userId ?? ns.currentUserId;
          ref.invalidate(userProfileProvider(uid)); // Rafraîchir l'UI
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profil mis à jour avec succès'), backgroundColor: _ThixColors.primary),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _ThixColors.red));
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  // ─── LOGIQUE DE BLOCAGE & MODE FANTÔME ───
  void _handleGhostMode() {
    // Logique pour basculer le compte en privé (masquer des recherches)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mode Fantôme activé. Votre compte est désormais invisible dans les recherches.'), backgroundColor: _ThixColors.navyDeep),
    );
  }

  Future<void> _handleBlockUser() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: _ThixColors.red),
            SizedBox(width: 8),
            Text('Bloquer l\'utilisateur ?'),
          ],
        ),
        content: const Text('Vous ne verrez plus ses publications et il ne pourra plus interagir avec vous.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _ThixColors.red),
            child: const Text('Bloquer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      // 1. Ajouter à la table "blocked_users" dans Supabase
      // 2. Rediriger vers l'accueil
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur bloqué.')));
        context.go('/network');
      }
    }
  }

  // ─── WIDGETS D'AFFICHAGE ───
  Widget _buildImg(String? url, {double? w, double? h, BoxFit fit = BoxFit.cover}) {
    if (url == null || url.isEmpty) {
      return Container(
        color: const Color(0xFFEAF1FF), 
        child: Icon(Icons.person_rounded, size: (w ?? 40) * 0.5, color: _ThixColors.primaryDeep.withOpacity(0.5))
      );
    }
    return Image.network(
      url, width: w, height: h, fit: fit,
      loadingBuilder: (_, child, p) => p == null ? child : Container(color: _ThixColors.softBlue),
      errorBuilder: (_, __, ___) => Container(color: _ThixColors.softBlue, child: Icon(Icons.broken_image, color: Colors.grey[400])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.userId ?? Supabase.instance.client.auth.currentUser!.id;
    final profileAsync = ref.watch(userProfileProvider(uid));
    final postsAsync = ref.watch(userPostsProvider(uid));
    final pinnedAsync = ref.watch(pinnedPostsProvider(uid));
    final isOwn = uid == Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userProfileProvider(uid));
          ref.read(userPostsProvider(uid).notifier).refresh();
        },
        color: _ThixColors.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ─── COUVERTURE & APP BAR (Design Premium) ───
            SliverAppBar(
              expandedHeight: 160.0,
              pinned: true,
              backgroundColor: _ThixColors.navyDeep,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).canPop() ? Navigator.pop(context) : context.go('/network'),
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (val) {
                    if (val == 'ghost') _handleGhostMode();
                    if (val == 'activity') context.push('/network/profile/activity');
                    if (val == 'settings') context.push('/network/profile-settings');
                    if (val == 'block') _handleBlockUser();
                    if (val == 'report') {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé aux équipes THIX.')));
                    }
                  },
                  itemBuilder: (_) => isOwn 
                    ? [
                        const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Modifier le profil')])),
                        const PopupMenuItem(value: 'activity', child: Row(children: [Icon(Icons.history_rounded, size: 18), SizedBox(width: 8), Text('Historique d\'activité')])),
                        const PopupMenuItem(value: 'ghost', child: Row(children: [Icon(Icons.visibility_off_outlined, size: 18, color: _ThixColors.navyDeep), SizedBox(width: 8), Text('Mode Fantôme', style: TextStyle(fontWeight: FontWeight.w600))])),
                      ]
                    : [
                        const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag_outlined, size: 18), SizedBox(width: 8), Text('Signaler ce compte')])),
                        const PopupMenuItem(value: 'block', child: Row(children: [Icon(Icons.block_rounded, size: 18, color: _ThixColors.red), SizedBox(width: 8), Text('Bloquer l\'utilisateur', style: TextStyle(color: _ThixColors.red))])),
                      ],
                )
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    profileAsync.when(
                      data: (u) => _buildImg(u?['cover_url'], w: double.infinity, h: 160),
                      loading: () => Container(color: _ThixColors.navyDeep),
                      error: (_, __) => Container(color: _ThixColors.navyDeep),
                    ),
                    // Bouton de modification de couverture
                    if (isOwn)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: InkWell(
                          onTap: () => _updateProfileImage('covers'),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ─── EN-TÊTE DU PROFIL (Avatar, Infos, Actions) ───
            SliverToBoxAdapter(
              child: profileAsync.when(
                data: (u) => _buildHeader(u, isOwn, uid),
                loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox(),
              ),
            ),

            // ─── STATISTIQUES CLIQUABLES ───
            SliverToBoxAdapter(
              child: profileAsync.when(
                data: (u) => _buildStats(u, uid), 
                loading: () => const SizedBox(), 
                error: (_, __) => const SizedBox()
              )
            ),

            // ─── PUBLICATION ÉPINGLÉE ───
            pinnedAsync.when(
              data: (pins) => pins.isNotEmpty ? SliverToBoxAdapter(child: _buildPinned(pins.first)) : const SliverToBoxAdapter(child: SizedBox()),
              loading: () => const SliverToBoxAdapter(child: SizedBox()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
            ),

            // ─── ONGLETS (Posts, Médias, Audios) ───
            SliverToBoxAdapter(child: _buildTabs()),

            // ─── CONTENU (GRILLE OU LISTE) ───
            postsAsync.when(
              data: (posts) {
                var displayed = posts;
                if (_selectedTab == 1) displayed = posts.where((p) => p.hasImages || p.hasVideos).toList();
                if (_selectedTab == 2) displayed = posts.where((p) => p.hasAudio).toList(); // Utilise ta nouvelle propriété
                
                if (displayed.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40), 
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.article_outlined, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            const Text('Aucune publication à afficher', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                          ],
                        )
                      )
                    )
                  );
                }
                
                if (_isGridView) {
                  return SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                    delegate: SliverChildBuilderDelegate((_, i) => _buildGridItem(displayed[i]), childCount: displayed.length),
                  );
                } else {
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((_, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        // 🌟 Utilisation de TA PostCard Premium
                        child: PostCard(
                          post: displayed[i],
                          currentProfileId: Supabase.instance.client.auth.currentUser!.id,
                          onRefresh: () => ref.read(userPostsProvider(uid).notifier).refresh(),
                        ),
                      );
                    }, childCount: displayed.length)
                  );
                }
              },
              loading: () => const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _ThixColors.primary)))),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Erreur: $e'))),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 100)), // Espace en bas
          ],
        ),
      ),
      
      // Overlay de chargement si upload en cours
      floatingActionButton: _isUploadingMedia 
          ? FloatingActionButton(onPressed: (){}, backgroundColor: Colors.white, child: const CircularProgressIndicator(strokeWidth: 3)) 
          : null,
    );
  }

  // ─── CONSTRUCTION DE L'EN-TÊTE ───
  Widget _buildHeader(Map<String, dynamic>? u, bool isOwn, String uid) {
    return Container(
      transform: Matrix4.translationValues(0.0, -40.0, 0.0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar avec bordure premium
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _ThixColors.bg),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: _ThixColors.gradientGold),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: SizedBox(width: 92, height: 92, child: _buildImg(u?['avatar_url'], w: 92, h: 92))
                        ),
                      ),
                    ),
                  ),
                  if (isOwn)
                    GestureDetector(
                      onTap: () => _updateProfileImage('avatars'),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: _ThixColors.primary, shape: BoxShape.circle, border: Border.all(color: _ThixColors.bg, width: 2)),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              
              // Boutons d'action (Message / Suivre)
              if (isOwn)
                OutlinedButton.icon(
                  onPressed: () => context.push('/network/profile-settings'),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Compléter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ThixColors.textDark,
                    side: const BorderSide(color: _ThixColors.textDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                )
              else
                Row(
                  children: [
                    // Bouton Message
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
                      child: IconButton(
                        icon: const Icon(Icons.mail_outline_rounded, color: _ThixColors.textDark),
                        onPressed: () => context.push('/network/messages/chat/$uid'), // Lien vers chat
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bouton Suivre
                    Consumer(builder: (context, ref, _) {
                      final followAsync = ref.watch(followStatusProvider(uid));
                      return followAsync.when(
                        data: (isFollowing) => ElevatedButton.icon(
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            await ref.read(networkServiceProvider).sendConnectionRequest(uid);
                            ref.invalidate(followStatusProvider(uid));
                          },
                          icon: Icon(isFollowing ? Icons.check_circle_outline_rounded : Icons.person_add_alt_1_rounded, size: 18),
                          label: Text(isFollowing ? 'Abonné' : 'Suivre', style: const TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowing ? Colors.grey[200] : _ThixColors.primary,
                            foregroundColor: isFollowing ? _ThixColors.textDark : Colors.white,
                            elevation: isFollowing ? 0 : 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                        loading: () => const SizedBox(width: 100, child: Center(child: LinearProgressIndicator())),
                        error: (_, __) => const SizedBox(),
                      );
                    }),
                  ],
                ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Nom et Titre
          Row(
            children: [
              Text(
                u?['display_name'] ?? 'Utilisateur THIX', 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ThixColors.textDark)
              ),
              const SizedBox(width: 6),
              const Icon(Icons.verified_rounded, color: _ThixColors.gold, size: 18), // Badge Vérifié
            ],
          ),
          const SizedBox(height: 2),
          Text(u?['profession'] ?? 'Membre THIX PRO', style: const TextStyle(color: _ThixColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
          
          // Bio (Si disponible)
          if (u?['bio'] != null && u!['bio'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                u['bio'],
                style: const TextStyle(fontSize: 13.5, height: 1.4, color: _ThixColors.textDark),
              ),
            ),
        ],
      ),
    );
  }

  // ─── STATISTIQUES CLIQUABLES ───
  Widget _buildStats(Map<String, dynamic>? u, String uid) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      transform: Matrix4.translationValues(0.0, -20.0, 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statTile('${u?['followers_count'] ?? 0}', 'Abonnés', () => context.push('/network/connections?tab=followers&uid=$uid')),
          Container(width: 1, height: 30, color: Colors.grey[300]), // Séparateur
          _statTile('${u?['following_count'] ?? 0}', 'Abonnements', () => context.push('/network/connections?tab=following&uid=$uid')),
          Container(width: 1, height: 30, color: Colors.grey[300]), // Séparateur
          _statTile('${u?['posts_count'] ?? 0}', 'Publications', () {
            _scrollController.animateTo(300, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
          }),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _ThixColors.navyDeep)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12, color: _ThixColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── ONGLETS DYNAMIQUES ───
  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final sel = _selectedTab == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTab = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? _ThixColors.navyDeep : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: sel ? _ThixColors.navyDeep : Colors.grey.shade300),
                        boxShadow: sel ? [BoxShadow(color: _ThixColors.navyDeep.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
                      ),
                      child: Text(
                        _tabs[i], 
                        style: TextStyle(color: sel ? Colors.white : _ThixColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)
                      )
                    ),
                  );
                }),
              ),
            ),
          ),
          // Bouton Vue Grille / Liste
          IconButton(
            icon: Icon(_isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded, color: _ThixColors.textSecondary),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: 'Changer la vue',
          ),
        ],
      ),
    );
  }

  // ─── ÉLÉMENTS DE LA LISTE ───
  Widget _buildGridItem(NetworkPost post) {
    String? mediaUrl;
    IconData? mediaIcon;
    
    if (post.hasImages) { mediaUrl = post.imageUrls.first; mediaIcon = Icons.photo_outlined; }
    else if (post.hasVideos) { mediaIcon = Icons.play_circle_outline_rounded; }
    else if (post.hasAudio) { mediaIcon = Icons.audiotrack_rounded; }

    return GestureDetector(
      onTap: () => context.push('/network/comments/${post.id}'),
      child: Container(
        color: Colors.white,
        child: mediaUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  _buildImg(mediaUrl, w: double.infinity, h: double.infinity),
                  if (post.imageUrls.length > 1)
                    const Positioned(top: 4, right: 4, child: Icon(Icons.collections_rounded, color: Colors.white, size: 16)),
                ],
              )
            : Container(
                padding: const EdgeInsets.all(8),
                color: _ThixColors.softBlue,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (mediaIcon != null) Icon(mediaIcon, color: _ThixColors.primary, size: 24),
                    if (mediaIcon != null) const SizedBox(height: 8),
                    Text(post.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _ThixColors.navyDeep), textAlign: TextAlign.center),
                  ],
                ),
              )
      ),
    );
  }

  Widget _buildPinned(NetworkPost post) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF9E6), Colors.white]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ThixColors.gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.push_pin_rounded, color: _ThixColors.gold, size: 16),
              const SizedBox(width: 8),
              const Text('Publication épinglée', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ThixColors.gold)),
              const Spacer(),
              if (widget.userId == null || widget.userId == Supabase.instance.client.auth.currentUser!.id)
                InkWell(
                  onTap: () => ref.read(networkServiceProvider).unpinPost(post.id),
                  child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                )
            ],
          ),
          const SizedBox(height: 10),
          Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ThixColors.textDark, fontSize: 13.5)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => context.push('/network/comments/${post.id}'),
            child: const Text('Voir la publication', style: TextStyle(color: _ThixColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
          )
        ],
      ),
    );
  }
}
