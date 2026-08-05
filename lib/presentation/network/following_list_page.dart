import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FollowingListPage extends StatefulWidget {
  final String userId;
  const FollowingListPage({super.key, required this.userId});
  @override State<FollowingListPage> createState() => _FollowingListPageState();
}

class _FollowingListPageState extends State<FollowingListPage> {
  List<Map<String, dynamic>> all = [];
  bool loading = true;

  @override void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; });
    try {
      final res = await Supabase.instance.client
          .from('follows')
          .select('following_id, profiles!follows_following_id_fkey(id, display_name, photo_url, avatar_url)')
          .eq('follower_id', widget.userId);
      setState(() {
        all = (res as List).cast<Map<String, dynamic>>();
        loading = false;
      });
    } catch (_) {
      setState(() { loading = false; });
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Abonnements (${all.length})')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: all.length,
                itemBuilder: (context, i) {
                  final item = all[i];
                  final profile = item['profiles'] as Map<String, dynamic>?;
                  final fid = item['following_id'] as String;
                  final name = profile != null ? (profile['display_name'] ?? 'User') as String : 'User';
                  final photo = profile != null ? (profile['photo_url'] ?? profile['avatar_url']) as String? : null;
                  
                  Widget avatarWidget;
                  if (photo != null && photo.isNotEmpty) {
                    avatarWidget = CircleAvatar(backgroundImage: NetworkImage(photo));
                  } else {
                    avatarWidget = const CircleAvatar(child: Icon(Icons.person));
                  }

                  return ListTile(
                    leading: avatarWidget,
                    title: Text(name),
                    onTap: () => context.push('/network/member/$fid'),
                  );
                },
              ),
            ),
    );
  }
}
