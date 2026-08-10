// lib/presentation/network/profile_page.dart
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
import 'package:thix_id/presentation/network/widgets/post_card.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final ScrollController _scrollController = ScrollController();
  int _selectedTab = 1; // Par défaut sur 'Publications'
  bool _isGridView = false;
  bool _isUploading = false;
  bool _isFollowLoading = false;

  // Images locales (priorité sur le profil distant)
  Uint8List? _localAvatarBytes;
  Uint8List? _localCoverBytes;
  String? _localAvatarUrl;
  String? _localCoverUrl;

  // Nouveaux onglets demandés
  final _tabs = [
    'Bio', 
    'Publications', 
    'Photos publiques', 
    'Vidéos', 
    'Audios', 
    'Galerie privée'
  ];

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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      final uid = widget.userId ??
          Supabase.instance.client.auth.currentUser!.id;
      ref.read(userPostsProvider(uid).notifier).loadMore();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UPLOAD PHOTO PROFIL / COUVERTURE
  // ─────────────────────────────────────────────────────────────
  Future<void> _pickAndUploadImage({required bool isAvatar}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes!;
      final ext = result.files.first.extension ?? 'jpg';

      setState(() {
        if (isAvatar) {
          _localAvatarBytes = bytes;
        } else {
          _localCoverBytes = bytes;
        }
        _isUploading = true;
      });

      final ns = ref.read(networkServiceProvider);
      final bucket = isAvatar ? 'avatars' : 'covers';
      final url = await ns.uploadImageBytes(
        bytes,
        fileExtension: ext,
        bucket: bucket,
      );

      if (url != null) {
        await Supabase.instance.client.from('profiles').update({
          isAvatar ? 'avatar_url' : 'cover_url': url,
        }).eq('id', ns.currentUserId);

        setState(() {
          if (isAvatar) {
            _localAvatarUrl = url;
            _localAvatarBytes = null;
          } else {
            _localCoverUrl = url;
            _localCoverBytes = null;
          }
        });

        final uid = widget.userId ?? ns.currentUserId;
        ref.invalidate(userProfileProvider(uid));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAvatar
                  ? 'Photo de profil mise à jour'
                  : 'Photo de couverture mise à jour'),
              backgroundColor: ThixPolicy.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIONS GALERIE PRIVÉE
  // ─────────────────────────────────────────────────────────────
  void _uploadPrivateMedia() {
    // Logique d'upload pour la galerie privée
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ouverture de l\'explorateur pour la galerie privée...')),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FOLLOW / UNFOLLOW (Avec Logs d'Erreur Explicites)
  // ─────────────────────────────────────────────────────────────
  Future<void> _toggleFollow(String targetId, bool currentlyFollowing) async {
    if (_isFollowLoading) return; 
    
    setState(() => _isFollowLoading = true);
    HapticFeedback.lightImpact();
    final ns = ref.read(networkServiceProvider);

    try {
      if (currentlyFollowing) {
        await ns.unfollowUser(targetId);
      } else {
        await ns.followUser(targetId);
      }
      ref.invalidate(followStatusProvider(targetId));
      ref.invalidate(userProfileProvider(targetId));
    } catch (e) {
      // 🚨 IMPRESSION DE L'ERREUR DANS LA CONSOLE POUR DEBUG
      debugPrint('🚨 ERREUR LORS DU FOLLOW : $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur Follow: $e'), // Affiché à l'écran
            backgroundColor: ThixPolicy.danger,
            duration: const Duration(seconds: 5), // Laisse le temps de lire
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _handleBlockUser(String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquer cet utilisateur ?'),
        content: const Text(
          'Vous ne verrez plus ses publications et il ne pourra plus interagir avec vous.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger),
            child: const Text('Bloquer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilisateur bloqué.')),
      );
      context.go('/network');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final uid = widget.userId ?? currentUid;
    final isOwn = uid == currentUid;

    final profileAsync = ref.watch(userProfileProvider(uid));
    final postsAsync = ref.watch(userPostsProvider(uid));
    final pinnedAsync = ref.watch(pinnedPostsProvider(uid));

    return Scaffold(
      extendBodyBehindAppBar: true, // L'AppBar flotte au-dessus de la Cover
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withValues(alpha: 0.4),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).canPop() ? Navigator.pop(context) : context.go('/network'),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
                onSelected: (val) {
                  if (val == 'settings') {
                    context.push('/network/profile-settings');
                  } else if (val == 'block') {
                    _handleBlockUser(uid);
                  } else if (val == 'report') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signalement envoyé.')),
                    );
                  }
                },
                itemBuilder: (_) => isOwn
                    ? [const PopupMenuItem(value: 'settings', child: Text('Modifier le profil'))]
                    : [
                        const PopupMenuItem(value: 'report', child: Text('Signaler')),
                        const PopupMenuItem(value: 'block', child: Text('Bloquer', style: TextStyle(color: Colors.red))),
                      ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userProfileProvider(uid));
              ref.read(userPostsProvider(uid).notifier).refresh();
            },
            color: ThixPolicy.primary,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── HEADER (COVER + AVATAR + ACTIONS) ──
                SliverToBoxAdapter(
                  child: profileAsync.when(
                    data: (u) => _buildTopSection(u, isOwn, uid),
                    loading: () => Container(height: 240, color: ThixPolicy.inkDeep),
                    error: (_, __) => Container(height: 240, color: ThixPolicy.inkDeep),
                  ),
                ),
                
                // Espace pour laisser l'avatar déborder
                const SliverToBoxAdapter(child: SizedBox(height: 55)),

                // ── INFO PROFIL (Nom, Profession) ──
                SliverToBoxAdapter(
                  child: profileAsync.when(
                    data: (u) => _buildProfileInfo(u),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ),

                // ── STATS ──
                SliverToBoxAdapter(
                  child: profileAsync.when(
                    data: (u) => _buildStats(u, uid),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ),

                // ── POST ÉPINGLÉ ──
                pinnedAsync.when(
                  data: (pins) => pins.isNotEmpty
                      ? SliverToBoxAdapter(child: _buildPinned(pins.first))
                      : const SliverToBoxAdapter(child: SizedBox()),
                  loading: () => const SliverToBoxAdapter(child: SizedBox()),
                  error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
                ),

                // ── TABS ──
                SliverToBoxAdapter(child: _buildTabs()),

                // ── CONTENU DES ONGLETS ──
                if (_tabs[_selectedTab] == 'Bio')
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        profileAsync.valueOrNull?['bio'] ?? 'Aucune biographie disponible.',
                        style: ThixPolicy.bodyStyle.copyWith(height: 1.5, fontSize: 15),
                      ),
                    ),
                  )
                else if (_tabs[_selectedTab] == 'Galerie privée')
                  SliverToBoxAdapter(child: _buildPrivateGallery(isOwn))
                else
                  postsAsync.when(
                    data: (posts) {
                      var displayed = posts;
                      
                      if (_tabs[_selectedTab] == 'Photos publiques') {
                        displayed = posts.where((p) => p.hasImages).toList();
                      } else if (_tabs[_selectedTab] == 'Vidéos') {
                        displayed = posts.where((p) => p.hasVideos).toList(); 
                      } else if (_tabs[_selectedTab] == 'Audios') {
                        displayed = posts.where((p) => p.hasAudio).toList();
                      }

                      if (displayed.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(48),
                            child: Column(
                              children: [
                                Icon(Icons.article_outlined, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text('Aucun contenu', style: ThixPolicy.bodySmallStyle),
                              ],
                            ),
                          ),
                        );
                      }

                      if (_isGridView) {
                        return SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _buildGridItem(displayed[i]),
                            childCount: displayed.length,
                          ),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PostCard(
                              post: displayed[i],
                              currentProfileId: currentUid,
                              onRefresh: () => ref.read(userPostsProvider(uid).notifier).refresh(),
                            ),
                          ),
                          childCount: displayed.length,
                        ),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                    ),
                    error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Erreur: $e'))),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),

          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOP SECTION (Cover + Avatar sur le même plan)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopSection(Map<String, dynamic>? u, bool isOwn, String uid) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Photo de couverture
        Container(
          height: 240, // Assez haut pour passer sous l'AppBar transparente
          width: double.infinity,
          color: ThixPolicy.inkDeep,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_localCoverBytes != null)
                Image.memory(_localCoverBytes!, fit: BoxFit.cover)
              else if (_localCoverUrl != null)
                Image.network(_localCoverUrl!, fit: BoxFit.cover)
              else if (u?['cover_url'] != null)
                Image.network(
                  u!['cover_url'],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: ThixPolicy.inkDeep),
                ),

              // Ombre dégradée
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),

              if (isOwn)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => _pickAndUploadImage(isAvatar: false),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2. Avatar (Superposé exactement à cheval sur la bordure)
        Positioned(
          bottom: -46, // Descend exactement de la moitié de son rayon (46px)
          left: 16,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.surface, // Bordure blanche autour de l'avatar
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: Colors.grey.shade100,
                  backgroundImage: _localAvatarBytes != null
                      ? MemoryImage(_localAvatarBytes!)
                      : (_localAvatarUrl != null
                          ? NetworkImage(_localAvatarUrl!)
                          : (u?['avatar_url'] != null
                              ? NetworkImage(u!['avatar_url'])
                              : null)) as ImageProvider?,
                  child: (_localAvatarBytes == null &&
                          _localAvatarUrl == null &&
                          (u?['avatar_url'] == null || u!['avatar_url'].toString().isEmpty))
                      ? Icon(Icons.person, size: 48, color: ThixPolicy.primary.withValues(alpha: 0.5))
                      : null,
                ),
              ),
              if (isOwn)
                GestureDetector(
                  onTap: () => _pickAndUploadImage(isAvatar: true),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4, right: 4),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: ThixPolicy.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: ThixPolicy.surface, width: 2.5),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                  ),
                ),
            ],
          ),
        ),

        // 3. Boutons d'action (Alignés à droite)
        Positioned(
          bottom: -20,
          right: 16,
          child: isOwn
              ? OutlinedButton.icon(
                  onPressed: () => context.push('/network/profile-settings'),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: ThixPolicy.surface,
                    foregroundColor: ThixPolicy.textMain,
                    side: BorderSide(color: ThixPolicy.borderStrong),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                  ),
                )
              : Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: ThixPolicy.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.borderStrong),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.mail_outline_rounded),
                        color: ThixPolicy.textMain,
                        onPressed: () => context.push('/network/chat/$uid'), // Route corrigée
                      ),
                    ),
                    const SizedBox(width: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final followAsync = ref.watch(followStatusProvider(uid));
                        return followAsync.when(
                          data: (isFollowing) {
                            return ElevatedButton(
                              onPressed: () => _toggleFollow(uid, isFollowing),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing ? ThixPolicy.surfaceStrong : ThixPolicy.primary,
                                foregroundColor: isFollowing ? ThixPolicy.textMain : Colors.white,
                                elevation: isFollowing ? 0 : 1,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                              ),
                              child: _isFollowLoading 
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(
                                    isFollowing ? 'Abonné' : 'Suivre',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                  ),
                            );
                          },
                          loading: () => const SizedBox(width: 90, height: 36, child: Center(child: CircularProgressIndicator())),
                          error: (_, __) => const SizedBox(),
                        );
                      },
                    ),
                  ],
                ),
        )
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // INFO PROFIL
  // ─────────────────────────────────────────────────────────────
  Widget _buildProfileInfo(Map<String, dynamic>? u) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  u?['display_name'] ?? 'Utilisateur THIX',
                  style: ThixPolicy.h2Style.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 6),
              // Certification dynamique
              if (u?['is_verified'] == true) 
                const Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            u?['profession'] ?? 'Membre THIX',
            style: ThixPolicy.bodySmallStyle,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STATS
  // ─────────────────────────────────────────────────────────────
  Widget _buildStats(Map<String, dynamic>? u, String uid) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          _statTile('${u?['followers_count'] ?? 0}', 'Abonnés', () => context.push('/network/connections?tab=followers&uid=$uid')),
          Container(width: 1, height: 28, color: ThixPolicy.border),
          _statTile('${u?['following_count'] ?? 0}', 'Abonnements', () => context.push('/network/connections?tab=following&uid=$uid')),
          Container(width: 1, height: 28, color: ThixPolicy.border),
          _statTile('${u?['posts_count'] ?? 0}', 'Publications', () {
            _scrollController.animateTo(350, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
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
        child: Column(
          children: [
            Text(value, style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep)),
            const SizedBox(height: 2),
            Text(label, style: ThixPolicy.captionStyle),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // GALERIE PRIVÉE UI
  // ─────────────────────────────────────────────────────────────
  Widget _buildPrivateGallery(bool isOwn) {
    if (!isOwn) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Ce contenu est privé', style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.lock_person_rounded, size: 48, color: ThixPolicy.textSecondary),
          const SizedBox(height: 12),
          Text('Votre galerie privée', style: ThixPolicy.h3Style),
          const SizedBox(height: 8),
          Text(
            'Gérez vos photos et vidéos privées ici. Vous seul y avez accès. Vous pourrez les publier plus tard si vous le souhaitez.',
            textAlign: TextAlign.center,
            style: ThixPolicy.bodyStyle,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _uploadPrivateMedia,
            icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
            label: const Text('Ajouter un média', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: ThixPolicy.surface,
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(color: ThixPolicy.border, style: BorderStyle.solid),
            ),
            child: Center(
              child: Text('Aucun média privé pour le moment.', style: ThixPolicy.captionStyle),
            ),
          )
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TABS
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final selected = _selectedTab == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          color: selected ? ThixPolicy.inkDeep : ThixPolicy.card,
                          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                          border: Border.all(color: selected ? ThixPolicy.inkDeep : ThixPolicy.border),
                        ),
                        child: Text(
                          _tabs[i],
                          style: TextStyle(
                            color: selected ? Colors.white : ThixPolicy.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          if (_tabs[_selectedTab] != 'Bio' && _tabs[_selectedTab] != 'Galerie privée')
            IconButton(
              icon: Icon(_isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded, color: ThixPolicy.textSecondary),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // GRID ITEM
  // ─────────────────────────────────────────────────────────────
  Widget _buildGridItem(NetworkPost post) {
    String? mediaUrl;
    if (post.hasImages) mediaUrl = post.imageUrls.first;

    return GestureDetector(
      onTap: () => context.push('/network/comments/${post.id}'),
      child: Container(
        color: ThixPolicy.card,
        child: mediaUrl != null
            ? Image.network(mediaUrl, fit: BoxFit.cover)
            : Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: Text(
                    post.content,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep),
                  ),
                ),
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PINNED
  // ─────────────────────────────────────────────────────────────
  Widget _buildPinned(NetworkPost post) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.push_pin_rounded, color: ThixPolicy.gold, size: 15),
              const SizedBox(width: 6),
              Text('Publication épinglée', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.gold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodyStyle),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => context.push('/network/comments/${post.id}'),
            child: Text('Voir la publication', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.primary)),
          ),
        ],
      ),
    );
  }
}
