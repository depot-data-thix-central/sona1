// lib/presentation/network/widgets/create_post_dialog.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart'; 
import 'package:image_picker/image_picker.dart'; 
import 'package:audioplayers/audioplayers.dart'; 

import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/services/ai/ai_service.dart';

class _C {
  static const bg = Color(0xFFF6F9FF);
  static const white = Color(0xFFFFFFFF);
  static const primary = Color(0xFF2D6CDF);
  static const primaryDeep = Color(0xFF123B7A);
  static const softBlue = Color(0xFFEAF1FF);
  static const gold = Color(0xFFD9A63C);
  static const textDark = Color(0xFF10192E);
  static const textSecondary = Color(0xFF7386A8);
  static const border = Color(0xFFE7EEFC);
  static const shadow = Color(0x142D6CDF);
  static const red = Color(0xFFE5484D);
  static const green = Color(0xFF059669);

  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1F44), primaryDeep, primary],
  );
}

Future<Uint8List> compressImageBytes(Uint8List bytes) async {
  if (kIsWeb) {
    return bytes;
  }
  
  try {
    return await FlutterImageCompress.compressWithList(
      bytes,
      minHeight: 1080,
      minWidth: 1080,
      quality: 85,
    );
  } catch (e) {
    debugPrint("Erreur de compression: $e");
    return bytes; 
  }
}

class _MediaItem {
  final Uint8List bytes;
  final String name;
  final bool isVideo;
  const _MediaItem(this.bytes, this.name, {this.isVideo = false});
}

class CreatePostDialog extends ConsumerStatefulWidget {
  final String? communityId;
  final VoidCallback? onPostCreated;
  const CreatePostDialog({super.key, this.communityId, this.onPostCreated});

  @override
  ConsumerState<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends ConsumerState<CreatePostDialog>
    with SingleTickerProviderStateMixin {
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();

  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _pollDurationDays = 1;

  final _challengeDescController = TextEditingController();
  final _challengeRewardController = TextEditingController();
  DateTime? _challengeEndDate;

  /// 0 standard · 1 sondage · 2 challenge
  int _postTypeMode = 0;

  Color _selectedBgColor = Colors.transparent;
  final List<Color> _bgColors = const [
    Colors.transparent,
    Color(0xFF00A4FF),
    Color(0xFFE5484D),
    Color(0xFF059669),
    Color(0xFFD9A63C),
    Color(0xFF8B5CF6),
    Color(0xFF10192E),
  ];

  final List<_MediaItem> _images = [];
  final List<_MediaItem> _videos = [];
  bool _isUploading = false;
  String? _errorMessage;
  String? _factCheckStatusLabel;

  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordDuration = 0;
  bool _isRecording = false;
  Uint8List? _audioBytes;
  String? _localAudioPath; 

  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _showMentions = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Color> _textColors = const [
    _C.textDark,
    _C.primary,
    _C.gold,
    _C.red,
    _C.green,
  ];

  // 🌟 NOUVEAU : Limite stricte pour les fonds colorés
  static const int _maxCharsForBgColor = 150;
  int _previousTextLength = 0;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onContentChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    _contentFocusNode.dispose();
    _challengeDescController.dispose();
    _challengeRewardController.dispose();
    for (final c in _pollOptionControllers) {
      c.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  bool get _hasBgColor => _selectedBgColor != Colors.transparent;
  
  // 🌟 MODIFIÉ : Vérifie que le texte ne dépasse pas la limite
  bool get _canHaveBgColor =>
      _postTypeMode == 0 && 
      _images.isEmpty && 
      _videos.isEmpty && 
      _audioBytes == null &&
      _contentController.text.length <= _maxCharsForBgColor;

  String _colorToHex(Color c) {
    final v = c.toARGB32();
    return '#${v.toRadixString(16).substring(2).toUpperCase()}';
  }

  void _onContentChanged() {
    final text = _contentController.text;
    final currentLength = text.length;

    // 🌟 NOUVEAU : Si on dépasse 150 caractères, on désactive le fond coloré en temps réel
    if ((_previousTextLength <= _maxCharsForBgColor && currentLength > _maxCharsForBgColor) ||
        (_previousTextLength > _maxCharsForBgColor && currentLength <= _maxCharsForBgColor)) {
      setState(() {
        if (currentLength > _maxCharsForBgColor && _hasBgColor) {
          _selectedBgColor = Colors.transparent; // Retire la couleur
        }
      });
    }
    _previousTextLength = currentLength;

    final lastAt = text.lastIndexOf('@');
    if (lastAt == -1) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    final query = text.substring(lastAt + 1);
    if (query.contains(' ') || query.contains('\n')) {
      setState(() => _showMentions = false);
    } else {
      setState(() => _showMentions = true);
      _searchUsers(query);
    }
  }

  Future<void> _searchUsers(String query) async {
    try {
      final users = await ref.read(networkServiceProvider).searchUsers(query);
      if (mounted) setState(() => _mentionSuggestions = users);
    } catch (e) {
      debugPrint('search: $e');
    }
  }

  void _insertMention(Map<String, dynamic> user) {
    final text = _contentController.text;
    final lastAt = text.lastIndexOf('@');
    final before = text.substring(0, lastAt);
    final newText = '$before@${user['display_name']} ';
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    setState(() => _showMentions = false);
  }

  void _wrapSelection(String prefix, String suffix) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (!sel.isValid) {
      final newText = '$text$prefix$suffix';
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: newText.length - suffix.length,
        ),
      );
    } else {
      final selected = text.substring(sel.start, sel.end);
      final newText =
          text.replaceRange(sel.start, sel.end, '$prefix$selected$suffix');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: sel.start + prefix.length + selected.length + suffix.length,
        ),
      );
    }
    _contentFocusNode.requestFocus();
  }

  void _applyBold() => _wrapSelection('**', '**');
  void _applyItalic() => _wrapSelection('*', '*');
  void _applyColor(Color color) {
    _wrapSelection('{c:${_colorToHex(color)}}', '{c}');
  }

  void _resetBgColorIfMediaAdded() {
    if (_hasBgColor) setState(() => _selectedBgColor = Colors.transparent);
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
          path: '', 
        );
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
          _audioBytes = null;
          _localAudioPath = null;
          _resetBgColorIfMediaAdded();
        });
        
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _recordDuration++);
          if (_recordDuration >= 120) { 
            _stopRecording();
          }
        });
      } else {
        setState(() => _errorMessage = 'Permission microphone refusée.');
      }
    } catch (e) {
      debugPrint('Erreur record: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        final file = XFile(path);
        final bytes = await file.readAsBytes();
        setState(() {
          _audioBytes = bytes;
          _localAudioPath = path; 
        });
      }
    } catch (e) {
      debugPrint('Erreur stop record: $e');
    }
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result != null && mounted) {
      setState(() {
        _resetBgColorIfMediaAdded();
        for (final f in result.files) {
          if (f.bytes != null) _images.add(_MediaItem(f.bytes!, f.name));
        }
      });
    }
  }

  Future<void> _pickVideos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
      withData: true,
    );
    if (result != null && mounted) {
      setState(() {
        _resetBgColorIfMediaAdded();
        for (final f in result.files) {
          if (f.bytes != null) {
            _videos.add(_MediaItem(f.bytes!, f.name, isVideo: true));
          }
        }
      });
    }
  }

  Future<void> _pickCamera() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty && mounted) {
      final f = result.files.first;
      if (f.bytes != null) {
        setState(() {
          _resetBgColorIfMediaAdded();
          _images.add(_MediaItem(f.bytes!, f.name));
        });
      }
    }
  }

  void _removeMedia(int index, bool isVideo) {
    setState(() {
      if (isVideo) {
        _videos.removeAt(index);
      } else {
        _images.removeAt(index);
      }
    });
  }

  Future<Map<String, String?>> _runFactCheck(String textContent) async {
    if (textContent.isEmpty) {
      return {'isMisinformation': 'false', 'message': null, 'severity': null};
    }

    final webSources = <String>[];
    try {
      final response = await Supabase.instance.client.rpc(
        'search_tavily',
        params: {'search_query': textContent},
      );
      if (response != null && response['results'] != null) {
        for (final r in response['results'] as List) {
          webSources.add(
            '- [${r['title'] ?? ''}](${r['url'] ?? ''}) : ${r['content'] ?? ''}',
          );
        }
      }
    } catch (e) {
      debugPrint('Tavily: $e');
    }

    if (webSources.isEmpty) {
      return {'isMisinformation': 'false', 'message': null, 'severity': null};
    }

    try {
      final ai = AiService(Supabase.instance.client);
      final today = DateTime.now();
      final prompt = '''
Date actuelle : ${today.day}/${today.month}/${today.year}

SOURCES WEB :
${webSources.join('\n')}

RÈGLES :
1. Vérifie UNIQUEMENT Gouvernements, Visas, Lois, Élections.
2. Histoires perso / entreprises privées → SAFE.
3. FAKE seulement si fausse info officielle avérée.

PUBLICATION : "$textContent"

Réponds : SAFE ou FAKE: [raison]
''';

      final aiResponse = await ai.askAi(
        prompt: prompt,
        provider: AiProvider.mistral,
        systemPrompt:
            'Fact-checker gouvernemental. SAFE pour le privé. Réponds SAFE ou FAKE: raison.',
      );

      final upper = aiResponse.trim().toUpperCase();
      if (upper.startsWith('FAKE:')) {
        final msg = aiResponse
            .substring(aiResponse.toUpperCase().indexOf('FAKE:') + 5)
            .trim();
        return {'isMisinformation': 'true', 'message': msg, 'severity': 'fake'};
      }
    } catch (e) {
      debugPrint('Fact-check AI: $e');
    }

    return {'isMisinformation': 'false', 'message': null, 'severity': null};
  }

  // ─────────────────────────────────────────────────────────────
  // PUBLISH — insert + post en tête du feed
  // ─────────────────────────────────────────────────────────────

  Future<void> _publishPost() async {
    final textContent = _contentController.text.trim();
    setState(() => _errorMessage = null);

    if (_postTypeMode == 0 && textContent.isEmpty && _images.isEmpty && _videos.isEmpty && _audioBytes == null) {
      setState(() => _errorMessage = 'Ajoutez du texte, un média ou un audio');
      return;
    }
    if (_postTypeMode == 1 && textContent.isEmpty) {
      setState(() => _errorMessage = 'Saisissez la question du sondage');
      return;
    }
    if (_postTypeMode == 2 && (textContent.isEmpty || _challengeEndDate == null || _challengeDescController.text.trim().isEmpty)) {
      setState(() => _errorMessage = 'Titre, description et date de fin obligatoires');
      return;
    }

    setState(() {
      _isUploading = true;
      _factCheckStatusLabel = textContent.isNotEmpty ? 'Vérification en cours…' : null;
    });

    try {
      final ns = ref.read(networkServiceProvider);
      final factCheckResult = await _runFactCheck(textContent).timeout(
        const Duration(seconds: 10),
        onTimeout: () => {'isMisinformation': 'false', 'message': null, 'severity': null},
      );

      final isMisinfo = factCheckResult['isMisinformation'] == 'true';
      final fcMessage = factCheckResult['message'];
      final fcSeverity = factCheckResult['severity'];

      if (mounted) setState(() => _factCheckStatusLabel = 'Envoi des médias…');

      final allMedia = <String>[];

      if (_audioBytes != null) {
        final url = await ns.uploadAudioBytes(_audioBytes!);
        if (url != null && url.isNotEmpty) allMedia.add(url);
      }

      for (final item in _images) {
        final compressed = await compressImageBytes(item.bytes);
        final ext = item.name.split('.').last;
        final url = await ns.uploadImageBytes(compressed, fileExtension: ext, bucket: 'post_images');
        if (url != null && url.isNotEmpty) allMedia.add(url);
      }

      for (final item in _videos) {
        final ext = item.name.split('.').last;
        final url = await ns.uploadImageBytes(item.bytes, fileExtension: ext, bucket: 'videos');
        if (url != null && url.isNotEmpty) allMedia.add(url);
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Non authentifié');

      String authorName = 'Moi';
      String? authorAvatar;
      String? authorTitle;
      try {
        final pr = await Supabase.instance.client
            .from('profiles')
            .select('display_name, avatar_url, profession')
            .eq('id', user.id)
            .maybeSingle();
        if (pr != null) {
          authorName = pr['display_name']?.toString() ?? authorName;
          authorAvatar = pr['avatar_url']?.toString();
          authorTitle = pr['profession']?.toString();
        }
      } catch (_) {}

      final payload = <String, dynamic>{
        'user_id': user.id,
        'content': textContent,
        'is_public': true,
        'is_fact_checked': true,
        'is_misinformation': isMisinfo,
        'fact_check_message': fcMessage,
        'fact_check_severity': fcSeverity,
        'image_urls': allMedia,
        'media_urls': allMedia,
        'media_url': allMedia.isNotEmpty ? allMedia.first : null,
        'community_id': widget.communityId,
        'post_type': 'standard',
      };

      if (_postTypeMode == 0 && _audioBytes != null && _images.isEmpty && _videos.isEmpty) {
        payload['post_type'] = 'audio';
      }

      if (_canHaveBgColor && _hasBgColor) {
        payload['bg_color'] = _colorToHex(_selectedBgColor);
      }

      if (_postTypeMode == 1) {
        final options = _pollOptionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
        if (options.length < 2) {
          setState(() { _errorMessage = 'Au moins 2 options pour le sondage'; _isUploading = false; _factCheckStatusLabel = null; });
          return;
        }
        payload['post_type'] = 'poll';
        payload['poll_data'] = {
          'options': options.map((o) => {'text': o, 'votes': []}).toList(),
          'end_date': DateTime.now().add(Duration(days: _pollDurationDays)).toIso8601String(),
        };
      } else if (_postTypeMode == 2) {
        payload['post_type'] = 'challenge';
        payload['challenge_data'] = {
          'description': _challengeDescController.text.trim(),
          'reward': _challengeRewardController.text.trim(),
          'end_date': _challengeEndDate?.toIso8601String(),
          'participants_count': 0,
          'participants': [],
        };
      }

      final inserted = await Supabase.instance.client.from('posts').insert(payload).select().single();
      final postId = inserted['id']?.toString() ?? '';
      final createdAt = DateTime.tryParse(inserted['created_at']?.toString() ?? '') ?? DateTime.now();

      final newPost = NetworkPost(
        id: postId, userId: user.id, authorName: authorName, authorAvatar: authorAvatar, authorTitle: authorTitle,
        content: textContent, bgColor: payload['bg_color'] as String?, mediaUrls: allMedia,
        postType: payload['post_type'] as String? ?? 'standard', pollData: payload['poll_data'] as Map<String, dynamic>?,
        challengeData: payload['challenge_data'] as Map<String, dynamic>?, isFactChecked: true, isMisinformation: isMisinfo,
        factCheckMessage: fcMessage, factCheckSeverity: fcSeverity, createdAt: createdAt, likesCount: 0, commentsCount: 0,
        repostsCount: 0, isLiked: false, isSaved: false, isReposted: false, isPublic: true,
      );

      try { ref.read(feedProvider.notifier).addPostOnTop(newPost); } catch (_) { ref.invalidate(feedProvider); }
      widget.onPostCreated?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isMisinfo ? 'Publié avec avertissement Fact-Check' : 'Publication réussie'), backgroundColor: isMisinfo ? Colors.orange : _C.primary));
      Navigator.pop(context, newPost);
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Erreur: $e'; _isUploading = false; _factCheckStatusLabel = null; });
    }
  }

  // ─────────────────────────── UI helpers ───────────────────────────

  Widget _typeTab(String label, int mode, IconData icon) {
    final sel = _postTypeMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _postTypeMode = mode),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: sel ? _C.gradientPrimary : null,
            color: sel ? null : _C.softBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: sel ? Colors.white : _C.primaryDeep),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: sel ? Colors.white : _C.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formatBtn({required Widget child, required VoidCallback onTap, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 30, height: 30, alignment: Alignment.center,
          decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: _C.shadow, blurRadius: 4, offset: Offset(0, 2))]),
          child: child,
        ),
      ),
    );
  }

  Widget _mediaBtn(IconData icon, VoidCallback onTap, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: (_isUploading || _isRecording) ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: _C.softBlue, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: _C.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.94,
          constraints: const BoxConstraints(maxHeight: 760),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) => _C.gradientPrimary.createShader(b),
                    child: const Text('Créer une publication', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _isUploading ? null : () => Navigator.pop(context),
                    child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: _C.softBlue, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 18)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _typeTab('Publication', 0, Icons.article_rounded),
                  const SizedBox(width: 6),
                  _typeTab('Sondage', 1, Icons.poll_rounded),
                  const SizedBox(width: 6),
                  _typeTab('Challenge', 2, Icons.emoji_events_rounded),
                ],
              ),
              const SizedBox(height: 12),

              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFFEAEA), borderRadius: BorderRadius.circular(14)),
                  child: Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: _C.red)),
                ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_postTypeMode != 2 && !_hasBgColor) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: _C.softBlue, borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              _formatBtn(child: const Text('B', style: TextStyle(fontWeight: FontWeight.w900)), onTap: _applyBold, tooltip: 'Gras'),
                              const SizedBox(width: 6),
                              _formatBtn(child: const Text('I', style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w800)), onTap: _applyItalic, tooltip: 'Italique'),
                              Container(width: 1, height: 20, color: _C.border, margin: const EdgeInsets.symmetric(horizontal: 8)),
                              for (final color in _textColors)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: GestureDetector(
                                    onTap: () => _applyColor(color),
                                    child: Container(width: 20, height: 20, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Zone texte
                      Container(
                        decoration: BoxDecoration(
                          color: _canHaveBgColor && _hasBgColor ? _selectedBgColor : _C.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _canHaveBgColor && _hasBgColor ? _selectedBgColor : _C.border),
                        ),
                        padding: _canHaveBgColor && _hasBgColor ? const EdgeInsets.symmetric(horizontal: 20, vertical: 40) : const EdgeInsets.all(14),
                        alignment: _canHaveBgColor && _hasBgColor ? Alignment.center : Alignment.topLeft,
                        child: TextField(
                          controller: _contentController,
                          focusNode: _contentFocusNode,
                          minLines: _postTypeMode == 2 ? 2 : (_canHaveBgColor && _hasBgColor ? null : 5),
                          maxLines: _canHaveBgColor && _hasBgColor ? null : 10,
                          textAlign: _canHaveBgColor && _hasBgColor ? TextAlign.center : TextAlign.start,
                          style: TextStyle(color: _canHaveBgColor && _hasBgColor ? Colors.white : _C.textDark, fontSize: _canHaveBgColor && _hasBgColor ? 22 : 14, fontWeight: _canHaveBgColor && _hasBgColor ? FontWeight.bold : FontWeight.normal),
                          decoration: InputDecoration(
                            hintText: _postTypeMode == 1 ? 'Posez votre question...' : _postTypeMode == 2 ? 'Titre du challenge...' : 'Exprimez-vous...',
                            hintStyle: TextStyle(color: _canHaveBgColor && _hasBgColor ? Colors.white70 : Colors.black45),
                            border: InputBorder.none, isCollapsed: true,
                          ),
                        ),
                      ),

                      if (_isRecording)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: _C.red.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.red.withOpacity(0.3))),
                          child: Row(
                            children: [
                              const Icon(Icons.mic, color: _C.red), const SizedBox(width: 12),
                              Text('Enregistrement... ${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')} / 02:00', style: const TextStyle(color: _C.red, fontWeight: FontWeight.w800)),
                              const Spacer(),
                              GestureDetector(onTap: _stopRecording, child: const Icon(Icons.stop_circle_rounded, color: _C.red, size: 32)),
                            ],
                          ),
                        )
                      else if (_localAudioPath != null)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: _C.primaryDeep, borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              Expanded(child: _DialogAudioPlayer(audioPath: _localAudioPath!)),
                              IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70), onPressed: () => setState(() { _audioBytes = null; _localAudioPath = null; })),
                            ],
                          ),
                        ),

                      // 🌟 AFFICHAGE DES COULEURS OU DU MESSAGE D'AVERTISSEMENT
                      if (_canHaveBgColor)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: _bgColors.map((c) {
                              final sel = _selectedBgColor == c;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedBgColor = c),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8), width: 32, height: 32,
                                  decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: sel ? _C.textDark : Colors.grey.shade300, width: sel ? 2.5 : 1.5)),
                                  child: c == Colors.transparent ? const Icon(Icons.format_color_reset_rounded, size: 16, color: Colors.black54) : null,
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      else if (_postTypeMode == 0 && _images.isEmpty && _videos.isEmpty && _audioBytes == null && _contentController.text.length > _maxCharsForBgColor)
                        Padding(
                          padding: const EdgeInsets.only(top: 10, left: 4),
                          child: Text(
                            'Texte trop long pour un fond coloré (max $_maxCharsForBgColor caractères).',
                            style: const TextStyle(fontSize: 12, color: _C.textSecondary, fontStyle: FontStyle.italic),
                          ),
                        ),

                      // Sondage
                      if (_postTypeMode == 1) ...[
                        const SizedBox(height: 14),
                        const Text('Options', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 8),
                        ..._pollOptionControllers.asMap().entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: e.value,
                                    decoration: InputDecoration(
                                      hintText: 'Option ${e.key + 1}', filled: true, fillColor: _C.bg,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ),
                                if (e.key > 1) 
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: _C.red),
                                    onPressed: () {
                                      setState(() {
                                        _pollOptionControllers[e.key].dispose();
                                        _pollOptionControllers.removeAt(e.key);
                                      });
                                    },
                                  )
                              ],
                            ),
                          );
                        }),
                        if (_pollOptionControllers.length < 4)
                          TextButton.icon(
                            onPressed: () => setState(() => _pollOptionControllers.add(TextEditingController())),
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Ajouter une option'),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(12)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _pollDurationDays, isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('1 jour')),
                                DropdownMenuItem(value: 3, child: Text('3 jours')),
                                DropdownMenuItem(value: 7, child: Text('1 semaine')),
                              ],
                              onChanged: (v) => setState(() => _pollDurationDays = v ?? 1),
                            ),
                          ),
                        ),
                      ],

                      // Challenge
                      if (_postTypeMode == 2) ...[
                        const SizedBox(height: 14),
                        const Text('Description du Challenge', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _challengeDescController, minLines: 3, maxLines: 5,
                          decoration: InputDecoration(hintText: 'Expliquez les règles et comment participer...', filled: true, fillColor: _C.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _challengeRewardController,
                          decoration: InputDecoration(hintText: 'Récompense (optionnel)', filled: true, fillColor: _C.bg, prefixIcon: const Icon(Icons.card_giftcard_rounded, size: 18, color: _C.gold), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: _C.bg,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _challengeEndDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 16, color: _C.primary),
                          label: Text(
                            _challengeEndDate == null ? 'Choisir la date de fin' : 'Date de fin: ${_challengeEndDate!.day}/${_challengeEndDate!.month}/${_challengeEndDate!.year}',
                            style: const TextStyle(color: _C.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],

                      if (_showMentions && _mentionSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
                          child: Column(
                            children: _mentionSuggestions.map((u) => ListTile(dense: true, title: Text(u['display_name'] ?? '', style: const TextStyle(fontSize: 13)), onTap: () => _insertMention(u))).toList(),
                          ),
                        ),

                      if (_images.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 8, runSpacing: 8,
                            children: [
                              for (int i = 0; i < _images.length; i++)
                                Stack(
                                  children: [
                                    ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(_images[i].bytes, width: 84, height: 84, fit: BoxFit.cover)),
                                    Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => _removeMedia(i, false), child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 13, color: Colors.white)))),
                                  ],
                                ),
                            ],
                          ),
                        ),

                      if (_videos.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              for (int i = 0; i < _videos.length; i++)
                                Stack(
                                  children: [
                                    Container(width: 84, height: 84, decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(14)), child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30))),
                                    Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => _removeMedia(i, true), child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 13, color: Colors.white)))),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (_factCheckStatusLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text(_factCheckStatusLabel!, style: const TextStyle(fontSize: 12, color: _C.textSecondary)),
                    ],
                  ),
                ),

              Row(
                children: [
                  _mediaBtn(Icons.photo_rounded, _pickImages, _C.green),
                  _mediaBtn(Icons.videocam_rounded, _pickVideos, _C.red),
                  _mediaBtn(Icons.photo_camera_rounded, _pickCamera, _C.primary),
                  _mediaBtn(
                    _isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                    _isRecording ? _stopRecording : _startRecording,
                    _C.gold,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: (_isUploading || _isRecording) ? null : _C.gradientPrimary,
                    color: (_isUploading || _isRecording) ? _C.border : null,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: ElevatedButton(
                    onPressed: (_isUploading || _isRecording) ? null : _publishPost, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isUploading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('PUBLIER', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogAudioPlayer extends StatefulWidget {
  final String audioPath;
  const _DialogAudioPlayer({required this.audioPath});

  @override
  State<_DialogAudioPlayer> createState() => _DialogAudioPlayerState();
}

class _DialogAudioPlayerState extends State<_DialogAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _player.setSourceUrl(widget.audioPath);
    } else {
      _player.setSourceDeviceFile(widget.audioPath);
    }
    
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (_isPlaying) _player.pause();
            else _player.resume();
          },
          child: Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(color: _C.gold, shape: BoxShape.circle),
            child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: _C.primaryDeep, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: _C.gold,
              inactiveTrackColor: Colors.white30,
              thumbColor: _C.gold,
            ),
            child: Slider(
              min: 0,
              max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
              value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0),
              onChanged: (val) {
                _player.seek(Duration(milliseconds: val.toInt()));
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_duration.inSeconds > 0 && !_isPlaying && _position.inSeconds == 0 ? _duration : _position),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }
}
