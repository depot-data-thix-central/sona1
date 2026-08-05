import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/presentation/network/widgets/connection_card.dart';

final connectionsProvider = AsyncNotifierProvider<Connections, List<Map<String, dynamic>>>(Connections.new);

class Connections extends AsyncNotifier<List<Map<String, dynamic>>> {
  static const _limit = 30;
  int _offset = 0;
  bool _hasMore = true;
  bool get hasMore => _hasMore;
  String _search = '';

  @override
  Future<List<Map<String, dynamic>>> build() async {
    _offset = 0; _hasMore = true;
    return _fetch(0);
  }

  Future<List<Map<String, dynamic>>> _fetch(int offset) async {
    final supa = Supabase.instance.client;
    final userId = supa.auth.currentUser?.id;
    if (userId == null) return [];

    final res = await supa.from('connections').select('''
      id, connection_id, created_at,
      users:connection_id!inner (id, display_name, photo_url, profession, bio)
    ''').eq('user_id', userId).eq('status', 'accepted').order('created_at', ascending: false).range(offset, offset + _limit - 1);

    final list = <Map<String, dynamic>>[];
    for (var conn in res as List) {
      final userData = conn['users'] as Map<String, dynamic>?;
      if (userData!= null) {
        list.add({
          'id': conn['id'],
          'user_id': userData['id'],
          'display_name': userData['display_name']?? 'Utilisateur',
          'photo_url': userData['photo_url'],
          'profession': userData['profession']?? 'Membre THIX',
          'bio': userData['bio'],
          'connected_at': conn['created_at'],
        });
      }
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      return list.where((c) => (c['display_name'] as String).toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final current = state.valueOrNull?? <Map<String, dynamic>>[];
    final more = await _fetch(_offset + _limit);
    if (more.isEmpty) { _hasMore = false; return; }
    _offset += _limit;
    _hasMore = more.length >= _limit;
    state = AsyncData([...current,...more]);
  }

  void search(String q) { _search = q; ref.invalidateSelf(); }

  Future<void> removeConnection(String connectionId) async {
    final current = [...state.valueOrNull?? <Map<String, dynamic>>[]];
    final filtered = current.where((c) => c['id']!= connectionId).toList();
    state = AsyncData(filtered);
    try {
      await Supabase.instance.client.from('connections').delete().eq('id', connectionId);
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

class ConnectionsListPage extends ConsumerStatefulWidget {
  const ConnectionsListPage({super.key});
  @override ConsumerState<ConnectionsListPage> createState() => _ConnectionsListPageState();
}

class _ConnectionsListPageState extends ConsumerState<ConnectionsListPage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
        ref.read(connectionsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() { _scroll.dispose(); _searchCtrl.dispose(); super.dispose(); }

  Future<void> _removeConnection(String connectionId, String userName) async {
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Supprimer la connexion'), content: Text('Voulez-vous vraiment retirer $userName de vos connexions?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Supprimer'))]));
    if (confirm!= true) return;
    try {
      await ref.read(connectionsProvider.notifier).removeConnection(connectionId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$userName a été retiré'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncConnections = ref.watch(connectionsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0.5,
        title: Row(children: [
          const Text('Mes connexions', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(width: 8),
          asyncConnections.when(data: (l) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text('${l.length}', style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 12))), loading: () => const SizedBox(), error: (_, __) => const SizedBox()),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A2E), size: 20), onPressed: () => context.pop()),
        actions: [IconButton(icon: const Icon(Icons.search, color: Color(0xFF1A1A2E), size: 22), onPressed: _showSearch)],
      ),
      body: asyncConnections.when(
        loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)))),
        error: (e, _) => _buildErrorWidget(e.toString()),
        data: (connections) => connections.isEmpty? _buildEmptyWidget() : RefreshIndicator(color: const Color(0xFFD4AF37), onRefresh: () async => ref.invalidate(connectionsProvider), child: ListView.builder(controller: _scroll, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), itemCount: connections.length + 1, itemBuilder: (context, index) {
          if (index == connections.length) return ref.read(connectionsProvider.notifier).hasMore? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))) : const SizedBox(height: 20);
          final conn = connections[index];
          return ConnectionCard(userId: conn['user_id'], displayName: conn['display_name'], photoUrl: conn['photo_url'], profession: conn['profession'], bio: conn['bio'], connectedAt: conn['connected_at'], onTap: () => context.push('/network/profile/${conn['user_id']}'), onMessageTap: () => context.push('/network/chat/${conn['user_id']}'), onRemoveTap: () => _removeConnection(conn['id'], conn['display_name']));
        })),
      ),
    );
  }

  Widget _buildErrorWidget(String error) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400), const SizedBox(height: 16), Text(error, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)), const SizedBox(height: 16), ElevatedButton(onPressed: () => ref.invalidate(connectionsProvider), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: const Text('Réessayer'))]));
  Widget _buildEmptyWidget() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.08), shape: BoxShape.circle), child: Icon(Icons.people_outline, size: 64, color: const Color(0xFFD4AF37).withOpacity(0.5))), const SizedBox(height: 24), const Text('Aucune connexion', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))), const SizedBox(height: 8), Text('Commencez à vous connecter avec\ndes professionnels de votre secteur.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)), const SizedBox(height: 24), ElevatedButton.icon(onPressed: () => context.push('/network/discover'), icon: const Icon(Icons.explore), label: const Text('Découvrir des personnes'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)))]));
  void _showSearch() => showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Rechercher'), content: TextField(controller: _searchCtrl, autofocus: true, decoration: const InputDecoration(hintText: 'Nom...', prefixIcon: Icon(Icons.search)), onChanged: (v) => ref.read(connectionsProvider.notifier).search(v)), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Fermer'))]));
}
