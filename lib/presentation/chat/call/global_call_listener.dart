// lib/presentation/chat/call/global_call_listener.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/chat/call_invite.dart';
import '../../../services/chat/call_signaling_service.dart';
import 'incoming_call_page.dart';

class GlobalCallListener extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const GlobalCallListener({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  @override
  ConsumerState<GlobalCallListener> createState() =>
      _GlobalCallListenerState();
}

class _GlobalCallListenerState extends ConsumerState<GlobalCallListener> {
  final _signal = CallSignalingService();
  StreamSubscription<CallInvite>? _sub;
  String? _shownInviteId;
  String? _lastUid;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _syncListen();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncListen());
  }

  void _syncListen() {
    final uid = Supabase.instance.client.auth.currentUser?.id;

    if (uid == null) {
      _sub?.cancel();
      _sub = null;
      _lastUid = null;
      return;
    }

    if (uid == _lastUid && _sub != null) return;

    _lastUid = uid;
    _sub?.cancel();

    _sub = _signal.watchIncoming().listen((invite) {
      if (!mounted) return;
      if (_shownInviteId == invite.id) return;
      _shownInviteId = invite.id;
      _openIncoming(invite);
    });
  }

  void _openIncoming(CallInvite invite) {
    final route = MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => IncomingCallPage(invite: invite),
    );

    final nav = widget.navigatorKey?.currentState;
    if (nav != null) {
      nav.push(route);
      return;
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).push(route);
    }
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
