// lib/presentation/network/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';

class _PostColors {
  static const background = Color(0xFFF6F7FB);
  static const white = Color(0xFFFFFFFF);
  static const primary = Color(0xFF2D6CDF);
  static const primaryDeep = Color(0xFF123B7A);
  static const navyDeep = Color(0xFF0A1F44);
  static const softBlue = Color(0xFFEAF1FF);
  static const gold = Color(0xFFE3B23C);
  static const goldLight = Color(0xFFF3D999);
  static const textDark = Color(0xFF10192E);
  static const textSecondary = Color(0xFF7386A8);
  static const border = Color(0xFFE7EEFC);
  static const red = Color(0xFFE5484D);
  static const green = Color(0xFF059669);
  static const shadow = Color(0x142D6CDF);

  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDeep, primaryDeep, primary],
  );
  static const gradientGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, goldLight],
  );
  static const gradientAvatarRing = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDeep, gold],
  );
}

// ─────────────────────────────────────────────────────────────
final postItemProvider =
    StateNotifierProvider.autoDispose<PostItemNotifier, NetworkPost>(
  (ref) => throw UnimplementedError('must override'),
);

class PostItemNotifier extends StateNotifier<NetworkPost> {
  PostItemNotifier(super.post, this.ref);
  final Ref ref;
  bool _likeBusy = false;

  Future<void> toggleLike() async {
    if (_likeBusy) return;
    _likeBusy = true;

    final wasLiked = state.isLiked;
    final oldCount = state.likesCount;

    state = state.copyWith(
      isLiked: !wasLiked,
      likesCount: wasLiked ? (oldCount - 1).clamp(0, 1 << 30) : oldCount + 1,
    );

    try {
      final s = ref.read(networkServiceProvider);
      try {
        final r = await s.togglePostLike(state.id);
        state = state.copyWith(isLiked: r.liked, likesCount: r.likesCount);
      } catch (_) {
        if (wasLiked) {
          await s.unlikePost(state.id);
        } else {
          await s.likePost(state.id);
        }
      }
    } catch (_) {
      state = state.copyWith(isLiked: wasLiked, likesCount: oldCount);
    } finally {
      _likeBusy = false;
    }
  }

  Future<void> toggleSave() async {
    final was = state.isSaved;
    state = state.copyWith(isSaved: !was);
    try {
      final s = ref.read(networkServiceProvider);
      if (was) {
        await s.unsavePost(state.id);
      } else {
        await s.savePost(state.id);
      }
    } catch (_) {
      state = state.copyWith(isSaved: was);
    }
  }

  void updateContent(String c) => state = state.copyWith(content: c);

  void incRepost() => state = state.copyWith(
        repostsCount: state.repostsCount + 1,
        isReposted: true,
      );
}

// ─────────────────────────────────────────────────────────────
class PostCard extends ConsumerStatefulWidget {
  final NetworkPost post;
  final String currentProfileId;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onRefresh;
  final VoidCallback? onPin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSave;

  const PostCard({
    super.key,
    required this.post,
    required this.currentProfileId,
    this.onLike,
    this.onComment,
    this.onTap,
    this.onShare,
    this.onRefresh,
    this.onPin,
    this.onEdit,
    this.onDelete,
    this.onSave,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isReposting = false;
  bool _isLikedAnimating = false;
  bool _isExpanded = false;
  final _quoteController = TextEditingController();

  static const _maxContentChars = 250;
  static const _maxParseDepth = 6;

  static final _richContentRegex = RegExp(
    r'\{c:(#[0-9A-Fa-f]{6,8})\}([\s\S]*?)\{c\}|'
    r'\*\*([\s\S]+?)\*\*|'
    r'\*([\s\S]+?)\*|'
    r'@(\w+)|'
    r'#(\w+)',
  );

  List<InlineSpan>? _cachedFullSpans;
  List<InlineSpan>? _cachedTruncatedSpans;
  bool _isTruncatable = false;
  final List<GestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _cacheParsedContent();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _quoteController.dispose();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _cacheParsedContent() {
    final content = widget.post.content;
    const baseStyle = TextStyle(
      fontSize: 14,
      height: 1.48,
      color: _PostColors.textDark,
    );
    _cachedFullSpans = _parseContent(content, baseStyle, 0);
    _isTruncatable = content.length > _maxContentChars;
    if (_isTruncatable) {
      var truncated = content.substring(0, _maxContentChars);
      final lastSpace = truncated.lastIndexOf(' ');
      if (lastSpace > 0) truncated = truncated.substring(0, lastSpace);
      _cachedTruncatedSpans =
          _parseContent('$truncated…', baseStyle, 0);
    } else {
      _cachedTruncatedSpans = _cachedFullSpans;
    }
  }

  List<InlineSpan> _parseContent(
    String content,
    TextStyle baseStyle,
    int depth,
  ) {
    if (depth > _maxParseDepth || content.isEmpty) {
      return [TextSpan(text: content, style: baseStyle)];
    }
    final spans = <InlineSpan>[];
    var lastIndex = 0;
    for (final match in _richContentRegex.allMatches(content)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: content.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }
      if (match.group(1) != null) {
        final hex = match.group(1)!.replaceFirst('#', '');
        final inner = match.group(2) ?? '';
        Color color;
        try {
          final argb = hex.length == 8 ? hex : 'FF$hex';
          color = Color(int.parse(argb, radix: 16));
        } catch (_) {
          color = baseStyle.color ?? _PostColors.textDark;
        }
        spans.addAll(
          _parseContent(inner, baseStyle.copyWith(color: color), depth + 1),
        );
      } else if (match.group(3) != null) {
        spans.addAll(_parseContent(
          match.group(3)!,
          baseStyle.copyWith(fontWeight: FontWeight.w800),
          depth + 1,
        ));
      } else if (match.group(4) != null) {
        spans.addAll(_parseContent(
          match.group(4)!,
          baseStyle.copyWith(fontStyle: FontStyle.italic),
          depth + 1,
        ));
      } else if (match.group(5) != null) {
        final value = match.group(5)!;
        final r = TapGestureRecognizer()
          ..onTap = () {
            if (mounted) context.push('/network/profile/$value');
          };
        _recognizers.add(r);
        spans.add(TextSpan(
          text: '@$value',
          style: baseStyle.merge(const TextStyle(
            color: _PostColors.primary,
            fontWeight: FontWeight.w700,
          )),
          recognizer: r,
        ));
      } else if (match.group(6) != null) {
        final value = match.group(6)!;
        final r = TapGestureRecognizer()
          ..onTap = () {
            if (mounted) context.push('/hashtag/$value');
          };
        _recognizers.add(r);
        spans.add(TextSpan(
          text: '#$value',
          style: baseStyle.merge(const TextStyle(
            color: _PostColors.gold,
            fontWeight: FontWeight.w700,
          )),
          recognizer: r,
        ));
      }
      lastIndex = match.end;
    }
    if (lastIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastIndex),
        style: baseStyle,
      ));
    }
    return spans;
  }

  Color? _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return null;
    final hexCode = hexColor.replaceAll('#', '');
    if (hexCode.length == 6 || hexCode.length == 8) {
      try {
        return Color(int.parse(
          hexCode.length == 6 ? 'FF$hexCode' : hexCode,
          radix: 16,
        ));
      } catch (_) {}
    }
    return null;
  }

  Widget _buildPostContent(NetworkPost post) {
    if (post.content.isEmpty) return const SizedBox.shrink();
    final bgColor = _parseColor(post.bgColor);
    if (bgColor != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          post.content,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: _isExpanded
                ? (_cachedFullSpans ?? [])
                : (_cachedTruncatedSpans ?? []),
          ),
        ),
        if (_isTruncatable)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _isExpanded ? 'Voir moins' : 'Voir plus',
                style: const TextStyle(
                  color: _PostColors.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getTimeAgo(DateTime dt) =>
      timeago.format(dt.toLocal(), locale: 'fr');

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }

  void _openPostDetails(String postId) {
    context
        .push('/network/comments/$postId')
        .then((_) => widget.onRefresh?.call());
  }

  void _openGallery(int initialIndex, List<String> urls) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(
          imageUrls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // ── IMAGE PLEINE LARGEUR ──
  Widget _buildImageGrid(List<String> urls, String postId) {
    if (urls.isEmpty) return const SizedBox.shrink();
    const spacing = 4.0;
    final radius = BorderRadius.circular(14);

    if (urls.length == 1) {
      return LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = (w * 1.05).clamp(220.0, 480.0);
          return GestureDetector(
            onTap: () => _openGallery(0, urls),
            child: ClipRRect(
              borderRadius: radius,
              child: SizedBox(
                width: w,
                height: h,
                child: Image.network(
                  urls[0],
                  width: w,
                  height: h,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  loadingBuilder: (_, child, p) {
                    if (p == null) return child;
                    return Container(
                      width: w,
                      height: h,
                      color: _PostColors.softBlue,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _PostColors.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    width: w,
                    height: h,
                    color: _PostColors.softBlue,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    Widget cell(int i, double h) => Expanded(
          child: GestureDetector(
            onTap: () => _openGallery(i, urls),
            child: ClipRRect(
              borderRadius: radius,
              child: Image.network(
                urls[i],
                width: double.infinity,
                height: h,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: _PostColors.softBlue,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        );

    if (urls.length == 2) {
      return SizedBox(
        height: 200,
        child: Row(children: [
          cell(0, 200),
          const SizedBox(width: spacing),
          cell(1, 200),
        ]),
      );
    }

    // 3+
    return SizedBox(
      height: 240,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () => _openGallery(0, urls),
              child: ClipRRect(
                borderRadius: radius,
                child: Image.network(
                  urls[0],
                  fit: BoxFit.cover,
                  height: 240,
                  width: double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(width: spacing),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openGallery(1, urls),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: Image.network(
                        urls[1],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: spacing),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openGallery(2, urls),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(urls[2], fit: BoxFit.cover),
                          if (urls.length > 3)
                            Container(
                              color: Colors.black54,
                              alignment: Alignment.center,
                              child: Text(
                                '+${urls.length - 3}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SONDAGE (design entreprise) ──
  Widget _buildPollWidget(NetworkPost post) {
    final pollData = post.pollData ?? {};
    final options = (pollData['options'] as List?) ?? [];
    if (options.isEmpty) return const SizedBox.shrink();

    var totalVotes = 0;
    for (final opt in options) {
      totalVotes += ((opt['votes'] as List?)?.length ?? 0);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _PostColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _PostColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.poll_rounded, size: 18, color: _PostColors.primary),
              SizedBox(width: 8),
              Text(
                'Sondage',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: _PostColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final opt = entry.value;
            final text = '${opt['text'] ?? ''}';
            final voters = (opt['votes'] as List?) ?? [];
            final pct = totalVotes > 0 ? voters.length / totalVotes : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    try {
                      await ref
                          .read(networkServiceProvider)
                          .votePoll(post.id, index);
                      if (!mounted) return;
                      widget.onRefresh?.call();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erreur vote: $e'),
                            backgroundColor: _PostColors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _PostColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _PostColors.border),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _PostColors.primary.withValues(alpha: 0.14),
                                    _PostColors.gold.withValues(alpha: 0.10),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                text,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: _PostColors.textDark,
                                ),
                              ),
                            ),
                            Text(
                              '${(pct * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _PostColors.primaryDeep,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
                      if (totalVotes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$totalVotes vote${totalVotes > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _PostColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );
    }


  // ── CHALLENGE (design entreprise) ──
  Widget _buildChallengeWidget(NetworkPost post) {
    final data = post.challengeData ?? {};
    final description = '${data['description'] ?? ''}';
    final participantsCount = data['participants_count'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_PostColors.softBlue, _PostColors.background],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _PostColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: _PostColors.gradientGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: _PostColors.navyDeep,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Challenge THIX',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _PostColors.textDark,
                  ),
                ),
              ),
              Text(
                '$participantsCount participants',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _PostColors.textSecondary,
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: _PostColors.textDark,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _PostColors.gradientPrimary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: _PostColors.shadow,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Participation enregistrée'),
                      backgroundColor: _PostColors.green,
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'RELEVER LE DÉFI',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── FACT-CHECK IA ──
  Widget _buildFactCheckBanner(bool isMisinformation, String? message) {
    if (!isMisinformation || message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _PostColors.red.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: _PostColors.red,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fact-Check THIX IA',
                  style: TextStyle(
                    color: _PostColors.red,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF7F1D1D),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionPill({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? color,
    Widget? animatedIcon,
  }) {
    final c = color ?? _PostColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              animatedIcon ?? Icon(icon, size: 18, color: c),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: c,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ProviderScope(
      overrides: [
        postItemProvider.overrideWith(
          (ref) => PostItemNotifier(widget.post, ref),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final post = ref.watch(postItemProvider);
          final isLiked =
              ref.watch(postItemProvider.select((p) => p.isLiked));
          final likesCount =
              ref.watch(postItemProvider.select((p) => p.likesCount));
          final isOwner = widget.currentProfileId == post.userId;

          return Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            decoration: BoxDecoration(
              color: _PostColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _PostColors.border),
              boxShadow: const [
                BoxShadow(
                  color: _PostColors.shadow,
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap ?? () => _openPostDetails(post.id),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => context
                                .push('/network/profile/${post.userId}'),
                            child: Container(
                              padding: const EdgeInsets.all(2.2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: _PostColors.gradientAvatarRing,
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: _PostColors.softBlue,
                                backgroundImage: post.authorAvatar != null &&
                                        post.authorAvatar!.isNotEmpty
                                    ? NetworkImage(post.authorAvatar!)
                                    : null,
                                child: post.authorAvatar == null ||
                                        post.authorAvatar!.isEmpty
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 19,
                                        color: _PostColors.primaryDeep,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => context
                                  .push('/network/profile/${post.userId}'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.authorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: _PostColors.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (post.authorTitle != null &&
                                      post.authorTitle!.isNotEmpty)
                                    Text(
                                      post.authorTitle!,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: _PostColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Text(
                                    _getTimeAgo(post.createdAt),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: _PostColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              size: 18,
                              color: _PostColors.primaryDeep,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            onSelected: (v) async {
                              final service =
                                  ref.read(networkServiceProvider);
                              switch (v) {
                                case 'delete':
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Supprimer ?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Annuler'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text(
                                            'Supprimer',
                                            style: TextStyle(
                                              color: _PostColors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await service.deletePost(post.id);
                                    if (!mounted) return;
                                    widget.onDelete?.call();
                                    widget.onRefresh?.call();
                                  }
                                  break;
                                case 'save':
                                  await ref
                                      .read(postItemProvider.notifier)
                                      .toggleSave();
                                  widget.onSave?.call();
                                  break;
                                case 'repost':
                                  await _repost(post, ref);
                                  break;
                                case 'hide':
                                  await service.hidePost(post.id);
                                  if (!mounted) return;
                                  widget.onRefresh?.call();
                                  break;
                                case 'share':
                                  widget.onShare?.call();
                                  break;
                              }
                            },
                            itemBuilder: (_) => [
                              if (isOwner)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Supprimer',
                                    style: TextStyle(color: _PostColors.red),
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'save',
                                child: Text('Sauvegarder'),
                              ),
                              const PopupMenuItem(
                                value: 'repost',
                                child: Text('Reposter'),
                              ),
                              const PopupMenuItem(
                                value: 'hide',
                                child: Text('Masquer'),
                              ),
                              const PopupMenuItem(
                                value: 'share',
                                child: Text('Partager'),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 13),
                      _buildPostContent(post),
                      _buildFactCheckBanner(
                        post.isMisinformation,
                        post.factCheckMessage,
                      ),

                      if (post.postType == 'poll') ...[
                        if (post.imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildImageGrid(post.imageUrls, post.id),
                        ],
                        const SizedBox(height: 10),
                        _buildPollWidget(post),
                      ] else if (post.postType == 'challenge') ...[
                        if (post.imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildImageGrid(post.imageUrls, post.id),
                        ],
                        const SizedBox(height: 10),
                        _buildChallengeWidget(post),
                      ] else if (post.imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildImageGrid(post.imageUrls, post.id),
                      ],

                      const SizedBox(height: 8),
                      const Divider(height: 1, color: _PostColors.border),

                      // Actions
                      Row(
                        children: [
                          _actionPill(
                            icon: isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            label: _formatCount(likesCount),
                            color: isLiked
                                ? _PostColors.red
                                : _PostColors.textSecondary,
                            animatedIcon: AnimatedScale(
                              scale: _isLikedAnimating ? 1.25 : 1.0,
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isLiked
                                    ? _PostColors.red
                                    : _PostColors.textSecondary,
                                size: 19,
                              ),
                            ),
                            onTap: () async {
                              setState(() => _isLikedAnimating = true);
                              await ref
                                  .read(postItemProvider.notifier)
                                  .toggleLike();
                              Future.delayed(
                                const Duration(milliseconds: 280),
                                () {
                                  if (mounted) {
                                    setState(
                                      () => _isLikedAnimating = false,
                                    );
                                  }
                                },
                              );
                              // Ne pas re-toggle côté parent
                              // widget.onLike?.call();
                            },
                          ),
                          _actionPill(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: _formatCount(post.commentsCount),
                            onTap: widget.onComment ??
                                () => _openPostDetails(post.id),
                          ),
                          _actionPill(
                            icon: Icons.repeat_rounded,
                            label: _formatCount(post.repostsCount),
                            color: post.isReposted
                                ? _PostColors.green
                                : _PostColors.textSecondary,
                            onTap: () => _repost(post, ref),
                          ),
                          _actionPill(
                            icon: Icons.share_rounded,
                            label: 'Partager',
                            onTap: widget.onShare,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _repost(NetworkPost post, WidgetRef ref) async {
    if (_isReposting) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reposter'),
        content: TextField(
          controller: _quoteController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Commentaire optionnel',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _PostColors.primary,
            ),
            child: const Text('Reposter'),
          ),
        ],
      ),
    );
    if (result != true) return;

    setState(() => _isReposting = true);
    final quote = _quoteController.text.trim();

    try {
      final created = await ref.read(networkServiceProvider).repostPost(
            post.id,
            quote: quote.isEmpty ? null : quote,
          );

      if (!mounted) return;

      // Compteur sur le post original
      ref.read(postItemProvider.notifier).incRepost();

      // 🔥 Carte visible en tête du fil (avec ton commentaire)
      if (created != null) {
        ref.read(feedProvider.notifier).addPostOnTop(created);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reposté sur votre fil'),
          backgroundColor: _PostColors.green,
        ),
      );
      // ❌ PAS de widget.onRefresh?.call() ici
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: _PostColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReposting = false);
      _quoteController.clear();
    }
  }
}
// ─────────────────────────────────────────────────────────────
class _FullScreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  const _FullScreenGallery({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, index) => Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Text(
                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
