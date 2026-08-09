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
  // Branchement 100% ThixPolicy pour les couleurs des services
  late final List<ServiceItem> _dossierServices = [
    ServiceItem('Ordonnances', 'Prescriptions', Icons.receipt_long_rounded, ThixPolicy.primaryDeep, const MesOrdonnancesPage()),
    ServiceItem('Résultats', 'Labo & Imagerie', Icons.biotech_rounded, ThixPolicy.primary, const ResultatsExamensPage()),
    ServiceItem('Vaccins', 'Carnet à jour', Icons.vaccines_rounded, ThixPolicy.success, const CarnetVaccinationPage()),
    ServiceItem('Historique', 'Dossier complet', Icons.folder_shared_rounded, ThixPolicy.textSecondary, const DossierMedicalPage()),
    ServiceItem('Assurance', 'Couverture', Icons.shield_rounded, ThixPolicy.inkDeep, const AssuranceSantePage()),
    ServiceItem('Partage', 'Accès médecins', Icons.share_rounded, ThixPolicy.primary, const DossierPartagePage()),
  ];

  late final List<ServiceItem> _careServices = [
    ServiceItem('Médicaments', 'En pharmacie', Icons.medication_rounded, ThixPolicy.primaryDeep, const TrouverMedicamentPage()),
    ServiceItem('Second Avis', 'Experts médicaux', Icons.people_alt_rounded, ThixPolicy.primary, const SecondAvisPage()),
    ServiceItem('Don de sang', 'Centres proches', Icons.bloodtype_rounded, ThixPolicy.danger, const DonSangPage()),
    ServiceItem('Rendez-vous', 'Planification', Icons.medical_services_rounded, ThixPolicy.success, const ConsulterMedecinPage()),
    ServiceItem('Épidémies', 'Alertes locales', Icons.coronavirus_rounded, ThixPolicy.warning, const EpidemiesPage()),
  ];

  late final List<ServiceItem> _familyServices = [
    ServiceItem('Profils', 'Gérer la famille', Icons.family_restroom_rounded, ThixPolicy.primaryDeep, const DossierFamillePage()),
    ServiceItem('Maternité', 'Suivi grossesse', Icons.pregnant_woman_rounded, ThixPolicy.danger, const SuiviGrossessePage()),
    ServiceItem('Pédiatrie', 'Santé enfants', Icons.child_care_rounded, ThixPolicy.primary, const SanteEnfantsPage()),
    ServiceItem('Rappels', 'Prochains soins', Icons.notifications_active_rounded, ThixPolicy.warning, const RappelsVaccinPage()),
  ];

  late final List<ServiceItem> _wellbeingServices = [
    ServiceItem('Nutrition', 'Suivi alimentaire', Icons.restaurant_rounded, ThixPolicy.warning, const NutritionPage()),
    ServiceItem('Activité', 'Sport & Fitness', Icons.directions_run_rounded, ThixPolicy.success, const ActivitePhysiquePage()),
    ServiceItem('Psychologie', 'Santé mentale', Icons.psychology_rounded, ThixPolicy.primaryDeep, const BienEtreMentalPage()),
    ServiceItem('Relaxation', 'Gestion du stress', Icons.self_improvement_rounded, ThixPolicy.primary, const GestionStressPage()),
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
                // 1. HEADER (SliverAppBar propre)
                _buildModernHeader(profile),
                
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 2. STATISTIQUES (Carte compacte)
                      _buildCompactStatsCard(stats),
                      const SizedBox(height: 24),
                      
                      // 3. ACTIONS RAPIDES (Bannières)
                      _buildQuickActionBanners(),
                      const SizedBox(height: 32),
                      
                      // 4. GRILLES DE SERVICES (Compactes et lisibles)
                      _buildSectionTitle('Dossier Médical'),
                      _buildServiceGrid(_dossierServices),
                      const SizedBox(height: 32),
                      
                      _buildSectionTitle('Parcours de Soins'),
                      _buildServiceGrid(_careServices),
                      const SizedBox(height: 32),
                      
                      _buildSectionTitle('Famille & Proches'),
                      _buildServiceGrid(_familyServices),
                      const SizedBox(height: 32),
                      
                      _buildSectionTitle('Bien-être & Prévention'),
                      _buildServiceGrid(_wellbeingServices),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          
          // BOTTOM NAVIGATION FLOTTANTE (Premium)
          _buildPremiumBottomNav(),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. HEADER MODERNE (SliverAppBar)
  // =========================================================================
  Widget _buildModernHeader(AsyncValue<PatientProfile> profileAsync) {
    final fullName = profileAsync.valueOrNull?.name ?? 'Patient';
    final firstName = fullName.split(' ').first;
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;

    return SliverAppBar(
      backgroundColor: ThixPolicy.surfaceSoft,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: ThixPolicy.inkDeep.withOpacity(0.05),
      collapsedHeight: 70,
      expandedHeight: 70,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              // Avatar
              Container(
                height: 44, width: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.card,
                  border: Border.all(color: ThixPolicy.border, width: 1.5),
                  image: (avatarUrl != null && avatarUrl.isNotEmpty) 
                      ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) 
                      : null,
                ),
                child: (avatarUrl == null || avatarUrl.isEmpty) 
                    ? const Icon(Icons.person_rounded, color: ThixPolicy.textMuted, size: 24) 
                    : null,
              ),
              const SizedBox(width: 12),
              
              // Texte
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Bonjour, $firstName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.inkDeep, letterSpacing: -0.5)),
                    const Row(
                      children: [
                        Icon(Icons.shield_rounded, size: 12, color: ThixPolicy.success),
                        SizedBox(width: 4),
                        Text('Espace sécurisé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThixPolicy.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Actions (SOS + Notifs)
              InkWell(
                onTap: () => _go(const UrgencesProchesPage()),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ThixPolicy.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ThixPolicy.danger.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 16, color: ThixPolicy.danger),
                      SizedBox(width: 4),
                      Text('SOS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: ThixPolicy.danger)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 40, width: 40,
                  decoration: BoxDecoration(
                    color: ThixPolicy.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: ThixPolicy.border),
                  ),
                  child: const Icon(Icons.notifications_none_rounded, color: ThixPolicy.inkDeep, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 2. CARTE STATISTIQUES COMPACTE
  // =========================================================================
  Widget _buildCompactStatsCard(AsyncValue<DashboardStats> statsAsync) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
      ),
      child: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
        error: (_, __) => const Center(child: Text('Erreur de chargement', style: TextStyle(color: ThixPolicy.textMuted))),
        data: (d) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            __buildStatItem('Consultations', d.consultations, ThixPolicy.primary, Icons.medical_services_rounded),
            _buildStatDivider(),
            _buildStatItem('Examens', d.examens, ThixPolicy.success, Icons.science_rounded),
            _buildStatDivider(),
            _buildStatItem('Traitements', d.medicaments, ThixPolicy.primaryDeep, Icons.medication_rounded),
            _buildStatDivider(),
            _buildStatItem('Rendez-vous', d.rdvs, ThixPolicy.warning, Icons.calendar_today_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ThixPolicy.inkDeep, letterSpacing: -0.5)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThixPolicy.textSecondary)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 30, width: 1, color: ThixPolicy.border);
  }

  // =========================================================================
  // 3. BANNIÈRES D'ACTIONS RAPIDES
  // =========================================================================
  Widget _buildQuickActionBanners() {
    return Row(
      children: [
        Expanded(
          child: _buildBanner(
            title: 'Pharmacies',
            subtitle: 'Trouver de garde',
            icon: Icons.local_pharmacy_rounded,
            bgColor: ThixPolicy.success.withOpacity(0.08),
            iconColor: ThixPolicy.success,
            onTap: () => _go(const PharmaciesProchesPage()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBanner(
            title: 'Hôpitaux',
            subtitle: 'Réseau de soins',
            icon: Icons.local_hospital_rounded,
            bgColor: ThixPolicy.primary.withOpacity(0.08),
            iconColor: ThixPolicy.primary,
            onTap: () => _go(const TrouverHopitalPage()),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner({required String title, required String subtitle, required IconData icon, required Color bgColor, required Color iconColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
      child: Container(
        padding: const EdgeInsets.all(ThixPolicy.s16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: iconColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: iconColor.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: ThixPolicy.s12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: ThixPolicy.inkDeep, letterSpacing: -0.3)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: iconColor)),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. GRILLES DE SERVICES COMPACTES
  // =========================================================================
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ThixPolicy.s16),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.inkDeep, letterSpacing: -0.3)),
    );
  }

  Widget _buildServiceGrid(List<ServiceItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: ThixPolicy.s12,
        crossAxisSpacing: ThixPolicy.s12,
        childAspectRatio: 2.6,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final it = items[index];
        return InkWell(
          onTap: () => _go(it.page),
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              border: Border.all(color: ThixPolicy.border),
              boxShadow: ThixPolicy.shadowSoft(opacity: 0.015),
            ),
            child: Row(
              children: [
                Container(
                  height: 38, width: 38,
                  decoration: BoxDecoration(
                    color: it.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(it.icon, color: it.color, size: 20),
                ),
                const SizedBox(width: 10),
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
            color: ThixPolicy.inkDeep, // Utilisation de ThixPolicy.inkDeep
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _premiumNavItem(Icons.home_rounded, 'Accueil', true, () {}),
                  _premiumNavItem(Icons.folder_shared_rounded, 'Dossier', false, () => _go(const DossierMedicalPage())),
                  const SizedBox(width: 50), // Espace pour le FAB IA
                  _premiumNavItem(Icons.search_rounded, 'Soins', false, () => _go(const TrouverHopitalPage())),
                  _premiumNavItem(Icons.people_alt_rounded, 'Famille', false, () => _go(const DossierFamillePage())),
                ],
              ),
              // Bouton IA Central Flottant (Dégradé ThixPolicy)
              Positioned(
                top: -20,
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
                        boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
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
        width: 50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: active ? Colors.white : ThixPolicy.textSecondary),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? Colors.white : ThixPolicy.textSecondary)),
          ],
        ),
      ),
    );
  }
}
