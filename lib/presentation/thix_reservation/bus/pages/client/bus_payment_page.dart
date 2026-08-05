// lib/presentation/thix_reservation/bus/pages/client/bus_payment_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/bus_trip_model.dart';
import '../../providers/booking_provider.dart';

class BusPaymentPage extends StatelessWidget {
  final BusTripModel trip;
  final List<String> seats;
  const BusPaymentPage({super.key, required this.trip, required this.seats});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final base = trip.priceFcfa * seats.length;
    final total = base + 300; // frais service

    return Scaffold(
      appBar: AppBar(title: const Text('Paiement')),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Trajet'), Text('${trip.departureCity} → ${trip.arrivalCity}', style: const TextStyle(fontWeight: FontWeight.bold))]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Sièges'), Text(seats.join(', '), style: const TextStyle(fontWeight: FontWeight.bold))]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Sous-total'), Text('$base FCFA')]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Frais service THIX'), const Text('300 FCFA')]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total à payer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Text('$total FCFA', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0D47A1)))]),
        ])),
        const Spacer(),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: provider.isPaying? null: () async {
          try {
            final booking = await provider.createBookingAndPay(agencyId: trip.agencyId, tripId: trip.id, seats: seats, basePrice: trip.priceFcfa, vipSupplement: 0);
            if (context.mounted) context.go('/thix-reservation/bus/ticket/${booking.id}', extra: booking);
          } catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'))); }
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)), child: provider.isPaying? const CircularProgressIndicator(color: Colors.white): const Text('Payer maintenant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
        const SizedBox(height: 12),
        Text('Paiement sécurisé lié à votre THIX ID • ${trip.agency?.name}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600), textAlign: TextAlign.center),
      ])),
    );
  }
}
