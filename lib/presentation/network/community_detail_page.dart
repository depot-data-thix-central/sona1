import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:thix_id/models/network_community.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/presentation/network/widgets/post_card.dart';

class CommunityDetailPage extends ConsumerStatefulWidget {
  final String communityId;
  const CommunityDetailPage({super.key, required this.communityId});
  @override
  ConsumerState<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends ConsumerState<CommunityDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NetworkCommunity? _community;
  List<NetworkPost> _posts = [];
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _isMember = false;
  bool _isJoining = false;
  String? _error;
  final ScrollController _postsScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    _postsScroll.addListener(() {
      if (_postsScroll.position.pixels >= _postsScroll.position.maxScrollExtent - 400) {
        _loadMorePosts(); // scalable pagination
      }
    });
  }

  @override
  void dispose() { _tabController.dispose(); _postsScroll.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final supabase = ref.read(supabaseClientProvider);
      final currentUserId = supabase.auth.currentUser?.id;

      final results = await Future.wait([
        supabase.from('communities').select('*').eq('id', widget.communityId).maybeSingle(),
        supabase.from('community_members').select('users!user_id (id, display_name, photo_url, profession)').eq('community_id', widget.communityId).limit(50),
        supabase.from('posts').select('*, users!user_id (display_name, photo_url, profession)').eq('community_id', widget.communityId).order('created_at', ascending: false).limit(20),
        currentUserId!= null? supabase.from('community_members').select('id').eq('community_id', widget.communityId).eq('user_id', currentUserId).maybeSingle() : Future.value(null),
      ]);

      if (!mounted) return;
      final communityData = results[0] as Map<String, dynamic>?;
      if (communityData == null) throw Exception('Communauté non trouvée');

      final membersData = results[1] as List<dynamic>;
      final postsData = results[2] as List<dynamic>;
      final memberCheck = results[3] as Map<String, dynamic>?;

      final posts = <NetworkPost>[];
      for (var e in postsData) {
        final userData = e['users'] as Map<String, dynamic>?;
        posts.add(NetworkPost.fromJson({
         ...e as Map<String, dynamic>,
          'author_name': userData?['display_name']?? 'Utilisateur',
          'author_avatar': userData?['photo_url'],
          'author_title': userData?['profession'],
          'media_urls': _extractMediaUrls(e),
        }));
      }

      setState(() {
        _community = NetworkCommunity.fromJson({...communityData, 'members_count': communityData['members_count']?? 0});
        _members = membersData.map((e) => e['users'] as Map<String, dynamic>).toList();
        _posts = posts;
        _isMember = memberCheck!= null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMorePosts() async {
    // scalable : pagination offset
    try {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase.from('posts').select('*, users!user_id (display_name, photo_url, profession)').eq('community_id', widget.communityId).order('created_at', ascending: false).range(_posts.length, _posts.length + 19);
      if (res.isEmpty) return;
      final more = (res as List).map((e) {
        final u = e['users'] as Map<String, dynamic>?;
        return NetworkPost.fromJson({...e as Map<String, dynamic>, 'author_name': u?['display_name']?? 'Utilisateur', 'author_avatar': u?['photo_url'], 'author_title': u?['profession'], 'media_urls': _extractMediaUrls(e)});
      }).toList();
      if (mounted) setState(() => _posts.addAll(more));
    } catch (_) {}
  }

  List<String> _extractMediaUrls(Map<String, dynamic> row) {
    if (row['media_urls']!= null) return List<String>.from(row['media_urls'] as List);
    if (row['media_url']!= null && row['media_url'].toString().isNotEmpty) return [row['media_url'].toString()];
    if (row['image_urls']!= null) return List<String>.from(row['image_urls'] as List);
    return [];
  }

  Future<void> _toggleJoin() async {
    if (_isJoining || _community == null) return;
    setState(() => _isJoining = true);
    final wasMember = _isMember;
    final prevCount = _community!.membersCount;
    setState(() { _isMember =!wasMember; _community = _community!.copyWith(membersCount: wasMember? (prevCount - 1) : (prevCount + 1)); });
    try {
      final supabase = ref.read(supabaseClientProvider);
      final uid = supabase.auth.currentUser!.id;
      if (wasMember) { await supabase.from('community_members').delete().eq('community_id', widget.communityId).eq('user_id', uid); }
      else { await supabase.from('community_members').insert({'community_id': widget.communityId, 'user_id': uid, 'joined_at': DateTime.now().toIso8601String()}); }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isMember? '✅ Vous avez rejoint' : '❌ Vous avez quitté'), backgroundColor: _isMember? Colors.green : Colors.orange));
    } catch (e) {
      if (mounted) { setState(() { _isMember = wasMember; _community = _community!.copyWith(membersCount: prevCount); }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur réseau'), backgroundColor: Colors.red)); }
    } finally { if (mounted) setState(() => _isJoining = false); }
  }

  void _shareCommunity() => Share.share('Rejoins "${_community?.name}" sur THIX PRO! https://thix.app/community/${widget.communityId}');

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authControllerProvider).value?.id?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0.5,
        title: Text(_community?.name?? 'Communauté', style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A2E), size: 20), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Color(0xFF1A1A2E), size: 22), onPressed: _shareCommunity),
          if (_community!= null) Padding(padding: const EdgeInsets.only(right: 12), child: ElevatedButton(onPressed: _isJoining? null : _toggleJoin, style: ElevatedButton.styleFrom(backgroundColor: _isMember? Colors.white : const Color(0xFFD4AF37), foregroundColor: _isMember? const Color(0xFFD4AF37) : Colors.white, side: _isMember? const BorderSide(color: Color(0xFFD4AF37)) : null, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)), child: _isJoining? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isMember? 'Quitter' : 'Rejoindre'))),
        ],
        bottom: TabBar(controller: _tabController, labelColor: const Color(0xFFD4AF37), unselectedLabelColor: Colors.grey.shade600, indicatorColor: const Color(0xFFD4AF37), labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), tabs: const [Tab(text: '📝 À propos'), Tab(text: '👥 Membres')]),
      ),
      body: _loading? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)))) : _error!= null? _buildErrorState() : _community == null? _buildNotFoundState() : TabBarView(controller: _tabController, children: [_buildAboutTab(currentUserId), _buildMembersTab()]),
    );
  }

  Widget _buildErrorState() => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline, size: 56, color: Colors.red.shade400), const SizedBox(height: 16), const Text('Erreur de chargement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)), const SizedBox(height: 24), ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Réessayer'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))))])));
  Widget _buildNotFoundState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.groups, size: 64, color: Colors.grey.shade400), const SizedBox(height: 16), const Text('Communauté non trouvée', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 24), ElevatedButton.icon(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back), label: const Text('Retour'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white))]));

  Widget _buildAboutTab(String currentUserId) {
    return RefreshIndicator(color: const Color(0xFFD4AF37), onRefresh: _loadData, child: SingleChildScrollView(controller: _postsScroll, physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(height: 160, width: double.infinity, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0B1B3D), Color(0xFF1A2B4D)]), borderRadius: BorderRadius.circular(16), image: _community?.bannerUrl!= null && _community!.bannerUrl!.isNotEmpty? DecorationImage(image: CachedNetworkImageProvider(_community!.bannerUrl!), fit: BoxFit.cover) : null), child: _community?.bannerUrl == null || _community!.bannerUrl!.isEmpty? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.groups, size: 56, color: const Color(0xFFD4AF37).withOpacity(0.6)), const SizedBox(height: 8), Text(_community?.name?? 'Communauté', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))])) : null),
      const SizedBox(height: 16),
      Row(children: [Expanded(child: Text(_community!.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)))), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text(_community?.privacy?? 'Public', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD4AF37))))]),
      if (_community?.description!= null && _community!.description!.isNotEmpty)...[const SizedBox(height: 8), Text(_community!.description!, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5))],
      const SizedBox(height: 16), Row(children: [_buildStatItem('${_community?.membersCount?? 0}', 'membres', Icons.people), const SizedBox(width: 24), _buildStatItem('${_posts.length}', 'publications', Icons.article)]),
      const SizedBox(height: 24), const Text('📄 Dernières publications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))), const SizedBox(height: 12),
      if (_posts.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [Icon(Icons.article_outlined, size: 48, color: Colors.grey.shade400), const SizedBox(height: 8), const Text('Aucune publication', style: TextStyle(color: Colors.grey))])))
      else Column(children: _posts.map((post) => PostCard(post: post, currentProfileId: currentUserId, onLike: () => _toggleLike(post.id), onComment: () => context.push('/network/comments/${post.id}'), onTap: () => context.push('/network/post/${post.id}'), onShare: () => Share.share('Découvrez cette publication'), onRefresh: _loadData)).toList()),
      const SizedBox(height: 80),
    ])));
  }

  Widget _buildStatItem(String value, String label, IconData icon) => Row(children: [Icon(icon, size: 18, color: const Color(0xFFD4AF37)), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))), Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))])]);
  Widget _buildMembersTab() => _members.isEmpty? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_outline, size: 48, color: Colors.grey), SizedBox(height: 8), Text('Aucun membre', style: TextStyle(color: Colors.grey))])) : RefreshIndicator(color: const Color(0xFFD4AF37), onRefresh: _loadData, child: ListView.builder(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), itemCount: _members.length, itemBuilder: (context, i) => _buildMemberTile(_members[i])));
  Widget _buildMemberTile(Map<String, dynamic> member) => Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))]), child: ListTile(leading: CircleAvatar(radius: 24, backgroundImage: member['photo_url']!= null && member['photo_url'].isNotEmpty? CachedNetworkImageProvider(member['photo_url']) : null, child: member['photo_url'] == null || member['photo_url'].isEmpty? Text((member['display_name']?? 'U')[0].toUpperCase()) : null), title: Text(member['display_name']?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), subtitle: member['profession']!= null? Text(member['profession'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600)) : null, trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20), onTap: () => context.push('/network/profile/${member['id']}')));

  Future<void> _toggleLike(String postId) async {
    try {
      final post = _posts.firstWhere((p) => p.id == postId);
      final newIsLiked =!post.isLiked;
      setState(() { final idx = _posts.indexWhere((p) => p.id == postId); if (idx!= -1) _posts[idx] = post.copyWith(isLiked: newIsLiked, likesCount: post.likesCount + (newIsLiked? 1 : -1)); });
      if (newIsLiked) await ref.read(networkServiceProvider).likePost(postId); else await ref.read(networkServiceProvider).unlikePost(postId);
    } catch (_) { await _loadData(); }
  }
}
