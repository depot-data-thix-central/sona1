// lib/presentation/network/widgets/comments_page.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http; // 🌟 IMPORT POUR RÉCUPÉRER L'AUDIO WEB
import 'package:image_picker/image_picker.dart'; // 🌟 IMPORT POUR XFILE MOBILE

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

  // ─── MÉDIAS (Audio & Photo) ───
  Uint8List? _imageBytes;
  Uint8List? _audioBytes;
  
  // ─── AUDIO RECORDING (Limite : 30 sec) ───
  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordDuration = 0;
  bool _isRecording = false;

  // ─── STICKERS ───
  bool _showStickers = false;

  static const List<String> _emojis = [
    '😀','😃','😄','😁','😆','😅','😂','🤣','🥲','🥹',
    '😊','😇','🙂','🙃','😉','😌','😍','🥰','😘','😗',
    '😙','😚','🤩','🥳','🤗','🤔','🤭','🤫','🤥','😏',
    '😒','🙄','😬','😮‍💨','😔','😪','🤤','😴','😷','🤒',
    '🤕','🤢','🤮','🥵','🥶','😵','🤯','🤠','🥸','😎',
    '🤓','🧐','😕','😟','🙁','☹️','😮','😯','😲','😳',
    '🥺','😦','😧','😨','😰','😥','😢','😭','😱','😖',
    '😣','😞','😓','😩','😫','🥱','😤','😡','😠','🤬',
  ];

  static const List<String> _reactions = [
    '👍','👎','👌','🤌','🤏','✌️','🤞','🫰','🤟','🤘',
    '🤙','👈','👉','👆','👇','☝️','✋','🤚','🖐️','🖖',
    '👋','👏','🙌','🫶','💪','🦾','🙏','✍️',
    '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔',
    '❣️','💕','💞','💓','💗','💖','💘','💝','💟','❤️‍🔥',
    '🔥','⭐','🌟','✨','💫','💥','💯','🎉','🎊','🏆',
    '🥇','🥈','🥉','🎯','✅','❌','⚡','💡','📌','🔔',
  ];

  static const List<String> _flags = [
    '🏁','🚩','🎌','🏴','🏳️','🏳️‍⚧️','🏴‍☠️',
    '🇦🇫','🇿🇦','🇦🇱','🇩🇿','🇩🇪','🇦🇩','🇦🇴','🇦🇬',
    '🇸🇦','🇦🇷','🇦🇲','🇦🇺','🇦🇹','🇦🇿','🇧🇸','🇧🇭',
    '🇧🇩','🇧🇧','🇧🇪','🇧🇿','🇧🇯','🇧🇹','🇧🇾','🇲🇲',
    '🇧🇴','🇧🇦','🇧🇼','🇧🇷','🇧🇳','🇧🇬','🇧🇫','🇧🇮',
    '🇰🇭','🇨🇲','🇨🇦','🇨🇻','🇨🇱','🇨🇳','🇨🇾','🇨🇴',
    '🇰🇲','🇨🇬','🇨🇩','🇰🇵','🇰🇷','🇨🇷','🇨🇮','🇭🇷',
    '🇨🇺','🇩🇰','🇩🇯','🇩🇲','🇪🇬','🇸🇻','🇦🇪','🇪🇨',
    '🇪🇷','🇪🇸','🇪🇪','🇺🇸','🇪🇹','🇫🇯','🇫🇮','🇫🇷',
    '🇬🇦','🇬🇲','🇬🇪','🇬🇭','🇬🇷','🇬🇩','🇬🇹','🇬🇳',
    '🇬🇶','🇬🇾','🇭🇹','🇭🇳','🇭🇰','🇭🇺','🇮🇳','🇮🇩',
    '🇮🇷','🇮🇶','🇮🇪','🇮🇸','🇮🇱','🇮🇹','🇯🇲','🇯🇵',
    '🇯🇴','🇰🇿','🇰🇪','🇰🇬','🇰🇼','🇱🇦','🇱🇻','🇱🇧',
    '🇱🇷','🇱🇾','🇱🇮','🇱🇹','🇱🇺','🇲🇬','🇲🇾','🇲🇼',
    '🇲🇻','🇲🇱','🇲🇹','🇲🇦','🇲🇺','🇲🇽','🇲🇩','🇲🇨',
    '🇲🇳','🇲🇪','🇲🇿','🇳🇦','🇳🇵','🇳🇮','🇳🇪','🇳🇬',
    '🇳🇴','🇳🇿','🇴🇲','🇺🇬','🇺🇿','🇵🇰','🇵🇸','🇵🇦',
    '🇵🇬','🇵🇾','🇳🇱','🇵🇪','🇵🇭','🇵🇱','🇵🇹','🇶🇦',
    '🇨🇫','🇩🇴','🇷🇴','🇬🇧','🇷🇺','🇷🇼','🇸🇳','🇷🇸',
    '🇸🇨','🇸🇱','🇸🇬','🇸🇰','🇸🇮','🇸🇴','🇸🇩','🇱🇰',
    '🇸🇪','🇨🇭','🇸🇾','🇹🇯','🇹🇼','🇹🇿','🇹🇩','🇨🇿',
    '🇹🇭','🇹🇬','🇹🇴','🇹🇹','🇹🇳','🇹🇷','🇺🇦','🇺🇾',
    '🇻🇪','🇻🇳','🇾🇪','🇿🇲','🇿🇼',
  ];

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

  @override
  void dispose() { 
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _controller.dispose(); 
    _scrollController.dispose(); 
    _focusNode.dispose(); 
    super.dispose(); 
  }

  Future<void> _loadPost() async {
    try {
      final p = await ref.read(networkServiceProvider).getPostById(widget.postId);
      if (mounted) setState(() { _post = p; _isLoadingPost = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingPost = false);
    }
  }

  // ─── LOGIQUE AUDIO (Vraie capture Web/Mobile) ───
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
          path: '', // Fichier temp
        );
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
          _audioBytes = null;
          _showStickers = false;
        });
        
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _recordDuration++);
          if (_recordDuration >= 30) {
            _stopRecording();
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission microphone requise')));
      }
    } catch (e) {
      debugPrint('Erreur record: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        Uint8List bytes;
        if (kIsWeb) {
          // 🌟 Sur le Web, Record génère un blob URL. On le télécharge en bytes :
          final response = await http.get(Uri.parse(path));
          bytes = response.bodyBytes;
        } else {
          // 🌟 Sur Mobile, on lit le fichier
          final file = XFile(path);
          bytes = await file.readAsBytes();
        }
        setState(() => _audioBytes = bytes);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note vocale prête !'), backgroundColor: Color(0xFF2D6CDF)));
      }
    } catch (e) {
      debugPrint('Erreur stop record: $e');
    }
  }

  // ─── LOGIQUE PHOTO ───
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _imageBytes = result.files.first.bytes;
        _showStickers = false;
      });
    }
  }

  // ─── SOUMISSION DÉFINITIVE ───
  Future<void> _submitComment({String? parentId}) async {
    final text = _controller.text.trim();
    if (text.isEmpty && _audioBytes == null && _imageBytes == null) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final ns = ref.read(networkServiceProvider);
      String? audioUrl;
      String? imageUrl;

      // 1. Upload de l'Audio si présent
      if (_audioBytes != null && _audioBytes!.isNotEmpty) {
        audioUrl = await ns.uploadAudioBytes(_audioBytes!);
      }
      
      // 2. Upload de l'Image si présente
      if (_imageBytes != null && _imageBytes!.isNotEmpty) {
        imageUrl = await ns.uploadImageBytes(_imageBytes!, fileExtension: 'jpg', bucket: 'post_images');
      }

      // 3. Définir le texte de fallback si le champ est vide
      String finalContent = text;
      if (finalContent.isEmpty) {
        if (audioUrl != null) finalContent = '🎤 Note vocale';
        else if (imageUrl != null) finalContent = '📷 Photo';
      }

      // 4. Envoi direct via le NetworkService pour garantir le passage des URLs
      await ns.addComment(
        widget.postId,
        finalContent,
        parentId: parentId ?? _replyingTo,
        audioUrl: audioUrl,
        imageUrl: imageUrl,
      );

      // 5. Rafraîchir la liste des commentaires à l'écran
      ref.invalidate(commentsProvider(widget.postId));
      
      setState(() {
        _controller.clear();
        _audioBytes = null;
        _imageBytes = null;
        _showStickers = false;
      });
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
    setState(() { comment.isLiked = !oldLiked; comment.likesCount = oldLiked ? oldCount - 1 : oldCount + 1; });
    try {
      if (comment.isLiked) await ref.read(networkServiceProvider).likeComment(comment.id);
      else await ref.read(networkServiceProvider).unlikeComment(comment.id);
    } catch (_) {
      setState(() { comment.isLiked = oldLiked; comment.likesCount = oldCount; });
    }
  }

  void _insertSticker(String sticker) {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid) {
      _controller.text = '$text$sticker';
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    } else {
      final newText = text.replaceRange(sel.start, sel.end, sticker);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: sel.start + sticker.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    final currentUserId = ref.watch(authControllerProvider).value?.id ?? widget.currentProfileId;

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
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async { await _loadPost(); ref.invalidate(commentsProvider(widget.postId)); },
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        if (_post != null)
                          SliverToBoxAdapter(
                            child: PostCard(
                              post: _post!, 
                              currentProfileId: widget.currentProfileId, 
                              onTap: () {}, 
                              onRefresh: _loadPost
                            )
                          ),
                        commentsAsync.when(
                          loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))),
                          error: (e, _) => SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Erreur: $e')))),
                          data: (comments) => comments.isEmpty
                             ? SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.comment_outlined, size: 60, color: Colors.grey[300]), const SizedBox(height: 12), Text('Soyez le premier à commenter !', style: TextStyle(color: Colors.grey[600]))])))
                              : SliverList(delegate: SliverChildBuilderDelegate((context, index) => _buildCommentTile(comments[index], currentUserId, isRoot: true), childCount: comments.length)),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildInputBar(),
                if (_showStickers) _buildStickerPicker(),
              ]
            ),
    );
  }

  // ─── TUILE DE COMMENTAIRE (Avec Audio et Image activés) ───
  Widget _buildCommentTile(Comment comment, String? currentUserId, {bool isRoot = true}) {
    final hasReplies = comment.replies.isNotEmpty;
    
    // 🌟 On vérifie maintenant les vraies variables
    final hasAudio = comment.audioUrl != null && comment.audioUrl!.isNotEmpty;
    final hasImage = comment.imageUrl != null && comment.imageUrl!.isNotEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isRoot)
            Container(
              margin: const EdgeInsets.only(left: 32, right: 10),
              width: 2,
              color: Colors.grey[300],
            ),
            
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isRoot ? 16 : 0, right: 16, bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(16), 
                  border: Border.all(color: const Color(0xFFE7EEFC)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 12, right: 12, top: 4),
                      leading: CircleAvatar(
                        radius: 16, 
                        backgroundColor: const Color(0xFFEAF1FF),
                        backgroundImage: comment.userAvatar != null && comment.userAvatar!.isNotEmpty ? NetworkImage(comment.userAvatar!) : null, 
                        child: comment.userAvatar == null || comment.userAvatar!.isEmpty ? Icon(Icons.person, size: 16, color: Colors.grey[600]) : null
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              comment.userName, 
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF10192E)),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            )
                          ), 
                          Text(timeago.format(comment.createdAt, locale: 'fr'), style: TextStyle(color: Colors.grey[500], fontSize: 10))
                        ]
                      ),
                    ),
                    
                    if (comment.content.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), 
                        child: Text(comment.content, style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF10192E)))
                      ),

                    // Affichage de la photo
                    if (hasImage)
                      Padding(
                        padding: const EdgeInsets.only(left: 14, right: 14, top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(comment.imageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover),
                        ),
                      ),
                      
                    // Affichage du lecteur Audio
                    if (hasAudio)
                      Padding(
                        padding: const EdgeInsets.only(left: 14, right: 14, top: 8),
                        child: _CommentAudioPlayer(audioUrl: comment.audioUrl!), 
                      ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                      child: Row(
                        children: [
                          _actionButton(
                            icon: comment.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                            iconColor: comment.isLiked ? const Color(0xFFE5484D) : Colors.grey[500]!, 
                            label: comment.likesCount > 0 ? '${comment.likesCount}' : '', 
                            onTap: () => _toggleLikeComment(comment)
                          ),
                          const SizedBox(width: 8),
                          _actionButton(
                            icon: Icons.reply_rounded, 
                            iconColor: Colors.grey[600]!, 
                            label: 'Répondre', 
                            onTap: () => _startReply(comment.userName, comment.id)
                          ),
                        ]
                      )
                    ),

                    if (hasReplies) ...[
                      Divider(height: 1, thickness: 0.8, color: Colors.grey[100]),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4), 
                        child: Column(
                          children: comment.replies.map((r) => _buildCommentTile(r, currentUserId, isRoot: false)).toList()
                        )
                      ),
                    ],
                  ]
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, required Color iconColor, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap, 
      borderRadius: BorderRadius.circular(20), 
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), 
        child: Row(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Icon(icon, size: 16, color: iconColor), 
            if (label.isNotEmpty)...[const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]))]
          ]
        )
      )
    );
  }

  // ─── BARRE DE SAISIE ───
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, 
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -4))]
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            if (_replyingTo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8), 
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                decoration: BoxDecoration(color: const Color(0xFFEAF1FF), borderRadius: BorderRadius.circular(20)), 
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 14, color: Color(0xFF123B7A)), 
                    const SizedBox(width: 6), 
                    Text('En réponse à $_replyingToName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF123B7A))), 
                    const Spacer(), 
                    InkWell(onTap: _clearReply, child: const Icon(Icons.close, size: 16, color: Color(0xFF123B7A)))
                  ]
                )
              ),
              
            if (_imageBytes != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_imageBytes!, width: 50, height: 50, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => setState(() => _imageBytes = null),
                    )
                  ],
                ),
              ),

            if (_isRecording)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enregistrement... 00:${_recordDuration.toString().padLeft(2, '0')} / 00:30',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
                      ),
                    ),
                    GestureDetector(
                      onTap: _stopRecording,
                      child: const Icon(Icons.stop_circle_rounded, color: Colors.red, size: 30),
                    ),
                  ],
                ),
              )
            else if (_audioBytes != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack_rounded, color: Color(0xFF2D6CDF)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Note vocale prête', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF123B7A))),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _audioBytes = null),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                    ),
                  ],
                ),
              ),

            if (!_isRecording && _audioBytes == null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.grey),
                    onPressed: _pickImage,
                  ),
                  IconButton(
                    icon: Icon(_showStickers ? Icons.keyboard_rounded : Icons.emoji_emotions_rounded, color: _showStickers ? const Color(0xFF2D6CDF) : Colors.grey),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _showStickers = !_showStickers);
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller, 
                      focusNode: _focusNode, 
                      maxLines: 4,
                      minLines: 1,
                      onTap: () {
                        if (_showStickers) setState(() => _showStickers = false);
                      },
                      decoration: InputDecoration(
                        hintText: _replyingTo != null ? 'Votre réponse...' : 'Votre commentaire...', 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), 
                        filled: true, 
                        fillColor: Colors.grey[100], 
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                      )
                    )
                  ),
                  const SizedBox(width: 8),
                  
                  _controller.text.trim().isEmpty && _imageBytes == null
                    ? CircleAvatar(
                        radius: 20, 
                        backgroundColor: const Color(0xFFE3B23C), 
                        child: IconButton(
                          icon: const Icon(Icons.mic_rounded, color: Colors.white, size: 20), 
                          onPressed: _startRecording,
                        )
                      )
                    : CircleAvatar(
                        radius: 20, 
                        backgroundColor: const Color(0xFF2D6CDF),
                        child: IconButton(
                          icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white, size: 18), 
                          onPressed: _isSubmitting ? null : () => _submitComment()
                        )
                      ),
                ]
              ),

            if (_audioBytes != null)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : () => _submitComment(),
                  icon: _isSubmitting ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, size: 16),
                  label: const Text("Publier l'audio"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6CDF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                  ),
                ),
              )
          ]
        ),
      ),
    );
  }

  // ─── CLAVIER STICKERS ───
  Widget _buildStickerPicker() {
    return SizedBox(
      height: 250,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: Color(0xFF2D6CDF),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF2D6CDF),
              tabs: [
                Tab(text: 'Émojis'),
                Tab(text: 'Réactions'),
                Tab(text: 'Drapeaux'),
              ]
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildStickerGrid(_emojis),
                  _buildStickerGrid(_reactions),
                  _buildStickerGrid(_flags),
                ]
              )
            )
          ]
        )
      )
    );
  }

  Widget _buildStickerGrid(List<String> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return InkWell(
          onTap: () => _insertSticker(items[index]),
          child: Center(child: Text(items[index], style: const TextStyle(fontSize: 24))),
        );
      },
    );
  }
}

// ─── LECTEUR AUDIO COMPACT POUR LES COMMENTAIRES ───
class _CommentAudioPlayer extends StatefulWidget {
  final String audioUrl;
  const _CommentAudioPlayer({required this.audioUrl});

  @override
  State<_CommentAudioPlayer> createState() => _CommentAudioPlayerState();
}

class _CommentAudioPlayerState extends State<_CommentAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final List<double> _wavePattern = [0.4, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 1.0, 0.5, 0.3, 0.7, 0.8, 0.4, 0.6];

  @override
  void initState() {
    super.initState();
    _audioPlayer.setSourceUrl(widget.audioUrl);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1F44), // Navy Deep
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_isPlaying) _audioPlayer.pause();
              else _audioPlayer.play(UrlSource(widget.audioUrl));
            },
            child: Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(color: Color(0xFFE3B23C), shape: BoxShape.circle),
              child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: const Color(0xFF0A1F44), size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const barWidth = 3.0;
                const spacing = 2.0;
                final barCount = (constraints.maxWidth / (barWidth + spacing)).floor();

                return GestureDetector(
                  onTapDown: (details) {
                    if (_duration.inMilliseconds > 0) {
                      final tapProgress = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                      _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * tapProgress).round()));
                    }
                  },
                  child: Container(
                    height: 24, color: Colors.transparent,
                    child: Row(
                      children: List.generate(barCount, (index) {
                        final baseHeight = _wavePattern[index % _wavePattern.length];
                        final isPlayed = (index / barCount) <= progress;
                        return Container(
                          width: barWidth, height: 24 * baseHeight, margin: const EdgeInsets.only(right: spacing),
                          decoration: BoxDecoration(color: isPlayed ? const Color(0xFFE3B23C) : Colors.white30, borderRadius: BorderRadius.circular(2)),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Text(_formatDuration(_duration.inSeconds > 0 && !_isPlaying && _position.inSeconds == 0 ? _duration : _position), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}
