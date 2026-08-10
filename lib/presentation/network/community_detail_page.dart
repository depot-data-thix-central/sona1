// lib/presentation/network/community_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:thix_id/models/network_community.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/presentation/network/widgets/post_card.dart';
import 'package:thix_id/features/network/presentation/providers/community_detail_provider.dart'; 

class CommunityDetailPage extends ConsumerStatefulWidget {
  final String communityId;
  const CommunityDetailPage({super.key, required this.communityId});

  @override
  ConsumerState<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends ConsumerState<CommunityDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _postsScroll = ScrollController();
  bool _isJoiningProcess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _postsScroll.addListener(() {
      if (_postsScroll.position.pixels >= _postsScroll.position.maxScrollExtent - 400) {
        ref.read(communityDetailProvider(widget.communityId).notifier).loadMorePosts();
      }
    });
  }

  @override
  void dispose() { 
    _tabController.dispose(); 
    _postsScroll.dispose(); 
    super.dispose(); 
  }

  Future<void> _handleToggleJoin(bool currentlyMember) async {
    if (_isJoiningProcess) return;
    setState(() => _isJoiningProcess = true);
    
    try {
      await ref.read(communityDetailProvider(widget.communityId).notifier).toggleJoin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(currentlyMember ? '❌ Vous avez quitté' : '✅ Vous avez rejoint'), 
          backgroundColor: currentlyMember ? Colors.orange : Colors.green
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur réseau'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isJoiningProcess = false);
    }
  }

  void _shareCommunity(NetworkCommunity? community) {
    if (community != null) {
      Share.share('Rejoins "${community.name}" sur THIX PRO! https://thix.app/community/${community.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(communityDetailProvider(widget.communityId));
    final currentUserId = ref.watch(authControllerProvider).value?.id ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0.5,
        title: Text(
          asyncState.valueOrNull?.community.name ?? 'Communauté', 
          style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold, fontSize: 18)
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A2E), size: 20), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Color(0xFF1A1A2E), size: 22), onPressed: () => _shareCommunity(asyncState.valueOrNull?.community)),
          if (asyncState.valueOrNull != null) 
            Padding(
              padding: const EdgeInsets.only(right: 12), 
              child: ElevatedButton(
                onPressed: _isJoiningProcess ? null : () => _handleToggleJoin(asyncState.valueOrNull!.isMember), 
                style: ElevatedButton.styleFrom(
                  backgroundColor: asyncState.valueOrNull!.isMember ? Colors.white : const Color(0xFFD4AF37), 
                  foregroundColor: asyncState.valueOrNull!.isMember ? const Color(0xFFD4AF37) : Colors.white, 
                  side: asyncState.valueOrNull!.isMember ? const BorderSide(color: Color(0xFFD4AF37)) : null, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                ), 
                child: _isJoiningProcess 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : Text(asyncState.valueOrNull!.isMember ? 'Quitter' : 'Rejoindre')
              )
            ),
        ],
        bottom: TabBar(
          controller: _tabController, 
          labelColor: const Color(0xFFD4AF37), 
          unselectedLabelColor: Colors.grey.shade600, 
          indicatorColor: const Color(0xFFD4AF37), 
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), 
          tabs: const [Tab(text: '📝 À propos'), Tab(text: '👥 Membres')]
        ),
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)))),
        error: (e, _) => _buildErrorState(e.toString()),
        data: (state) => TabBarView(
          controller: _tabController, 
          children: [
            _buildAboutTab(state, currentUserId), 
            _buildMembersTab(state.members)
          ]
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline, size: 56, color: Colors.red.shade400), const SizedBox(height: 16), const Text('Erreur de chargement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(error, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)), const SizedBox(height: 24), ElevatedButton.icon(onPressed: () => ref.invalidate(communityDetailProvider(widget.communityId)), icon: const Icon(Icons.refresh), label: const Text('Réessayer'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))))])));

  Widget _buildAboutTab(CommunityDetailState state, String currentUserId) {
    final community = state.community;
    final posts = state.posts;

    return RefreshIndicator(
      color: const Color(0xFFD4AF37), 
      onRefresh: () async => ref.invalidate(communityDetailProvider(widget.communityId)), 
      child: SingleChildScrollView(
        controller: _postsScroll, 
        physics: const AlwaysScrollableScrollPhysics(), 
        padding: const EdgeInsets.all(16), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Container(
              height: 160, 
              width: double.infinity, 
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0B1B3D), Color(0xFF1A2B4D)]), 
                borderRadius: BorderRadius.circular(16), 
                image: community.bannerUrl != null && community.bannerUrl!.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(community.bannerUrl!), fit: BoxFit.cover) : null
              ), 
              child: community.bannerUrl == null || community.bannerUrl!.isEmpty 
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.groups, size: 56, color: const Color(0xFFD4AF37).withOpacity(0.6)), const SizedBox(height: 8), Text(community.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))])) 
                : null
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(community.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)))), 
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text(community.privacy ?? 'Public', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD4AF37))))
            ]),
            if (community.description != null && community.description!.isNotEmpty) ...[
              const SizedBox(height: 8), 
              Text(community.description!, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5))
            ],
            const SizedBox(height: 16), 
            Row(children: [
              _buildStatItem('${community.membersCount}', 'membres', Icons.people), 
              const SizedBox(width: 24), 
              _buildStatItem('${posts.length}', 'publications', Icons.article)
            ]),
            const SizedBox(height: 24), 
            const Text('📄 Dernières publications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))), 
            const SizedBox(height: 12),
            if (posts.isEmpty) 
              Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [Icon(Icons.article_outlined, size: 48, color: Colors.grey.shade400), const SizedBox(height: 8), const Text('Aucune publication', style: TextStyle(color: Colors.grey))])))
            else 
              Column(children: posts.map((post) => PostCard(
                post: post, 
                currentProfileId: currentUserId, 
                onLike: () => ref.read(communityDetailProvider(widget.communityId).notifier).toggleLike(post.id), 
                onComment: () => context.push('/network/comments/${post.id}'), 
                onTap: () => context.push('/network/post/${post.id}'), 
                onShare: () => Share.share('Découvrez cette publication'), 
                onRefresh: () => ref.invalidate(communityDetailProvider(widget.communityId))
              )).toList()),
            
            // Scalable: Loading indicator en bas lors de la pagination
            if (state.hasMorePosts && posts.isNotEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              
            const SizedBox(height: 80),
          ]
        )
      )
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) => Row(children: [Icon(icon, size: 18, color: const Color(0xFFD4AF37)), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))), Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))])]);
  
  Widget _buildMembersTab(List<Map<String, dynamic>> members) => members.isEmpty ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_outline, size: 48, color: Colors.grey), SizedBox(height: 8), Text('Aucun membre', style: TextStyle(color: Colors.grey))])) : RefreshIndicator(color: const Color(0xFFD4AF37), onRefresh: () async => ref.invalidate(communityDetailProvider(widget.communityId)), child: ListView.builder(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), itemCount: members.length, itemBuilder: (context, i) => _buildMemberTile(members[i])));
  
  Widget _buildMemberTile(Map<String, dynamic> member) => Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))]), child: ListTile(leading: CircleAvatar(radius: 24, backgroundImage: member['photo_url'] != null && member['photo_url'].isNotEmpty ? CachedNetworkImageProvider(member['photo_url']) : null, child: member['photo_url'] == null || member['photo_url'].isEmpty ? Text((member['display_name'] ?? 'U')[0].toUpperCase()) : null), title: Text(member['display_name'] ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), subtitle: member['profession'] != null ? Text(member['profession'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600)) : null, trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20), onTap: () => context.push('/network/profile/${member['id']}')));
}
