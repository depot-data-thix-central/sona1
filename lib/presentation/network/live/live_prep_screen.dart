// lib/presentation/network/live/live_prep_screen.dart
import 'package:flutter/material.dart';

class _C {
  static const primary = Color(0xFF2D6CDF);
  static const primaryDeep = Color(0xFF0A1F44);
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

  void _startLive() {
    final title = _titleController.text.trim().isEmpty 
        ? "Mon Direct" 
        : _titleController.text.trim();

    // TODO: Connecter à Supabase RPC et Agora/LiveKit ici.
    // Pour l'instant, on simule le lancement.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lancement du Live : $title...')),
    );
    
    // Prochaine étape : Rediriger vers LiveBroadcastScreen(title: title, isVideo: _isVideoEnabled)
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgDark, // Thème sombre pour la préparation vidéo
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
          // TODO: Insérer ici le CameraPreview (Aperçu caméra en fond)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF1E293B), // Fond temporaire en attendant la caméra
              child: const Center(
                child: Icon(Icons.camera_alt_outlined, color: Colors.white24, size: 80),
              ),
            ),
          ),

          // Voile sombre pour lisibilité
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),

          // Contenu de la préparation
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Titre du Live
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

                  // Contrôles (Mic & Caméra)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRoundBtn(
                        icon: _isMicEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                        isActive: _isMicEnabled,
                        onTap: () => setState(() => _isMicEnabled = !_isMicEnabled),
                      ),
                      const SizedBox(width: 24),
                      _buildRoundBtn(
                        icon: _isVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                        isActive: _isVideoEnabled,
                        onTap: () => setState(() => _isVideoEnabled = !_isVideoEnabled),
                      ),
                      const SizedBox(width: 24),
                      _buildRoundBtn(
                        icon: Icons.flip_camera_ios_rounded,
                        isActive: true,
                        onTap: () {
                          // TODO: Basculer Caméra Avant/Arrière
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Bouton Lancer le Direct
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _startLive,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 8,
                        shadowColor: _C.red.withOpacity(0.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sensors_rounded, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'COMMENCER LE DIRECT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
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
          backdropFilter: isActive ? null : null, // Pour un futur effet Blur
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
