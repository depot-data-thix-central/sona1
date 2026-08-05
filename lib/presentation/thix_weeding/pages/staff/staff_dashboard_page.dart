// lib/presentation/thix_weeding/pages/staff/staff_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

class StaffDashboardPage extends ConsumerWidget {
  final String weddingId;
  const StaffDashboardPage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weddingAsync = ref.watch(weddingProvider(weddingId));
    final statsAsync = ref.watch(dashboardStatsProvider(weddingId));
    final budgetAsync = ref.watch(paymentsSummaryProvider(weddingId));
    final messagesAsync = ref.watch(messagesProvider(weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.menu),
            SizedBox(width: 12),
            Text(
              'Mariage+',
              style: TextStyle(
                color: Color(0xFF0B3B8F),
                fontWeight: FontWeight.w900,
              ),
            ),
            Text('❤️'),
          ],
        ),
        actions: [
          messagesAsync.maybeWhen(
            data: (msgs) {
              final unread = msgs.where((m) => !m.isRead).length;
              return IconButton(
                onPressed: () =>
                    context.push('/thix-weeding/staff/$weddingId/messages'),
                icon: unread > 0
                    ? Badge(
                        label: Text('$unread'),
                        child: const Icon(Icons.notifications_outlined),
                      )
                    : const Icon(Icons.notifications_outlined),
              );
            },
            orElse: () => IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundImage: NetworkImage('https://i.pravatar.cc/100'),
            ),
          ),
        ],
      ),
      body: weddingAsync.when(
        // ========== LOADING ==========
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF0B3B8F)),
              SizedBox(height: 16),
              Text(
                'Chargement du mariage...',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),

        // ========== ERROR ==========
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Impossible de charger le mariage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'ID: $weddingId',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(weddingProvider(weddingId));
                    ref.invalidate(dashboardStatsProvider(weddingId));
                    ref.invalidate(paymentsSummaryProvider(weddingId));
                    ref.invalidate(messagesProvider(weddingId));
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B3B8F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ========== DATA ==========
        data: (WeddingModel wedding) {
          final stats = statsAsync.value;
          final summary = budgetAsync.value;

          final daysLeft = wedding.weddingDate != null
              ? wedding.weddingDate!.difference(DateTime.now()).inDays.clamp(0, 9999)
              : 0;
          final totalBudget = summary?['budget'] ?? 0.0;
          final totalSpent = summary?['spent'] ?? 0.0;
          final totalPaid = summary?['paid'] ?? 0.0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(weddingProvider(weddingId));
              ref.invalidate(dashboardStatsProvider(weddingId));
              ref.invalidate(paymentsSummaryProvider(weddingId));
              ref.invalidate(messagesProvider(weddingId));
              ref.invalidate(guestbookProvider(weddingId));
              ref.invalidate(galleryProvider(weddingId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(wedding: wedding, weddingId: weddingId),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tableau de bord',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Personnaliser'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _DashCard(
                      title: 'Invités',
                      subtitle: 'Gérez vos invités\net les RSVPs',
                      icon: Icons.people,
                      color: Colors.blue,
                      badge: '${stats?['guests'] ?? 0}',
                      onTap: () => context.push('/thix-weeding/staff/$weddingId/invites'),
                    ),
                    _DashCard(
                      title: 'Prestataires',
                      subtitle: 'Gérez vos\nprestataires',
                      icon: Icons.store,
                      color: Colors.purple,
                      badge: '${stats?['vendors'] ?? 0}',
                      onTap: () => context.push('/thix-weeding/staff/$weddingId/prestataires'),
                    ),
                    _DashCard(
                      title: 'Budget',
                      subtitle: 'Suivez vos dépenses\net votre budget',
                      icon: Icons.attach_money,
                      color: Colors.green,
                      badge: '${totalBudget > 0 ? ((totalSpent / totalBudget * 100).toInt()) : 0}%',
                      onTap: () => context.push('/thix-weeding/staff/$weddingId/budget'),
                    ),
                    _DashCard(
                      title: 'Planning',
                      subtitle: 'Planifiez les tâches\net événements',
                      icon: Icons.calendar_month,
                      color: Colors.pink,
                      badge: '',
                      onTap: () => context.push('/thix-weeding/staff/$weddingId/checklist'), // temporairement vers checklist
                    ),
                    _DashCard(
                      title: 'Checklist',
                      subtitle: 'Suivez toutes vos\ntâches',
                      icon: Icons.checklist,
                      color: Colors.orange,
                      badge: '${stats?['pendingTasks'] ?? 0}',
                      onTap: () => context.push('/thix-weeding/staff/$weddingId/checklist'),
                    ),
                    _DashCard(
                      title: 'Galerie',
                      subtitle: 'Photos et vidéos\ndu mariage',
                      icon: Icons.photo,
                      color: Colors.blue,
                      badge: '${ref.watch(galleryProvider(weddingId)).value?.length ?? 0}',
                      onTap: () => context.push('/thix-weeding/staff/$weddingId/galerie'),
                    ),
                    _DashCard(
                      title: 'Livre d\'or',
                      subtitle: 'Messages et vœux\nde vos invités',
                      icon: Icons.favorite_border,
                      color: Colors.pink,
                      badge: '${ref.watch(guestbookProvider(weddingId)).value?.length ?? 0}',
                      onTap: () => context.push('/thix-weeding/staff/$weddingId/livre-or'),
                    ),
                    _DashCard(
                      title: 'Messages',
                      subtitle: 'Discussions avec vos\ninvités & prestataires',
                      icon: Icons.chat_bubble_outline,
                      color: Colors.blue,
                      badge: '${ref.watch(messagesProvider(weddingId)).value?.where((m) => !m.isRead).length ?? 0}',
                      onTap: () => context.push('/thix-weeding/staff/$weddingId/messages'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _PaymentsCard(
                        totalSpent: totalPaid,
                        totalBudget: totalBudget,
                        onTap: () => context.push('/thix-weeding/staff/$weddingId/paiements'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CountdownCard(
                        days: daysLeft,
                        dateStr: wedding.weddingDate?.toString().substring(0, 10) ?? 'À définir',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================= WIDGETS INTERNES =================

class _HeaderCard extends StatelessWidget {
  final WeddingModel wedding;
  final String weddingId;
  const _HeaderCard({required this.wedding, required this.weddingId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bonjour 👋', style: TextStyle(color: Colors.grey)),
                Text(
                  '${wedding.brideName} & ${wedding.groomName}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const Text(
                  'Organisez votre mariage\nen toute sérénité 💖',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: wedding.weddingDate?.toString().substring(0, 10) ?? '-',
                    ),
                    const SizedBox(width: 12),
                    _InfoChip(
                      icon: Icons.location_on,
                      label: 'Lieu',
                      value: wedding.venue ?? '-',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Progression globale', style: TextStyle(fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: 0.0,
                        backgroundColor: Colors.grey[200],
                        color: const Color(0xFF0B3B8F),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('0%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Vous êtes sur la bonne voie! 😊',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1520854221256-17451ccdf07b?w=400',
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/thix-weeding/guest/$weddingId/invitation'),
                    icon: const Icon(Icons.mail_outline, size: 16),
                    label: const Text('Voir invitation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0B3B8F),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF0B3B8F)),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

class _DashCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String badge;
  final VoidCallback onTap;

  const _DashCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context
