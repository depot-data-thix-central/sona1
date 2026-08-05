// lib/presentation/chat/chat_screen.dart
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/services/chat/audio_service.dart';

import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/models/chat/user_status.dart';
import 'package:thix_id/models/chat/group_info.dart';
import 'package:thix_id/models/chat/call_status.dart';

import 'package:thix_id/presentation/chat/widgets/chat_message_bubble.dart';
import 'package:thix_id/presentation/chat/widgets/chat_input_bar.dart';
import 'package:thix_id/presentation/chat/widgets/audio_recorder.dart';
import 'package:thix_id/presentation/chat/encryption_service.dart';
import 'package:thix_id/presentation/chat/call/call_page.dart';
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';

import 'package:thix_id/presentation/chat/providers/chat_providers.dart';
import 'package:thix_id/presentation/chat/providers/chat_list_provider.dart';

// ─────────────────────────────────────────────────────────────
// CHARTE THIX + STYLE WHATSAPP ENTERPRISE
// ─────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFE5DDD5); // fond type WhatsApp
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF1D4ED8);
  static const primaryDeep = Color(0xFF123B7A);
  static const primarySoft = Color(0xFFEFF6FF);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const red = Color(0xFFEF4444);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF59E0B);
  static const gold = Color(0xFFE3B23C);
  static const bubbleOwn = Color(0xFFDCF8C6); // vert WhatsApp soft
  static const bubbleOther = Colors.white;
}

// Messages provider (family)
final chatMessagesProvider = StateNotifierProvider.family<
    ChatMsgNotifier, List<ChatMessage>, String>((ref, conversationId) {
  return ChatMsgNotifier(ref.read(chatServiceProvider), conversationId);
});

class ChatMsgNotifier extends StateNotifier<List<ChatMessage>> {
  final ChatService svc;
  final String convId;
  int page = 0;
  static const pageSize = 30;
  bool hasMore = true;
  bool loadingMore = false;

  ChatMsgNotifier(this.svc, this.convId) : super([]) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    page = 0;
    final msgs = await svc.getMessages(convId, limit: pageSize, offset: 0);
    hasMore = msgs.length >= pageSize;
    msgs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = msgs;
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    page++;
    final msgs = await svc.getMessages(
      convId,
      limit: pageSize,
      offset: page * pageSize,
    );
    hasMore = msgs.length >= pageSize;

    var current = [...state, ...msgs];
    final seen = <String>{};
    current = current.where((m) => seen.add(m.id)).toList();
    current.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = current;
    loadingMore = false;
  }

  void upsertRealtime(List<ChatMessage> updated) {
    var current = [...state];
    var changed = false;

    for (final msg in updated) {
      final idx = current.indexWhere((m) => m.id == msg.id);
      if (idx != -1) {
        current[idx] = msg;
        changed = true;
      } else if (!msg.isDeleted) {
        current.insert(0, msg);
        changed = true;
      }
    }

    if (changed) {
      current.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = current;
    }
  }

  void addLocal(ChatMessage msg) {
    if (!state.any((m) => m.id == msg.id)) {
      final current = [msg, ...state]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = current;
    }
  }

  void removeLocal(String id) {
    state = state.where((m) => m.id != id).toList();
  }
}

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final ChatConversation conversation;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.conversation,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();

  UserStatus? _otherParticipant;
  List<GroupMember> _groupMembers = [];
  String _replyToId = '';

  bool _isEphemeral = false;
  int? _ephemeralDuration;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  bool _isSending = false;

  List<PlatformFile> _selectedFiles = [];

  Timer? _typingTimer;
  RealtimeChannel? _typingChannel;
  bool _isAgent = false;
  bool _isInternalNoteMode = false;
  StreamSubscription<List<ChatMessage>>? _messageSub;
  StreamSubscription<List<UserStatus>>? _presenceSub;

  // ── Stickers organisés ──
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
  '🏁','🚩','🎌','🏴','🏳️','🏳️‍🌈','🏳️‍⚧️','🏴‍☠️',
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
    WidgetsBinding.instance.addObserver(this);
    ref.read(chatServiceProvider).startPresenceHeartbeat();
    _loadUserRole();
    _getParticipantInfo();
    _markAsRead();
    _subscribeToPresence();
    _subscribeToRealtime();
    _subscribeToTyping();
    _loadGroupMembers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final svc = ref.read(chatServiceProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        svc.startPresenceHeartbeat();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        svc.stopPresenceHeartbeat();
        break;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatMessagesProvider(widget.conversationId).notifier).loadMore();
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final uid = ref.read(chatServiceProvider).currentUserId;
      if (uid.isEmpty) return;
      final row = await Supabase.instance.client
          .from('profiles')
          .select('role, account_type')
          .eq('id', uid)
          .maybeSingle();
      if (row != null && mounted) {
        final role = (row['role'] ?? row['account_type'] ?? '').toString();
        setState(() {
          _isAgent = role == 'agent' ||
              role == 'admin' ||
              role == 'support' ||
              role == 'enterprise';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadGroupMembers() async {
    if (!widget.conversation.isGroup) return;
    try {
      final members =
          await ref.read(chatServiceProvider).getGroupMembers(widget.conversationId);
      if (mounted) setState(() => _groupMembers = members);
    } catch (e) {
      debugPrint('Error loading group members: $e');
    }
  }

  @override
  void dispose() {
    ref.read(chatServiceProvider).stopPresenceHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    _typingTimer?.cancel();
    _messageSub?.cancel();
    _presenceSub?.cancel();
    _typingChannel?.unsubscribe();
    ref.read(audioServiceProvider).dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    await ref.read(chatServiceProvider).markAsRead(widget.conversationId);
    try {
      ref.read(chatListProvider.notifier).refresh();
    } catch (_) {}
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  void _subscribeToPresence() {
    if (widget.conversation.isGroup) return;
    final svc = ref.read(chatServiceProvider);
    final otherId = widget.conversation.participantIds.firstWhere(
      (id) => id != svc.currentUserId,
      orElse: () => '',
    );
    if (otherId.isEmpty) return;

    _presenceSub = svc.subscribeToPresence([otherId]).listen((list) {
      if (mounted && list.isNotEmpty) {
        setState(() => _otherParticipant = list.first);
      }
    });
  }

  Future<void> _getParticipantInfo() async {
    if (widget.conversation.isGroup) return;
    final svc = ref.read(chatServiceProvider);
    final otherId = widget.conversation.participantIds.firstWhere(
      (id) => id != svc.currentUserId,
      orElse: () => '',
    );
    if (otherId.isEmpty) return;
    final p = await svc.getUserPresence(otherId);
    if (mounted) setState(() => _otherParticipant = p);
  }

  void _subscribeToRealtime() {
    _messageSub = ref
        .read(chatServiceProvider)
        .subscribeToMessages(widget.conversationId)
        .listen((updated) {
      ref
          .read(chatMessagesProvider(widget.conversationId).notifier)
          .upsertRealtime(updated);
      _markAsRead();
    });
  }

  void _subscribeToTyping() {
    final cur = ref.read(chatServiceProvider).currentUserId;
    if (cur.isEmpty) return;

    _typingChannel = Supabase.instance.client
        .channel('typing:${widget.conversationId}')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final sid = payload['senderId'] as String?;
            final typing = payload['isTyping'] as bool? ?? false;
            if (sid != null && sid != cur && mounted) {
              setState(() => _otherUserTyping = typing);
            }
          },
        )
        .subscribe();
  }

  void _sendTypingStatus(bool t) {
    final cur = ref.read(chatServiceProvider).currentUserId;
    if (cur.isEmpty || _typingChannel == null) return;
    _typingChannel!.sendBroadcastMessage(
      event: 'typing',
      payload: {'senderId': cur, 'isTyping': t},
    );
  }

  void _onTypingChanged(String t) {
    if (t.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _sendTypingStatus(true);
    } else if (t.isEmpty && _isTyping) {
      _isTyping = false;
      _sendTypingStatus(false);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _sendTypingStatus(false);
      }
    });
  }

  void _startCall(CallType type) {
    final svc = ref.read(chatServiceProvider);
    final otherId = widget.conversation.participantIds.firstWhere(
      (id) => id != svc.currentUserId,
      orElse: () => '',
    );
    ref.read(callProvider.notifier).start(
          channel: widget.conversationId,
          calleeId: otherId,
          callType: type,
        );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallPage(
          channel: widget.conversationId,
          name: widget.conversation.displayName,
          type: type,
          isCaller: true,
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty && _selectedFiles.isEmpty) return;
    if (_isSending) return;

    final svc = ref.read(chatServiceProvider);

    if (!widget.conversation.isGroup && !_isInternalNoteMode) {
      final cur = svc.currentUserId;
      if (cur.isNotEmpty) {
        final otherId = widget.conversation.participantIds.firstWhere(
          (id) => id != cur,
          orElse: () => '',
        );
        if (otherId.isNotEmpty) {
          final ok =
              await ref.read(connectionServiceProvider).checkConnection(cur, otherId);
          if (!ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vous devez être connecté pour interagir'),
                backgroundColor: _C.orange,
              ),
            );
            return;
          }
        }
      }
    }

    _isTyping = false;
    _sendTypingStatus(false);
    setState(() => _isSending = true);

    try {
      if (_selectedFiles.isNotEmpty) {
        final filesToSend = List<PlatformFile>.from(_selectedFiles);
        setState(() => _selectedFiles.clear());

        await Future.wait(filesToSend.map((f) async {
          final bytes =
              f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
          if (bytes == null) return;

          final ext = f.extension ?? 'jpg';
          final url = await svc.uploadFileWithUniqueName(
            'chat-media',
            'messages/${widget.conversationId}',
            Uint8List.fromList(bytes),
            ext,
          );

          if (url != null) {
            final msg = await svc.sendMessage(
              conversationId: widget.conversationId,
              content: f.name,
              mediaUrl: url,
              mediaType: _getMediaType(ext),
              mediaName: f.name,
              mediaSize: f.size,
              isEphemeral: _isEphemeral,
              ephemeralDuration: _ephemeralDuration,
              replyToId: _replyToId.isEmpty ? null : _replyToId,
            );
            ref
                .read(chatMessagesProvider(widget.conversationId).notifier)
                .addLocal(msg);
          }
        }));
      }

      if (text.isNotEmpty && !text.startsWith('📎')) {
        final msg = await svc.sendMessage(
          conversationId: widget.conversationId,
          content: text,
          replyToId: _replyToId.isEmpty ? null : _replyToId,
          isEphemeral: _isEphemeral,
          ephemeralDuration: _isEphemeral ? _ephemeralDuration : null,
        );
        ref
            .read(chatMessagesProvider(widget.conversationId).notifier)
            .addLocal(msg);
      }

      if (mounted) {
        setState(() {
          _inputController.clear();
          _replyToId = '';
          _isSending = false;
          if (_isInternalNoteMode) _isInternalNoteMode = false;
        });
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _C.red),
        );
      }
    }
  }

  void _showStickerPicker() {
  void _showStickerPicker() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return DefaultTabController(
        length: 3,
        child: DraggableScrollableSheet(
          initialChildSize: 0.52,
          maxChildSize: 0.9,
          minChildSize: 0.35,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _C.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                const TabBar(
                  labelColor: _C.primary,
                  unselectedLabelColor: _C.textMuted,
                  indicatorColor: _C.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  tabs: [
                    Tab(text: 'Emojis'),
                    Tab(text: 'Réactions'),
                    Tab(text: 'Drapeaux'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _stickerGrid(_emojis, scrollCtrl, ctx),
                      _stickerGrid(_reactions, scrollCtrl, ctx),
                      _stickerGrid(_flags, scrollCtrl, ctx),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

Widget _stickerGrid(
  List<String> items,
  ScrollController scrollCtrl,
  BuildContext sheetCtx,
) {
  return GridView.builder(
    controller: scrollCtrl,
    padding: const EdgeInsets.all(12),
    // 👇 LA CORRECTION EST ICI (tout sur une seule ligne) 👇
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 8,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.pop(sheetCtx);
          _inputController.text += items[i];
          _inputController.selection = TextSelection.fromPosition(
            TextPosition(offset: _inputController.text.length),
          );
        },
        child: Center(
          child: Text(items[i], style: const TextStyle(fontSize: 26)),
        ),
      );
    },
  );
}


  void _showEphemeralTimerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _C.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Message éphémère',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...[
              ('Désactivé', null),
              ('10 secondes', 10),
              ('1 minute', 60),
              ('1 heure', 3600),
              ('24 heures', 86400),
            ].map((e) {
              final selected = _ephemeralDuration == e.$2;
              return ListTile(
                title: Text(e.$1),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: _C.primary)
                    : null,
                onTap: () {
                  setState(() {
                    _ephemeralDuration = e.$2;
                    _isEphemeral = e.$2 != null;
                  });
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showPasswordProtectDialog() {
    final msgCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Message sécurisé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: msgCtrl,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.primary),
            onPressed: () async {
              if (msgCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
              final enc =
                  EncryptionService.encryptMessage(msgCtrl.text, passCtrl.text);
              Navigator.pop(ctx);
              try {
                final msg = await ref.read(chatServiceProvider).sendMessage(
                      conversationId: widget.conversationId,
                      content: enc,
                      replyToId: _replyToId.isEmpty ? null : _replyToId,
                      isEphemeral: _isEphemeral,
                      ephemeralDuration: _ephemeralDuration,
                    );
                ref
                    .read(chatMessagesProvider(widget.conversationId).notifier)
                    .addLocal(msg);
                if (mounted) setState(() => _replyToId = '');
                _scrollToBottom();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: _C.red),
                  );
                }
              }
            },
            child: const Text('Envoyer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startAudioRecording() async {
    final st = await Permission.microphone.request();
    if (st.isGranted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.all(20),
          child: AudioRecorderWidget(
            audioService: ref.read(audioServiceProvider),
            onRecordingComplete: (p, d) {
              Navigator.pop(ctx);
              _sendAudio(p, d);
            },
            onRecordingCanceled: () => Navigator.pop(ctx),
            maxDuration: 120,
          ),
        ),
      );
    } else if (st.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _sendAudio(String path, int dur) async {
    try {
      final bytes = await File(path).readAsBytes();
      final msg = await ref.read(chatServiceProvider).sendAudioMessage(
            conversationId: widget.conversationId,
            audioData: Uint8List.fromList(bytes),
            duration: dur,
            isEphemeral: _isEphemeral,
            ephemeralDuration: _ephemeralDuration,
            replyToId: _replyToId.isEmpty ? null : _replyToId,
          );
      ref
          .read(chatMessagesProvider(widget.conversationId).notifier)
          .addLocal(msg);
      if (mounted) setState(() => _replyToId = '');
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur audio: $e'), backgroundColor: _C.red),
        );
      }
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _C.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.attach_file_rounded, color: _C.primary),
                  SizedBox(width: 10),
                  Text(
                    'Joindre un fichier',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
            ),
            _attachTile(Icons.image_rounded, _C.gold, 'Photo(s)', FileType.image, ctx),
            _attachTile(Icons.videocam_rounded, _C.primary, 'Vidéo(s)', FileType.video, ctx),
            _attachTile(
              Icons.insert_drive_file_rounded,
              _C.textMain,
              'Document(s)',
              FileType.any,
              ctx,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _attachTile(
    IconData icon,
    Color color,
    String title,
    FileType type,
    BuildContext ctx,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      onTap: () {
        Navigator.pop(ctx);
        _pickFile(type: type);
      },
    );
  }

  Future<void> _pickFile({FileType type = FileType.any}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: type,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
          if (_inputController.text.trim().isEmpty) {
            _inputController.text = '📎 ${_selectedFiles.length} fichier(s)';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _C.red),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      if (_selectedFiles.isEmpty && _inputController.text.startsWith('📎')) {
        _inputController.clear();
      } else if (_selectedFiles.isNotEmpty &&
          _inputController.text.startsWith('📎')) {
        _inputController.text = '📎 ${_selectedFiles.length} fichier(s)';
      }
    });
  }

  String _getMediaType(String ext) {
    const img = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
    const vid = {'mp4', 'mov', 'avi', 'mkv'};
    const aud = {'mp3', 'wav', 'm4a'};
    final e = ext.toLowerCase();
    if (img.contains(e)) return 'image';
    if (vid.contains(e)) return 'video';
    if (aud.contains(e)) return 'audio';
    return 'file';
  }

  void _escalateConversation() {
    context.pushNamed(
      'chatEscalate',
      pathParameters: {'conversationId': widget.conversationId},
      queryParameters: {
        'agentId': ref.read(chatServiceProvider).currentUserId,
        'agentName': 'Agent',
      },
    );
  }

  void _viewEscalationHistory() {
    context.pushNamed(
      'chatEscalationHistory',
      pathParameters: {'conversationId': widget.conversationId},
    );
  }

  void _toggleInternalNoteMode() {
    setState(() => _isInternalNoteMode = !_isInternalNoteMode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isInternalNoteMode ? 'Mode note interne ON' : 'Mode note interne OFF',
        ),
        backgroundColor: _isInternalNoteMode ? _C.orange : _C.textMuted,
      ),
    );
  }

    String _getPresenceText(UserStatus status) {
    final lastSeen = status.lastSeenAt;
    final diff = DateTime.now().difference(lastSeen);
    if (status.status == 'online' && diff.inMinutes <= 2) return 'En ligne';
    return 'Vu ${_formatLastSeen(lastSeen)}';
  }

  bool get _isOnline {
    if (_otherParticipant == null) return false;
    final diff = DateTime.now().difference(_otherParticipant!.lastSeenAt);
    return _otherParticipant!.status == 'online' && diff.inMinutes <= 2;
  }



  // ─────────────────────── UI ───────────────────────

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final msgNotifier =
        ref.watch(chatMessagesProvider(widget.conversationId).notifier);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Fond type WhatsApp (motif discret)
          Positioned.fill(
            child: CustomPaint(
              painter: _WhatsAppPatternPainter(),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount:
                          messages.length + (msgNotifier.loadingMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
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
                        }

                        final msg = messages[i];
                        final isOwn = msg.senderId ==
                            ref.read(chatServiceProvider).currentUserId;

                        return ChatMessageBubble(
                          message: msg,
                          isOwn: isOwn,
                          onReply: () => setState(() => _replyToId = msg.id),
                          onDelete: () async {
                            ref
                                .read(chatMessagesProvider(widget.conversationId)
                                    .notifier)
                                .removeLocal(msg.id);
                            if (isOwn) {
                              try {
                                await ref
                                    .read(chatServiceProvider)
                                    .deleteMessage(msg.id);
                              } catch (_) {}
                            }
                          },
                          onReaction: (r) => ref
                              .read(chatServiceProvider)
                              .toggleReaction(msg.id, r),
                          replyToMessage: msg.replyToId != null
                              ? messages
                                  .where((m) => m.id == msg.replyToId)
                                  .firstOrNull
                              : null,
                          isEphemeralActive: msg.isEphemeral,
                          isInternalNote: msg.isInternalNote,
                          isAgentView: _isAgent,
                        );
                      },
                    ),
                    if (_otherUserTyping)
                      Positioned(
                        bottom: 10,
                        left: 16,
                        child: _TypingPill(),
                      ),
                  ],
                ),
              ),

              // Banner reply
              if (_replyToId.isNotEmpty) _ReplyBanner(
                text: messages
                    .firstWhere(
                      (m) => m.id == _replyToId,
                      orElse: () => messages.isNotEmpty
                          ? messages.first
                          : ChatMessage(
                              id: '',
                              conversationId: '',
                              senderId: '',
                              senderName: '',
                              content: '',
                              createdAt: DateTime.now(),
                            ),
                    )
                    .content,
                onClose: () => setState(() => _replyToId = ''),
              ),

              // Fichiers sélectionnés
              if (_selectedFiles.isNotEmpty) _FilesPreview(
                files: _selectedFiles,
                onRemove: _removeFile,
              ),

              // Input
              ChatInputBar(
                controller: _inputController,
                focusNode: _inputFocus,
                onSend: _sendMessage,
                isSending: _isSending,
                onAttach: _showAttachmentMenu,
                onAudio: _startAudioRecording,
                onSecureMessage: _showPasswordProtectDialog,
                onEphemeralToggle: _showEphemeralTimerDialog,
                isEphemeral: _isEphemeral,
                onTyping: _onTypingChanged,
                onInternalNoteToggle: _isAgent ? _toggleInternalNoteMode : null,
                onStickerTap: _showStickerPicker,
                isInternalNote: _isInternalNoteMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.8,
      shadowColor: Colors.black12,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain),
        onPressed: () {
          _markAsRead();
          context.pop();
        },
      ),
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _C.surfaceAlt,
                child: widget.conversation.isGroup
                    ? const Icon(Icons.groups_rounded, color: _C.textMuted)
                    : ClipOval(
                        child: Image.network(
                          widget.conversation.displayAvatar ??
                              'https://i.pravatar.cc/150?img=11',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person, color: _C.textMuted),
                        ),
                      ),
              ),
              if (!widget.conversation.isGroup && _isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _C.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.conversation.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _C.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!widget.conversation.isGroup && _otherParticipant != null)
                  Text(
                    _getPresenceText(_otherParticipant!),
                    style: TextStyle(
                      fontSize: 12,
                      color: _isOnline ? _C.green : _C.textMuted,
                      fontWeight: _isOnline ? FontWeight.w600 : FontWeight.w400,
                    ),
                  )
                else if (widget.conversation.isGroup)
                  Text(
                    '${_groupMembers.length} membres',
                    style: const TextStyle(fontSize: 12, color: _C.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_outlined, color: _C.primary, size: 26),
          onPressed: () => _startCall(CallType.video),
        ),
        IconButton(
          icon: const Icon(Icons.call_outlined, color: _C.primary, size: 24),
          onPressed: () => _startCall(CallType.audio),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: _C.textMain),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            if (v == 'escalate') _escalateConversation();
            else if (v == 'history') _viewEscalationHistory();
            else if (v == 'group') {
              GoRouter.of(context).go('/chat/group/${widget.conversationId}/info');
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'escalate',
              child: Row(children: [
                Icon(Icons.arrow_upward, color: _C.orange, size: 20),
                SizedBox(width: 10),
                Text('Escalader'),
              ]),
            ),
            const PopupMenuItem(
              value: 'history',
              child: Row(children: [
                Icon(Icons.history, color: _C.primary, size: 20),
                SizedBox(width: 10),
                Text('Historique'),
              ]),
            ),
            if (widget.conversation.isGroup)
              const PopupMenuItem(
                value: 'group',
                child: Row(children: [
                  Icon(Icons.info_outline, color: _C.textMuted, size: 20),
                  SizedBox(width: 10),
                  Text('Infos groupe'),
                ]),
              ),
          ],
        ),
      ],
    );
  }

  String _formatLastSeen(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 0) return 'à ${DateFormat('HH:mm').format(d)}';
    if (diff.inDays == 1) return 'hier à ${DateFormat('HH:mm').format(d)}';
    return 'le ${DateFormat('dd/MM/yyyy').format(d)}';
  }
}

// ─────────────────────────────────────────────────────────────
// PETITS WIDGETS DESIGN
// ─────────────────────────────────────────────────────────────

class _TypingPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(),
          SizedBox(width: 3),
          _Dot(delay: 120),
          SizedBox(width: 3),
          _Dot(delay: 240),
          SizedBox(width: 8),
          Text(
            "écrit…",
            style: TextStyle(
              fontSize: 12,
              color: _C.primary,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({this.delay = 0});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    if (widget.delay > 0) {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) _c.forward();
      });
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: _C.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ReplyBanner extends StatelessWidget {
  final String text;
  final VoidCallback onClose;
  const _ReplyBanner({required this.text, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: _C.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _C.textMuted, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: _C.textMuted),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _FilesPreview extends StatelessWidget {
  final List<PlatformFile> files;
  final void Function(int) onRemove;
  const _FilesPreview({required this.files, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        itemBuilder: (ctx, i) {
          final f = files[i];
          final ext = f.extension?.toLowerCase() ?? '';
          final isImg = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 70,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: _C.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.border),
                ),
                clipBehavior: Clip.hardEdge,
                child: isImg && f.bytes != null
                    ? Image.memory(f.bytes!, fit: BoxFit.cover)
                    : const Center(
                        child: Icon(Icons.insert_drive_file_rounded,
                            color: _C.primary, size: 28),
                      ),
              ),
              Positioned(
                top: -4,
                right: 4,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: const CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.black87,
                    child: Icon(Icons.close, size: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Motif de fond discret style WhatsApp
class _WhatsAppPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1C7B7).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    const step = 28.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        // petits losanges / points alternés
        if (((x \~/ step) + (y \~/ step)) % 3 == 0) {
          canvas.drawCircle(Offset(x + 6, y + 6), 1.2, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
