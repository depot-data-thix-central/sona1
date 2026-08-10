// lib/presentation/network/live/live_broadcast_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ Ajout du cache
import 'package:thix_id/core/theme/thix_design_policy.dart';

class _C {
  static const primary = ThixPolicy.primary;
  static const red = ThixPolicy.danger; 
  static const bgDark = ThixPolicy.inkDeep;
  static const textMain = Colors.white; 
  static const textMuted = Colors.white70;
}

class LiveBroadcastScreen extends StatefulWidget {
  final String title;
  final bool isVideoEnabled;
  final bool isMicEnabled;
  final String liveId;
  final String channelName;
  final String hostName; // Nom de l'hôte
  final String? hostAvatarUrl; // ✅ URL de l'avatar avec Cache

  const LiveBroadcastScreen({
    super.key,
    required this.title,
    required this.isVideoEnabled,
    required this.isMicEnabled,
    required this.liveId,
    required this.channelName,
    this.hostName = 'Hôte THIX',
    this.hostAvatarUrl,
  });

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> with TickerProviderStateMixin {
  late RtcEngine _engine;
  RealtimeChannel? _realtimeChannel; 
  
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isEnding = false;

  bool _isFrontCamera = true;
  bool _isBeautyEnabled = false;
  
  int _viewerCount = 0; 
  final List<int> _coHostUids = []; 
  
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _comments = [];
  final List<Widget> _floatingHearts = [];
  final Random _random = Random();

  String get _myUserId => Supabase.instance.client.auth.currentUser?.id ?? 'host';

  @override
  void initState() {
    super.initState();
    _isMuted = !widget.isMicEnabled;
    _isVideoOff = !widget.isVideoEnabled;
    _initAgora();
    _initRealtime();
  }

  // ─── 1. INITIALISATION AGORA ───
  Future<void> _initAgora() async {
    try {
      if (!kIsWeb) await [Permission.camera, Permission.microphone].request();

      final response = await Supabase.instance.client.functions.invoke(
        'get-agora-token',
        body: {'channelName': widget.channelName, 'uid': 0, 'isHost': true},
      );
      final data = response.data as Map<String, dynamic>;

      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: data['appId'],
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      if (!_isVideoOff) {
        await _engine.enableVideo();
        await _engine.startPreview();
      }

      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            setState(() {
              if (!_coHostUids.contains(remoteUid)) _coHostUids.add(remoteUid);
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            setState(() {
              _coHostUids.remove(remoteUid);
            });
          },
        ),
      );

      await _engine.joinChannel(
        token: data['token'],
        channelId: widget.channelName,
        uid: 0,
        options: ChannelMediaOptions(
          publishCameraTrack: !_isVideoOff,
          publishMicrophoneTrack: !_isMuted,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Erreur Agora: $e');
    }
  }

  // ─── 2. INITIALISATION SUPABASE REALTIME (VRAI TEMPS RÉEL) ───
  void _initRealtime() {
    _realtimeChannel = Supabase.instance.client.channel('live_${widget.liveId}');

    _realtimeChannel!
      .onBroadcast(event: 'chat', callback: (payload) {
        setState(() => _comments.add({"user": payload['user'], "text": payload['text']}));
      })
      .onBroadcast(event: 'heart', callback: (payload) {
        _triggerHeartAnimation();
      })
      .onBroadcast(event: 'cohost_request', callback: (payload) {
        _handleCoHostRequest(payload['userId'], payload['userName']);
      })
      .onPresenceSync((_) {
  final state = _realtimeChannel!.presenceState();
  final int count = state.length;
  
  setState(() => _viewerCount = count > 0 ? count - 1 : 0); // On s'exclut du comptage
})
.subscribe((status, [error]) {
  if (status == RealtimeSubscribeStatus.subscribed) {
    _realtimeChannel!.track({'user_id': _myUserId, 'is_host': true});
  }
});

  }

  // ─── GESTION DES CO-HÔTES ───
  void _handleCoHostRequest(String requestUserId, String requestUserName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bgDark,
        title: const Text('Demande de participation', style: TextStyle(color: _C.textMain)),
        content: Text('$requestUserName souhaite rejoindre le direct en vidéo.', style: const TextStyle(color: _C.textMuted)),
        actions: [
          TextButton(
            onPressed: () {
              _realtimeChannel!.sendBroadcastMessage(event: 'cohost_response', payload: {'targetUserId': requestUserId, 'accepted': false});
              Navigator.pop(ctx);
            },
            child: const Text('Refuser', style: TextStyle(color: _C.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.primary),
            onPressed: () {
              _realtimeChannel!.sendBroadcastMessage(event: 'cohost_response', payload: {'targetUserId': requestUserId, 'accepted': true});
              Navigator.pop(ctx);
            },
            child: const Text('Accepter', style: TextStyle(color: _C.textMain)),
          ),
        ],
      ),
    );
  }

  // ─── ACTIONS ───
  void _sendComment() {
    if (_chatController.text.trim().isEmpty) return;
    final text = _chatController.text.trim();
    
    _realtimeChannel!.sendBroadcastMessage(event: 'chat', payload: {'user': widget.hostName, 'text': text});
    setState(() {
      _comments.add({"user": widget.hostName, "text": text});
      _chatController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _triggerHeartAnimation() {
    final key = UniqueKey();
    setState(() {
      _floatingHearts.add(_AnimatedHeart(
        key: key,
        color: Colors.primaries[_random.nextInt(Colors.primaries.length)],
        onComplete: () => setState(() => _floatingHearts.removeWhere((w) => w.key == key)),
      ));
    });
  }

  Future<void> _endBroadcast() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);

    try {
      await Supabase.instance.client.from('live_sessions').delete().eq('id', widget.liveId);
      _realtimeChannel?.unsubscribe();
      if (_isInitialized) {
        await _engine.leaveChannel();
        await _engine.release();
      }
    } catch (e) {
      debugPrint('Erreur fermeture: $e');
    }
    if (mounted) Navigator.pop(context);
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
            // 1. FOND VIDÉO HÔTE
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
                              rtcEngine: _engine, canvas: const VideoCanvas(uid: 0), useFlutterTexture: kIsWeb,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(color: _C.bgDark, child: const Center(child: Icon(Icons.videocam_off_rounded, size: 80, color: Colors.white24))),
            ),

            // 2. DÉGRADÉS LISIBILITÉ
            Positioned(top: 0, left: 0, right: 0, height: 140, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.6), Colors.transparent])))),
            Positioned(bottom: 0, left: 0, right: 0, height: 300, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])))),

            // 3. VIDÉOS DES CO-HÔTES (Flottantes)
            if (_coHostUids.isNotEmpty)
              Positioned(
                top: 100, right: 16,
                child: Column(
                  children: _coHostUids.map((uid) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    width: 100, height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.primary, width: 2), color: Colors.black,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: _engine, canvas: VideoCanvas(uid: uid), connection: RtcConnection(channelId: widget.channelName), useFlutterTexture: kIsWeb,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),

            // 4. TOP BAR
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(30)),
                      child: Row(
                        children: [
                          // ✅ CACHED NETWORK IMAGE INTÉGRÉ
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: _C.primary,
                            backgroundImage: widget.hostAvatarUrl != null && widget.hostAvatarUrl!.isNotEmpty
                                ? CachedNetworkImageProvider(widget.hostAvatarUrl!)
                                : null,
                            child: widget.hostAvatarUrl == null || widget.hostAvatarUrl!.isEmpty
                                ? const Icon(Icons.person, size: 20, color: _C.textMain)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.hostName, style: const TextStyle(color: _C.textMain, fontSize: 13, fontWeight: FontWeight.bold)),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                      child: Row(children: [const Icon(Icons.visibility_rounded, color: _C.textMain, size: 14), const SizedBox(width: 4), Text('$_viewerCount', style: const TextStyle(color: _C.textMain, fontSize: 13, fontWeight: FontWeight.bold))]),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _endBroadcast,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: _isEnding ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _C.textMain, strokeWidth: 2)) : const Icon(Icons.close_rounded, color: _C.textMain, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. BARRE D'ACTIONS LATÉRALE
            Positioned(
              right: 16, bottom: 100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SideActionButton(icon: Icons.flip_camera_ios_rounded, label: 'Tourner', onTap: () async { await _engine.switchCamera(); setState(() => _isFrontCamera = !_isFrontCamera); }),
                  _SideActionButton(icon: _isBeautyEnabled ? Icons.face_retouching_natural_rounded : Icons.face_rounded, label: 'Beauté', color: _isBeautyEnabled ? _C.primary : _C.textMain, onTap: () async { setState(() => _isBeautyEnabled = !_isBeautyEnabled); await _engine.setBeautyEffectOptions(enabled: _isBeautyEnabled, options: const BeautyOptions(lighteningContrastLevel: LighteningContrastLevel.lighteningContrastNormal, lighteningLevel: 0.7, smoothnessLevel: 0.5, rednessLevel: 0.1)); }),
                  _SideActionButton(icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, label: _isMuted ? 'Muet' : 'Mic', onTap: () { setState(() => _isMuted = !_isMuted); _engine.muteLocalAudioStream(_isMuted); }),
                ],
              ),
            ),

            // 6. CHAT
            Positioned(
              left: 16, bottom: 80, width: MediaQuery.of(context).size.width * 0.7, height: 250,
              child: ShaderMask(
                shaderCallback: (Rect bounds) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.white, Colors.white], stops: [0.0, 0.2, 1.0]).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: ListView.builder(
                  reverse: true,
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[_comments.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16)),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(text: '${comment["user"]}   ', style: TextStyle(color: _C.textMain.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 13)),
                              TextSpan(text: comment["text"], style: const TextStyle(color: _C.textMain, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 7. INPUT CHAT
            Positioned(
              left: 16, right: 16, bottom: 20,
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                        child: TextField(
                          controller: _chatController,
                          style: const TextStyle(color: _C.textMain, fontSize: 14),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendComment(),
                          decoration: const InputDecoration(hintText: 'Ajouter un commentaire...', hintStyle: TextStyle(color: _C.textMuted), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            ..._floatingHearts,
          ],
        ),
      ),
    );
  }
}

// ─── COMPOSANTS ANNEXES ───
class _SideActionButton extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final Color color;
  const _SideActionButton({required this.icon, required this.label, required this.onTap, this.color = _C.textMain});
  @override Widget build(BuildContext context) { return Padding(padding: const EdgeInsets.only(bottom: 16), child: GestureDetector(onTap: onTap, child: Column(children: [Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: _C.textMain, fontSize: 10, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black54, blurRadius: 2)]))]))); }
}

class _AnimatedHeart extends StatefulWidget {
  final Color color; final VoidCallback onComplete;
  const _AnimatedHeart({super.key, required this.color, required this.onComplete});
  @override State<_AnimatedHeart> createState() => _AnimatedHeartState();
}
class _AnimatedHeartState extends State<_AnimatedHeart> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _pos, _op, _sc; final _r = Random(); late double _x;
  @override void initState() { super.initState(); _x = (_r.nextDouble() * 60) - 30; _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000)); _pos = Tween<double>(begin: 0, end: 400).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)); _op = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0.5, 1.0, curve: Curves.easeOut))); _sc = Tween<double>(begin: 0.5, end: 1.5).animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut)); _c.forward().then((_) => widget.onComplete()); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _c, builder: (c, _) => Positioned(bottom: 70 + _pos.value, right: 25 + _x + (sin(_pos.value / 30) * 20), child: Opacity(opacity: _op.value, child: Transform.scale(scale: _sc.value, child: Icon(Icons.favorite_rounded, color: widget.color, size: 28))))); }
}
