
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/chat/call_invite.dart';
import 'package:thix_id/services/chat/call_signaling_service.dart';

import 'incoming_call_page.dart';

/// À placer une seule fois au-dessus de l'app (après auth).
/// Écoute les appels entrants et ouvre IncomingCallPage.
/// Version durcie pour éviter les doubles push / doubles listeners.
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

class _GlobalCallListenerState extends State<GlobalCallListener>
    with WidgetsBindingObserver {
  final CallSignalingService _signal = CallSignalingService();

  StreamSubscription<CallInvite>? _inviteSub;
  String? _listeningFor;
  String? _lastInviteId;

  bool _incomingPageOpen = false;
  DateTime? _lastPushAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Premier attachement après frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureListening();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureListening();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Re-vérifie l'abonnement au retour, sans en empiler.
      _ensureListening();
    }
  }

  void _ensureListening() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return;

    // Déjà abonné pour ce user.
    if (_listeningFor == uid && _inviteSub != null) return;

    // Changement de user ou rebind propre.
    _inviteSub?.cancel();
    _inviteSub = null;
    _listeningFor = uid;

    debugPrint('🔔 GlobalCallListener: listening for $uid');

    // IMPORTANT:
    // Cette ligne suppose que listenMyInvites retourne Stream<CallInvite>.
    // Si ta signature actuelle est callback-based, adapte CallSignalingService
    // pour retourner un StreamSubscription et stocke/annule pareil.
    _inviteSub = _signal.listenMyInvites(uid).listen(
      _onInvite,
      onError: (e, st) {
        debugPrint('❌ GlobalCallListener invite stream error: $e');
      },
    );
  }

  Future<void> _onInvite(CallInvite invite) async {
    if (!mounted) return;

    // Anti-doublon invite id
    if (_lastInviteId == invite.id) return;
    _lastInviteId = invite.id;

    // Anti-push concurrent / rafale
    if (_incomingPageOpen) return;

    final now = DateTime.now();
    if (_lastPushAt != null &&
        now.difference(_lastPushAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastPushAt = now;

    final nav = widget.navigatorKey?.currentState ??
        Navigator.of(context, rootNavigator: true);

    _incomingPageOpen = true;
    try {
      await nav.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IncomingCallPage(invite: invite),
        ),
      );
    } catch (e) {
      debugPrint('❌ GlobalCallListener navigation error: $e');
    } finally {
      _incomingPageOpen = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inviteSub?.cancel();
    _signal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
