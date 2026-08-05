// lib/presentation/thix_reservation/bus/pages/client/bus_trip_detail_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/bus_trip_model.dart';

class BusTripDetailPage extends StatelessWidget {
  final BusTripModel trip;
  const BusTripDetailPage({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('${trip.departureCity} → ${trip.arrivalCity}'), backgroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header Agence SaaS
        Row(children: [
          CircleAvatar(radius: 24, backgroundImage: trip.agency?.logoUrl!= null? NetworkImage(trip.agency!.logoUrl!): null, child: trip.agency?.logoUrl== null? Text(trip.agency?.name[0]??'A'): null),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(trip.agency?.name??'', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), if(trip.agency?.isVerified==true) const Icon(Icons.verified, color: Colors.blue, size: 16)]), Text('${trip.busType.toUpperCase()} • ${trip.agency?.ratingAvg??0} ⭐ (${trip.agency?.ratingCount??0})', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])
        ]),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${trip.departureTime.hour.toString().padLeft(2,'0')}:${trip.departureTime.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)), Text(trip.departureCity, style: const TextStyle(fontWeight: FontWeight.w600)), Text(trip.departureStation, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))]),
          Column(children: [Text(trip.durationLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)), const Icon(Icons.arrow_right_alt), Text('${trip.availableSeats} places', style: const TextStyle(fontSize: 11, color: Colors.green))]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${trip.arrivalTime.hour.toString().padLeft(2,'0')}:${trip.arrivalTime.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)), Text(trip.arrivalCity, style: const TextStyle(fontWeight: FontWeight.w600)), Text(trip.arrivalStation, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))]),
        ])),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: trip.amenities.map((a) => Chip(label: Text(a, style: const TextStyle(fontSize: 11)), backgroundColor: Colors.blue.shade50)).toList()),
        const SizedBox(height: 24),
        const Text('Politique agence', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(trip.agency?.description?? 'Aucune politique renseignée', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
      ])),
      bottomNavigationBar: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${trip.priceFcfa} FCFA', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF0D47A1))), Text('par place • frais inclus', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))]),
        const Spacer(),
        SizedBox(height: 48, child: ElevatedButton(onPressed: trip.isFull? null: () => context.push('/thix-reservation/bus/seats/${trip.id}', extra: trip), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(trip.isFull? 'Complet': 'Choisir sièges', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      ])),
    );
  }
}
