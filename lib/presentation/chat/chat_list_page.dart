// lib/presentation/chat/chat_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// ✅ Import de la Policy de Design
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../models/chat/chat_conversation.dart';
import 'providers/chat_list_provider.dart';
import 'providers/presence_provider.dart';
import 'chat_screen.dart';
import 'new_conversation_page.dart';
import 'package:thix_id/presentation/chat/screens/group_create_page.dart';
import 'settings/chat_settings_page.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';

import 'package:thix_id/presentation/chat/widgets/status_story_row.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();

  int _selectedNav = 1;
  bool _isNavExpanded = false;
  Timer? _navInactivityTimer;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(chatListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.dispose();
    _navInactivityTimer?.cancel();
    super.dispose();
  }

  void _toggleNav() {
    setState(() => _isNavExpanded = !_isNavExpanded);
    _resetNavTimer();
  }

  void _resetNavTimer() {
    _navInactivityTimer?.cancel();
    if (_isNavExpanded) {
      _navInactivityTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _isNavExpanded = false);
      });
    }
  }

  Future<void> _openConversation(ChatConversation conv) async {
    ref.read(chatListProvider.notifier).markAsRead(conv.id);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conv.id,
          conversation: conv,
        ),
      ),
    );

    ref.read(chatListProvider.notifier).refresh(silent: true);
  }

  void _openNotifications(int pending) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.55,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: ThixPolicy.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Row(
                children: [
                  Icon(Icons.notifications_rounded, color: ThixPolicy.textMain, size: 22),
                  SizedBox(width: 12),
                  Text(
                    'Notifications',
                    style: TextStyle(
                      color: ThixPolicy.textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: ThixPolicy.border),
            Flexible(
              child: pending > 0
                  ? ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: ThixPolicy.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.swap_vert_rounded,
                          color: ThixPolicy.danger,
                          size: 24,
                        ),
                      ),
                      title: const Text(
                        'Escalade(s) en attente', // Dynamique supprimé pour l'exemple
                        style: TextStyle(
                          color: ThixPolicy.textMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text(
                          'Nécessite une action de votre part',
                          style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: ThixPolicy.textSecondary,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.pushNamed('chatEscalationReceived');
                      },
                    )
                  : const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          'Aucune notification récente',
                          style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: ThixPolicy.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 28),
            _sheetOpt(
              Icons.chat_bubble_outline_rounded,
              'Nouvelle discussion',
              'Démarrer une conversation privée',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewConversationPage()),
              ),
            ),
            const SizedBox(height: 14),
            _sheetOpt(
              Icons.group_add_outlined,
              'Créer un groupe',
              'Collaborer en équipe',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GroupCreatePage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetOpt(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback tap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          tap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: ThixPolicy.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: ThixPolicy.tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(icon, size: 24, color: ThixPolicy.primary), // Icône
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: ThixPolicy.textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: ThixPolicy.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: ThixPolicy.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPreview(String? raw) {
    if (raw == null || raw.isEmpty) return 'Nouvelle conversation';
    
    if (raw.startsWith('ENCv1:') || 
        raw.startsWith('🔒') || 
        (raw.length > 20 && !raw.contains(' ') && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(raw.replaceFirst(RegExp(r'^ENCv1:'), '')))) {
      return '🔒 Message protégé';
    }
    
    final lower = raw.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.gif') || lower.endsWith('.webp')) {
      return '📷 Photo';
    }
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi')) {
      return '🎥 Vidéo';
    }
    if (lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.endsWith('.m4a') || raw.contains('Message audio (')) {
      return '🎤 Message audio';
    }
    
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatListProvider);
    final notifier = ref.read(chatListProvider.notifier);

    final currentUser = ref.watch(authControllerProvider).value;
    final currentUserName = currentUser?.displayName ?? '';
    final currentUserId = currentUser?.id ?? '';
    final currentUserPhoto = currentUser?.photoUrl;

    final onlineUserIds = ref.watch(presenceProvider);

    final seenUserIds = <String>{};
    final onlineContacts = <ChatConversation>[];

    for (final c in state.filtered) {
      if (c.isGroup) continue;
      
      final otherUserId = c.participantIds.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );

      if (otherUserId.isNotEmpty && onlineUserIds.contains(otherUserId)) {
        if (seenUserIds.add(otherUserId)) {
          onlineContacts.add(c);
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: ThixPolicy.primary,
                    strokeWidth: 3,
                  ),
                )
              : RefreshIndicator(
                  color: ThixPolicy.primary,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await notifier.refresh(silent: true);
                    try {
                      ref.read(statusProvider.notifier).refresh();
                    } catch (_) {}
                  },
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // Header
                      SliverToBoxAdapter(
                        child: _buildGradientHeader(
                          currentUserName,
                          currentUserPhoto,
                          onlineContacts,
                          state.pendingEscalations,
                          currentUserId,
                        ),
                      ),

                      // Search
                      SliverToBoxAdapter(child: _searchCard()),

                      // Escalation banner
                      if (state.pendingEscalations > 0)
                        SliverToBoxAdapter(
                          child: _escalationBanner(state.pendingEscalations),
                        ),

                      // Filters
                      SliverToBoxAdapter(child: _filters(state.filterIndex)),

                      const SliverToBoxAdapter(child: SizedBox(height: 4)),

                      // Liste des discussions
                      _chatList(
                        state.filtered,
                        currentUserId,
                        currentUserName,
                        onlineUserIds,
                      ),

                      // Loading more
                      if (state.isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: ThixPolicy.primary,
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 140)),
                    ],
                  ),
                ),

          // Bottom nav
          _buildExpandableBottomNav(state.totalUnread),
        ],
      ),
    );
  }

  // ─────────────────────── HEADER ───────────────────────

  Widget _buildGradientHeader(
    String userName,
    String? userPhoto,
    List<ChatConversation> online,
    int pending,
    String currentUserId,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: const BoxDecoration(
        gradient: ThixPolicy.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bonjour,',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userName.isNotEmpty ? userName : 'Utilisateur',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _headerIcon(
                  icon: Icons.swap_vert_rounded,
                  badge: pending > 0,
                  onTap: () => context.pushNamed('chatEscalationReceived'),
                ),
                const SizedBox(width: 8),
                _headerIcon(
                  icon: Icons.notifications_outlined,
                  badge: pending > 0,
                  onTap: () => _openNotifications(pending),
                ),
              ],
            ),
            
            const SizedBox(height: 20),

            StatusStoryRow(
              currentUserId: currentUserId,
              currentUserAvatar: userPhoto,
              currentUserName: userName,
            ),

            if (online.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: online.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (c, i) {
                    final conv = online[i];
                    return _onlineAvatar(
                      label: conv.displayName.split(' ').first,
                      avatarUrl: conv.displayAvatar,
                      isSelf: false,
                      isOnline: true,
                      onTap: () => _openConversation(conv),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerIcon({
    required IconData icon,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 19, color: Colors.white),
            if (badge)
              Positioned(
                top: 6,
                right: 7,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: ThixPolicy.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: ThixPolicy.primaryDeep, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _onlineAvatar({
    required String label,
    required String? avatarUrl,
    required bool isSelf,
    required bool isOnline,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isOnline ? ThixPolicy.goldGradient : null,
                  color: isOnline ? null : Colors.white24,
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Icon(
                          isSelf
                              ? Icons.person_rounded
                              : Icons.person_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: ThixPolicy.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: ThixPolicy.primaryDeep, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 48,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: ThixPolicy.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => ref.read(chatListProvider.notifier).search(v),
          style: const TextStyle(
            fontSize: 15,
            color: ThixPolicy.textMain,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Rechercher...',
            hintStyle: const TextStyle(
              fontSize: 15,
              color: ThixPolicy.textSecondary,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: ThixPolicy.textSecondary,
            ),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: ThixPolicy.textSecondary,
                    ),
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(chatListProvider.notifier).search('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _escalationBanner(int pending) {
    return GestureDetector(
      onTap: () => context.pushNamed('chatEscalationReceived'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: ThixPolicy.danger.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: ThixPolicy.danger, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '$pending escalade(s) en attente',
                style: const TextStyle(
                  color: ThixPolicy.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: ThixPolicy.danger,
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters(int selected) {
    final tabs = ['Toutes', 'Non lues', 'Équipes', 'Personnelles'];

    return SizedBox(
      height: 36,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (ctx, i) {
          final sel = selected == i;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => ref.read(chatListProvider.notifier).setFilter(i),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? ThixPolicy.tint : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                      color: sel ? ThixPolicy.primaryDeep : ThixPolicy.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────── LISTE CORPORATE STYLE ───────────────────────

  Widget _chatList(
    List<ChatConversation> list,
    String currentUserId,
    String currentUserName,
    Set<String> onlineUserIds,
  ) {
    if (list.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: ThixPolicy.textSecondary,
              ),
              SizedBox(height: 16),
              Text(
                'Aucune conversation',
                style: TextStyle(
                  color: ThixPolicy.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, idx) {
          final conv = list[idx];
          final last = conv.lastMessage;
          final t = last?.createdAt ?? conv.updatedAt;
          final unread = conv.unreadCount > 0;
          
          final otherUserId = conv.participantIds.firstWhere(
            (id) => id != currentUserId,
            orElse: () => '',
          );
          final isOnline = onlineUserIds.contains(otherUserId);

          String chatName = conv.displayName;
          if (!conv.isGroup && chatName == currentUserName) {
            chatName = 'Contact (ID: ${otherUserId.length > 4 ? otherUserId.substring(0, 4) : ''}...)';
          }

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openConversation(conv),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 24, 
                          backgroundColor: ThixPolicy.surface,
                          backgroundImage: conv.displayAvatar != null
                              ? NetworkImage(conv.displayAvatar!)
                              : null,
                          child: conv.displayAvatar == null
                              ? Text(
                                  chatName.isNotEmpty
                                      ? chatName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: ThixPolicy.textSecondary,
                                    fontSize: 20,
                                  ),
                                )
                              : null,
                        ),
                        if (!conv.isGroup && isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: ThixPolicy.success,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  chatName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15, 
                                    fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                                    color: ThixPolicy.textMain,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _fmt(t),
                                style: TextStyle(
                                  fontSize: 11.5, 
                                  fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                                  color: unread ? ThixPolicy.primary : ThixPolicy.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _formatPreview(last?.content),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5, 
                                    fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
                                    color: unread ? ThixPolicy.textMain : ThixPolicy.textSecondary,
                                  ),
                                ),
                              ),
                              if (unread)
                                Container(
                                  margin: const EdgeInsets.only(left: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: ThixPolicy.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${conv.unreadCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
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
        },
        childCount: list.length,
      ),
    );
  }

  // ─────────────────────── BOTTOM NAV ───────────────────────

  Widget _buildExpandableBottomNav(int unread) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _resetNavTimer,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            height: 64,
            width: _isNavExpanded
                ? MediaQuery.of(context).size.width * 0.92
                : 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _isNavExpanded
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _navItem(
                        Icons.people_alt_outlined,
                        Icons.people_alt,
                        'Réseau',
                        0,
                        unread,
                      ),
                      _navItem(
                        Icons.chat_bubble_outline_rounded,
                        Icons.chat_bubble_rounded,
                        'Discussions',
                        1,
                        unread,
                      ),
                      GestureDetector(
                        onTap: () {
                          _resetNavTimer();
                          _showCreateMenu();
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: ThixPolicy.brandGradient,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_comment_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      _navItem(
                        Icons.workspaces_outline,
                        Icons.workspaces_filled,
                        'Espaces',
                        2,
                        unread,
                      ),
                      _navItem(
                        Icons.settings_outlined,
                        Icons.settings,
                        'Réglages',
                        3,
                        unread,
                      ),
                    ],
                  )
                : Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _toggleNav,
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [ThixPolicy.premiumAccent, ThixPolicy.primary],
                            radius: 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    IconData iconOutlined,
    IconData iconFilled,
    String label,
    int idx,
    int unread,
  ) {
    final isSelected = _selectedNav == idx;

    return InkWell(
      onTap: () {
        _resetNavTimer();
        if (idx == 0) {
          context.pushNamed('connections');
        } else if (idx == 2) {
          context.pushNamed('workspaces');
        } else if (idx == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatSettingsPage()),
          );
        } else {
          setState(() => _selectedNav = idx);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              isSelected ? iconFilled : iconOutlined,
              color: isSelected ? ThixPolicy.primary : ThixPolicy.textSecondary,
              size: 26,
            ),
            if (idx == 1 && unread > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ThixPolicy.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);

    if (day == today) return DateFormat('HH:mm').format(d);
    if (day == today.subtract(const Duration(days: 1))) return 'Hier';
    if (now.difference(d).inDays < 7) {
      return DateFormat('EEEE', 'fr_FR').format(d);
    }
    return DateFormat('dd/MM/yy').format(d);
  }
}
