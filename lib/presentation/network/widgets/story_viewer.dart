import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/network_story.dart';

class StoryViewer extends StatefulWidget {
  final List<NetworkStory> stories;
  final int initialIndex;
  const StoryViewer({super.key, required this.stories, required this.initialIndex});
  @override State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  late PageController _controller;
  late int _currentIndex;
  Timer? _timer;
  double _progress = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _progress = 0;
    const duration = Duration(milliseconds: 5000);
    const tick = Duration(milliseconds: 50);
    _timer = Timer.periodic(tick, (t) {
      if (_paused) return;
      if (!mounted) return;
      setState(() {
        _progress += tick.inMilliseconds / duration.inMilliseconds;
        if (_progress >= 1) {
          _progress = 0;
          if (_currentIndex < widget.stories.length - 1) {
            _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
          } else {
            if (mounted) Navigator.pop(context);
          }
        }
      });
    });
  }

  Future<void> _deleteStory(String storyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la story?'),
        content: const Text('Irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('stories').delete().eq('id', storyId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story supprimée'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final dx = details.globalPosition.dx;
          final w = MediaQuery.of(context).size.width;
          if (dx < w * 0.3) {
            if (_currentIndex > 0) _controller.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
          } else if (dx > w * 0.7) {
            if (_currentIndex < widget.stories.length - 1) {
              _controller.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
            } else {
              Navigator.pop(context);
            }
          }
        },
        onLongPressStart: (_) => setState(() => _paused = true),
        onLongPressEnd: (_) => setState(() => _paused = false),
        child: PageView.builder(
          controller: _controller,
          onPageChanged: (i) { setState(() { _currentIndex = i; _progress = 0; }); _startTimer(); },
          itemCount: widget.stories.length,
          itemBuilder: (context, index) {
            final s = widget.stories[index];
            
            // 🔴 CORRECTION ICI : On essaie mediaUrl en priorité, puis imageUrl
            // Si ton modèle utilise une autre propriété, vérifie le nom exact dans network_story.dart
            String safeUrl = '';
            try { safeUrl = (s as dynamic).mediaUrl ?? (s as dynamic).imageUrl ?? ''; } catch (_) { }

            final storyText = s.textContent ?? '';
            final isMyStory = s.userId == currentUserId;
            
            return Stack(
              children: [
                Positioned.fill(
                  child: safeUrl.isNotEmpty
                   // 🔴 CORRECTION ICI : Ajout du loadingBuilder pour voir que l'image charge
                   ? Image.network(
                       safeUrl, 
                       fit: BoxFit.cover,
                       loadingBuilder: (_, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
                       errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 50))
                     )
                   : Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B3B7A), Color(0xFF0B1B3D)]))),
                ),
                if (storyText.isNotEmpty)
                  Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(storyText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)))),
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(child: Padding(padding: const EdgeInsets.all(6), child: Row(children: List.generate(widget.stories.length, (i) {
                    return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), height: 3, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)), child: Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: i == _currentIndex ? _progress : (i < _currentIndex ? 1.0 : 0.0), child: Container(color: Colors.white)))));
                  })))),
                ),
                Positioned(
                  top: 30, left: 16, right: 16,
                  child: SafeArea(child: Row(children: [
                    const CircleAvatar(radius: 18, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    if (isMyStory) Container(decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)), child: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white), onPressed: () => _deleteStory(s.id))),
                    const SizedBox(width: 8),
                    Container(decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
                  ])),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
