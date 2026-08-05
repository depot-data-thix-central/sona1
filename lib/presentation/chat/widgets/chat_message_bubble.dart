// lib/presentation/chat/widgets/chat_message_bubble.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/presentation/chat/widgets/audio_player.dart';
import 'package:thix_id/presentation/chat/encryption_service.dart';
import 'chat_code_snippet.dart';
import 'chat_ephemeral_timer.dart';
import 'package:thix_id/models/chat/sentiment.dart';
import 'package:thix_id/presentation/chat/widgets/sentiment_indicator.dart';
// Assurez-vous d'importer le widget s'il est dans un autre fichier, ou définissez-le ci-dessous :
// import 'message_status_ticks.dart'; 

class _C {
  static const bg = Colors.white;
  static const searchBg = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFFEFF6FF);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const red = Color(0xFFEF4444);
  static const gold = Color(0xFFE3B23C);
}

class ChatMessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isOwn;
  final VoidCallback? onReply;
  final void Function(String reaction)? onReaction;
  final VoidCallback? onDelete;
  final ChatMessage? replyToMessage;
  final bool isEphemeralActive;
  final bool isInternalNote;
  final bool isAgentView;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    this.onReply,
    this.onReaction,
    this.onDelete,
    this.replyToMessage,
    this.isEphemeralActive = false,
    this.isInternalNote = false,
    this.isAgentView = false,
  });

  @override
  ConsumerState<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends ConsumerState<ChatMessageBubble> {
  bool _hover = false;
  bool _showReact = false;
  bool _isDecrypted = false;
  String? _decrypted;

  final _quick = ['❤️','😂','🔥','👍','😮','😢'];

  static const List<String> flags = [
    '🇦🇫','🇦🇱','🇩🇿','🇦🇩','🇦🇴','🇦🇬','🇦🇷','🇦🇲','🇦🇺','🇦🇹',
    '🇦🇿','🇧🇸','🇧🇭','🇧🇩','🇧🇧','🇧🇾','🇧🇪','🇧🇿','🇧🇯','🇧🇹',
    '🇧🇴','🇧🇦','🇧🇼','🇧🇷','🇧🇳','🇧🇬','🇧🇫','🇧🇮','🇰🇭','🇨🇲',
    '🇨🇦','🇨🇻','🇨🇫','🇹🇩','🇨🇱','🇨🇳','🇨🇴','🇰🇲','🇨🇬','🇨🇩',
    '🇨🇷','🇭🇷','🇨🇺','🇨🇾','🇨🇿','🇩🇰','🇩🇯','🇩🇲','🇩🇴','🇪🇨',
    '🇪🇬','🇸🇻','🇬🇶','🇪🇷','🇪🇪','🇸🇿','🇪🇹','🇫🇯','🇫🇮','🇫🇷',
    '🇬🇦','🇬🇲','🇬🇪','🇩🇪','🇬🇭','🇬🇷','🇬🇩','🇬🇹','🇬🇳','🇬🇼',
    '🇬🇾','🇭🇹','🇭🇳','🇭🇺','🇮🇸','🇮🇳','🇮🇩','🇮🇷','🇮🇶','🇮🇪',
    '🇮🇱','🇮🇹','🇯🇲','🇯🇵','🇯🇴','🇰🇿','🇰🇪','🇰🇮','🇰🇵','🇰🇷',
    '🇰🇼','🇰🇬','🇱🇦','🇱🇻','🇱🇧','🇱🇸','🇱🇷','🇱🇾','🇱🇮','🇱🇹',
    '🇱🇺','🇲🇬','🇲🇼','🇲🇾','🇲🇻','🇲🇱','🇲🇹','🇲🇭','🇲🇷','🇲🇺',
    '🇲🇽','🇫🇲','🇲🇩','🇲🇨','🇲🇳','🇲🇪','🇲🇦','🇲🇿','🇲🇲','🇳🇦',
    '🇳🇷','🇳🇵','🇳🇱','🇳🇿','🇳🇮','🇳🇪','🇳🇬','🇲🇰','🇳🇴','🇴🇲',
    '🇵🇰','🇵🇼','🇵🇸','🇵🇦','🇵🇬','🇵🇾','🇵🇪','🇵🇭','🇵🇱','🇵🇹',
    '🇶🇦','🇷🇴','🇷🇺','🇷🇼','🇰🇳','🇱🇨','🇻🇨','🇼🇸','🇸🇲','🇸🇹',
    '🇸🇦','🇸🇳','🇷🇸','🇸🇨','🇸🇱','🇸🇬','🇸🇰','🇸🇮','🇸🇧','🇸🇴',
    '🇿🇦','🇸🇸','🇪🇸','🇱🇰','🇸🇩','🇸🇷','🇸🇪','🇨🇭','🇸🇾','🇹🇯',
    '🇹🇿','🇹🇭','🇹🇱','🇹🇬','🇹🇴','🇹🇹','🇹🇳','🇹🇷','🇹🇲','🇹🇻',
    '🇺🇬','🇺🇦','🇦🇪','🇬🇧','🇺🇸','🇺🇾','🇺🇿','🇻🇺','🇻🇦','🇻🇪',
    '🇻🇳','🇾🇪','🇿🇲','🇿🇼','🇹🇼','🇭🇰','🇲🇴','🇵🇷','🇬🇺','🇽🇰',
    '🇪🇺','🇺🇳',
  ];

  static const List<String> stickers = [
    '😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇',
    '🙂','😉','😌','😍','🥰','😘','🤩','🥳','🤗','🤔',
    '😏','😒','🙄','😬','😔','😪','😴','🤒','😷','🥵',
    '🥶','😵','🤯','🥴','🤠','❤️','🧡','💛','💚','💙',
    '💜','🖤','🤍','💔','💕','💞','💓','💗','💖','💝',
    '💘','💌','💋','💯','🔥','⭐','🌟','💫','✨','🎉',
    '🎊','🎈','🎁','🏆','👍','👎','👌','✌️','👈','👉',
    '👆','👇','✋','👋','🙏','💪','👀','🐶','🐱','🦊',
    '🐻','🐼','🐨','🦁','🐮','🐷','🐸','🐵','🐔','🐧',
    '🐦','🐤','🦆','🐺','🐴','🦄','🐝','🦋','🐌','🐢',
    '🐍','🐙','🐠','🐬','🐳','🐋','🦈','🍏','🍎','🍐',
    '🍊','🍋','🍌','🍉','🍇','🍓','🍒','🍑','🥭','🍍',
    '🥝','🍅','🥑','🥦','🥒','🌽','🥕','🍞','🧀','🍔',
    '🍟','🍕','🌮','🍝','🍣','🍱','🍙','🍚','🍦','🍰',
    '🎂','🍭','🍫','🍿','🍩','☕','🍵','🍺','⚽','🏀',
    '🏈','🎾','🏐','🎱','🏓','🥊','🛹','🎿','🎯','🎮',
    '🎲','🧩','🎨','🎤','🎧','🎵','🎶','🎹','🥁','🎸',
  ];

  bool get _isEncrypted {
    final c = widget.message.content;
    return c.startsWith('🔒') || (c.length > 50 && c.contains('+') && c.contains('/')) || EncryptionService.isEncrypted(c);
  }

  Future<void> _decrypt() async {
    final c = TextEditingController();
    final pass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.lock_rounded, color: _C.gold, size: 18), SizedBox(width: 8), Text('Message chiffré', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _C.textMain))]),
        content: TextField(
          controller: c,
          obscureText: true,
          style: const TextStyle(color: _C.textMain, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            hintText: '••••••••',
            filled: true,
            fillColor: _C.searchBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.border)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _C.primary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _C.textMuted))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _C.primary), onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Déchiffrer', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (pass != null && pass.isNotEmpty) {
      try {
        final d = EncryptionService.decryptMessage(widget.message.content, pass);
        setState(() { _decrypted = d; _isDecrypted = true; });
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe incorrect'), backgroundColor: _C.red));
      }
    }
  }

  String get _display {
    if (_isEncrypted && !_isDecrypted) return '🔒 Message chiffré (tap pour déchiffrer)';
    if (_isDecrypted) return _decrypted ?? widget.message.content;
    return widget.message.content;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isInternalNote && !widget.isAgentView) return const SizedBox.shrink();
    final isOwn = widget.isOwn;
    final msg = widget.message;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isOwn && !widget.isInternalNote)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 4),
              child: Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _C.searchBg,
                  backgroundImage: msg.senderAvatar != null ? NetworkImage(msg.senderAvatar!) : null,
                  child: msg.senderAvatar == null ? Text(msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _C.textMuted)) : null,
                ),
                const SizedBox(width: 8),
                Text(msg.senderName, style: const TextStyle(fontSize: 11, color: _C.textMuted, fontWeight: FontWeight.w600)),
              ]),
            ),
          if (widget.replyToMessage != null && !widget.isInternalNote)
            Padding(
              padding: EdgeInsets.only(bottom: 4, left: isOwn ? 60 : 20, right: isOwn ? 20 : 60),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: isOwn ? _C.primaryLight : _C.searchBg, borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: isOwn ? _C.primary : _C.border, width: 3))),
                child: Text(widget.replyToMessage!.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _C.textMuted)),
              ),
            ),
          Row(
            mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () { if (_isEncrypted && !_isDecrypted) _decrypt(); },
                onLongPress: () => setState(() => _showReact = !_showReact),
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hover = true),
                  onExit: (_) => setState(() => _hover = false),
                  child: Container(
                    padding: msg.mediaType == 'image' ? const EdgeInsets.all(3) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: widget.isInternalNote ? const Color(0xFFFFF7ED) : (isOwn ? _C.primary : _C.bg),
                      borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(isOwn ? 18 : 4), bottomRight: Radius.circular(isOwn ? 4 : 18)),
                      border: Border.all(color: widget.isInternalNote ? const Color(0xFFFDBA74) : (_isEncrypted && !_isDecrypted ? _C.gold : (isOwn ? _C.primary : _C.border)), width: _isEncrypted && !_isDecrypted ? 1.5 : 1),
                      boxShadow: [if (!isOwn) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (_isEncrypted || widget.isEphemeralActive || widget.isInternalNote) _badges(),
                        if (msg.sentiment != null) Padding(padding: const EdgeInsets.only(bottom: 5), child: SentimentIndicator(result: msg.sentiment!, size: 12, showLabel: false)),
                        if (msg.isCodeSnippet && msg.codeContent != null) ChatCodeSnippet(code: msg.codeContent!, language: msg.codeLanguage ?? 'text')
                        else if (msg.mediaType == 'audio' && msg.mediaUrl != null) AudioPlayerWidget(audioUrl: msg.mediaUrl!, totalDuration: msg.ephemeralDuration, primaryColor: isOwn ? Colors.white : _C.primary, accentColor: isOwn ? Colors.white70 : _C.textMuted)
                        else if (msg.mediaUrl != null) _media()
                        else if (_display.isNotEmpty) Text(_display, style: TextStyle(color: widget.isInternalNote ? Colors.black87 : (isOwn ? Colors.white : _C.textMain), fontSize: 14, height: 1.35, fontWeight: isOwn ? FontWeight.w500 : FontWeight.w400)),
                        if (msg.reactions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 4, runSpacing: 4,
                              children: msg.reactions.map((r) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: _C.searchBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
                                child: Text(r.reaction, style: const TextStyle(fontSize: 12)),
                              )).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 4, left: isOwn ? 0 : 20, right: isOwn ? 20 : 0),
            child: Row(
              mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (widget.isEphemeralActive) ChatEphemeralTimer(duration: widget.message.ephemeralDuration ?? 60, onExpired: () => widget.onDelete?.call()),
                if (widget.isEphemeralActive) const SizedBox(width: 6),
                Text(DateFormat('HH:mm').format(msg.createdAt), style: const TextStyle(fontSize: 10, color: _C.textMuted, fontWeight: FontWeight.w500)),
                if (isOwn) ...[
                  const SizedBox(width: 4),
                  MessageStatusTicks(isRead: widget.message.isRead),
                ],
              ],
            ),
          ),
          if (_hover || _showReact)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 20, right: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(24), border: Border.all(color: _C.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))]),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                   ..._quick.map((e) => InkWell(onTap: () { widget.onReaction?.call(e); setState(() => _showReact = false); }, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(e, style: const TextStyle(fontSize: 18))))),
                    Container(width: 1, height: 18, color: _C.border, margin: const EdgeInsets.symmetric(horizontal: 6)),
                    _iconBtn(Icons.emoji_emotions_outlined, 'Stickers', _showStickerPicker),
                    _iconBtn(Icons.flag_outlined, 'Drapeaux', _showFlagPicker),
                    _iconBtn(Icons.reply_rounded, 'Répondre', () => widget.onReply?.call()),
                    if (isOwn) _iconBtn(Icons.delete_outline_rounded, 'Supprimer', () => widget.onDelete?.call()),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Icon(icon, size: 18, color: _C.textMuted)),
      ),
    );
  }

  Widget _badges() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(spacing: 4, children: [
      if (widget.isInternalNote) _badge(Icons.note_alt_outlined, 'Interne', const Color(0xFFEA580C)),
      if (_isEncrypted) _badge(_isDecrypted ? Icons.lock_open_rounded : Icons.lock_rounded, _isDecrypted ? 'Déchiffré' : 'Chiffré', _C.gold),
      if (widget.isEphemeralActive) _badge(Icons.timer_outlined, 'Éphémère', const Color(0xFFD97706)),
    ]),
  );

  Widget _badge(IconData ic, String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: c.withOpacity(0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(ic, size: 11, color: c), const SizedBox(width: 3), Text(t, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c))]),
  );

  void _showStickerPicker() {
    int visible = 60;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return Container(
          decoration: const BoxDecoration(color: _C.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: DraggableScrollableSheet(
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (_, sc) {
              sc.addListener(() {
                if (sc.position.pixels > sc.position.maxScrollExtent - 200 && visible < stickers.length) {
                  setSt(() => visible = (visible + 60).clamp(0, stickers.length));
                }
              });
              return Column(children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 5, decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(3))),
                const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 8), child: Row(children: [Icon(Icons.emoji_emotions_rounded, color: _C.textMain, size: 20), SizedBox(width: 8), Text('Stickers • 280', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _C.textMain))])),
                Expanded(
                  child: GridView.builder(
                    controller: sc,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, crossAxisSpacing: 6, mainAxisSpacing: 6),
                    itemCount: visible,
                    itemBuilder: (_, i) => InkWell(
                      onTap: () { Navigator.pop(ctx); widget.onReaction?.call(stickers[i]); },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(decoration: BoxDecoration(color: _C.searchBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)), child: Center(child: Text(stickers[i], style: const TextStyle(fontSize: 22)))),
                    ),
                  ),
                ),
              ]);
            },
          ),
        );
      }),
    );
  }

  void _showFlagPicker() {
    int visible = 60;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return Container(
          decoration: const BoxDecoration(color: _C.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: DraggableScrollableSheet(
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (_, sc) {
              sc.addListener(() {
                if (sc.position.pixels > sc.position.maxScrollExtent - 200 && visible < flags.length) {
                  setSt(() => visible = (visible + 60).clamp(0, flags.length));
                }
              });
              return Column(children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 5, decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(3))),
                const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 8), child: Row(children: [Icon(Icons.flag_rounded, color: _C.textMain, size: 20), SizedBox(width: 8), Text('Drapeaux • 240 pays', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _C.textMain))])),
                Expanded(
                  child: GridView.builder(
                    controller: sc,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: visible,
                    itemBuilder: (_, i) => InkWell(
                      onTap: () { Navigator.pop(ctx); widget.onReaction?.call(flags[i]); },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(decoration: BoxDecoration(color: _C.searchBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)), child: Center(child: Text(flags[i], style: const TextStyle(fontSize: 26)))),
                    ),
                  ),
                ),
              ]);
            },
          ),
        );
      }),
    );
  }

  Widget _media() {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) return Text(widget.message.content, style: TextStyle(color: widget.isOwn ? Colors.white : _C.textMain, fontSize: 13));
    final type = widget.message.mediaType ?? 'file';
    if (type == 'image') {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImagePage(imageUrl: url, tag: widget.message.id))),
        child: Hero(
          tag: widget.message.id,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 250,
                maxWidth: 250,
              ),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 150, 
                    width: 200, 
                    color: _C.searchBg, 
                    child: const Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2))
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 120, 
                  width: 180, 
                  color: _C.searchBg, 
                  child: const Icon(Icons.broken_image_outlined, color: _C.textMuted, size: 30)
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: widget.isOwn ? Colors.white.withOpacity(0.15) : _C.searchBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: widget.isOwn ? Colors.white24 : _C.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(type == 'video' ? Icons.videocam_rounded : Icons.insert_drive_file_rounded, size: 16, color: widget.isOwn ? Colors.white : _C.primary),
        const SizedBox(width: 6),
        Flexible(child: Text(widget.message.content.isNotEmpty ? widget.message.content : type, style: TextStyle(color: widget.isOwn ? Colors.white : _C.textMain, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;
  final String tag;
  const FullScreenImagePage({super.key, required this.imageUrl, required this.tag});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)), 
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5, 
          maxScale: 4, 
          child: Hero(
            tag: tag, 
            child: Image.network(imageUrl, fit: BoxFit.contain)
          )
        )
      )
    );
  }
}

// Assurez-vous que ce widget existe (déclarez-le ici ou importez-le depuis son fichier d'origine s'il manque)
class MessageStatusTicks extends StatelessWidget {
  final bool isRead;
  const MessageStatusTicks({super.key, required this.isRead});

  @override
  Widget build(BuildContext context) {
    return Icon(
      isRead ? Icons.done_all_rounded : Icons.check_rounded,
      size: 12,
      color: isRead ? _C.primary : _C.textMuted,
    );
  }
}
