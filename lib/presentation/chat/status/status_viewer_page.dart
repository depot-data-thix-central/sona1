// lib/presentation/chat/status/status_viewer_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:thix_id/models/chat/user_status_story.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';

class StatusViewerPage extends ConsumerStatefulWidget {
  final List<UserStatusStory> stories;

  const StatusViewerPage({super.key, required this.stories});

  @override
  ConsumerState<StatusViewerPage> createState() => _StatusViewerPageState();
}

class _StatusViewerPageState extends ConsumerState<StatusViewerPage> {
  late PageController _pageCtrl;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markCurrent());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _markCurrent() {
    if (widget.stories.isEmpty) return;
    final s = widget.stories[_index];
    if (!s.isMine && !s.hasViewed) {
      ref.read(statusProvider.notifier).markViewed(s.statusId);
    }
  }

  Color _parseBg(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF1D4ED8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stories = widget.stories;
    if (stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Aucun statut', style: TextStyle(color: Colors.white))),
      );
    }

    final current = stories[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.localPosition.dx < w / 3) {
            if (_index > 0) {
              setState(() => _index--);
              _pageCtrl.jumpToPage(_index);
              _markCurrent();
            } else {
              Navigator.pop(context);
            }
          } else {
            if (_index < stories.length - 1) {
              setState(() => _index++);
              _pageCtrl.jumpToPage(_index);
              _markCurrent();
            } else {
              Navigator.pop(context);
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageCtrl,
              itemCount: stories.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                _markCurrent();
              },
              itemBuilder: (_, i) {
                final s = stories[i];
                if (s.isImage && s.mediaUrl != null) {
                  return Image.network(s.mediaUrl!, fit: BoxFit.contain);
                }
                return Container(
                  color: _parseBg(s.background),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    s.content ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                );
              },
            ),
            // Top bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  children: [
                    // Progress segments
                    Row(
                      children: List.generate(stories.length, (i) {
                        return Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: i <= _index
                                  ? Colors.white
                                  : Colors.white30,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: current.avatarUrl != null
                              ? NetworkImage(current.avatarUrl!)
                              : null,
                          child: current.avatarUrl == null
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current.isMine ? 'Mon statut' : current.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                DateFormat('HH:mm').format(current.createdAt),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
