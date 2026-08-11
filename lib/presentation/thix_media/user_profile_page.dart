// lib/presentation/media/user_profile_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ Design System et Modèles
import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../services/media_service.dart';
import '../../models/media_content.dart';

// ✅ Pages de navigation
import 'video_player_page.dart';
import 'create_post_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  Map<String, int> _stats = {'followers': 0, 'following': 0, 'posts': 0};
  
  bool _isFollowing = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  
  List<MediaContent> _userPosts = [];
  final ScrollController _scrollController = ScrollController();
  static const int _limit = 15;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final service = MediaService();
      
      final results = await Future.wait([
        service.fetchProfile(widget.userId),
        service.fetchUserStats(widget.userId),
        service.isFollowing(widget.userId),
        Supabase.instance.client
            .from('media_content')
            .select('*')
            .eq('user_id', widget.userId)
            .order('created_at', ascending: false)
            .limit(_limit)
      ]);

      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>?;
          _stats = Map<String, int>.from(results[1] as Map);
          _isFollowing = results[2] as bool;
          
          final postsData = results[3] as List<dynamic>;
          _userPosts = postsData.map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();
          _hasMore = postsData.length == _limit;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement profil: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore || !_hasMore || _userPosts.isEmpty) return;
    setState(() => _loadingMore = true);

    try {
      final lastPost = _userPosts.last;
      final postsData = await Supabase.instance.client
          .from('media_content')
          .select('*')
          .eq('user_id', widget.userId)
          .lt('created_at', lastPost.createdAt.toIso8601String())
          .order('created_at', ascending: false)
          .limit(_limit);

      final newPosts = (postsData as List).map((e) => MediaContent.fromJson(e as Map<String, dynamic>)).toList();

      if (mounted) {
        setState(() {
          _userPosts.addAll(newPosts);
          _hasMore = newPosts.length == _limit;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _handleFollowToggle() async {
    HapticFeedback.lightImpact();
    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !_isFollowing;
      _stats['followers'] = (_stats['followers'] ?? 0) + (_isFollowing ? 1 : -1);
    });

    try {
      await MediaService().toggleFollow(widget.userId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFollowing = wasFollowing;
          _stats['followers'] = (_stats['followers'] ?? 0) + (_isFollowing ? 1 : -1);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur réseau', style: TextStyle(color: Colors.white)), backgroundColor: ThixPolicy.danger));
      }
    }
  }

  String _getDisplayName() {
    final uname = _profile?['username'] as String?;
    final fname = _profile?['full_name'] as String?;
    if (uname != null && uname.trim().isNotEmpty) return uname.trim();
    if (fname != null && fname.trim().isNotEmpty) return fname.trim();
    return 'Créateur';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: ThixPolicy.inkDeep, 
        body: Center(child: CircularProgressIndicator(color: ThixPolicy.primary))
      );
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMe = currentUserId == widget.userId;

    // Tri des contenus pour les onglets
    final standaloneVideos = _userPosts.where((p) => p.type == 'Fil' || p.type == 'Musique' || p.type == 'Gaming').toList();
    final seriesVideos = _userPosts.where((p) => p.type == 'Série' || p.type == 'Formation' || p.type == 'NOVA Originals').toList();

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // COLONNE GAUCHE : INFOS & ACTIONS (35%)
            // ==========================================
            Container(
              width: MediaQuery.of(context).size.width * 0.35,
              decoration: const BoxDecoration(
                color: ThixPolicy.surface,
                border: Border(right: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                children: [
                  // En-tête avec retour et "+ Créer" si c'est mon profil
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        if (isMe)
                          IconButton(
                            icon: const Icon(Icons.add_box_rounded, color: ThixPolicy.primary, size: 24),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage())).then((_) => _loadProfileData()), // Rafraîchit au retour
                            tooltip: "Nouveau contenu",
                          ),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          
                          // Avatar Premium
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: ThixPolicy.brandGradient,
                            ),
                            child: CircleAvatar(
                              radius: 42,
                              backgroundColor: ThixPolicy.surfaceSoft,
                              backgroundImage: _profile?['avatar_url'] != null && _profile!['avatar_url'].toString().isNotEmpty
                                  ? CachedNetworkImageProvider(_profile!['avatar_url'])
                                  : null,
                              child: _profile?['avatar_url'] == null || _profile!['avatar_url'].toString().isEmpty
                                  ? const Icon(Icons.person, size: 40, color: ThixPolicy.textSecondary)
                                  : null,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Noms
                          Text(
                            _getDisplayName(),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          if (_profile?['full_name'] != null && _profile!['full_name'].toString().trim().isNotEmpty && _profile?['username'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '@${_profile!['username']}',
                                style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Boutons d'Action (Abonnement ou Édition)
                          if (!isMe)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _handleFollowToggle,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFollowing ? ThixPolicy.surfaceSoft : ThixPolicy.primary,
                                  elevation: _isFollowing ? 0 : 4,
                                  shadowColor: ThixPolicy.primary.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  _isFollowing ? 'Abonné' : 'Suivre',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  // Naviguer vers la page de modification du profil
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Gérer le profil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                              ),
                            ),
                          
                          const SizedBox(height: 32),

                          // Statistiques verticales
                          _buildVerticalStat('Publications', _stats['posts'] ?? 0),
                          const Divider(color: Colors.white10, height: 24),
                          _buildVerticalStat('Abonnés', _stats['followers'] ?? 0),
                          const Divider(color: Colors.white10, height: 24),
                          _buildVerticalStat('Abonnements', _stats['following'] ?? 0),
                          
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // COLONNE DROITE : LE FLUX VIDÉO (65%)
            // ==========================================
            Expanded(
              child: Column(
                children: [
                  // Système d'onglets (Vidéos vs Séries)
                  TabBar(
                    controller: _tabController,
                    indicatorColor: ThixPolicy.primary,
                    labelColor: Colors.white,
                    unselectedLabelColor: ThixPolicy.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    dividerColor: Colors.white10,
                    tabs: const [
                      Tab(text: 'Vidéos'),
                      Tab(text: 'Séries & Formations'),
                    ],
                  ),
                  
                  // Contenu des onglets
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMediaGrid(standaloneVideos, 'Aucune vidéo standard'),
                        _buildMediaGrid(seriesVideos, 'Aucune série ou formation'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalStat(String label, int count) {
    String format(int num) {
      if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
      if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}k';
      return num.toString();
    }

    return Column(
      children: [
        Text(format(count), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMediaGrid(List<MediaContent> list, String emptyMessage) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_creation_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(emptyMessage, style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: ThixPolicy.primary,
      backgroundColor: ThixPolicy.surface,
      onRefresh: _loadProfileData,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: list.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == list.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
            );
          }
          return _ProfileVideoCard(post: list[index]);
        },
      ),
    );
  }
}

// ==========================================================
// COMPOSANT : CARTE VIDÉO (Prend en charge les séries)
// ==========================================================
class _ProfileVideoCard extends StatefulWidget {
  final MediaContent post;
  const _ProfileVideoCard({required this.post});

  @override
  State<_ProfileVideoCard> createState() => _ProfileVideoCardState();
}

class _ProfileVideoCardState extends State<_ProfileVideoCard> {
  int _likes = 0;
  int _views = 0;
  int _comments = 0;
  StreamSubscription? _statsSub;

  @override
  void initState() {
    super.initState();
    _likes = widget.post.likeCount;
    _views = widget.post.viewCount;
    _comments = widget.post.commentCount;
    _listenToStats();
  }

  void _listenToStats() {
    _statsSub = Stream.periodic(const Duration(seconds: 15)).asyncMap((_) async {
      final r = await Supabase.instance.client
          .from('media_stats')
          .select('like_count, view_count, comment_count')
          .eq('media_id', widget.post.id)
          .maybeSingle();
      return r;
    }).listen((data) {
      if (data != null && mounted) {
        setState(() {
          _likes = (data['like_count'] as num?)?.toInt() ?? _likes;
          _views = (data['view_count'] as num?)?.toInt() ?? _views;
          _comments = (data['comment_count'] as num?)?.toInt() ?? _comments;
        });
      }
    });
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    super.dispose();
  }

  String _format(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}k';
    return num.toString();
  }

  void _openPlayer(String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerPage(title: title, videoUrl: url))
    );
  }

  void _showSeriesEpisodesDialog() {
    final allEpisodes = [widget.post.videoUrl, ...widget.post.episodesUrls].where((u) => u.isNotEmpty).toList();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 16),
              Text(widget.post.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              Text('Sélectionnez une partie', style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: allEpisodes.length,
                  itemBuilder: (context, idx) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.center,
                        child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      title: Text('Partie ${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.play_circle_fill_rounded, color: ThixPolicy.primary),
                      onTap: () {
                        Navigator.pop(context);
                        _openPlayer(allEpisodes[idx], '${widget.post.title} - Partie ${idx + 1}');
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalEpisodes = 1 + widget.post.episodesUrls.length;
    final isSeries = widget.post.type == 'Série' || widget.post.type == 'Formation' || widget.post.episodesUrls.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (isSeries) {
          _showSeriesEpisodesDialog();
        } else {
          _openPlayer(widget.post.videoUrl, widget.post.title);
        }
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: ThixPolicy.surface,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))
          ]
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Couverture Image
              CachedNetworkImage(
                imageUrl: widget.post.coverUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: ThixPolicy.textSecondary)),
              ),
              
              // 2. Dégradé de lisibilité
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.4), Colors.black.withOpacity(0.9)],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // 3. Bouton Play Central ou Multi-Play
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24)
                  ),
                  child: Icon(isSeries ? Icons.video_library_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32),
                ),
              ),

              // Si Payant (Monétisé)
              if (widget.post.isPaid)
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(20)),
                    child: Text('\$${widget.post.price}', style: const TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ),

              // 4. Infos & Statistiques en bas
              Positioned(
                bottom: 12, left: 12, right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                    ),
                    const SizedBox(height: 10),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildStatIcon(Icons.remove_red_eye_rounded, _format(_views)),
                            const SizedBox(width: 12),
                            _buildStatIcon(Icons.favorite_rounded, _format(_likes), color: ThixPolicy.danger),
                            const SizedBox(width: 12),
                            _buildStatIcon(Icons.chat_bubble_rounded, _format(_comments)),
                          ],
                        ),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.8), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            isSeries ? '${widget.post.type} ($totalEpisodes pts)' : widget.post.type,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatIcon(IconData icon, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color ?? Colors.white70, size: 14),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: color ?? Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
