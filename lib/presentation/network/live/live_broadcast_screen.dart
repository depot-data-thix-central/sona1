// lib/presentation/network/live/live_broadcast_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 🌟 IMPÉRATIF POUR DÉTECTER LE WEB
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _C {
  static const primary = Color(0xFF2D6CDF);
  static const red = Color(0xFFE5484D);
  static const bgDark = Color(0xFF10192E);
}

class LiveBroadcastScreen extends StatefulWidget {
  final String title;
  final bool isVideoEnabled;
  final bool isMicEnabled;

  const LiveBroadcastScreen({
    super.key,
    required this.title,
    required this.isVideoEnabled,
    required this.isMicEnabled,
  });

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> {
  late RtcEngine _engine;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isVideoOff = false;

  final List<String> _comments = [
    "Nathan Lumina : Super initiative !",
    "Sonathix Group : On suit ça de près 🚀"
  ];

  @override
  void initState() {
    super.initState();
    _isMuted = !widget.isMicEnabled;
    _isVideoOff = !widget.isVideoEnabled;
    _initAgora();
  }

  Future<void> _initAgora() async {
    try {
      // 1. Gérer les permissions (Chrome/Safari Web gèrent ça nativement)
      if (!kIsWeb) {
        await [Permission.camera, Permission.microphone].request();
      }

      // 2. Préparation du nom de canal sans caractères spéciaux
      String safeChannelName = widget.title.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      if (safeChannelName.isEmpty) safeChannelName = "ThixLive";

      // 3. Appel sécurisé à Supabase pour le Token
      final response = await Supabase.instance.client.functions.invoke(
        'get-agora-token',
        body: {'channelName': safeChannelName, 'uid': 0, 'isHost': true},
      );
      
      final data = response.data as Map<String, dynamic>;
      final appId = data['appId'] as String;
      final token = data['token'] as String;

      // 4. Initialisation Agora
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // 5. Paramétrage vidéo
      if (!_isVideoOff) {
        await _engine.enableVideo();
        await _engine.startPreview();
      }

      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // 6. Connexion
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _engine.leaveChannel();
      _engine.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgDark,
      body: Stack(
        children: [
          // ─── AFFICHAGE VIDÉO CORRIGÉ POUR LE WEB ───
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
                            useFlutterTexture: kIsWeb, // 🌟 Clé pour le rendu Web
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(Icons.mic_rounded, size: 80, color: Colors.white24),
                    ),
                  ),
          ),

          // UI UI par-dessus
          Positioned(
            top: 50, left: 16, right: 16,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _C.red, borderRadius: BorderRadius.circular(20)),
                  child: const Text('EN DIRECT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),

          Positioned(
            bottom: 20, left: 16, right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                // Contrôles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                      onPressed: () {
                        setState(() => _isMuted = !_isMuted);
                        if (_isInitialized) _engine.muteLocalAudioStream(_isMuted);
                      },
                    ),
                    IconButton(
                      icon: Icon(_isVideoOff ? Icons.videocam_off : Icons.videocam, color: Colors.white),
                      onPressed: () {
                        setState(() => _isVideoOff = !_isVideoOff);
                        if (_isInitialized) _engine.muteLocalVideoStream(_isVideoOff);
                      },
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _C.red),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Quitter', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
