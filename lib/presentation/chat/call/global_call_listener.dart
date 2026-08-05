// lib/presentation/chat/call/global_call_listener.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/chat/call_invite.dart';
import 'package:thix_id/services/chat/call_signaling_service.dart';
import 'incoming_call_page.dart';

/// À placer une seule fois au-dessus de l'app (après auth).
/// Écoute les appels entrants et ouvre IncomingCallPage.
class GlobalCallListener extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const GlobalCallListener({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  @override
  State<GlobalCallListener> createState() => _GlobalCallListenerState();
}

class _GlobalCallListenerState extends State<GlobalCallListener> {
  final _signal = CallSignalingService();
  String? _listeningFor;
  String? _lastInviteId; // anti-doublon

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureListening());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureListening();
  }

  void _ensureListening() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    if (_listeningFor == uid) return;

    _listeningFor = uid;
    debugPrint('🔔 GlobalCallListener: listening for $uid');

    _signal.listenMyInvites(uid, (CallInvite invite) {
      // Anti-doublon : même invite déjà affichée
      if (_lastInviteId == invite.id) return;
      _lastInviteId = invite.id;

      debugPrint('📞 Incoming invite \( {invite.id} type= \){invite.callType}');

      final nav = widget.navigatorKey?.currentState;
      if (nav != null) {
        nav.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => IncomingCallPage(invite: invite),
          ),
        );
      } else if (mounted) {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => IncomingCallPage(invite: invite),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _signal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
