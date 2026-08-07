// lib/presentation/network/live/live_broadcast_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 🌟 IMPÉRATIF POUR kIsWeb
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
      // 1. Ne pas faire crasher le Web avec les permissions
      if (!kIsWeb) {
        await [Permission.camera, Permission.microphone].request();
      }

      // 2. Nettoyer le nom du canal (Agora n'accepte pas les espaces)
      String safeChannelName = widget.title.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      if (safeChannelName.isEmpty) safeChannelName = "ThixLive";

      // 3. Récupérer le vrai Token via ton Edge Function Supabase
      final response = await Supabase.instance.client.functions.invoke(
        'get-agora-token',
        body: {'channelName': safeChannelName, 'uid': 0, 'isHost': true},
      );
      
      final data = response.data as Map<String, dynamic>;
      final appId = data['appId'] as String;
      final token = data['token'] as String;

      // 4. Initialiser Agora
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // 5. Configurer et allumer la vidéo
      if (!_isVideoOff) {
        await _engine.enableVideo();
        await _engine.startPreview();
      }

      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // 6. Rejoindre le canal AVEC LE TOKEN !
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
      debugPrint('Erreur init Broadcast: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion : $e'),
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

  void _endLiveConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer le direct ?'),
        content: const Text('La diffusion sera arrêtée pour tous les spectateurs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.red),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Terminer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgDark,
      body: Stack(
        children: [
          // ─── AFFICHAGE DU FLUX VIDÉO ───
          Positioned.fill(
            child: _isInitialized && !_isVideoOff
                ? AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  )
                : Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(Icons.mic_rounded, size: 80, color: Colors.white24),
                    ),
                  ),
          ),

          // ─── HEADER (EN DIRECT & Fermer) ───
          Positioned(
            top: 50, left: 16, right: 16,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _C.red, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                      SizedBox(width: 6),
                      Text('EN DIRECT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: _endLiveConfirmation,
                ),
              ],
            ),
          ),

          // ─── CHAT ET BOUTONS DU BAS ───
          Positioned(
            bottom: 20, left: 16, right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                
                // Fil de commentaires
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _comments[index],
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Contrôles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white, size: 28),
                      onPressed: () {
                        setState(() => _isMuted = !_isMuted);
                        if (_isInitialized) _engine.muteLocalAudioStream(_isMuted);
                      },
                    ),
                    IconButton(
                      icon: Icon(_isVideoOff ? Icons.videocam_off : Icons.videocam, color: Colors.white, size: 28),
                      onPressed: () {
                        setState(() => _isVideoOff = !_isVideoOff);
                        if (_isInitialized) {
                          _engine.muteLocalVideoStream(_isVideoOff);
                        }
                      },
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _C.red),
                      onPressed: _endLiveConfirmation,
                      icon: const Icon(Icons.call_end, color: Colors.white),
                      label: const Text('Quitter', style: TextStyle(color: Colors.white)),
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
