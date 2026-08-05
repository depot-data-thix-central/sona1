import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/models/chat/call_invite.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/services/chat/call_signaling_service.dart';
import 'call_page.dart';
import 'widgets/call_avatar.dart';

class IncomingCallPage extends ConsumerStatefulWidget {
  final CallInvite invite;
  const IncomingCallPage({super.key, required this.invite});

  @override
  ConsumerState<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends ConsumerState<IncomingCallPage>
    with SingleTickerProviderStateMixin {
  final _signal = CallSignalingService();
  late AnimationController _pulseController;
  Timer? _timeoutTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    HapticFeedback.heavyImpact();
    _startTimeout();
    _startElapsedTimer();
  }

  void _startTimeout() {
    _timeoutTimer = Timer(const Duration(seconds: 45), () async {
      await _signal.update(widget.invite.id, 'missed');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appel manqué')),
        );
      }
    });
  }

  void _startElapsedTimer() {
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds % 2 == 0) {
        HapticFeedback.vibrate();
      }
    });
  }

  Future<void> _onReject() async {
    _timeoutTimer?.cancel();
    try {
      await _signal.update(widget.invite.id, 'rejected');
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onAccept() async {
    _timeoutTimer?.cancel();
    final isVideo = widget.invite.callType == CallType.video;

    if (!mounted) return;
    _pulseController.stop();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallPage(
          channel: widget.invite.channelName,
          name: widget.invite.callerName ?? 'Inconnu',
          avatarUrl: widget.invite.callerAvatar,
          type: isVideo ? CallType.video : CallType.audio,
          inviteId: widget.invite.id,
          isCaller: false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.invite.callType == CallType.video;
    final name = widget.invite.callerName ?? 'Inconnu';
    final avatar = widget.invite.callerAvatar;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1F44),
      body: Stack(
        children: [
          Positioned.fill(
            child: avatar != null && avatar.isNotEmpty
                ? Image.network(
                    avatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(color: const Color(0xFF0A1F44));
                    },
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0A1F44), Color(0xFF123B7A)],
                      ),
                    ),
                  ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: const Color(0xFF0A1F44).withOpacity(0.75)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  isVideo ? 'Appel vidéo entrant...' : 'Appel audio entrant...',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: Tween<double>(begin: 0.7, end: 1.0)
                      .animate(_pulseController),
                  child: CallAvatar(
                    name: name,
                    imageUrl: avatar,
                    size: 120,
                    isVideo: isVideo,
                    isRinging: true,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVideo
                      ? 'THIX CHAT Vidéo • ${_formatElapsed(_elapsedSeconds)}'
                      : 'THIX CHAT Audio • ${_formatElapsed(_elapsedSeconds)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildActionButton(
                        icon: Icons.call_end_rounded,
                        color: const Color(0xFFD64545),
                        label: 'Refuser',
                        onTap: _onReject,
                      ),
                      _buildActionButton(
                        icon: isVideo
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        color: const Color(0xFF1FA971),
                        label: 'Accepter',
                        onTap: _onAccept,
                        isPrimary: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatElapsed(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, child) {
            return Transform.scale(
              scale: isPrimary ? 1.0 + (_pulseController.value * 0.08) : 1.0,
              child: child,
            );
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(icon, color: Colors.white, size: 32),
              onPressed: onTap,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
