// lib/presentation/network/live/live_broadcast_screen.dart
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class _C {
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
  // Remplace ceci par ton App ID Agora (ou récupère-le depuis tes secrets/environnement)
  static const String _appId = " TON_AGORA_APP_ID "; 
  static const String _token = ""; // Token temporaire ou vide si le mode test sans certificat est actif
  static const String _channelName = "thix_pro_live_channel";

  late RtcEngine _engine;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isVideoOff = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // 1. Demander les permissions Caméra et Micro
    await [Permission.camera, Permission.microphone].request();

    // 2. Créer le moteur Agora
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: _appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    // 3. Activer la vidéo si demandée
    if (widget.isVideoEnabled) {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else {
      await _engine.disableVideo();
    }

    // 4. Définir le rôle (Broadcaster pour l'hôte)
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    // 5. Rejoindre le canal
    await _engine.joinChannel(
      token: _token,
      channelId: _channelName,
      options: const ChannelMediaOptions(
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
      uid: 0,
    );

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _disposeAgora();
    super.dispose();
  }

  Future<void> _disposeAgora() async {
    await _engine.leaveChannel();
    await _engine.release();
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
              Navigator.pop(ctx); // Ferme la modale
              Navigator.pop(context); // Quitte l'écran de live
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
          // ─── AFFICHAGE DU FLUX VIDÉO AGORA DE L'HÔTE ───
          Positioned.fill(
            child: _isInitialized && widget.isVideoEnabled && !_isVideoOff
                ? AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine,
                      canvas: const VideoCanvas(uid: 0), // 0 = soi-même (Hôte)
                    ),
                  )
                : Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(Icons.mic_rounded, size: 80, color: Colors.white24),
                    ),
                  ),
          ),

          // ─── HEADER (Infos Live & Bouton Quitter) ───
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _C.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
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

          // ─── CONTRÔLES DU BAS (Mic, Caméra, Quitter) ───
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white, size: 28),
                  onPressed: () {
                    setState(() => _isMuted = !_isMuted);
                    _engine.muteLocalAudioStream(_isMuted);
                  },
                ),
                IconButton(
                  icon: Icon(_isVideoOff ? Icons.videocam_off : Icons.videocam, color: Colors.white, size: 28),
                  onPressed: () {
                    setState(() => _isVideoOff = !_isVideoOff);
                    _engine.muteLocalVideoStream(_isVideoOff);
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
          ),
        ],
      ),
    );
  }
}
