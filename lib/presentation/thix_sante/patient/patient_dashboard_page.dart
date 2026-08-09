// lib/presentation/thix_sante/patient/patient_dashboard_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

// Imports des pages (inchangés)
import 'screens/mon_medecin_traitant_page.dart';
import 'screens/dossier_famille_page.dart';
import 'screens/second_avis_page.dart';
import 'screens/dossier_medical_page.dart';
import 'screens/resultats_examens_page.dart';
import 'screens/mes_ordonnances_page.dart';
import 'screens/consulter_medecin_page.dart';
import 'screens/trouver_hopital_page.dart';
import 'screens/trouver_medicament_page.dart';
import 'screens/pharmacies_proches_page.dart';
import 'screens/urgences_proches_page.dart';
import 'screens/prendre_rdv_page.dart';
import 'screens/teleconsultation_page.dart';
import 'screens/assistant_ia_page.dart';
import 'screens/dossier_partage_page.dart';
import 'screens/epidemies_page.dart';
import 'screens/don_sang_page.dart';
import 'screens/rappels_vaccin_page.dart';
import 'screens/certificat_medical_page.dart';
import 'screens/assurance_sante_page.dart';
import 'screens/sante_enfants_page.dart';
import 'screens/carnet_vaccination_page.dart';
import 'screens/suivi_grossesse_page.dart';
import 'screens/analyse_predictive_page.dart';
import 'screens/bien_etre_mental_page.dart';
import 'screens/nutrition_page.dart';
import 'screens/activite_physique_page.dart';
import 'screens/gestion_stress_page.dart';

// ---------------- Données réelles ----------------
class DashboardStats {
  final int consultations, examens, medicaments, rdvs;
  const DashboardStats({
    this.consultations = 0,
    this.examens = 0,
    this.medicaments = 0,
    this.rdvs = 0,
  });
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) return const DashboardStats();
  try {
    final c = await db.from('health_links').select('id').eq('patient_id', uid);
    final e = await db.from('health_records').select('id').eq('patient_id', uid);
    final p = await db.from('prescriptions').select('id').eq('patient_id', uid).neq('status', 'delivree');
    final r = await db.from('appointments').select('id').eq('patient_id', uid).gte('date_rdv', DateTime.now().toIso8601String());
    return DashboardStats(
      consultations: (c as List).length,
      examens: (e as List).length,
      medicaments: (p as List).length,
      rdvs: (r as List).length,
    );
  } catch (_) {
    return const DashboardStats();
  }
});

class PatientProfile {
  final String name;
  final String? avatarUrl;
  const PatientProfile({required this.name, this.avatarUrl});
}

final patientProfileProvider = FutureProvider<PatientProfile>((ref) async {
  final db = Supabase.instance.client;
  final user = db.auth.currentUser;
  if (user == null) return const PatientProfile(name: 'Patient');
  try {
    final res = await db.from('profiles').select('full_name, avatar_url').eq('id', user.id).maybeSingle();
    final name = (res?['full_name'] as String?)?.trim();
    final avatar = res?['avatar_url'] as String?;
    if (name != null && name.isNotEmpty) return PatientProfile(name: name, avatarUrl: avatar);
  } catch (_) {}
  final metaName = user.userMetadata?['full_name'] as String?;
  return PatientProfile(name: (metaName != null && metaName.isNotEmpty) ? metaName : 'Patient');
});

class ServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget page;
  ServiceItem(this.title, this.subtitle, this.icon, this.color, this.page);
}

class PatientDashboardPage extends ConsumerStatefulWidget {
  const PatientDashboardPage({super.key});
  @override
  ConsumerState<PatientDashboardPage> createState() => _PatientDashboardPageState();
}

class _PatientDashboardPageState extends ConsumerState<PatientDashboardPage> {
  // Couleurs unifiées pour un look professionnel
  late final List<ServiceItem> _dossierServices = [
    ServiceItem('Ordonnances', 'Prescriptions', Icons.receipt_long_rounded, ThixPolicy.inkDeep, const MesOrdonnancesPage()),
    ServiceItem('Résultats', 'Labo & Imagerie', Icons.biotech_rounded, ThixPolicy.primaryDeep, const ResultatsExamensPage()),
    ServiceItem('Vaccins', 'Carnet à jour', Icons.vaccines_rounded, ThixPolicy.success, const CarnetVaccinationPage()),
    ServiceItem('Historique', 'Dossier complet', Icons.folder_shared_rounded, ThixPolicy.inkDeep, const DossierMedicalPage()),
    ServiceItem('Assurance', 'Couverture', Icons.shield_rounded, ThixPolicy.primary, const AssuranceSantePage()),
    ServiceItem('Partage', 'Accès médecins', Icons.share_rounded, ThixPolicy.textSecondary, const DossierPartagePage()),
  ];

  late final List<ServiceItem> _careServices = [
    ServiceItem('Médicaments', 'En pharmacie', Icons.medication_rounded, ThixPolicy.inkDeep, const TrouverMedicamentPage()),
    ServiceItem('Second Avis', 'Experts médicaux', Icons.people_alt_rounded, ThixPolicy.primaryDeep, const SecondAvisPage()),
    ServiceItem('Don de sang', 'Centres proches', Icons.bloodtype_rounded, ThixPolicy.danger, const DonSangPage()),
    ServiceItem('Rendez-vous', 'Planification', Icons.medical_services_rounded, ThixPolicy.success, const ConsulterMedecinPage()),
    ServiceItem('Épidémies', 'Alertes locales', Icons.coronavirus_rounded, ThixPolicy.warning, const EpidemiesPage()),
  ];

  late final List<ServiceItem> _familyServices = [
    ServiceItem('Profils', 'Gérer la famille', Icons.family_restroom_rounded, ThixPolicy.inkDeep, const DossierFamillePage()),
    ServiceItem('Maternité', 'Suivi grossesse', Icons.pregnant_woman_rounded, ThixPolicy.danger, const SuiviGrossessePage()),
    ServiceItem('Pédiatrie', 'Santé enfants', Icons.child_care_rounded, ThixPolicy.primary, const SanteEnfantsPage()),
    ServiceItem('Rappels', 'Prochains soins', Icons.notifications_active_rounded, ThixPolicy.warning, const RappelsVaccinPage()),
  ];

  late final List<ServiceItem> _wellbeingServices = [
    ServiceItem('Nutrition', 'Suivi alimentaire', Icons.restaurant_rounded, ThixPolicy.warning, const NutritionPage()),
    ServiceItem('Activité', 'Sport & Fitness', Icons.directions_run_rounded, ThixPolicy.success, const ActivitePhysiquePage()),
    ServiceItem('Psychologie', 'Santé mentale', Icons.psychology_rounded, ThixPolicy.inkDeep, const BienEtreMentalPage()),
    ServiceItem('Relaxation', 'Gestion du stress', Icons.self_improvement_rounded, ThixPolicy.primaryDeep, const GestionStressPage()),
  ];

  void _go(Widget page) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(patientProfileProvider);
    final stats = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: Stack(
        children: [
          RefreshIndicator(
            color: ThixPolicy.primary,
            backgroundColor: ThixPolicy.card,
            onRefresh: () async {
              ref.invalidate(dashboardStatsProvider);
              ref.invalidate(patientProfileProvider);
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildEnterpriseHeader(profile),
                
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. CARTE PREMIUM (STATISTIQUES)
                      _buildPremiumStatsCard(stats),
                      const SizedBox(height: 32),
                      
                      // 2. ACTIONS URGENTES (Design épuré, sans gros blocs pastel)
                      _buildSectionTitle('Accès Rapide', actionText: 'Tout voir'),
                      _buildUrgentActions(),
                      const SizedBox(height: 36),
                      
                      // 3. GRILLES DE SERVICES (Design Entreprise structuré)
                      _buildSectionTitle('Dossier Médical'),
                      _buildEnterpriseGrid(_dossierServices),
                      const SizedBox(height: 36),
                      
                      _buildSectionTitle('Parcours de Soins'),
                      _buildEnterpriseGrid(_careServices),
                      const SizedBox(height: 36),
                      
                      _buildSectionTitle('Famille & Proches'),
                      _buildEnterpriseGrid(_familyServices),
                      const SizedBox(height: 36),
                      
                      _buildSectionTitle('Bien-être & Prévention'),
                      _buildEnterpriseGrid(_wellbeingServices),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          
          // NAVIGATION FLOTTANTE
          _buildPremiumBottomNav(),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. EN-TÊTE (HEADER) ULTRA-CLEAN
  // =========================================================================
  Widget _buildEnterpriseHeader(AsyncValue<PatientProfile> profileAsync) {
    final fullName = profileAsync.valueOrNull?.name ?? 'Patient';
    final firstName = fullName.split(' ').first;
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;

    return SliverAppBar(
      backgroundColor: ThixPolicy.surfaceSoft,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      collapsedHeight: 75,
      expandedHeight: 75,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar avec contour premium
              Container(
                height: 48, width: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.card,
                  border: Border.all(color: ThixPolicy.borderStrong, width: 1),
                  image: (avatarUrl != null && avatarUrl.isNotEmpty) 
                      ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) 
                      : null,
                ),
                child: (avatarUrl == null || avatarUrl.isEmpty) 
                    ? const Icon(Icons.person_outline_rounded, color: ThixPolicy.textSecondary, size: 24) 
                    : null,
              ),
              const SizedBox(width: 16),
              
              // Salutation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Bonjour, $firstName', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ThixPolicy.inkDeep, letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(height: 6, width: 6, decoration: const BoxDecoration(color: ThixPolicy.success, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text('Dossier sécurisé (E2E)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ThixPolicy.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Bouton SOS Premium
              InkWell(
                onTap: () => _go(const UrgencesProchesPage()),
                borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: ThixPolicy.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                    border: Border.all(color: ThixPolicy.danger.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.emergency_rounded, size: 16, color: ThixPolicy.danger),
                      SizedBox(width: 6),
                      Text('SOS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: ThixPolicy.danger, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 2. CARTE NOIRE PREMIUM (STATISTIQUES)
  // =========================================================================
  Widget _buildPremiumStatsCard(AsyncValue<DashboardStats> statsAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // Un dégradé sombre très classe type "Carte Premium"
        gradient: const LinearGradient(
          colors: [ThixPolicy.inkDeep, Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Synthèse Santé', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              Icon(Icons.health_and_safety_rounded, color: Colors.white.withOpacity(0.5), size: 20),
            ],
          ),
          const SizedBox(height: 24),
          statsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.white))),
            error: (_, __) => const Text('Erreur de chargement', style: TextStyle(color: ThixPolicy.danger)),
            data: (d) => Column(
              children: [
                Row(
                  children: [
                    _buildDarkStatItem('Consultations', d.consultations),
                    _buildDarkDivider(),
                    _buildDarkStatItem('Examens Labo', d.examens),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Colors.white.withOpacity(0.1), height: 1),
                ),
                Row(
                  children: [
                    _buildDarkStatItem('Traitements', d.medicaments),
                    _buildDarkDivider(),
                    _buildDarkStatItem('Rendez-vous', d.rdvs),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkStatItem(String label, int value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _buildDarkDivider() {
    return Container(height: 40, width: 1, color: Colors.white.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 16));
  }

  // =========================================================================
  // 3. ACTIONS RAPIDES (Design épuré et sérieux)
  // =========================================================================
  Widget _buildUrgentActions() {
    return Row(
      children: [
        Expanded(
          child: _buildEnterpriseActionCard(
            title: 'Pharmacies',
            subtitle: 'Trouver de garde',
            icon: Icons.local_pharmacy_rounded,
            iconBgColor: ThixPolicy.success.withOpacity(0.1),
            iconColor: ThixPolicy.success,
            onTap: () => _go(const PharmaciesProchesPage()),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildEnterpriseActionCard(
            title: 'Hôpitaux',
            subtitle: 'Réseau de soins',
            icon: Icons.domain_rounded,
            iconBgColor: ThixPolicy.primary.withOpacity(0.1),
            iconColor: ThixPolicy.primary,
            onTap: () => _go(const TrouverHopitalPage()),
          ),
        ),
      ],
    );
  }

  Widget _buildEnterpriseActionCard({required String title, required String subtitle, required IconData icon, required Color iconBgColor, required Color iconColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThixPolicy.card, // Fond blanc pur
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ThixPolicy.inkDeep, letterSpacing: -0.3)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ThixPolicy.textSecondary)),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. GRILLES DE SERVICES (Design Liste Structurée / Grille Fine)
  // =========================================================================
  Widget _buildSectionTitle(String title, {String? actionText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.inkDeep, letterSpacing: -0.5)),
          if (actionText != null)
            Text(actionText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThixPolicy.primary)),
        ],
      ),
    );
  }

  Widget _buildEnterpriseGrid(List<ServiceItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.4, // Ratio allongé pour un aspect "bouton de menu"
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final it = items[index];
        return InkWell(
          onTap: () => _go(it.page),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ThixPolicy.border),
            ),
            child: Row(
              children: [
                Icon(it.icon, color: it.color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep, letterSpacing: -0.2)),
                      const SizedBox(height: 2),
                      Text(it.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ThixPolicy.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // 5. BOTTOM NAVIGATION PREMIUM (Pillule sombre)
  // =========================================================================
  Widget _buildPremiumBottomNav() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: ThixPolicy.inkDeep,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 12))],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _premiumNavItem(Icons.home_filled, 'Accueil', true, () {}),
                  _premiumNavItem(Icons.folder_shared_rounded, 'Dossier', false, () => _go(const DossierMedicalPage())),
                  const SizedBox(width: 50), // Espace pour le FAB IA
                  _premiumNavItem(Icons.search_rounded, 'Soins', false, () => _go(const TrouverHopitalPage())),
                  _premiumNavItem(Icons.people_alt_rounded, 'Famille', false, () => _go(const DossierFamillePage())),
                ],
              ),
              // Bouton IA Central Flottant (Dégradé ThixPolicy)
              Positioned(
                top: -24,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _go(const AssistantIAPage()),
                    child: Container(
                      height: 64, width: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [ThixPolicy.primary, ThixPolicy.primaryDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.surfaceSoft, width: 4),
                        boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8))],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _premiumNavItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: active ? Colors.white : ThixPolicy.textSecondary.withOpacity(0.7)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? Colors.white : ThixPolicy.textSecondary.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}
