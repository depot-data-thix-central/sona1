import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/models/network_post.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});
  @override ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final ScrollController _scrollController = ScrollController();
  int _selectedTab = 0;
  bool _isGridView = true;

  final _thixBgColor = const Color(0xFFF5F8FA);
  final _thixPrimaryBlue = const Color(0xFF2B5CFF);
  final _thixDarkText = const Color(0xFF1A1A2E);
  final _tabs = ['Posts', 'Photos', 'Vidéos'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }
  @override void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      final uid = widget.userId?? Supabase.instance.client.auth.currentUser!.id;
      ref.read(userPostsProvider(uid).notifier).loadMore();
    }
  }

  Widget _buildImg(String? url, {double? w, double? h, BoxFit fit = BoxFit.cover}) {
    if (url == null || url.isEmpty) return Container(color: Colors.grey[100], child: Icon(Icons.person, color: _thixPrimaryBlue.withOpacity(0.5)));
    return Image.network(url, width: w, height: h, fit: fit,
      loadingBuilder: (_, child, p) => p == null? child : Container(color: Colors.grey[100]),
      errorBuilder: (_, __, ___) => Container(color: Colors.grey[100], child: Icon(Icons.broken_image, color: Colors.grey[300])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.userId?? Supabase.instance.client.auth.currentUser!.id;
    final profileAsync = ref.watch(userProfileProvider(uid));
    final postsAsync = ref.watch(userPostsProvider(uid));
    final pinnedAsync = ref.watch(pinnedPostsProvider(uid));
    final isOwn = uid == Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: _thixBgColor,
      body: RefreshIndicator(
        onRefresh: () => ref.read(userPostsProvider(uid).notifier).refresh(),
        color: _thixPrimaryBlue,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: profileAsync.when(
              data: (u) => _buildCover(u?['cover_url']),
              loading: () => Container(height: 140, color: _thixDarkText),
              error: (_, __) => Container(height: 140, color: _thixDarkText),
            )),
            SliverToBoxAdapter(child: profileAsync.when(
              data: (u) => _buildHeader(u, isOwn),
              loading: () => SizedBox(height: 80),
              error: (_, __) => SizedBox(),
            )),
            pinnedAsync.when(
              data: (pins) => pins.isNotEmpty? SliverToBoxAdapter(child: _buildPinned(pins.first)) : SliverToBoxAdapter(child: SizedBox()),
              loading: () => SliverToBoxAdapter(child: SizedBox()),
              error: (_, __) => SliverToBoxAdapter(child: SizedBox()),
            ),
            SliverToBoxAdapter(child: profileAsync.when(data: (u) => _buildStats(u), loading: () => SizedBox(), error: (_, __) => SizedBox())),
            SliverToBoxAdapter(child: _buildTabs()),
            postsAsync.when(
              data: (posts) {
                var displayed = posts;
                if (_selectedTab == 1) displayed = posts.where((p) => p.imageUrls.isNotEmpty).toList();
                if (_selectedTab == 2) displayed = posts.where((p) => p.videoUrls.isNotEmpty).toList();
                if (displayed.isEmpty) return SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Aucune publication'))));
                if (_isGridView) {
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                    delegate: SliverChildBuilderDelegate((_, i) => _buildGridItem(displayed[i]), childCount: displayed.length),
                  );
                } else {
                  return SliverList(delegate: SliverChildBuilderDelegate((_, i) => _buildListItem(displayed[i]), childCount: displayed.length));
                }
              },
              loading: () => SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: _thixPrimaryBlue)))),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Erreur: $e'))),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(String? url) => Container(height: 140, width: double.infinity, color: _thixDarkText, child: url!= null? _buildImg(url, w: double.infinity, h: 140) : null);

  Widget _buildHeader(Map<String, dynamic>? u, bool isOwn) => Container(transform: Matrix4.translationValues(0.0, -30.0, 0.0), padding: EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _thixBgColor, width: 4)), child: CircleAvatar(radius: 46, backgroundColor: Colors.white, child: ClipOval(child: SizedBox(width: 92, height: 92, child: _buildImg(u?['avatar_url']?? u?['photo_url'], w: 92, h: 92))))),
      Spacer(),
      if (isOwn) OutlinedButton(onPressed: () => context.push('/network/profile-settings'), child: Text('Modifier le profil')) else Consumer(builder: (context, ref, _) {
        final follow = ref.watch(followStatusProvider(widget.userId!));
        return follow.when(data: (isFollowing) => ElevatedButton.icon(onPressed: () async { await ref.read(networkServiceProvider).sendConnectionRequest(widget.userId!); ref.invalidate(followStatusProvider(widget.userId!)); }, icon: Icon(isFollowing? Icons.check : Icons.person_add, size: 18), label: Text(isFollowing? 'Abonné' : 'Suivre'), style: ElevatedButton.styleFrom(backgroundColor: isFollowing? Colors.grey[200] : _thixPrimaryBlue, foregroundColor: isFollowing? _thixDarkText : Colors.white)), loading: () => SizedBox(), error: (_, __) => SizedBox());
      }),
    ]),
    SizedBox(height: 12),
    Text(u?['display_name']?? 'Utilisateur', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _thixDarkText)),
    Text(u?['profession']?? 'Membre THIX PRO', style: TextStyle(color: Colors.grey)),
  ]));

  Widget _buildStats(Map<String, dynamic>? u) => Container(margin: EdgeInsets.symmetric(horizontal: 16), transform: Matrix4.translationValues(0.0, -10.0, 0.0), child: Row(children: [
    _stat('${u?['followers_count']?? 0}', 'Abonnés'), SizedBox(width: 24),
    _stat('${u?['following_count']?? 0}', 'Abonnements'), SizedBox(width: 24),
    _stat('${u?['posts_count']?? 0}', 'Publications'),
  ]));
  Widget _stat(String v, String l) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _thixDarkText)), Text(l, style: TextStyle(fontSize: 13, color: Colors.grey))]);

  Widget _buildTabs() => Container(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [
    Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(_tabs.length, (i) {
      final sel = _selectedTab == i;
      return GestureDetector(onTap: () => setState(() => _selectedTab = i), child: Container(margin: EdgeInsets.only(right: 10), padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8), decoration: BoxDecoration(color: sel? _thixPrimaryBlue : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel? _thixPrimaryBlue : Colors.grey.shade300)), child: Text(_tabs[i], style: TextStyle(color: sel? Colors.white : _thixDarkText, fontWeight: FontWeight.w600))));
    })))),
    IconButton(icon: Icon(_isGridView? Icons.grid_view_rounded : Icons.view_agenda_rounded), onPressed: () => setState(() => _isGridView =!_isGridView)),
  ]));

  Widget _buildGridItem(NetworkPost post) {
    final url = post.imageUrls.isNotEmpty? post.imageUrls.first : null;
    return GestureDetector(onTap: () => context.push('/network/post/${post.id}'), child: Container(color: Colors.white, child: url!= null? _buildImg(url, w: 300, h: 300) : Center(child: Text(post.content, maxLines: 3, style: TextStyle(fontSize: 10), textAlign: TextAlign.center))));
  }
  Widget _buildListItem(NetworkPost post) => GestureDetector(onTap: () => context.push('/network/post/${post.id}'), child: Container(margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6), padding: EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(post.content, maxLines: 3), SizedBox(height: 12), Row(children: [Icon(Icons.favorite_border, size: 16, color: Colors.grey), SizedBox(width: 4), Text('${post.likesCount}'), SizedBox(width: 16), Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey), SizedBox(width: 4), Text('${post.commentsCount}')])])));
  Widget _buildPinned(NetworkPost post) => Container(margin: EdgeInsets.all(16), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.shade200)), child: Row(children: [Icon(Icons.push_pin, color: Colors.amber), SizedBox(width: 8), Expanded(child: Text(post.content, maxLines: 1, overflow: TextOverflow.ellipsis))]));
}
