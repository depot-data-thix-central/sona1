// lib/presentation/thix_reservation/bus/pages/agency/agency_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/agency_dashboard_provider.dart';

class AgencyDashboardPage extends StatefulWidget {
  const AgencyDashboardPage({super.key});
  @override
  State<AgencyDashboardPage> createState() => _AgencyDashboardPageState();
}

class _AgencyDashboardPageState extends State<AgencyDashboardPage> {
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AgencyDashboardProvider>().init()); }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AgencyDashboardProvider>();
    if (p.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!p.hasAgency) { Future.microtask(()=> context.go('/thix-reservation/bus/agency/onboarding')); return const SizedBox(); }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: Text(p.myAgency!.name), backgroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: ()=> context.push('/thix-reservation/bus/agency/scan'))]),
      body: RefreshIndicator(onRefresh: p.init, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if(p.isPending) Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)), child: Row(children: [Icon(Icons.hourglass_top, color: Colors.orange.shade800), const SizedBox(width: 8), Expanded(child: Text('Votre agence est en attente de validation Super Admin. Vous pourrez publier des trajets après activation.', style: TextStyle(color: Colors.orange.shade900, fontSize: 12)))])),
        const SizedBox(height: 16),
        Row(children: [
          _StatCard(title: 'Aujourd\'hui', value: '${p.todayBookingsCount}', subtitle: 'réservations', color: Colors.blue),
          const SizedBox(width: 12),
          _StatCard(title: 'Revenu jour', value: '${p.todayRevenue} FCFA', subtitle: 'encaissé', color: Colors.green),
          const SizedBox(width: 12),
          _StatCard(title: 'Départs', value: '${p.pendingDepartures}', subtitle: 'à venir', color: Colors.purple),
        ]),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Mes trajets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), ElevatedButton.icon(onPressed: p.isAgencyActive? ()=> context.push('/thix-reservation/bus/agency/create-trip'): null, icon: const Icon(Icons.add, size: 16), label: const Text('Nouveau'))]),
        const SizedBox(height: 8),
        if(p.myTrips.isEmpty) Container(height: 100, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Text('Aucun trajet créé')),
        ...p.myTrips.take(5).map((t) => Card(child: ListTile(title: Text('${t.departureCity} → ${t.arrivalCity}'), subtitle: Text('${t.departureTime.day}/${t.departureTime.month} ${t.departureTime.hour}h${t.departureTime.minute.toString().padLeft(2,'0')} • ${t.availableSeats}/${t.totalSeats} places'), trailing: Text('${t.priceFcfa} FCFA', style: const TextStyle(fontWeight: FontWeight.bold))))),
        const SizedBox(height: 20),
        const Text('Dernières réservations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 8),
        ...p.agencyBookings.take(5).map((b) => Card(child: ListTile(leading: const Icon(Icons.confirmation_number), title: Text('Sièges ${b.seats.join(', ')} • ${b.totalPriceFcfa} FCFA'), subtitle: Text('${b.status} • QR ${b.qrCode}'), trailing: IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: ()=> context.push('/thix-reservation/bus/agency/scan'))))),
      ]))),
      floatingActionButton: FloatingActionButton.extended(onPressed: ()=> context.push('/thix-reservation/bus/agency/scan'), icon: const Icon(Icons.qr_code_scanner), label: const Text('Scanner billet')),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value, subtitle; final MaterialColor color;
  const _StatCard({required this.title, required this.value, required this.subtitle, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)), const SizedBox(height: 4), Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color.shade700), maxLines: 1, overflow: TextOverflow.ellipsis), Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)) ])));
}
