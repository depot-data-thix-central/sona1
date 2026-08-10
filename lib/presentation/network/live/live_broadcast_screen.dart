// lib/presentation/network/live/live_broadcast_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Import de la charte graphique officielle
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ✅ La classe _C dépend désormais entièrement de ThixPolicy
class _C {
  static const primary = ThixPolicy.primary;
  static const red = ThixPolicy.danger; 
  static const bgDark = ThixPolicy.inkDeep;
  // Les textes sur une vidéo live doivent rester clairs pour la lisibilité
  static const textMain = Colors.white; 
  static const textMuted = Colors.white70;
}

class LiveBroadcastScreen extends StatefulWidget {
  final String title;
  final bool isVideoEnabled;
  final bool isMicEnabled;
  final String liveId;
  final String channelName;

  const LiveBroadcastScreen({
    super.key,
    required this.title,
    required this.isVideoEnabled,
    required this.isMicEnabled,
    required this.liveId,
    required this.channelName,
  });

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> with TickerProviderStateMixin {
  late RtcEngine _engine;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isEnding = false;

  // Fonctionnalités avancées
  bool _isFrontCamera = true;
  bool _isBeautyEnabled = false;
  int _viewerCount = 1; // Simulé pour l'UI
  
  // Chat
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _comments = [
    {"user": "Système", "text": "Bienvenue dans le direct !"},
    {"user": "Sarah Mitonga", "text": "Super initiative 🚀"},
  ];

  // Animation Coeurs
  final List<Widget> _floatingHearts = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _isMuted = !widget.isMicEnabled;
    _isVideoOff = !widget.isVideoEnabled;
    _initAgora();
  }

  Future<void> _initAgora() async {
    try {
      if (!kIsWeb) {
        await [Permission.camera, Permission.microphone].request();
      }

      final safeChannelName = widget.channelName;

      final response = await Supabase.instance.client.functions.invoke(
        'get-agora-token',
        body: {'channelName': safeChannelName, 'uid': 0, 'isHost': true},
      );
      
      final data = response.data as Map<String, dynamic>;
      final appId = data['appId'] as String;
      final token = data['token'] as String;

      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      if (!_isVideoOff) {
        await _engine.enableVideo();
        await _engine.startPreview();
      }

      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      await _engine.joinChannel(
        token: token,
        channelId: safeChannelName,
        uid: 0,
        options: ChannelMediaOptions(
          publishCameraTrack: !_isVideoOff,
          publishMicrophoneTrack: !_isMuted,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      if (mounted) setState(() => _isInitialized = true);

    } catch (e) {
      debugPrint('Erreur init Agora: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _C.red));
      }
    }
  }

  // ─── ACTIONS AGORA ───

  Future<void> _switchCamera() async {
    if (!_isInitialized) return;
    await _engine.switchCamera();
    setState(() => _isFrontCamera = !_isFrontCamera);
  }

  Future<void> _toggleBeautyEffect() async {
    if (!_isInitialized) return;
    setState(() => _isBeautyEnabled = !_isBeautyEnabled);
    
    await _engine.setBeautyEffectOptions(
      enabled: _isBeautyEnabled,
      options: const BeautyOptions(
        lighteningContrastLevel: LighteningContrastLevel.lighteningContrastNormal,
        lighteningLevel: 0.7,
        smoothnessLevel: 0.5,
        rednessLevel: 0.1,
      ),
    );
  }

  Future<void> _endBroadcast() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);

    try {
      await Supabase.instance.client.from('live_sessions').delete().eq('id', widget.liveId);
      if (_isInitialized) {
        await _engine.leaveChannel();
        await _engine.release();
      }
    } catch (e) {
      debugPrint('Erreur fermeture: $e');
    }

    if (mounted) Navigator.pop(context);
  }

  // ─── ANIMATION COEURS (Effet TikTok) ───
  void _addHeart() {
    final key = UniqueKey();
    setState(() {
      _floatingHearts.add(_AnimatedHeart(
        key: key,
        color: Colors.primaries[_random.nextInt(Colors.primaries.length)],
        onComplete: () {
          setState(() {
            _floatingHearts.removeWhere((w) => w.key == key);
          });
        },
      ));
    });
  }

  void _sendComment() {
    if (_chatController.text.trim().isEmpty) return;
    setState(() {
      _comments.add({"user": "Hôte (Vous)", "text": _chatController.text.trim()});
      _chatController.clear();
    });
    // Fermer le clavier
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    if (!_isEnding) _endBroadcast(); 
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _endBroadcast();
      },
      child: Scaffold(
        backgroundColor: _C.bgDark,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // 1. FOND VIDÉO
            Positioned.fill(
              child: _isInitialized && !_isVideoOff
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          child: AgoraVideoView(
                            controller: VideoViewController(
                              rtcEngine: _engine,
                              canvas: const VideoCanvas(uid: 0),
                              useFlutterTexture: kIsWeb,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: _C.bgDark,
                      child: const Center(child: Icon(Icons.videocam_off_rounded, size: 80, color: Colors.white24)),
                    ),
            ),

            // 2. DÉGRADÉS HAUT ET BAS (Lisibilité)
            Positioned(
              top: 0, left: 0, right: 0,
              height: 140,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: 300,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
              ),
            ),

            // 3. TOP BAR (Hôte, Vues, Quitter)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Hôte
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: _C.primary,
                            child: Icon(Icons.person, size: 20, color: _C.textMain),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('THIX Host', style: TextStyle(color: _C.textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                              Row(
                                children: [
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: _C.red, shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  const Text('EN DIRECT', style: TextStyle(color: _C.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                    const Spacer(),
                    
                    // Compteur de vues
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility_rounded, color: _C.textMain, size: 14),
                          const SizedBox(width: 4),
                          Text('$_viewerCount', style: const TextStyle(color: _C.textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Bouton Quitter
                    GestureDetector(
                      onTap: _endBroadcast,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: _isEnding 
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _C.textMain, strokeWidth: 2))
                          : const Icon(Icons.close_rounded, color: _C.textMain, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. BARRE D'ACTIONS LATÉRALE (Droite)
            Positioned(
              right: 16,
              bottom: 100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SideActionButton(
                    icon: Icons.flip_camera_ios_rounded,
                    label: 'Tourner',
                    onTap: _switchCamera,
                  ),
                  _SideActionButton(
                    icon: _isBeautyEnabled ? Icons.face_retouching_natural_rounded : Icons.face_rounded,
                    label: 'Beauté',
                    color: _isBeautyEnabled ? _C.primary : _C.textMain,
                    onTap: _toggleBeautyEffect,
                  ),
                  _SideActionButton(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _isMuted ? 'Muet' : 'Mic',
                    onTap: () {
                      setState(() => _isMuted = !_isMuted);
                      if (_isInitialized) _engine.muteLocalAudioStream(_isMuted);
                    },
                  ),
                  _SideActionButton(
                    icon: Icons.share_rounded,
                    label: 'Partager',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié !')));
                    },
                  ),
                ],
              ),
            ),

            // 5. ZONE DE CHAT DÉFILANTE (Gauche)
            Positioned(
              left: 16,
              bottom: 80,
              width: MediaQuery.of(context).size.width * 0.7,
              height: 250,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.white, Colors.white],
                    stops: [0.0, 0.2, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ListView.builder(
                  reverse: true, // Les nouveaux messages en bas
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[_comments.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${comment["user"]}   ',
                                style: TextStyle(color: _C.textMain.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              TextSpan(
                                text: comment["text"],
                                style: const TextStyle(color: _C.textMain, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 6. ZONE DE SAISIE ET LIKE (En bas)
            Positioned(
              left: 16, right: 16, bottom: 20,
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                        ),
                        child: TextField(
                          controller: _chatController,
                          style: const TextStyle(color: _C.textMain, fontSize: 14),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendComment(),
                          decoration: const InputDecoration(
                            hintText: 'Ajouter un commentaire...',
                            hintStyle: TextStyle(color: _C.textMuted),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _addHeart,
                      child: Container(
                        width: 44, height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [_C.red, Colors.orange]),
                        ),
                        child: const Icon(Icons.favorite_rounded, color: _C.textMain, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 7. OVERLAY COEURS ANIMÉS
            ..._floatingHearts,
          ],
        ),
      ),
    );
  }
}

// ─── COMPOSANT : BOUTON LATÉRAL ───
class _SideActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _SideActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = _C.textMain,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: _C.textMain, fontSize: 11, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black54, blurRadius: 2)])),
          ],
        ),
      ),
    );
  }
}

// ─── COMPOSANT : COEUR ANIMÉ FLOTTANT ───
class _AnimatedHeart extends StatefulWidget {
  final Color color;
  final VoidCallback onComplete;

  const _AnimatedHeart({super.key, required this.color, required this.onComplete});

  @override
  State<_AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<_AnimatedHeart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  final Random _random = Random();
  late double _horizontalOffset;

  @override
  void initState() {
    super.initState();
    _horizontalOffset = (_random.nextDouble() * 60) - 30; // Variation gauche/droite

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    
    _positionAnimation = Tween<double>(begin: 0, end: 400).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          bottom: 70 + _positionAnimation.value,
          right: 25 + _horizontalOffset + (sin(_positionAnimation.value / 30) * 20), // Trajectoire en S
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Icon(Icons.favorite_rounded, color: widget.color, size: 28),
            ),
          ),
        );
      },
    );
  }
}
