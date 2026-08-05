// lib/presentation/thix_sante/patient/patient_dashboard_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
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

class _C {
  static const bg = Color(0xFFF4F7FB);
  static const white = Color(0xFFFFFFFF);
  static const navy = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const emerald = Color(0xFF10B981);
  static const sky = Color(0xFF0EA5E9);
  static const violet = Color(0xFF8B5CF6);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const border = Color(0xFFE2E8F0);
  static const fabBg = Color(0xFF06B6D4);
  static const primary = Color(0xFF3B82F6); // Ajout de la couleur manquante
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

// Modèle de service avec sous-titre
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
  // Définition des services avec des sous-titres génériques (Pas de fausses données)
  late final List<ServiceItem> _dossierServices = [
    ServiceItem('Ordonnances', 'Vos prescriptions', Icons.receipt_long_rounded, _C.violet, const MesOrdonnancesPage()),
    ServiceItem('Résultats', 'Analyses & labo', Icons.biotech_rounded, _C.sky, const ResultatsExamensPage()),
    ServiceItem('Vaccination', 'Carnet à jour', Icons.vaccines_rounded, _C.emerald, const CarnetVaccinationPage()),
    ServiceItem('Dossier Médical', 'Historique complet', Icons.folder_shared_rounded, _C.sky, const DossierMedicalPage()),
    ServiceItem('Assurance', 'Couverture santé', Icons.shield_rounded, _C.navy, const AssuranceSantePage()),
    ServiceItem('Partage', 'Accès médecins', Icons.share_rounded, _C.emerald, const DossierPartagePage()),
  ];

  late final List<ServiceItem> _careServices = [
    ServiceItem('Médicaments', 'Trouver en pharmacie', Icons.medication_rounded, _C.violet, const TrouverMedicamentPage()),
    ServiceItem('Second Avis', 'Avis d\'experts', Icons.people_alt_rounded, _C.sky, const SecondAvisPage()),
    ServiceItem('Don de sang', 'Centres de collecte', Icons.bloodtype_rounded, _C.red, const DonSangPage()),
    ServiceItem('Consulter', 'Prendre rendez-vous', Icons.medical_services_rounded, _C.sky, const ConsulterMedecinPage()),
    ServiceItem('Épidémies', 'Alertes sanitaires', Icons.coronavirus_rounded, _C.red, const EpidemiesPage()),
  ];

  late final List<ServiceItem> _familyServices = [
    ServiceItem('Famille', 'Gérer les profils', Icons.family_restroom_rounded, _C.violet, const DossierFamillePage()),
    ServiceItem('Grossesse', 'Suivi de maternité', Icons.pregnant_woman_rounded, const Color(0xFFEC4899), const SuiviGrossessePage()),
    ServiceItem('Enfants', 'Suivi pédiatrique', Icons.child_care_rounded, _C.sky, const SanteEnfantsPage()),
    ServiceItem('Rappels', 'Prochains vaccins', Icons.notifications_active_rounded, _C.amber, const RappelsVaccinPage()),
  ];

  late final List<ServiceItem> _wellbeingServices = [
    ServiceItem('Nutrition', 'Suivi alimentaire', Icons.restaurant_rounded, _C.amber, const NutritionPage()),
    ServiceItem('Activité', 'Exercices physiques', Icons.directions_run_rounded, _C.emerald, const ActivitePhysiquePage()),
    ServiceItem('Santé Mentale', 'Soutien psychologique', Icons.psychology_rounded, _C.violet, const BienEtreMentalPage()),
    ServiceItem('Gestion Stress', 'Relaxation', Icons.self_improvement_rounded, _C.sky, const GestionStressPage()),
  ];

  void _go(Widget page) {
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
          Column(
            children: [
              // EN-TÊTE FIXE (Nom + Mon Suivi en cercles)
              _buildFixedHeader(profile, stats),
              
              // CONTENU DÉFILANT
              Expanded(
                child: RefreshIndicator(
                  color: _C.sky,
                  backgroundColor: _C.white,
                  onRefresh: () async {
                    ref.invalidate(dashboardStatsProvider);
                    ref.invalidate(patientProfileProvider);
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(top: 16, bottom: 120),
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    children: [
                      // Section "Trouver des soins" principale
                      _buildSectionHeaderWithLocation('Trouver des soins', 'Dar es Salaam'),
                      const SizedBox(height: 16),
                      _buildPharmacyCard(),
                      const SizedBox(height: 12),
                      _buildHospitalCard(),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle('Mon dossier'),
                      _horizontalServiceRow(_dossierServices),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle('Autres soins'),
                      _horizontalServiceRow(_careServices),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle('Famille & Proches'),
                      _horizontalServiceRow(_familyServices),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle('Bien-être & Prévention'),
                      _horizontalServiceRow(_wellbeingServices),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // BOTTOM NAVIGATION FLOTTANTE
          _buildFloatingBottomNav(),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. PARTIE HAUTE FIXE (NOM + MON SUIVI)
  // =========================================================================
  Widget _buildFixedHeader(AsyncValue<PatientProfile> profileAsync, AsyncValue<DashboardStats> statsAsync) {
    final fullName = profileAsync.valueOrNull?.name ?? 'Alex';
    final firstName = fullName.split(' ').first;
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;

    return Container(
      decoration: const BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 5))
        ]
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              // Ligne 1 : Avatar, Nom, Boutons
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 48, width: 48,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _C.emerald.withOpacity(0.5), width: 1.5),
                        ),
                        child: ClipOval(
                          child: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultAvatar())
                              : _defaultAvatar(),
                        ),
                      ),
                      Positioned(
                        bottom: 2, right: 2,
                        child: Container(
                          height: 12, width: 12,
                          decoration: BoxDecoration(color: _C.emerald, shape: BoxShape.circle, border: Border.all(color: _C.white, width: 2)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bonjour $firstName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _C.navy, letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        const Row(
                          children: [
                            Icon(Icons.verified_rounded, size: 12, color: _C.sky),
                            SizedBox(width: 4),
                            Text('Dossier sécurisé', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _go(const UrgencesProchesPage()),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 14, color: _C.red),
                          SizedBox(width: 4),
                          Text('SOS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _C.red, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Stack(
                    children: [
                      Container(
                        height: 38, width: 38,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _C.border)),
                        child: const Icon(Icons.notifications_none_rounded, color: _C.navy, size: 20),
                      ),
                      Positioned(
                        top: 0, right: 0,
                        child: Container(height: 10, width: 10, decoration: BoxDecoration(color: _C.red, shape: BoxShape.circle, border: Border.all(color: _C.white, width: 2))),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Ligne 2 : Mon Suivi (Les 4 cercles)
              statsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: _C.sky)),
                error: (_, __) => const SizedBox(),
                data: (d) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCircle('Consults.', d.consultations, _C.primary),
                    _buildStatCircle('Examens', d.examens, _C.emerald),
                    _buildStatCircle('Traitements', d.medicaments, _C.violet),
                    _buildStatCircle('RDV', d.rdvs, _C.amber),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultAvatar() => Container(color: _C.bg, child: const Icon(Icons.person, color: _C.textMuted));

  // Les cercles de "Mon Suivi"
  Widget _buildStatCircle(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          height: 56, width: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 3),
            color: color.withOpacity(0.05),
          ),
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _C.textMuted, letterSpacing: 0.2)),
      ],
    );
  }

  // =========================================================================
  // 2. CARTES D'ACCUEIL (TROUVER DES SOINS)
  // =========================================================================
  Widget _buildSectionHeaderWithLocation(String title, String location) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _C.navy, letterSpacing: -0.5)),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: _C.textMuted),
              const SizedBox(width: 4),
              Text(location, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _C.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPharmacyCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _C.border)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 64, width: 64,
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.add_rounded, color: _C.emerald, size: 32),
                ),
                Positioned(bottom: -2, right: -2, child: Container(height: 14, width: 14, decoration: BoxDecoration(color: _C.emerald, shape: BoxShape.circle, border: Border.all(color: _C.white, width: 2)))),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Pharmacies de garde', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _C.navy, letterSpacing: -0.2), overflow: TextOverflow.ellipsis)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Container(height: 6, width: 6, decoration: const BoxDecoration(color: _C.emerald, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _C.emerald)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Ouvertes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _C.emerald)),
                      const Text(' • Localisez les plus proches', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _C.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _go(const PharmaciesProchesPage()),
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(color: _C.navy, borderRadius: BorderRadius.circular(18)),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.near_me_rounded, color: _C.white, size: 14),
                              SizedBox(width: 6),
                              Text('Rechercher', style: TextStyle(color: _C.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHospitalCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _C.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _C.border)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 64, width: 64,
                  decoration: BoxDecoration(color: _C.navy, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.domain_rounded, color: _C.white, size: 28),
                ),
                Positioned(bottom: -2, right: -2, child: Container(height: 14, width: 14, decoration: BoxDecoration(color: _C.amber, shape: BoxShape.circle, border: Border.all(color: _C.white, width: 2)))),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hôpitaux & Cliniques', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _C.navy, letterSpacing: -0.2)),
                  const SizedBox(height: 4),
                  const Text('Réseau de soins • SAMU & Urgences', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _C.textMuted)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _go(const TrouverHopitalPage()),
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(color: _C.white, border: Border.all(color: _C.border), borderRadius: BorderRadius.circular(18)),
                            child: const Center(child: Text('Voir la liste', style: TextStyle(color: _C.navy, fontSize: 13, fontWeight: FontWeight.w700))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _go(const UrgencesProchesPage()),
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(18)),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.access_time_rounded, color: _C.red, size: 14),
                              SizedBox(width: 6),
                              Text('Urgence', style: TextStyle(color: _C.red, fontSize: 13, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 3. CARTES VERTICALES DE SERVICES (COMME SUR LA CAPTURE)
  // =========================================================================
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _C.navy, letterSpacing: -0.3)),
    );
  }

  Widget _horizontalServiceRow(List<ServiceItem> items) {
    return SizedBox(
      height: 160, // Plus haut pour donner l'aspect de carte verticale
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final it = items[i];
          return InkWell(
            onTap: () => _go(it.page),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 140, // Assez large pour que le texte respire
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _C.white, 
                borderRadius: BorderRadius.circular(24), 
                border: Border.all(color: _C.border)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône en haut à gauche (Squircle)
                  Container(
                    height: 48, width: 48,
                    decoration: BoxDecoration(
                      color: it.color.withOpacity(0.1), 
                      borderRadius: BorderRadius.circular(14)
                    ),
                    child: Icon(it.icon, color: it.color, size: 24),
                  ),
                  const Spacer(),
                  // Textes en bas
                  Text(
                    it.title, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _C.navy, height: 1.2)
                  ),
                  const SizedBox(height: 4),
                  Text(
                    it.subtitle, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.textMuted)
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // 4. BOTTOM NAVIGATION BAR FLOTTANTE
  // =========================================================================
  Widget _buildFloatingBottomNav() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        child: SizedBox(
          height: 80, 
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: _C.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 10))]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _navItem(Icons.home_rounded, 'Accueil', true, () {}),
                    _navItem(Icons.folder_shared_rounded, 'Dossier', false, () => _go(const DossierMedicalPage())),
                    const SizedBox(width: 60), 
                    _navItem(Icons.search_rounded, 'Soins', false, () => _go(const TrouverHopitalPage())),
                    _navItem(Icons.people_alt_rounded, 'Famille', false, () => _go(const DossierFamillePage())),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                child: GestureDetector(
                  onTap: () => _go(const AssistantIAPage()),
                  child: Container(
                    height: 60, width: 60,
                    decoration: BoxDecoration(
                      color: _C.fabBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: _C.bg, width: 4),
                      boxShadow: [BoxShadow(color: _C.fabBg.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: _C.white, size: 28),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                child: Container(height: 4, width: 4, decoration: const BoxDecoration(color: _C.emerald, shape: BoxShape.circle)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: active ? _C.navy : _C.textMuted.withOpacity(0.5)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? _C.navy : _C.textMuted)),
        ],
      ),
    );
  }
}
