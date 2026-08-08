// lib/presentation/network/live/live_prep_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'live_broadcast_screen.dart';

class _C {
  static const primary = Color(0xFF2D6CDF);
  static const red = Color(0xFFE5484D);
  static const bgDark = Color(0xFF10192E);
}

class LivePrepScreen extends StatefulWidget {
  const LivePrepScreen({super.key});

  @override
  State<LivePrepScreen> createState() => _LivePrepScreenState();
}

class _LivePrepScreenState extends State<LivePrepScreen> {
  final TextEditingController _titleController = TextEditingController();
  bool _isVideoEnabled = true;
  bool _isMicEnabled = true;

  RtcEngine? _engine;
  bool _isEngineReady = false;
  bool _isStartingLive = false; // 🌟 État de chargement

  @override
  void initState() {
    super.initState();
    _initPreviewAgora();
  }

  Future<void> _initPreviewAgora() async {
    try {
      if (!kIsWeb) {
        await [Permission.camera, Permission.microphone].request();
      }

      String appId = "96ed392d17c74fe684bbb9d4a031ad12"; 

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      await _engine!.enableVideo();
      await _engine!.startPreview();

      if (mounted) setState(() => _isEngineReady = true);
      
    } catch (e) {
      debugPrint('Erreur init preview Agora: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur Caméra : $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  Future<void> _startLive() async {
    if (_isStartingLive) return;

    final title = _titleController.text.trim().isEmpty 
        ? "Mon Direct" 
        : _titleController.text.trim();

    setState(() => _isStartingLive = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("Vous devez être connecté");

      // 1. Générer un nom de canal unique
      final channelName = 'live_${user.id}_${DateTime.now().millisecondsSinceEpoch}';

      // 2. 🚀 Enregistrer le direct dans Supabase
      final response = await Supabase.instance.client
          .from('live_sessions')
          .insert({
            'host_id': user.id,
            'title': title,
            'channel_name': channelName, 
            'status': 'live',
          })
          .select()
          .single();

      final liveId = response['id'].toString();

      // 3. Arrêter le preview
      if (_isEngineReady && _engine != null) {
        await _engine!.stopPreview();
      }

      if (!mounted) return;

      // 4. Lancer l'écran de diffusion
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LiveBroadcastScreen(
            title: title,
            isVideoEnabled: _isVideoEnabled,
            isMicEnabled: _isMicEnabled,
            liveId: liveId,           // 🌟 Passé à l'écran suivant
            channelName: channelName, // 🌟 Passé à l'écran suivant
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erreur création live: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de connexion : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingLive = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    if (_isEngineReady && _engine != null) {
      _engine!.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _isEngineReady && _isVideoEnabled && _engine != null
                ? AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine!,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  )
                : Container(
                    color: const Color(0xFF1E293B),
                    child: const Center(
                      child: Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 80),
                    ),
                  ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "De quoi allez-vous parler ?",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 24),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRoundBtn(
                        icon: _isMicEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                        isActive: _isMicEnabled,
                        onTap: () {
                          setState(() => _isMicEnabled = !_isMicEnabled);
                          if (_isEngineReady && _engine != null) {
                            _engine!.muteLocalAudioStream(!_isMicEnabled);
                          }
                        },
                      ),
                      const SizedBox(width: 24),
                      _buildRoundBtn(
                        icon: _isVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                        isActive: _isVideoEnabled,
                        onTap: () {
                          setState(() => _isVideoEnabled = !_isVideoEnabled);
                          if (_isEngineReady && _engine != null) {
                            if (_isVideoEnabled) {
                              _engine!.enableVideo();
                              _engine!.startPreview();
                            } else {
                              _engine!.disableVideo();
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 24),
                      _buildRoundBtn(
                        icon: Icons.flip_camera_ios_rounded,
                        isActive: true,
                        onTap: () {
                          if (_isEngineReady && _engine != null) {
                            _engine!.switchCamera();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isStartingLive ? null : _startLive,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isStartingLive ? Colors.grey : _C.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 8,
                        shadowColor: _C.red.withOpacity(0.5),
                      ),
                      child: _isStartingLive 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sensors_rounded, color: Colors.white),
                              SizedBox(width: 10),
                              Text(
                                'COMMENCER LE DIRECT',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0),
                              ),
                            ],
                          ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundBtn({required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.red.withOpacity(0.8),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54, width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
