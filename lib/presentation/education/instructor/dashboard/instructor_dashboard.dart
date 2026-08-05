// lib/presentation/education/instructor/dashboard/instructor_dashboard.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _C {
  static const bg = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF2D6CDF);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF59E0B);
  static const purple = Color(0xFF8B5CF6);
  static const red = Color(0xFFEF4444);
}

class InstructorDashboard extends ConsumerStatefulWidget {
  const InstructorDashboard({super.key});

  @override
  ConsumerState<InstructorDashboard> createState() => _InstructorDashboardState();
}

class _InstructorDashboardState extends ConsumerState<InstructorDashboard> {
  int _totalCourses = 0;
  int _totalBooks = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _recentCourses = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // 1. Récupération réelle des cours du formateur
      final coursesRes = await Supabase.instance.client
          .from('formations')
          .select('id, title, created_at')
          .eq('instructor_id', userId)
          .order('created_at', ascending: false);

      final coursesList = List<Map<String, dynamic>>.from(coursesRes as List);

      // 2. Récupération réelle des livres (si la table existe)
      int booksCount = 0;
      try {
        final booksRes = await Supabase.instance.client
            .from('books')
            .select('id')
            .eq('instructor_id', userId);
        booksCount = (booksRes as List).length;
      } catch (_) {
        // Table optionnelle ou autre nom, géré proprement sans bloquer
      }

      if (mounted) {
        setState(() {
          _totalCourses = coursesList.length;
          _totalBooks = booksCount;
          _recentCourses = coursesList.take(4).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement dashboard formateur: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Text('Tableau de bord formateur', style: TextStyle(fontWeight: FontWeight.w800, color: _C.textMain, fontSize: 18)),
        backgroundColor: _C.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded, color: _C.primary),
            onPressed: () => context.push('/education'),
            tooltip: 'Espace apprenant',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: _C.textMain),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _C.primary))
          : RefreshIndicator(
              color: _C.primary,
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistiques dynamiques réelles
                    Row(
                      children: [
                        _StatCard(icon: Icons.school_rounded, label: 'Mes Cours', value: '$_totalCourses', color: _C.primary),
                        const SizedBox(width: 12),
                        _StatCard(icon: Icons.menu_book_rounded, label: 'Mes Livres', value: '$_totalBooks', color: _C.green),
                        const SizedBox(width: 12),
                        _StatCard(icon: Icons.people_rounded, label: 'Activité', value: 'Actif', color: _C.purple),
                      ],
                    ),
                    const SizedBox(height: 28),
                    
                    const Text('Actions rapides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.textMain)),
                    const SizedBox(height: 14),
                    
                    // Grille des actions rapides (Cours + Livres intégrés avec GoRouter)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _QuickAction(
                          icon: Icons.add_rounded, 
                          label: 'Nouveau cours', 
                          onTap: () async { await context.push('/instructor/courses/create'); _loadDashboardData(); }, 
                          color: _C.primary,
                        ),
                        _QuickAction(
                          icon: Icons.menu_book_rounded, 
                          label: 'Mes cours', 
                          onTap: () async { await context.push('/instructor/courses'); _loadDashboardData(); }, 
                          color: _C.green,
                        ),
                        _QuickAction(
                          icon: Icons.library_add_rounded, 
                          label: 'Nouveau livre', 
                          onTap: () async { await context.push('/instructor/books/create'); _loadDashboardData(); }, 
                          color: _C.orange,
                        ),
                        _QuickAction(
                          icon: Icons.collections_bookmark_rounded, 
                          label: 'Mes livres', 
                          onTap: () async { await context.push('/instructor/books'); _loadDashboardData(); }, 
                          color: _C.purple,
                        ),
                        _QuickAction(
                          icon: Icons.bar_chart_rounded, 
                          label: 'Performance', 
                          onTap: () => context.push('/instructor/performance'), 
                          color: _C.orange,
                        ),
                        _QuickAction(
                          icon: Icons.announcement_rounded, 
                          label: 'Annonces', 
                          onTap: () => context.push('/instructor/announcements'), 
                          color: _C.red,
                        ),
                        _QuickAction(
                          icon: Icons.calendar_today_rounded, 
                          label: 'Calendrier', 
                          onTap: () => context.push('/instructor/calendar'), 
                          color: const Color(0xFF0D9488),
                        ),
                        _QuickAction(
                          icon: Icons.flag_rounded, 
                          label: 'Bannière À la une', 
                          onTap: () => context.push('/instructor/banner'), 
                          color: _C.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    
                    const Text('Activités récentes (Cours créés)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.textMain)),
                    const SizedBox(height: 14),
                    
                    // Liste réelle des derniers cours créés
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.border),
                      ),
                      child: _recentCourses.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text('Aucune activité récente pour le moment.', style: TextStyle(color: _C.textMuted, fontSize: 13)),
                              ),
                            )
                          : Column(
                              children: _recentCourses.map((course) {
                                final title = course['title'] as String? ?? 'Cours sans titre';
                                return _ActivityItem(
                                  icon: Icons.check_circle_rounded,
                                  title: 'Cours créé : $title',
                                  time: 'Enregistré dans la base',
                                  color: _C.green,
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon; 
  final String label; 
  final String value; 
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override 
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface, 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: _C.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28), 
            const SizedBox(height: 8), 
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _C.textMain)), 
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: _C.textMuted, fontWeight: FontWeight.w500))
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon; 
  final String label; 
  final VoidCallback onTap; 
  final Color color;

  const _QuickAction({required this.icon, required this.label, required this.onTap, required this.color});

  @override 
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08), 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Icon(icon, color: color, size: 20), 
            const SizedBox(width: 8), 
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color))
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon; 
  final String title; 
  final String time; 
  final Color color;

  const _ActivityItem({required this.icon, required this.title, required this.time, required this.color});

  @override 
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36, 
            height: 36, 
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), 
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.textMain)), 
                Text(time, style: const TextStyle(fontSize: 12, color: _C.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
