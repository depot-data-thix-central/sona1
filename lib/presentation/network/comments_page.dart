import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/models/comment.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/comments_provider.dart';
import 'package:thix_id/presentation/network/widgets/post_card.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentsPage extends ConsumerStatefulWidget {
  final String postId;
  final String currentProfileId;
  const CommentsPage({super.key, required this.postId, required this.currentProfileId});
  @override
  ConsumerState<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends ConsumerState<CommentsPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  NetworkPost? _post;
  bool _isLoadingPost = true;
  bool _isSubmitting = false;
  String? _replyingTo;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
        ref.read(commentsProvider(widget.postId).notifier).loadMore();
      }
    });
    _loadPost();
  }

  Future<void> _loadPost() async {
    try {
      final p = await ref.read(networkServiceProvider).getPostById(widget.postId);
      if (mounted) setState(() { _post = p; _isLoadingPost = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingPost = false);
    }
  }

  Future<void> _submitComment({String? parentId}) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(commentsProvider(widget.postId).notifier).addComment(text, parentId: parentId?? _replyingTo);
      _controller.clear();
      _clearReply();
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clearReply() => setState(() { _replyingTo = null; _replyingToName = null; });

  void _startReply(String userName, String commentId) {
    setState(() { _replyingTo = commentId; _replyingToName = userName; });
    _focusNode.requestFocus();
  }

  Future<void> _toggleLikeComment(Comment comment) async {
    final oldLiked = comment.isLiked;
    final oldCount = comment.likesCount;
    setState(() { comment.isLiked =!oldLiked; comment.likesCount = oldLiked? oldCount - 1 : oldCount + 1; });
    try {
      if (comment.isLiked) await ref.read(networkServiceProvider).likeComment(comment.id);
      else await ref.read(networkServiceProvider).unlikeComment(comment.id);
    } catch (_) {
      setState(() { comment.isLiked = oldLiked; comment.likesCount = oldCount; });
    }
  }

  @override
  void dispose() { _controller.dispose(); _scrollController.dispose(); _focusNode.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    final currentUserId = ref.watch(authControllerProvider).value?.id?? widget.currentProfileId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Commentaires', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(onPressed: () => ref.invalidate(commentsProvider(widget.postId)), icon: const Icon(Icons.refresh_rounded, color: Colors.grey))],
      ),
      body: _isLoadingPost && _post == null
         ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async { await _loadPost(); ref.invalidate(commentsProvider(widget.postId)); },
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      if (_post!= null)
                        SliverToBoxAdapter(child: PostCard(post: _post!, currentProfileId: widget.currentProfileId, onTap: () => Navigator.pop(context), onRefresh: _loadPost)),
                      commentsAsync.when(
                        loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))),
                        error: (e, _) => SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Erreur: $e')))),
                        data: (comments) => comments.isEmpty
                           ? SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.comment_outlined, size: 60, color: Colors.grey[300]), const SizedBox(height: 12), Text('Aucun commentaire', style: TextStyle(color: Colors.grey[600]))])))
                            : SliverList(delegate: SliverChildBuilderDelegate((context, index) => _buildCommentTile(comments[index], currentUserId, isRoot: true), childCount: comments.length)),
                      ),
                    ],
                  ),
                ),
              ),
              _buildInputBar(),
            ]),
    );
  }

  Widget _buildCommentTile(Comment comment, String? currentUserId, {bool isRoot = true}) {
    final isOwn = comment.userId == currentUserId;
    final hasReplies = comment.replies.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(left: isRoot? 16 : 24, right: 16, bottom: 6),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(radius: 18, backgroundImage: comment.userAvatar!= null && comment.userAvatar!.isNotEmpty? NetworkImage(comment.userAvatar!) : null, child: comment.userAvatar == null || comment.userAvatar!.isEmpty? Icon(Icons.person, size: 18, color: Colors.grey[600]) : null),
            title: Row(children: [Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), const SizedBox(width: 6), Text(timeago.format(comment.createdAt, locale: 'fr'), style: TextStyle(color: Colors.grey[500], fontSize: 10))]),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(comment.content, style: const TextStyle(fontSize: 14, height: 1.4))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Row(children: [
            _actionButton(icon: comment.isLiked? Icons.favorite_rounded : Icons.favorite_border_rounded, iconColor: comment.isLiked? Colors.red : Colors.grey[600]!, label: comment.likesCount > 0? '${comment.likesCount}' : '', onTap: () => _toggleLikeComment(comment)),
            const SizedBox(width: 12),
            _actionButton(icon: Icons.reply_rounded, iconColor: Colors.grey[600]!, label: 'Répondre', onTap: () => _startReply(comment.userName, comment.id)),
          ])),
          if (hasReplies)...[
            Divider(height: 1, thickness: 0.8, color: Colors.grey[200]),
            Padding(padding: const EdgeInsets.only(top: 4), child: Column(children: comment.replies.map((r) => _buildCommentTile(r, currentUserId, isRoot: false)).toList())),
          ],
        ]),
      ),
    );
  }

  Widget _actionButton({required IconData icon, required Color iconColor, required String label, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: iconColor), if (label.isNotEmpty)...[const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600]))]])));
  }

  void _editComment(Comment comment) async {
    final controller = TextEditingController(text: comment.content);
    final newContent = await showDialog<String>(context: context, builder: (c) => AlertDialog(title: const Text('Modifier'), content: TextField(controller: controller, maxLines: 3), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')), ElevatedButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Enregistrer'))]));
    if (newContent!= null && newContent!= comment.content) {
      try { await ref.read(networkServiceProvider).updateComment(comment.id, newContent); setState(() => comment.content = newContent); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'))); }
    }
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_replyingTo!= null)
          Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(Icons.reply_rounded, size: 14, color: Colors.blue[700]), const SizedBox(width: 6), Text('Réponse à $_replyingToName', style: TextStyle(fontSize: 12, color: Colors.blue[700])), const Spacer(), InkWell(onTap: _clearReply, child: const Icon(Icons.close, size: 16))])),
        Row(children: [
          Expanded(child: TextField(controller: _controller, focusNode: _focusNode, onSubmitted: (_) => _submitComment(), decoration: InputDecoration(hintText: _replyingTo!= null? 'Écrire une réponse...' : 'Écrire un commentaire...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), filled: true, fillColor: Colors.grey[100], contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)))),
          const SizedBox(width: 8),
          CircleAvatar(radius: 22, backgroundColor: Colors.blue, child: IconButton(icon: _isSubmitting? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white, size: 20), onPressed: _isSubmitting? null : () => _submitComment())),
        ]),
      ]),
    );
  }
}
