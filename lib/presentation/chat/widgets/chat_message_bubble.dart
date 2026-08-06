// lib/presentation/chat/widgets/chat_message_bubble.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/presentation/chat/encryption_service.dart';
import 'package:thix_id/presentation/chat/widgets/audio_player.dart';
import 'package:thix_id/presentation/chat/widgets/chat_code_snippet.dart';
import 'package:thix_id/presentation/chat/widgets/chat_ephemeral_timer.dart';
import 'package:thix_id/presentation/chat/widgets/sentiment_indicator.dart';

// ─────────────────────────────────────────────────────────────
// CHARTE
// ─────────────────────────────────────────────────────────────
class _C {
  static const ownBubble = Color(0xFFDCF8C6);
  static const otherBubble = Colors.white;
  static const noteBubble = Color(0xFFFFF7ED);
  static const searchBg = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF1D4ED8);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF59E0B);
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
  bool _showReact = false;
  bool _isDecrypted = false;
  String? _decrypted;

  static const _quickReactions = ['❤️', '😂', '🔥', '👍', '😮', '😢'];

  ChatMessage get m => widget.message;

  bool get _isNote => widget.isInternalNote || m.isInternalNote;

  bool get _shouldHideNote {
    if (!_isNote) return false;
    return !widget.isAgentView;
  }

  Color get _bubbleColor {
    if (_isNote) return _C.noteBubble;
    return widget.isOwn ? _C.ownBubble : _C.otherBubble;
  }

  Color get _textColor => _C.textMain;

  @override
  Widget build(BuildContext context) {
    if (_shouldHideNote) return const SizedBox.shrink();

    if (m.isDeleted) {
      return _DeletedBubble(isOwn: widget.isOwn);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment:
            widget.isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!widget.isOwn && m.senderName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(
                m.senderName,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _C.primary,
                ),
              ),
            ),

          if (_isNote && widget.isAgentView)
            const Padding(
              padding: EdgeInsets.only(bottom: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 12, color: _C.orange),
                  SizedBox(width: 4),
                  Text(
                    'Note interne',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _C.orange,
                    ),
                  ),
                ],
              ),
            ),

          GestureDetector(
            onLongPress: _openActions,
            onDoubleTap: () {
              if (widget.onReaction != null) {
                widget.onReaction!('❤️');
              }
            },
            child: Align(
              alignment:
                  widget.isOwn ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      margin: EdgeInsets.only(
                        left: widget.isOwn ? 40 : 4,
                        right: widget.isOwn ? 4 : 40,
                      ),
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                      decoration: BoxDecoration(
                        color: _bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(widget.isOwn ? 14 : 4),
                          bottomRight: Radius.circular(widget.isOwn ? 4 : 14),
                        ),
                        border: _isNote
                            ? Border.all(color: _C.orange.withValues(alpha: 0.35))
                            : Border.all(color: _C.border.withValues(alpha: 0.6)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.replyToMessage != null)
                            _ReplyQuote(
                              message: widget.replyToMessage!,
                              isOwn: widget.isOwn,
                            ),

                          _buildBody(),

                          const SizedBox(height: 4),

                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (m.isEphemeral || widget.isEphemeralActive) ...[
                                const ChatEphemeralTimer(),
                                const SizedBox(width: 6),
                              ],
                              if (m.sentiment != null && widget.isAgentView) ...[
                                SentimentIndicator(result: m.sentiment!),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                DateFormat('HH:mm').format(m.createdAt.toLocal()),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _C.textMuted,
                                ),
                              ),
                              if (widget.isOwn) ...[
                                const SizedBox(width: 4),
                                MessageStatusTicks(
                                  isDelivered: m.isDelivered,
                                  isRead: m.isRead,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (m.reactions.isNotEmpty)
                      Positioned(
                        bottom: -10,
                        right: widget.isOwn ? 16 : null,
                        left: widget.isOwn ? null : 16,
                        child: _ReactionsChip(reactions: m.reactions),
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (_showReact)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _QuickReactions(
                onPick: (r) {
                  setState(() => _showReact = false);
                  widget.onReaction?.call(r);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (m.isCodeSnippet && (m.codeContent?.isNotEmpty ?? false)) {
      return ChatCodeSnippet(
        code: m.codeContent!,
        language: m.codeLanguage ?? 'text',
      );
    }

    if (m.mediaType == 'audio' && m.mediaUrl != null) {
      return AudioPlayerWidget(audioUrl: m.mediaUrl!);
    }

    if (m.mediaType == 'image' && m.mediaUrl != null) {
      return _ImageBody(url: m.mediaUrl!, messageId: m.id);
    }

    if (m.mediaUrl != null &&
        (m.mediaType == 'video' || m.mediaType == 'file')) {
      return _FileBody(
        type: m.mediaType ?? 'file',
        name: m.mediaName ?? m.content,
        isOwn: widget.isOwn,
      );
    }

    final raw = m.content;
    final looksEncrypted = raw.length > 16 && 
                           !raw.contains(' ') && 
                           RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(raw);

    if (looksEncrypted && !_isDecrypted) {
      return _EncryptedBody(onUnlock: _unlock);
    }

    final text = _isDecrypted ? (_decrypted ?? raw) : raw;
    if (text.trim().isEmpty && m.mediaUrl == null) {
      return const SizedBox.shrink();
    }

    return SelectableText(
      text,
      style: TextStyle(
        color: _textColor,
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Future<void> _unlock() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Message protégé'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mot de passe'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déverrouiller'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final plain =
          EncryptionService.decryptMessage(m.content, ctrl.text.trim());
      if (mounted) {
        setState(() {
          _isDecrypted = true;
          _decrypted = plain;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe incorrect'),
            backgroundColor: _C.red,
          ),
        );
      }
    }
  }

  void _openActions() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _C.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _quickReactions
                    .map(
                      (r) => InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          widget.onReaction?.call(r);
                        },
                        child: Text(r, style: const TextStyle(fontSize: 28)),
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: _C.primary),
              title: const Text('Répondre'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onReply?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: _C.textMuted),
              title: const Text('Copier'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: m.content));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copié'),
                    duration: Duration(milliseconds: 800),
                  ),
                );
              },
            ),
            if (widget.isOwn)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: _C.red),
                title: const Text('Supprimer', style: TextStyle(color: _C.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDelete?.call();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SOUS-WIDGETS
// ─────────────────────────────────────────────────────────────

class _DeletedBubble extends StatelessWidget {
  final bool isOwn;
  const _DeletedBubble({required this.isOwn});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white70,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 14, color: _C.textMuted),
            SizedBox(width: 6),
            Text(
              'Message supprimé',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: _C.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  const _ReplyQuote({required this.message, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: _C.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.senderName.isNotEmpty ? message.senderName : 'Message',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _C.primary,
            ),
          ),
          Text(
            message.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _C.textMuted),
          ),
        ],
      ),
    );
  }
}

class _EncryptedBody extends StatelessWidget {
  final VoidCallback onUnlock;
  const _EncryptedBody({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onUnlock,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.lock_rounded, size: 16, color: _C.primary),
          SizedBox(width: 8),
          Text(
            'Message protégé — appuyer pour ouvrir',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _C.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageBody extends StatelessWidget {
  final String url;
  final String messageId;
  const _ImageBody({required this.url, required this.messageId});

  @override
  Widget build(BuildContext context) {
    final tag = 'img_$messageId';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImagePage(imageUrl: url, tag: tag),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Hero(
          tag: tag,
          child: Image.network(
            url,
            width: 220,
            height: 180,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 220,
                height: 180,
                color: _C.searchBg,
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _C.primary,
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              width: 180,
              height: 120,
              color: _C.searchBg,
              child: const Icon(Icons.broken_image_outlined, color: _C.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileBody extends StatelessWidget {
  final String type;
  final String name;
  final bool isOwn;
  const _FileBody({
    required this.type,
    required this.name,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == 'video'
                ? Icons.videocam_rounded
                : Icons.insert_drive_file_rounded,
            size: 18,
            color: _C.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name.isNotEmpty ? name : type,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _C.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionsChip extends StatelessWidget {
  final List<MessageReaction> reactions;
  const _ReactionsChip({required this.reactions});

  @override
  Widget build(BuildContext context) {
    final map = <String, int>{};
    for (final r in reactions) {
      map[r.reaction] = (map[r.reaction] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: map.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  e.value > 1 ? '\( {e.key} \){e.value}' : e.key,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _QuickReactions extends StatelessWidget {
  final void Function(String) onPick;
  const _QuickReactions({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['❤️', '😂', '🔥', '👍', '😮', '😢']
            .map(
              (r) => InkWell(
                onTap: () => onPick(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(r, style: const TextStyle(fontSize: 22)),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class MessageStatusTicks extends StatelessWidget {
  final bool isDelivered;
  final bool isRead;

  const MessageStatusTicks({
    super.key,
    this.isDelivered = true,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    if (isRead) {
      return const Icon(Icons.done_all_rounded, size: 14, color: _C.primary);
    }
    if (isDelivered) {
      return const Icon(Icons.done_all_rounded, size: 14, color: _C.textMuted);
    }
    return const Icon(Icons.check_rounded, size: 14, color: _C.textMuted);
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;
  final String tag;
  const FullScreenImagePage({
    super.key,
    required this.imageUrl,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Hero(
            tag: tag,
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
