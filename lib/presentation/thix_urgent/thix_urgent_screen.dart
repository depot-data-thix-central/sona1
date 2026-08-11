import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'controllers/urgent_controller.dart';

// Palette de couleurs THIX
const Color kBg = Color(0xFF0A0A0F);
const Color kCard = Color(0xFF1A1C25);
const Color kRed = Color(0xFFFF2D2D);
const Color kAmber = Color(0xFFFBBF24);
const Color kBlue = Color(0xFF2D6CDF);
const Color kGreen = Color(0xFF22C55E);

class ThixSosDashboard extends StatefulWidget {
  const ThixSosDashboard({super.key});

  @override
  State<ThixSosDashboard> createState() => _ThixSosDashboardState();
}

class _ThixSosDashboardState extends State<ThixSosDashboard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<UrgentController>().loadGardiens());
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<UrgentController>();

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('THIX CENTRAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // ==========================================
            // PARTIE 1: THIX RETROUVE
            // ==========================================
            const Row(children: [
              Icon(Icons.search, color: kAmber, size: 28),
              SizedBox(width: 8),
              Text('THIX RETROUVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            ]),
            const SizedBox(height: 16),
            Row(
              children: [
                _actionCard(context, 'J\'ai perdu un objet', Icons.help_outline, kAmber, '/thix-retrouve/perdu'),
                const SizedBox(width: 12),
                _actionCard(context, 'J\'ai trouvé un objet', Icons.inventory, kBlue, '/thix-retrouve/trouve'),
              ],
            ),
            const SizedBox(height: 30),

            // ==========================================
            // PARTIE 2: THIX URGENT
            // ==========================================
            const Row(children: [
              Icon(Icons.shield_rounded, color: kRed, size: 28),
              SizedBox(width: 8),
              Text('THIX URGENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            ]),
            const SizedBox(height: 16),

            // Gardiens Config
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const CircleAvatar(backgroundColor: Colors.black12, child: Icon(Icons.person, color: Colors.black)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Mes gardiens', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${ctrl.gardiens.length} contacts configurés', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ])),
                TextButton(onPressed: () => _showConfigSecours(context, ctrl), child: const Text('CONFIGURER', style: TextStyle(fontWeight: FontWeight.bold)))
              ]),
            ),

            const SizedBox(height: 40),

            // Gros Bouton SOS
            GestureDetector(
              onLongPress: () async {
                HapticFeedback.heavyImpact();
                final ok = await ctrl.declencherAlerte();
                if (ok && mounted) {
                  context.push('/thix-urgent/chambre-de-crise', extra: {'criseId': ctrl.criseId, 'type': ctrl.selectedType});
                }
              },
              child: Container(
                width: 180, height: 180,
                decoration: BoxDecoration(
                  color: kRed,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: kRed.withOpacity(0.4), blurRadius: 40, spreadRadius: 10)]
                ),
                child: const Icon(Icons.shield_rounded, size: 70, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Maintiens 2s pour alerter', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),

            const SizedBox(height: 30),

            // Sélecteurs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Row(children: [
                _buildGreenBtn(Icons.warning_rounded, 'DÉNONCER', EmergencyType.denoncer, ctrl),
                _buildGreenBtn(Icons.car_crash_rounded, 'ACCIDENT', EmergencyType.accident, ctrl),
                _buildGreenBtn(Icons.local_police_rounded, 'POLICE', EmergencyType.police, ctrl),
                _buildGreenBtn(Icons.person_search_rounded, 'PERSONNE', EmergencyType.personne, ctrl),
              ]),
            ),

            const SizedBox(height: 20),

            // Chambre de crise
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kCard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => context.push('/thix-urgent/chambre-de-crise', extra: {'criseId': ctrl.criseId, 'type': ctrl.selectedType}),
                icon: const Icon(Icons.lock, color: Colors.white),
                label: const Text('CHAMBRE DE CRISE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(BuildContext context, String title, IconData icon, Color color, String route) {
    return Expanded(
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _buildGreenBtn(IconData icon, String label, EmergencyType type, UrgentController ctrl) {
    final isSelected = ctrl.selectedType == type;
    return Expanded(child: GestureDetector(
      onTap: () => ctrl.selectType(type),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? kGreen : kGreen.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2)
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ]),
      ),
    ));
  }

  void _showConfigSecours(BuildContext context, UrgentController ctrl) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: kCard, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(20), 
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Configuration Secours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          _listTileSecours(Icons.contacts, 'Mes gardiens', 'Gérer les contacts', () => context.push('/thix-urgent/config/gardiens')),
          _listTileSecours(Icons.local_police, 'Police', 'Auto-localisation active', null),
          _listTileSecours(Icons.mic, 'Sirène d\'alerte', ctrl.sireneActive ? 'ON' : 'OFF', () {
            ctrl.sireneActive = !ctrl.sireneActive;
            ctrl.notifyListeners();
            Navigator.pop(sheetCtx);
          }),
        ]),
      )
    );
  }

  Widget _listTileSecours(IconData icon, String title, String sub, VoidCallback? onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      onTap: onTap,
    );
  }
}
