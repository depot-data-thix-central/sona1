// lib/presentation/network/live/live_broadcast_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  
  // 🌟 NOUVEAU : Identifiants reçus depuis l'écran de préparation
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

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> {
  late RtcEngine _engine;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isEnding = false; // Sécurité pour ne pas supprimer 2 fois

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
      // 1. Gérer les permissions
      if (!kIsWeb) {
        await [Permission.camera, Permission.microphone].request();
      }

      // 🌟 NOUVEAU : On utilise le nom de canal unique passé par le lanceur
      final safeChannelName = widget.channelName;

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

  // 🌟 NOUVEAU : Fonction de nettoyage pour la base de données et Agora
  Future<void> _endBroadcast() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);

    try {
      // 1. On supprime le direct de Supabase pour qu'il disparaisse chez les autres
      await Supabase.instance.client
          .from('live_sessions')
          .delete()
          .eq('id', widget.liveId);
          
      // 2. On quitte Agora proprement
      if (_isInitialized) {
        await _engine.leaveChannel();
        await _engine.release();
      }
    } catch (e) {
      debugPrint('Erreur suppression live Supabase: $e');
    }

    if (mounted) {
      Navigator.pop(context); // On retourne à la page précédente
    }
  }

  @override
  void dispose() {
    // Si l'utilisateur a quitté l'écran d'une autre façon (bouton retour du téléphone)
    if (!_isEnding) {
      _endBroadcast(); 
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 NOUVEAU : PopScope empêche le bouton "Retour" physique d'Android de casser le système
    // Il force l'appel à notre fonction de nettoyage _endBroadcast
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _endBroadcast();
      },
      child: Scaffold(
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
                              useFlutterTexture: kIsWeb,
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
      
            // UI par-dessus
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
                  // 🌟 BOUTON FERMER HAUT
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white), 
                    onPressed: _endBroadcast,
                  ),
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
                      // 🌟 BOUTON QUITTER BAS
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _C.red),
                        onPressed: _endBroadcast,
                        child: _isEnding 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Quitter', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
