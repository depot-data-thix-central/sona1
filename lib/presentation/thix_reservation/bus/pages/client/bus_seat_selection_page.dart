// lib/presentation/thix_reservation/bus/pages/client/bus_seat_selection_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/bus_trip_model.dart';
import '../../providers/seat_selection_provider.dart';
import '../../widgets/client/seat_map_widget.dart';

class BusSeatSelectionPage extends StatefulWidget {
  final BusTripModel trip;
  const BusSeatSelectionPage({super.key, required this.trip});
  @override
  State<BusSeatSelectionPage> createState() => _BusSeatSelectionPageState();
}

class _BusSeatSelectionPageState extends State<BusSeatSelectionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SeatSelectionProvider>().init(widget.trip.id, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SeatSelectionProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Choix des sièges'), actions: [if(provider.lockRemainingSeconds>0) Center(child: Padding(padding: const EdgeInsets.only(right: 12), child: Text('⏳ ${provider.lockRemainingSeconds~/60}:${(provider.lockRemainingSeconds%60).toString().padLeft(2,'0')}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))))]),
      body: provider.isLoading? const Center(child: CircularProgressIndicator()): SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Legend(color: Colors.white, label: 'Libre'), _Legend(color: Colors.grey.shade300, label: 'Occupé'), _Legend(color: const Color(0xFF0D47A1), label: 'Sélectionné'), _Legend(color: Colors.amber.shade100, label: 'VIP +1000'),
        ]),
        const SizedBox(height: 20),
        SeatMapWidget(seats: provider.seats, selected: provider.selectedSeats, onTap: provider.toggleSeat),
        const SizedBox(height: 20),
        if(provider.selectedSeats.isNotEmpty) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.event_seat, color: Color(0xFF0D47A1)), const SizedBox(width: 8), Text('Sièges: ${provider.selectedSeats.join(', ')}', style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text('+${provider.totalVipSupplement} FCFA VIP', style: TextStyle(fontSize: 11, color: Colors.grey.shade700))]))
      ])),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(height: 50, child: ElevatedButton(onPressed: provider.selectedSeats.isEmpty? null: () async { await provider.confirmAndUnlockForPayment(); if(context.mounted) context.push('/thix-reservation/bus/passenger', extra: {'trip': widget.trip, 'seats': provider.selectedSeats.toList()}); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)), child: Text('Continuer (${provider.selectedSeats.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))))),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color; final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [Container(width: 14, height: 14, decoration: BoxDecoration(color: color, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(3))), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 11))]);
}
