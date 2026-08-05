// lib/presentation/chat/connections_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat/connection_service.dart';

// Nouvelle palette "Grandeur Entreprise" (Thème Clair & Lumineux)
class _C {
  static const bg = Color(0xFFF8FAFC); // Gris perle très léger
  static const surface = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF1D4ED8); // Bleu "Trust"
  static const primaryLight = Color(0xFFEFF6FF);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const red = Color(0xFFEF4444);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF59E0B);
}

class ConnectionsState {
  final List<ConnectionRequest> received;
  final List<ConnectionRequest> sent;
  final List<dynamic> connections;
  final bool loading;
  final bool loadingMore;
  final bool hasMoreConnections;
  final String? error;

  const ConnectionsState({
    this.received = const [], 
    this.sent = const [], 
    this.connections = const [], 
    this.loading = true, 
    this.loadingMore = false, 
    this.hasMoreConnections = true, 
    this.error
  });

  ConnectionsState copyWith({
    List<ConnectionRequest>? received, 
    List<ConnectionRequest>? sent, 
    List<dynamic>? connections, 
    bool? loading, 
    bool? loadingMore, 
    bool? hasMoreConnections, 
    String? error
  }) {
    return ConnectionsState(
      received: received ?? this.received, 
      sent: sent ?? this.sent, 
      connections: connections ?? this.connections, 
      loading: loading ?? this.loading, 
      loadingMore: loadingMore ?? this.loadingMore, 
      hasMoreConnections: hasMoreConnections ?? this.hasMoreConnections, 
      error: error
    );
  }
}

class ConnectionsNotifier extends StateNotifier<ConnectionsState> {
  final ConnectionService _svc;
  static const _limit = 20;
  
  ConnectionsNotifier(this._svc) : super(const ConnectionsState()) { 
    loadInitial(); 
  }

  Future<void> loadInitial() async {
    state = state.copyWith(loading: true);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    
    if (uid == null) { 
      state = state.copyWith(loading: false); 
      return; 
    }
    
    try {
      await _svc.loadData(uid, limit: _limit, offset: 0);
      state = ConnectionsState(
        received: _svc.receivedRequests,
        sent: _svc.sentRequests,
        connections: _svc.connections,
        loading: false,
        hasMoreConnections: _svc.connections.length == _limit,
      );
    } catch (e) { 
      state = state.copyWith(loading: false, error: e.toString()); 
    }
  }

  Future<void> loadMoreConnections() async {
    if (state.loadingMore || !state.hasMoreConnections) return;
    
    state = state.copyWith(loadingMore: true);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    
    if (uid == null) { 
      state = state.copyWith(loadingMore: false); 
      return; 
    }
    
    try {
      final more = await _svc.loadMoreConnections(uid, offset: state.connections.length, limit: _limit);
      state = state.copyWith(
        connections: [...state.connections, ...more], 
        hasMoreConnections: more.length == _limit, 
        loadingMore: false
      );
    } catch (_) { 
      state = state.copyWith(loadingMore: false); 
    }
  }

  Future<bool> accept(String id) async {
    final uid = Supabase.instance.client.auth.currentUser?.id; 
    if (uid == null) return false;
    final ok = await _svc.acceptRequest(id, uid); 
    if (ok) await loadInitial(); 
    return ok;
  }
  
  Future<bool> reject(String id) async {
    final uid = Supabase.instance.client.auth.currentUser?.id; 
    if (uid == null) return false;
    final ok = await _svc.rejectRequest(id, uid); 
    if (ok) await loadInitial(); 
    return ok;
  }
  
  Future<bool> cancel(String id) async {
    final uid = Supabase.instance.client.auth.currentUser?.id; 
    if (uid == null) return false;
    final ok = await _svc.cancelRequest(id, uid); 
    if (ok) await loadInitial(); 
    return ok;
  }
}

final connectionsProvider = StateNotifierProvider<ConnectionsNotifier, ConnectionsState>((ref) {
  return ConnectionsNotifier(ConnectionService());
});

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key});
  @override 
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage> {
  final _scroll = ScrollController();
  
  @override 
  void initState() { 
    super.initState(); 
    _scroll.addListener(() { 
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(connectionsProvider.notifier).loadMoreConnections(); 
      }
    }); 
  }
  
  @override 
  void dispose() { 
    _scroll.dispose(); 
    super.dispose(); 
  }

  Future<void> _confirmCancel(String id) async {
    final ok = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _C.border)),
        title: const Text('Annuler la demande ?', style: TextStyle(color: _C.textMain, fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text('Cette action retirera votre demande de connexion en attente.', style: TextStyle(color: _C.textMuted, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text('Non', style: TextStyle(color: _C.textMuted, fontWeight: FontWeight.w600))
          ), 
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ), 
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Oui, annuler', style: TextStyle(fontWeight: FontWeight.bold))
          )
        ],
      )
    );
    
    if (ok == true) { 
      final svc = ref.read(connectionsProvider.notifier); 
      final res = await svc.cancel(id); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res ? 'Demande annulée avec succès' : 'Erreur lors de l\'annulation'), 
            backgroundColor: res ? _C.textMuted : _C.red
          )
        ); 
      }
    }
  }

  @override 
  Widget build(BuildContext context) {
    final state = ref.watch(connectionsProvider);
    final notifier = ref.read(connectionsProvider.notifier);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain, size: 24), 
          onPressed: () => Navigator.pop(context),
          splashRadius: 24,
        ), 
        title: const Text('Réseau & Connexions', style: TextStyle(color: _C.textMain, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)), 
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _C.textMain, size: 24), 
            onPressed: () => notifier.loadInitial(),
            splashRadius: 24,
          ),
          const SizedBox(width: 8),
        ]
      ),
      body: state.loading 
        ? const Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 3)) 
        : RefreshIndicator(
            color: _C.primary, 
            backgroundColor: Colors.white,
            onRefresh: () async => notifier.loadInitial(),
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // SECTION: DEMANDES REÇUES
                if (state.received.isNotEmpty) ...[
                  _sectionTitle('Demandes reçues (${state.received.length})'),
                  ...state.received.map((r) => _buildReceivedRequestCard(r, notifier)),
                  const SizedBox(height: 16),
                ],
                
                // SECTION: DEMANDES ENVOYÉES
                if (state.sent.isNotEmpty) ...[
                  _sectionTitle('Demandes envoyées (${state.sent.length})'),
                  ...state.sent.map((r) => _buildSentRequestCard(r)),
                  const SizedBox(height: 16),
                ],
                
                // SECTION: CONNEXIONS ACTIVES
                _sectionTitle('Vos connexions (${state.connections.length})'),
                if (state.connections.isEmpty) 
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20), 
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)), 
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: _C.bg, shape: BoxShape.circle),
                          child: const Icon(Icons.people_outline_rounded, size: 40, color: _C.textMuted),
                        ),
                        const SizedBox(height: 16),
                        const Text('Aucune connexion pour le moment', style: TextStyle(color: _C.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Recherchez vos collègues et partenaires pour démarrer des discussions.', textAlign: TextAlign.center, style: TextStyle(color: _C.textMuted, fontSize: 14)),
                      ],
                    )
                  ),
                
                // Liste des connexions (SaaS Style)
                if (state.connections.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _C.border),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    child: Column(
                      children: state.connections.asMap().entries.map((entry) {
                        final i = entry.key;
                        final c = entry.value;
                        final isLast = i == state.connections.length - 1;
                        
                        return Column(
                          children: [
                            _buildConnectionItem(c),
                            if (!isLast) const Divider(height: 1, color: _C.border, indent: 76),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                if (state.loadingMore) 
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 3))),
                
                const SizedBox(height: 80),
              ],
            ),
          ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12, left: 4), 
      child: Text(title, style: const TextStyle(color: _C.textMain, fontWeight: FontWeight.w800, fontSize: 16))
    );
  }

  // Carte de demande reçue (Façon LinkedIn)
  Widget _buildReceivedRequestCard(ConnectionRequest r, ConnectionsNotifier notifier) {
    final name = r.sender?['display_name'] ?? 'Utilisateur inconnu';
    final sub = r.message ?? 'Souhaite se connecter avec vous';
    final avatarUrl = r.sender?['avatar_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar Squircle
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                  image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                ),
                child: avatarUrl == null 
                  ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: _C.primary, fontWeight: FontWeight.bold, fontSize: 18)))
                  : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: _C.textMain, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(sub, style: const TextStyle(color: _C.textMuted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Boutons d'action clairs
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async { 
                    final ok = await notifier.reject(r.id); 
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Demande ignorée' : 'Erreur'), backgroundColor: _C.textMuted)); 
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _C.textMuted,
                    side: const BorderSide(color: _C.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12)
                  ),
                  child: const Text('Ignorer', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async { 
                    final ok = await notifier.accept(r.id); 
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Connexion acceptée' : 'Erreur'), backgroundColor: _C.green)); 
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12)
                  ),
                  child: const Text('Accepter', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Carte de demande envoyée
  Widget _buildSentRequestCard(ConnectionRequest r) {
    final name = r.receiver?['display_name'] ?? 'Utilisateur inconnu';
    final avatarUrl = r.receiver?['avatar_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _C.bg,
            borderRadius: BorderRadius.circular(12),
            image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
          ),
          child: avatarUrl == null 
            ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: _C.textMuted, fontWeight: FontWeight.bold, fontSize: 16)))
            : null,
        ),
        title: Text(name, style: const TextStyle(color: _C.textMain, fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Row(
          children: const [
            Icon(Icons.access_time_rounded, size: 14, color: _C.orange),
            SizedBox(width: 4),
            Text('En attente...', style: TextStyle(color: _C.orange, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        trailing: TextButton(
          onPressed: () => _confirmCancel(r.id),
          style: TextButton.styleFrom(foregroundColor: _C.textMuted),
          child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // Item de connexion active (Liste propre et continue)
  Widget _buildConnectionItem(Map<String, dynamic> c) {
    final name = c['display_name'] ?? 'Utilisateur inconnu';
    final username = c['username'] ?? '';
    final avatarUrl = c['avatar_url'];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _C.primaryLight,
          borderRadius: BorderRadius.circular(12),
          image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
        ),
        child: avatarUrl == null 
          ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: _C.primary, fontWeight: FontWeight.bold, fontSize: 16)))
          : null,
      ),
      title: Text(name, style: const TextStyle(color: _C.textMain, fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: username.isNotEmpty ? Text('@$username', style: const TextStyle(color: _C.textMuted, fontSize: 13)) : null,
      trailing: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.chat_bubble_outline_rounded, color: _C.primary, size: 20),
      ),
      onTap: () {
        // Logique pour ouvrir le profil ou démarrer directement le chat
      },
    );
  }
}
