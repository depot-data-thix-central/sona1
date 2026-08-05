// lib/presentation/chat/chat_list_page.dart
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/chat/chat_conversation.dart';
import 'providers/chat_list_provider.dart';
import 'providers/presence_provider.dart';
import 'chat_screen.dart';
import 'new_conversation_page.dart';
import 'package:thix_id/presentation/chat/screens/group_create_page.dart';
import 'settings/chat_settings_page.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';

// ── PALETTE ENTERPRISE PREMIUM — harmonisée Charte THIX ID ──
class _C {
  static const bg = Colors.white;
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF1F5F9);
  static const searchBg = Color(0xFFF1F5F9);
  static const border = Color(0xFFE2E8F0);
  static const navyDeep = Color(0xFF0A1F44);
  static const primaryDeep = Color(0xFF123B7A);
  static const primary = Color(0xFF2D6CDF);
  static const primarySoft = Color(0xFFEFF6FF);
  static const gold = Color(0xFFE3B23C);
  static const goldLight = Color(0xFFF3D999);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const textSoft = Color(0xFF94A3B8);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF59E0B);
  static const green = Color(0xFF10B981); // uniquement pour le point "en ligne"

  static const gradientHeader = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [navyDeep, primaryDeep, primary],
  );
  static const gradientOnlineRing = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [gold, goldLight],
  );
}

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

  /// Ouvre une conversation et la marque comme lue immédiatement (optimiste),
  /// avant même que l'utilisateur ait fini de lire — évite tout flash de
  /// badge non-lu au retour sur la liste.
  Future<void> _openConversation(ChatConversation conv) async {
    ref.read(chatListProvider.notifier).markAsRead(conv.id);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: conv.id, conversation: conv)));
    ref.read(chatListProvider.notifier).refresh();
  }

  void _openNotifications(int pending) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Container(
              width: 42, height: 5,
              decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(3)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Row(
                children: [
                  Icon(Icons.notifications_rounded, color: _C.textMain, size: 22),
                  SizedBox(width: 12),
                  Text('Notifications', style: TextStyle(color: _C.textMain, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                ],
              ),
            ),
            const Divider(height: 1, color: _C.border),
            Flexible(
              child: pending > 0
                  ? ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      leading: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: _C.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.swap_vert_rounded, color: _C.red, size: 24),
                      ),
                      title: Text('$pending escalade(s) en attente', style: const TextStyle(color: _C.textMain, fontWeight: FontWeight.w700, fontSize: 15)),
                      subtitle: const Padding(padding: EdgeInsets.only(top: 3), child: Text('Nécessite une action de votre part', style: TextStyle(color: _C.textMuted, fontSize: 13))),
                      trailing: const Icon(Icons.chevron_right_rounded, color: _C.textSoft),
                      onTap: () { Navigator.pop(ctx); context.pushNamed('chatEscalationReceived'); },
                    )
                  : const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: Text('Aucune notification récente', style: TextStyle(color: _C.textMuted, fontSize: 14))),
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
            Container(width: 42, height: 5, decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 28),
            _sheetOpt(Icons.chat_bubble_outline_rounded, 'Nouvelle discussion', 'Démarrer une conversation privée', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewConversationPage()))),
            const SizedBox(height: 14),
            _sheetOpt(Icons.group_add_outlined, 'Créer un groupe', 'Collaborer en équipe', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupCreatePage()))),
          ],
        ),
      ),
    );
  }

  Widget _sheetOpt(IconData icon, String title, String subtitle, VoidCallback tap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () { Navigator.pop(context); tap(); },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: _C.surface, border: Border.all(color: _C.border), borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: _C.primarySoft, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, size: 24, color: _C.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: _C.textMain, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: _C.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _C.textSoft),
            ],
          ),
        ),
      ),
    );
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

    final onlineContacts = state.filtered.where((c) {
      if (c.isGroup) return false;
      final otherUserId = c.participantIds.firstWhere((id) => id != currentUserId, orElse: () => '');
      return onlineUserIds.contains(otherUserId);
    }).toList();

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          state.isLoading
              ? const Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 3))
              : RefreshIndicator(
                  color: _C.primary,
                  backgroundColor: Colors.white,
                  onRefresh: () async => notifier.refresh(),
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      SliverToBoxAdapter(child: _buildGradientHeader(currentUserName, currentUserPhoto, onlineContacts, state.pendingEscalations)),
                      SliverToBoxAdapter(child: _searchCard()),
                      if (state.pendingEscalations > 0)
                        SliverToBoxAdapter(child: _escalationBanner(state.pendingEscalations)),
                      SliverToBoxAdapter(child: _filters(state.filterIndex)),
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      _chatList(state.filtered, currentUserId, onlineUserIds),
                      if (state.isLoadingMore)
                        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 3)))),
                      const SliverToBoxAdapter(child: SizedBox(height: 140)),
                    ],
                  ),
                ),
          _buildExpandableBottomNav(state.totalUnread),
        ],
      ),
    );
  }

  // ─────────────────────── EN-TÊTE & RECHERCHE ───────────────────────
  // Dégradé aligné sur la Charte THIX ID (navyDeep → primaryDeep → primary),
  // identique à celui de THIX PRO / MON PAYS pour une cohérence inter-modules.

  Widget _buildGradientHeader(String userName, String? userPhoto, List<ChatConversation> online, int pending) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: const BoxDecoration(
        gradient: _C.gradientHeader,
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
                        style: TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w500, letterSpacing: -0.1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userName.isNotEmpty ? userName : 'Utilisateur',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.25),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _headerIcon(icon: Icons.swap_vert_rounded, badge: pending > 0, onTap: () => context.pushNamed('chatEscalationReceived')),
                const SizedBox(width: 8),
                _headerIcon(icon: Icons.notifications_outlined, badge: pending > 0, onTap: () => _openNotifications(pending)),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: online.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (c, i) {
                  if (i == 0) {
                    return _onlineAvatar(label: 'Vous', avatarUrl: userPhoto, isSelf: true, isOnline: true);
                  }
                  final conv = online[i - 1];
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
        ),
      ),
    );
  }

  Widget _headerIcon({required IconData icon, required VoidCallback onTap, bool badge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), shape: BoxShape.circle),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 19, color: Colors.white),
            if (badge)
              Positioned(top: 6, right: 7, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: _C.gold, shape: BoxShape.circle, border: Border.all(color: _C.primaryDeep, width: 1.5)))),
          ],
        ),
      ),
    );
  }

  Widget _onlineAvatar({required String label, required String? avatarUrl, required bool isSelf, required bool isOnline, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: const EdgeInsets.all(2.4),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: isOnline ? _C.gradientOnlineRing : null, color: isOnline ? null : Colors.white24),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white24,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Icon(isSelf ? Icons.person_rounded : Icons.person_outline_rounded, color: Colors.white, size: 22)
                  : null,
            ),
          ),
          if (isOnline)
            Positioned(
              right: 0, bottom: 1,
              child: Container(width: 12, height: 12, decoration: BoxDecoration(color: _C.green, shape: BoxShape.circle, border: Border.all(color: _C.primaryDeep, width: 2))),
            ),
        ]),
        const SizedBox(height: 5),
        SizedBox(
          width: 56,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
    );
  }

  Widget _searchCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _C.searchBg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => ref.read(chatListProvider.notifier).search(v),
          style: const TextStyle(fontSize: 15, color: _C.textMain, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Rechercher une conversation...',
            hintStyle: const TextStyle(fontSize: 15, color: _C.textSoft, fontWeight: FontWeight.w400),
            prefixIcon: const Icon(Icons.search_rounded, size: 22, color: _C.textSoft),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: _C.textSoft), onPressed: () { _searchCtrl.clear(); ref.read(chatListProvider.notifier).search(''); })
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
        decoration: BoxDecoration(color: _C.red.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _C.red, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text('$pending escalade(s) en attente', style: const TextStyle(color: _C.red, fontWeight: FontWeight.w700, fontSize: 14))),
            const Icon(Icons.arrow_forward_ios_rounded, color: _C.red, size: 13),
          ],
        ),
      ),
    );
  }

  Widget _filters(int selected) {
    final tabs = ['Toutes', 'Non lues', 'Équipes', 'Personnelles'];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (ctx, i) {
          final sel = selected == i;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
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
                    color: sel ? _C.primary : _C.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? _C.primary : _C.border, width: 1),
                    boxShadow: sel ? [BoxShadow(color: _C.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? Colors.white : _C.textMuted,
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

  // ─────────────────────────── LISTE DES CHATS ───────────────────────────

  Widget _chatList(List<ChatConversation> list, String currentUserId, Set<String> onlineUserIds) {
    if (list.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Column(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 48, color: _C.textSoft),
              SizedBox(height: 16),
              Text('Aucune conversation trouvée', style: TextStyle(color: _C.textMuted, fontSize: 15, fontWeight: FontWeight.w500)),
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
          final t = last != null ? last.createdAt : conv.updatedAt;
          final unread = conv.unreadCount > 0;
          final otherUserId = conv.participantIds.firstWhere((id) => id != currentUserId, orElse: () => '');
          final isOnline = onlineUserIds.contains(otherUserId);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openConversation(conv),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: _C.surfaceAlt,
                          backgroundImage: conv.displayAvatar != null ? NetworkImage(conv.displayAvatar!) : null,
                          child: conv.displayAvatar == null
                              ? Text(conv.displayName.isNotEmpty ? conv.displayName[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.w600, color: _C.textMuted, fontSize: 22))
                              : null,
                        ),
                        if (!conv.isGroup && isOnline)
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              width: 14, height: 14,
                              decoration: BoxDecoration(color: _C.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
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
                                  conv.displayName,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: _C.textMain),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _fmt(t),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                                  color: unread ? _C.primary : _C.textSoft,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  last?.content ?? 'Nouvelle conversation',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                                    color: unread ? _C.textMain : _C.textMuted,
                                  ),
                                ),
                              ),
                              if (unread)
                                Container(
                                  margin: const EdgeInsets.only(left: 10),
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: _C.primary, shape: BoxShape.circle),
                                  child: Text(
                                    '${conv.unreadCount}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
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

  // ────────────────── BARRE DE NAVIGATION MAGIQUE & BOUTON NOUVEAU CHAT ──────────────────

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
            width: _isNavExpanded ? MediaQuery.of(context).size.width * 0.92 : 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: _isNavExpanded
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _navItem(Icons.people_alt_outlined, Icons.people_alt, 'Réseau', 0, unread),
                      _navItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Discussions', 1, unread),
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
                            gradient: _C.gradientHeader,
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                          ),
                          child: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                      _navItem(Icons.workspaces_outline, Icons.workspaces_filled, 'Espaces', 2, unread),
                      _navItem(Icons.settings_outlined, Icons.settings, 'Réglages', 3, unread),
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
                          gradient: RadialGradient(colors: [_C.goldLight, _C.primary], radius: 0.8),
                        ),
                        child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData iconOutlined, IconData iconFilled, String label, int idx, int unread) {
    final isSelected = _selectedNav == idx;
    return InkWell(
      onTap: () {
        _resetNavTimer();
        if (idx == 0) context.pushNamed('connections');
        else if (idx == 2) context.pushNamed('workspaces');
        else if (idx == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatSettingsPage()));
        else setState(() => _selectedNav = idx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(isSelected ? iconFilled : iconOutlined, color: isSelected ? _C.primary : _C.textSoft, size: 26),
            if (idx == 1 && unread > 0)
              Positioned(
                right: -4, top: -4,
                child: Container(width: 10, height: 10, decoration: BoxDecoration(color: _C.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
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
    if (now.difference(d).inDays < 7) return DateFormat('EEEE', 'fr_FR').format(d);
    return DateFormat('dd/MM/yy').format(d);
  }
}
