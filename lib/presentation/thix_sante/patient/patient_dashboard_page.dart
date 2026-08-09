// lib/presentation/thix_sante/patient/patient_dashboard_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

// =========================================================================
// DESIGN SYSTEM PREMIUM - NIVEAU ENTREPRISE
// =========================================================================
class _C {
  static const bg = Color(0xFFF8FAFC); // Fond très clair et moderne
  static const white = Color(0xFFFFFFFF);
  static const navy = Color(0xFF0F172A); // Texte principal très sombre
  static const slate = Color(0xFF334155); // Texte secondaire
  static const textMuted = Color(0xFF64748B); // Texte tertiaire
  
  static const primary = Color(0xFF2563EB); // Bleu médical premium
  static const emerald = Color(0xFF059669); // Vert santé/succès
  static const violet = Color(0xFF7C3AED); // Violet tech/IA
  static const red = Color(0xFFDC2626); // Rouge urgence
  static const amber = Color(0xFFD97706); // Orange alertes
  
  static const border = Color(0xFFE2E8F0);
  static const borderLight = Color(0xFFF1F5F9);
}

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
  late final List<ServiceItem> _dossierServices = [
    ServiceItem('Ordonnances', 'Prescriptions', Icons.receipt_long_rounded, _C.violet, const MesOrdonnancesPage()),
    ServiceItem('Résultats', 'Labo & Imagerie', Icons.biotech_rounded, _C.primary, const ResultatsExamensPage()),
    ServiceItem('Vaccins', 'Carnet à jour', Icons.vaccines_rounded, _C.emerald, const CarnetVaccinationPage()),
    ServiceItem('Historique', 'Dossier complet', Icons.folder_shared_rounded, _C.slate, const DossierMedicalPage()),
    ServiceItem('Assurance', 'Couverture', Icons.shield_rounded, _C.navy, const AssuranceSantePage()),
    ServiceItem('Partage', 'Accès médecins', Icons.share_rounded, _C.primary, const DossierPartagePage()),
  ];

  late final List<ServiceItem> _careServices = [
    ServiceItem('Médicaments', 'En pharmacie', Icons.medication_rounded, _C.violet, const TrouverMedicamentPage()),
    ServiceItem('Second Avis', 'Experts médicaux', Icons.people_alt_rounded, _C.primary, const SecondAvisPage()),
    ServiceItem('Don de sang', 'Centres proches', Icons.bloodtype_rounded, _C.red, const DonSangPage()),
    ServiceItem('Rendez-vous', 'Planification', Icons.medical_services_rounded, _C.emerald, const ConsulterMedecinPage()),
    ServiceItem('Épidémies', 'Alertes locales', Icons.coronavirus_rounded, _C.amber, const EpidemiesPage()),
  ];

  late final List<ServiceItem> _familyServices = [
    ServiceItem('Profils', 'Gérer la famille', Icons.family_restroom_rounded, _C.violet, const DossierFamillePage()),
    ServiceItem('Maternité', 'Suivi grossesse', Icons.pregnant_woman_rounded, const Color(0xFFDB2777), const SuiviGrossessePage()),
    ServiceItem('Pédiatrie', 'Santé enfants', Icons.child_care_rounded, _C.primary, const SanteEnfantsPage()),
    ServiceItem('Rappels', 'Prochains soins', Icons.notifications_active_rounded, _C.amber, const RappelsVaccinPage()),
  ];

  late final List<ServiceItem> _wellbeingServices = [
    ServiceItem('Nutrition', 'Suivi alimentaire', Icons.restaurant_rounded, _C.amber, const NutritionPage()),
    ServiceItem('Activité', 'Sport & Fitness', Icons.directions_run_rounded, _C.emerald, const ActivitePhysiquePage()),
    ServiceItem('Psychologie', 'Santé mentale', Icons.psychology_rounded, _C.violet, const BienEtreMentalPage()),
    ServiceItem('Relaxation', 'Gestion du stress', Icons.self_improvement_rounded, _C.primary, const GestionStressPage()),
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
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          RefreshIndicator(
            color: _C.primary,
            backgroundColor: _C.white,
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
      backgroundColor: _C.bg,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: _C.navy.withOpacity(0.1),
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
                  color: _C.white,
                  border: Border.all(color: _C.border, width: 1.5),
                  image: (avatarUrl != null && avatarUrl.isNotEmpty) 
                      ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) 
                      : null,
                ),
                child: (avatarUrl == null || avatarUrl.isEmpty) 
                    ? const Icon(Icons.person_rounded, color: _C.textMuted, size: 24) 
                    : null,
              ),
              const SizedBox(width: 12),
              
              // Texte
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Bonjour, $firstName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _C.navy, letterSpacing: -0.5)),
                    const Row(
                      children: [
                        Icon(Icons.shield_rounded, size: 12, color: _C.emerald),
                        SizedBox(width: 4),
                        Text('Espace sécurisé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.textMuted)),
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
                    color: _C.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _C.red.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 16, color: _C.red),
                      SizedBox(width: 4),
                      Text('SOS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _C.red)),
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
                    color: _C.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.border),
                  ),
                  child: const Icon(Icons.notifications_none_rounded, color: _C.navy, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 2. CARTE STATISTIQUES COMPACTE (Remplacement des gros cercles)
  // =========================================================================
  Widget _buildCompactStatsCard(AsyncValue<DashboardStats> statsAsync) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.borderLight),
        boxShadow: [BoxShadow(color: _C.navy.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _C.primary)),
        error: (_, __) => const Center(child: Text('Erreur de chargement', style: TextStyle(color: _C.textMuted))),
        data: (d) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Consultations', d.consultations, _C.primary, Icons.stethoscope),
            _buildStatDivider(),
            _buildStatItem('Examens', d.examens, _C.emerald, Icons.science_rounded),
            _buildStatDivider(),
            _buildStatItem('Traitements', d.medicaments, _C.violet, Icons.medication_rounded),
            _buildStatDivider(),
            _buildStatItem('Rendez-vous', d.rdvs, _C.amber, Icons.calendar_today_rounded),
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
            Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _C.navy, letterSpacing: -0.5)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _C.textMuted)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 30, width: 1, color: _C.borderLight);
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
            bgColor: const Color(0xFFF0FDF4),
            iconColor: _C.emerald,
            onTap: () => _go(const PharmaciesProchesPage()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBanner(
            title: 'Hôpitaux',
            subtitle: 'Réseau de soins',
            icon: Icons.local_hospital_rounded,
            bgColor: const Color(0xFFEFF6FF),
            iconColor: _C.primary,
            onTap: () => _go(const TrouverHopitalPage()),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner({required String title, required String subtitle, required IconData icon, required Color bgColor, required Color iconColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: iconColor.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _C.navy, letterSpacing: -0.3)),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _C.navy, letterSpacing: -0.3)),
    );
  }

  Widget _buildServiceGrid(List<ServiceItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.6, // Ratio parfait pour icône + 2 lignes de texte
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final it = items[index];
        return InkWell(
          onTap: () => _go(it.page),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.borderLight),
              boxShadow: [BoxShadow(color: _C.navy.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 2))],
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
                      Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _C.navy, letterSpacing: -0.2)),
                      const SizedBox(height: 2),
                      Text(it.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _C.textMuted)),
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
            color: _C.navy, // Fond sombre premium
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: _C.navy.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
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
              // Bouton IA Central Flottant
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
                        gradient: const LinearGradient(colors: [_C.primary, Color(0xFF0EA5E9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.bg, width: 4),
                        boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: _C.white, size: 28),
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
            Icon(icon, size: 22, color: active ? _C.white : _C.textMuted),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? _C.white : _C.textMuted)),
          ],
        ),
      ),
    );
  }
}
