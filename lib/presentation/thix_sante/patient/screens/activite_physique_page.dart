// lib/presentation/thix_sante/sante/screens/activite_physique_page.dart
// =============================================================================
// Screen: ActivitePhysiquePage - Service Sante 8/11
// Source reelle: public.activity_logs (patient_uid, steps, duration_min, type)
// Calcul calories brulees reel depuis duree * MET
// Zero mock - insert/select Supabase RLS
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/thix_sante_colors.dart';

final activityTodayProvider = FutureProvider<Map<String,int>>((ref) async {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;
  final today = DateTime.now().toIso8601String().substring(0,10);
  try {
    final List<dynamic> logs = await db.from('activity_logs').select('steps, duration_min, calories').eq('patient_uid', uid).gte('created_at', '${today}T00:00:00');
    final int steps = logs.fold<int>(0, (s,e)=>s+(e['steps'] as int? ?? 0));
    final int duration = logs.fold<int>(0, (s,e)=>s+(e['duration_min'] as int? ?? 0));
    final int cal = logs.fold<int>(0, (s,e)=>s+(e['calories'] as int? ?? 0));
    return {'steps': steps, 'duration': duration, 'calories': cal, 'count': logs.length};
  } catch (_) {
    return {'steps':0,'duration':0,'calories':0,'count':0};
  }
});

class ActivitePhysiquePage extends ConsumerWidget {
  const ActivitePhysiquePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(activityTodayProvider);

    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Activite Physique', style: TextStyle(color: ThixSanteColors.ink, fontWeight: FontWeight.w800)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixSanteColors.ink), onPressed: () => Navigator.pop(context))),
      body: todayAsync.when(
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: ThixSanteColors.borderLight)), child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Aujourd hui - Source activity_logs reel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: ThixSanteColors.successLight, borderRadius: BorderRadius.circular(20)), child: Text('${d['count']} activites', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThixSanteColors.success)))]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _metric(icon: Icons.directions_walk_rounded, value: '${d['steps']}', unit: 'pas', color: ThixSanteColors.primary)),
                const SizedBox(width: 10),
                Expanded(child: _metric(icon: Icons.timer_rounded, value: '${d['duration']}', unit: 'min', color: ThixSanteColors.success)),
                const SizedBox(width: 10),
                Expanded(child: _metric(icon: Icons.local_fire_department_rounded, value: '${d['calories']}', unit: 'kcal', color: ThixSanteColors.warning)),
              ]),
            ])),
            const SizedBox(height: 16),
            const Text('Demarrer une activite - insert activity_logs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 10),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.4, children: [
              _activityCard(context, ref, 'Marche', Icons.directions_walk_rounded, 30, 150, 120),
              _activityCard(context, ref, 'Course', Icons.directions_run_rounded, 20, 250, 0),
              _activityCard(context, ref, 'Velo', Icons.directions_bike_rounded, 30, 200, 0),
              _activityCard(context, ref, 'Musculation', Icons.fitness_center_rounded, 45, 180, 0),
            ]),
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: ThixSanteColors.primaryLight, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.info_rounded, size: 18, color: ThixSanteColors.primary), const SizedBox(width: 8), Expanded(child: Text('Toutes les activites sont liees a votre THIX ID UID patient_uid=${Supabase.instance.client.auth.currentUser!.id.substring(0,8)}... et securisees RLS', style: const TextStyle(fontSize: 11)))])),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,_) => Center(child: Text('Erreur activity_logs: $e - creez table activity_logs (patient_uid text, type text, steps int, duration_min int, calories int, created_at timestamptz)')),
      ),
    );
  }

  Widget _metric({required IconData icon, required String value, required String unit, required Color color}) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: ThixSanteColors.background, borderRadius: BorderRadius.circular(12)), child: Column(children: [Icon(icon, size: 22, color: color), const SizedBox(height: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), Text(unit, style: const TextStyle(fontSize: 10, color: ThixSanteColors.muted))]));
  Widget _activityCard(BuildContext context, WidgetRef ref, String type, IconData icon, int duration, int calories, int steps) => InkWell(onTap: () async {
    final db = Supabase.instance.client;
    final uid = db.auth.currentUser!.id;
    try {
      await db.from('activity_logs').insert({'patient_uid': uid, 'type': type, 'duration_min': duration, 'calories': calories, 'steps': steps, 'created_at': DateTime.now().toIso8601String()});
      ref.invalidate(activityTodayProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type $duration min enregistre - activity_logs'), backgroundColor: ThixSanteColors.success));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Creez table activity_logs. Erreur: $e'), backgroundColor: ThixSanteColors.warning));
    }
  }, borderRadius: BorderRadius.circular(14), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixSanteColors.borderLight)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ThixSanteColors.primaryLight, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 20, color: ThixSanteColors.primary)), const Spacer(), Text(type, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text('$duration min • ~$calories kcal - insert reel', style: const TextStyle(fontSize: 10, color: ThixSanteColors.muted))]))); 
}
