// lib/presentation/network/live/live_broadcast_screen.dart
import 'package:flutter/material.dart';

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
  bool _isMuted = false;
  bool _isVideoOff = false;
  final List<String> _comments = [
    "Nathan Lumina : Super initiative !",
    "Sonathix Group : On suit ça de près 🚀",
    "Utilisateur : Bonjour tout le monde !"
  ];
  final TextEditingController _chatController = TextEditingController();

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
              Navigator.pop(context); // Revient au feed principal
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
          // ─── FOND VIDÉO / CAMÉRA OU SIMULATION ───
          Positioned.fill(
            child: widget.isVideoEnabled && !_isVideoOff
                ? Container(
                    color: const Color(0xFF1E293B),
                    child: const Center(
                      child: Text(
                        "Flux Caméra Actif (Hôte)",
                        style: TextStyle(color: Colors.white54, fontSize: 16),
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
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text('342', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: _endLiveConfirmation,
                ),
              ],
            ),
          ),

          // ─── TITRE ET CHAT EN DIRECT (Bas de l'écran) ───
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                
                // Fil de commentaires simulé
                SizedBox(
                  height: 150,
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

                // Barre d'outils (Mic, Caméra, Fin)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                      onPressed: () => setState(() => _isMuted = !_isMuted),
                    ),
                    IconButton(
                      icon: Icon(_isVideoOff ? Icons.videocam_off : Icons.videocam, color: Colors.white),
                      onPressed: () => setState(() => _isVideoOff = !_isVideoOff),
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
