import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});
  @override 
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _tags = [], _users = [], _posts = [];
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();

  @override 
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }
  
  @override 
  void dispose() { 
    _tab.dispose(); 
    _search.dispose(); 
    super.dispose(); 
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final supa = Supabase.instance.client;
      
      // 1. Hashtags Tendances
      final rawPosts = await supa.from('network_posts').select('content').limit(200);
      final Map<String, int> counter = {};
      final reg = RegExp(r'#(\w+)');
      for (final r in (rawPosts as List)) {
        final c = (r['content'] ?? '') as String;
        for (final m in reg.allMatches(c)) {
          final t = m.group(1)!.toLowerCase();
          counter[t] = (counter[t] ?? 0) + 1;
        }
      }
      final sortedTags = counter.entries.toList()..sort((a,b) => b.value.compareTo(a.value));

      // 2. Personnes (Utilisateurs)
      List users = [];
      try {
        users = await supa.from('profiles').select('id, display_name, photo_url, avatar_url, profession, followers_count').order('followers_count', ascending: false).limit(20);
      } catch (_) {
        users = await supa.from('profiles').select('id, display_name, photo_url, avatar_url, profession').limit(20);
      }

      // 3. Publications Populaires
      final pop = await supa.from('network_posts')
          .select('id, content, image_url, likes_count, created_at, profiles(display_name, photo_url)')
          .order('likes_count', ascending: false)
          .limit(20);

      if (!mounted) return;
      
      setState(() {
        _tags = sortedTags.take(15).map((e) => {'tag': e.key, 'count': e.value}).toList();
        _users = (users as List).cast<Map<String, dynamic>>();
        _posts = (pop as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override 
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 0,
        title: const Text('Découvrir', style: TextStyle(color: Color(0xFF0B1B3D), fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab, 
          labelColor: const Color(0xFF2B5CFF), 
          unselectedLabelColor: Colors.grey, 
          indicatorColor: const Color(0xFF2B5CFF), 
          tabs: const [
            Tab(text: 'Tendances'), 
            Tab(text: 'Personnes'), 
            Tab(text: 'Populaires')
          ]
        ),
      ),
      body: Column(children: [
        Container(
          color: Colors.white, 
          padding: const EdgeInsets.all(12), 
          child: TextField(
            controller: _search, 
            onSubmitted: (v) { 
              if (v.trim().isEmpty) return; 
              if (v.startsWith('#')) { 
                context.push('/network/hashtag/${v.replaceAll('#','').trim()}'); 
              } else { 
                context.push('/network/search?q=${Uri.encodeComponent(v)}'); 
              } 
            }, 
            decoration: InputDecoration(
              hintText: 'Rechercher #hashtag ou personne', 
              prefixIcon: const Icon(Icons.search), 
              filled: true, 
              fillColor: const Color(0xFFF5F7FA), 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)
            )
          )
        ),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator()) 
            : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_error!), ElevatedButton(onPressed: _load, child: const Text('Réessayer'))])) 
              : TabBarView(
                  controller: _tab, 
                  children: [
                    _trendTab(), 
                    _peopleTab(), 
                    _popularTab()
                  ]
                )
        ),
      ]),
    );
  }

  Widget _trendTab() => RefreshIndicator(
    onRefresh: _load, 
    child: ListView(
      padding: const EdgeInsets.all(16), 
      children: [
        const Text('Hashtags tendances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, 
          runSpacing: 8, 
          children: _tags.map((t) => ActionChip(
            label: Text('#${t['tag']} • ${t['count']}'), 
            onPressed: () => context.push('/network/hashtag/${t['tag']}')
          )).toList()
        ),
        if (_tags.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Pas encore de tendances'))),
      ]
    )
  );

  Widget _peopleTab() => RefreshIndicator(
    onRefresh: _load, 
    child: ListView.builder(
      padding: const EdgeInsets.all(12), 
      itemCount: _users.length, 
      itemBuilder: (_, i) {
        final u = _users[i];
        final avatar = u['photo_url'] ?? u['avatar_url'];
        return Container(
          margin: const EdgeInsets.only(bottom: 8), 
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), 
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: avatar != null ? NetworkImage(avatar) : null, 
              child: avatar == null ? const Icon(Icons.person) : null
            ), 
            title: Text(u['display_name'] ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), 
            subtitle: Text(u['profession'] ?? '', style: const TextStyle(fontSize: 11)), 
            
            // CORRECTION ICI : Redirection vers /network/profile/ au lieu de /network/member/
            trailing: ElevatedButton(
              onPressed: () => context.push('/network/profile/${u['id']}'), 
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2B5CFF)), 
              child: const Text('Voir', style: TextStyle(color: Colors.white, fontSize: 11))
            ), 
            onTap: () => context.push('/network/profile/${u['id']}')
          )
        );
      }
    )
  );

  Widget _popularTab() => RefreshIndicator(
    onRefresh: _load, 
    child: GridView.builder(
      padding: const EdgeInsets.all(8), 
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, 
        childAspectRatio: 0.78, 
        crossAxisSpacing: 8, 
        mainAxisSpacing: 8
      ), 
      itemCount: _posts.length, 
      itemBuilder: (_, i) {
        final p = _posts[i];
        // Ajout d'une vérification sécurisée pour récupérer l'image
        final img = p['image_url'];
        
        return GestureDetector(
          onTap: () => context.push('/network/post/${p['id']}'), 
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                if (img != null) 
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), 
                    child: Image.network(img, height: 110, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 110, color: Colors.grey.shade200, child: const Icon(Icons.image)))
                  ),
                Padding(
                  padding: const EdgeInsets.all(10), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text((p['profiles']?['display_name'] ?? ''), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), 
                      const SizedBox(height: 4), 
                      Text(p['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)), 
                      const SizedBox(height: 6), 
                      Row(children: [const Icon(Icons.favorite, size: 12, color: Colors.red), const SizedBox(width: 4), Text('${p['likes_count'] ?? 0}', style: const TextStyle(fontSize: 11))])
                    ]
                  )
                ),
              ]
            )
          )
        );
      }
    )
  );
}
