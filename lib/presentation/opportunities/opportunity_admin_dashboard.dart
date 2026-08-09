// lib/presentation/opportunities/opportunity_admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/services/opportunity_service.dart';

class OpportunityAdminDashboard extends StatefulWidget {
  const OpportunityAdminDashboard({super.key});

  @override
  State<OpportunityAdminDashboard> createState() => _OpportunityAdminDashboardState();
}

class _OpportunityAdminDashboardState extends State<OpportunityAdminDashboard> {
  final OpportunityService _service = OpportunityService();
  late Future<List<OpportunityItem>> _opportunitiesFuture;
  
  String _currentFilter = 'Toutes';
  final List<String> _filters = ['Toutes', 'Publiées', 'Brouillons', 'Expirées'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _opportunitiesFuture = _service.listOpportunities();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS D'ADMINISTRATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _deleteOpportunity(OpportunityItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: const Text('Supprimer définitivement ?', style: TextStyle(color: ThixPolicy.danger, fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text('Êtes-vous sûr de vouloir supprimer "${item.title}" ? Cette action est irréversible.', style: const TextStyle(color: ThixPolicy.textMain)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: ThixPolicy.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 🌟 APPEL SUPABASE POUR SUPPRIMER
        // await Supabase.instance.client.from('thix_opportunities').delete().eq('id', item.id);
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opportunité supprimée.'), backgroundColor: ThixPolicy.success));
        _loadData(); // Rafraîchir la liste
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: ThixPolicy.danger));
      }
    }
  }

  Future<void> _updateStatus(OpportunityItem item, String newStatus) async {
    try {
      // 🌟 APPEL SUPABASE POUR METTRE À JOUR LE STATUT ('published', 'draft', 'countdown')
      // await Supabase.instance.client.from('thix_opportunities').update({'status': newStatus}).eq('id', item.id);
      
      String msg = '';
      if (newStatus == 'draft') msg = 'Déplacé vers les brouillons.';
      if (newStatus == 'published') msg = 'Opportunité publiée en ligne.';
      if (newStatus == 'countdown') msg = 'Compte à rebours d\'urgence activé !';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: newStatus == 'countdown' ? ThixPolicy.warning : ThixPolicy.success));
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: ThixPolicy.danger));
    }
  }

  void _showActionMenu(OpportunityItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s12, ThixPolicy.s20, ThixPolicy.s32),
        decoration: const BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: ThixPolicy.s24),
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)),
            const SizedBox(height: ThixPolicy.s16),
            const Divider(height: 1, color: ThixPolicy.border),
            const SizedBox(height: ThixPolicy.s8),

            _buildActionItem(Icons.edit_rounded, 'Modifier l\'opportunité', ThixPolicy.textMain, () {
              Navigator.pop(ctx);
              // context.push('/opportunities/admin/edit/${item.id}'); // Route vers ton formulaire avec données pré-remplies
            }),
            
            _buildActionItem(Icons.visibility_off_rounded, 'Mettre en brouillon', ThixPolicy.textMain, () {
              Navigator.pop(ctx);
              _updateStatus(item, 'draft');
            }),
            
            _buildActionItem(Icons.timer_rounded, 'Activer le compte à rebours', ThixPolicy.warning, () {
              Navigator.pop(ctx);
              _updateStatus(item, 'countdown');
            }),

            _buildActionItem(Icons.delete_outline_rounded, 'Supprimer définitivement', ThixPolicy.danger, () {
              Navigator.pop(ctx);
              _deleteOpportunity(item);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI PRINCIPALE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20),
          onPressed: () => context.pop(), // Retour à l'appli principale
        ),
        title: const Text('Gestion des Opportunités', style: TextStyle(color: ThixPolicy.textMain, fontSize: 16, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: ThixPolicy.border, height: 1)),
      ),
      // Le bouton d'ajout flottant
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.selectionClick();
          context.push('/opportunities/admin/create'); // Route vers le formulaire qu'on a créé tout à l'heure
        },
        backgroundColor: ThixPolicy.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Créer', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtres Rapides
          Container(
            color: ThixPolicy.card,
            padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s16),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final isSelected = _currentFilter == _filters[i];
                  return InkWell(
                    onTap: () => setState(() => _currentFilter = _filters[i]),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? ThixPolicy.inkDeep : ThixPolicy.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? ThixPolicy.inkDeep : ThixPolicy.border),
                      ),
                      child: Text(_filters[i], style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? Colors.white : ThixPolicy.textSecondary)),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Liste des Opportunités
          Expanded(
            child: FutureBuilder<List<OpportunityItem>>(
              future: _opportunitiesFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
                }

                final list = snap.data ?? [];
                
                // Ici tu devrais filtrer la liste en fonction de _currentFilter
                // ex: if (_currentFilter == 'Brouillons') list = list.where((o) => o.status == 'draft').toList();

                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 64, color: ThixPolicy.borderStrong),
                        const SizedBox(height: 16),
                        const Text('Aucune opportunité trouvée.', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(ThixPolicy.s16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    return _buildAdminCard(list[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(OpportunityItem item) {
    // 🌟 Simulation de statut pour l'UI (À adapter avec tes vraies données Supabase)
    // On simule un statut en fonction du nom pour le test visuel
    String status = 'published';
    Color statusColor = ThixPolicy.success;
    String statusLabel = 'Publiée';
    IconData statusIcon = Icons.check_circle_rounded;

    // Logique fictive pour l'exemple
    if (item.title.contains('Brouillon')) {
      status = 'draft';
      statusColor = ThixPolicy.textSecondary;
      statusLabel = 'Brouillon';
      statusIcon = Icons.visibility_off_rounded;
    } else if (item.deadline.isBefore(DateTime.now())) {
      status = 'expired';
      statusColor = ThixPolicy.danger;
      statusLabel = 'Expirée';
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: ThixPolicy.s16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la carte (Statut + Bouton Options)
          Padding(
            padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s12, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded, color: ThixPolicy.textSecondary),
                  onPressed: () => _showActionMenu(item),
                ),
              ],
            ),
          ),
          
          // Contenu principal
          Padding(
            padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, 0, ThixPolicy.s16, ThixPolicy.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.apartment_rounded, size: 14, color: ThixPolicy.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(item.organizer, style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: ThixPolicy.border),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Date limite', style: TextStyle(fontSize: 10, color: ThixPolicy.textMuted, fontWeight: FontWeight.w600)),
                        Text(DateFormat('dd MMM yyyy', 'fr_FR').format(item.deadline), style: TextStyle(fontSize: 12, color: status == 'expired' ? ThixPolicy.danger : ThixPolicy.textMain, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Vues (Estimé)', style: TextStyle(fontSize: 10, color: ThixPolicy.textMuted, fontWeight: FontWeight.w600)),
                        Text('1 240', style: const TextStyle(fontSize: 12, color: ThixPolicy.primary, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
