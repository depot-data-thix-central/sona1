// lib/presentation/chat/call/global_call_listener.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/chat/call_invite.dart';
import '../../../services/chat/call_signaling_service.dart';
import 'incoming_call_page.dart';

/// À placer une fois sous MaterialApp / shell authentifié
class GlobalCallListener extends ConsumerStatefulWidget {
  final Widget child;
  const GlobalCallListener({super.key, required this.child});

  @override
  ConsumerState<GlobalCallListener> createState() =>
      _GlobalCallListenerState();
}

class _GlobalCallListenerState extends ConsumerState<GlobalCallListener> {
  final _signal = CallSignalingService();
  StreamSubscription? _sub;
  String? _shownInviteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  void _listen() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _sub?.cancel();
    _sub = _signal.watchIncoming().listen((invite) {
      if (_shownInviteId == invite.id) return;
      _shownInviteId = invite.id;
      _openIncoming(invite);
    });
  }

  void _openIncoming(CallInvite invite) {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingCallPage(invite: invite),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _signal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
