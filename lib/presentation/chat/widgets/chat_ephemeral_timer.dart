import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _C {
  static const bg = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const primary = Color(0xFF1D4ED8);
  static const red = Color(0xFFEF4444);
}

class ChatEphemeralTimer extends ConsumerStatefulWidget {
  final int duration;
  final VoidCallback onExpired;

  const ChatEphemeralTimer({
    super.key,
    required this.duration,
    required this.onExpired,
  });

  @override
  ConsumerState<ChatEphemeralTimer> createState() => _ChatEphemeralTimerState();
}

class _ChatEphemeralTimerState extends ConsumerState<ChatEphemeralTimer> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        widget.onExpired();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = _remaining < 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isCritical ? _C.red.withOpacity(0.08) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCritical ? _C.red.withOpacity(0.25) : const Color(0xFFFDBA74).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: isCritical ? _C.red : const Color(0xFFEA580C)),
          const SizedBox(width: 3),
          Text(
            '${_remaining}s',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isCritical ? _C.red : const Color(0xFFEA580C),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
