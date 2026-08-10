// lib/presentation/chat/call/call_history_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/chat/call_invite.dart';
import '../../../models/chat/call_status.dart';

class CallHistoryPage extends StatefulWidget {
  const CallHistoryPage({super.key});

  @override
  State<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends State<CallHistoryPage> {
  final _db = Supabase.instance.client;
  late Future<List<CallInvite>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CallInvite>> _load() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return [];

    final rows = await _db
        .from('call_invites')
        .select()
        .or('caller_id.eq.$uid,callee_id.eq.$uid')
        .order('created_at', ascending: false)
        .limit(50);

    return (rows as List)
        .map((r) => CallInvite.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  String _peerName(CallInvite inv, String myId) {
    final isCaller = inv.callerId == myId;
    if (isCaller) {
      final n = inv.calleeName?.trim();
      if (n != null && n.isNotEmpty) return n;
      return 'Contact';
    }
    final n = inv.callerName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Contact';
  }

  IconData _statusIcon(CallInvite inv, String myId) {
    final missed = inv.status == CallStatus.missed ||
        inv.status == CallStatus.rejected ||
        inv.status == CallStatus.canceled;
    if (missed) return Icons.call_missed;
    if (inv.callerId == myId) return Icons.call_made;
    return Icons.call_received;
  }

  Color _statusColor(CallInvite inv) {
    if (inv.status == CallStatus.missed ||
        inv.status == CallStatus.rejected ||
        inv.status == CallStatus.canceled) {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFF0B3D91);
  }

  String _subtitle(CallInvite inv) {
    final type = inv.isVideo ? 'Video' : 'Audio';
    final label = inv.status.label;
    if (inv.durationSec > 0) {
      return '$type · $label · ${_fmtDuration(inv.durationSec)}';
    }
    return '$type · $label';
  }

  String _fmtDuration(int sec) {
    final m = sec ~/ 60; // ✅ Correction ici (suppression de l'antislash)
    final s = sec % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _fmtDate(DateTime d) {
    final local = d.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) {
      return DateFormat('HH:mm').format(local);
    }
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Hier';
    }
    return DateFormat('dd/MM/yy').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final myId = _db.auth.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Appels'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A1F44),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<CallInvite>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Erreur: ${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              );
            }

            final list = snap.data ?? [];
            if (list.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.call_outlined, size: 48, color: Colors.black26),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Aucun appel pour le moment',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final inv = list[i];
                final name = _peerName(inv, myId);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE8EEF7),
                    child: Icon(
                      inv.isVideo ? Icons.videocam : Icons.call,
                      color: const Color(0xFF0B3D91),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A1F44),
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(
                        _statusIcon(inv, myId),
                        size: 14,
                        color: _statusColor(inv),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _subtitle(inv),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    _fmtDate(inv.createdAt),
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
