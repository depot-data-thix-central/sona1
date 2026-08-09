// lib/presentation/thix_sante/sante/screens/activite_physique_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// =============================================================================
// DESIGN SYSTEM PREMIUM SANTE
// =============================================================================
class _C {
  static const bg = Color(0xFFF8FAFC);
  static const white = Color(0xFFFFFFFF);
  static const navy = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const primary = Color(0xFF2563EB); // Bleu tech
  static const emerald = Color(0xFF059669); // Vert santé
  static const warning = Color(0xFFD97706); // Orange calories
  static const border = Color(0xFFE2E8F0);
}

// =============================================================================
// LOGIQUE SUPABASE (ZÉRO MOCK)
// Table : activity_logs (id uuid, patient_uid uuid, type text, steps int, duration_min int, calories int, created_at timestamptz)
// =============================================================================

class DailyActivity {
  final int totalSteps;
  final int totalDuration;
  final int totalCalories;
  final List<Map<String, dynamic>> logs;

  DailyActivity({
    required this.totalSteps,
    required this.totalDuration,
    required this.totalCalories,
    required this.logs,
  });
}

final dailyActivityProvider = FutureProvider<DailyActivity>((ref) async {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;
  final today = DateTime.now().toIso8601String().substring(0, 10);
  
  try {
    // 🌟 SELECTION REELLE SUR SUPABASE (Filtre par date du jour)
    final List<dynamic> response = await db
        .from('activity_logs')
        .select('id, type, steps, duration_min, calories, created_at')
        .eq('patient_uid', uid)
        .gte('created_at', '${today}T00:00:00')
        .order('created_at', ascending: false);

    final logs = List<Map<String, dynamic>>.from(response);
    
    // Agrégation mathématique des données
    final int steps = logs.fold<int>(0, (s, e) => s + (e['steps'] as int? ?? 0));
    final int duration = logs.fold<int>(0, (s, e) => s + (e['duration_min'] as int? ?? 0));
    final int cal = logs.fold<int>(0, (s, e) => s + (e['calories'] as int? ?? 0));

    return DailyActivity(
      totalSteps: steps,
      totalDuration: duration,
      totalCalories: cal,
      logs: logs,
    );
  } catch (e) {
    debugPrint("Erreur Supabase activity_logs: $e");
    return DailyActivity(totalSteps: 0, totalDuration: 0, totalCalories: 0, logs: []);
  }
});

class ActivitePhysiquePage extends ConsumerStatefulWidget {
  const ActivitePhysiquePage({super.key});

  @override
  ConsumerState<ActivitePhysiquePage> createState() => _ActivitePhysiquePageState();
}

class _ActivitePhysiquePageState extends ConsumerState<ActivitePhysiquePage> {
  bool _isInserting = false;

  // 🌟 FONCTION D'INSERTION RÉELLE
  Future<void> _logActivity(String type, IconData icon, int duration, int calories, int steps) async {
    if (_isInserting) return;
    setState(() => _isInserting = true);
    HapticFeedback.lightImpact();

    final db = Supabase.instance.client;
    final uid = db.auth.currentUser!.id;
    
    try {
      await db.from('activity_logs').insert({
        'patient_uid': uid,
        'type': type,
        'duration_min': duration,
        'calories': calories,
        'steps': steps,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Invalidation pour rafraîchir l'UI immédiatement
      ref.invalidate(dailyActivityProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('$type enregistré avec succès !', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            backgroundColor: _C.emerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'enregistrement : $e'), backgroundColor: _C.warning),
        );
      }
    } finally {
      if (mounted) setState(() => _isInserting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(dailyActivityProvider);

    return Scaffold(
      backgroundColor: _C.bg,
      body: RefreshIndicator(
        color: _C.primary,
        onRefresh: () async => ref.invalidate(dailyActivityProvider),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            _buildAppBar(),
            
            SliverToBoxAdapter(
              child: activityAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Center(child: CircularProgressIndicator(color: _C.primary)),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('Erreur: Configurez la table activity_logs sur Supabase.\n$e', style: const TextStyle(color: _C.textMuted), textAlign: TextAlign.center)),
                ),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildMainDashboard(data),
                    const SizedBox(height: 32),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text('Enregistrer une activité', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _C.navy, letterSpacing: -0.3)),
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActionList(),
                    
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Historique du jour', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _C.navy, letterSpacing: -0.3)),
                          Text('${data.logs.length} sessions', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.primary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildHistoryTimeline(data.logs),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // UI : APPBAR MODERNE
  // =========================================================================
  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _C.bg,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.navy, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Activité Physique', style: TextStyle(color: _C.navy, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
      centerTitle: false,
    );
  }

  // =========================================================================
  // UI : DASHBOARD STATISTIQUES (DESIGN PREMIUM)
  // =========================================================================
  Widget _buildMainDashboard(DailyActivity data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _C.border.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: _C.navy.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Aujourd\'hui', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.textMuted)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _C.emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    children: [
                      Icon(Icons.sync_rounded, size: 12, color: _C.emerald),
                      SizedBox(width: 4),
                      Text('Synchronisé', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _C.emerald)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildMetricRing(Icons.directions_walk_rounded, data.totalSteps.toString(), 'Pas', _C.primary)),
                Container(height: 50, width: 1, color: _C.border),
                Expanded(child: _buildMetricRing(Icons.timer_rounded, data.totalDuration.toString(), 'Min', _C.emerald)),
                Container(height: 50, width: 1, color: _C.border),
                Expanded(child: _buildMetricRing(Icons.local_fire_department_rounded, data.totalCalories.toString(), 'Kcal', _C.warning)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRing(IconData icon, String value, String unit, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _C.navy, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(unit, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.textMuted)),
      ],
    );
  }

  // =========================================================================
  // UI : CARROUSEL D'AJOUT RAPIDE
  // =========================================================================
  Widget _buildQuickActionList() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildQuickActionCard('Marche', Icons.directions_walk_rounded, 30, 150, 2500, _C.primary),
          const SizedBox(width: 12),
          _buildQuickActionCard('Course', Icons.directions_run_rounded, 20, 280, 3000, _C.warning),
          const SizedBox(width: 12),
          _buildQuickActionCard('Vélo', Icons.directions_bike_rounded, 45, 320, 0, _C.emerald),
          const SizedBox(width: 12),
          _buildQuickActionCard('Fitness', Icons.fitness_center_rounded, 30, 200, 0, const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String type, IconData icon, int duration, int kcal, int steps, Color color) {
    return InkWell(
      onTap: () => _logActivity(type, icon, duration, kcal, steps),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _C.navy)),
            const SizedBox(height: 2),
            Text('+$kcal kcal', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _C.textMuted)),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // UI : HISTORIQUE REEL (TIMELINE)
  // =========================================================================
  Widget _buildHistoryTimeline(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.history_rounded, size: 48, color: _C.border),
              const SizedBox(height: 12),
              const Text('Aucune activité enregistrée aujourd\'hui.', style: TextStyle(color: _C.textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: logs.map((log) {
          final type = log['type'] as String? ?? 'Activité';
          final kcal = log['calories'] as int? ?? 0;
          final min = log['duration_min'] as int? ?? 0;
          
          DateTime date = DateTime.now();
          if (log['created_at'] != null) {
            date = DateTime.parse(log['created_at']).toLocal();
          }
          final timeStr = DateFormat('HH:mm').format(date);

          IconData icon = Icons.fitness_center_rounded;
          Color color = const Color(0xFF8B5CF6);
          if (type.toLowerCase().contains('marche')) { icon = Icons.directions_walk_rounded; color = _C.primary; }
          else if (type.toLowerCase().contains('course')) { icon = Icons.directions_run_rounded; color = _C.warning; }
          else if (type.toLowerCase().contains('vélo') || type.toLowerCase().contains('velo')) { icon = Icons.directions_bike_rounded; color = _C.emerald; }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  height: 44, width: 44,
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.navy)),
                      const SizedBox(height: 4),
                      Text('$min minutes actives', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _C.textMuted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('+$kcal kcal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                    const SizedBox(height: 4),
                    Text(timeStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _C.textMuted)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
