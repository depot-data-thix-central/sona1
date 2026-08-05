// lib/presentation/thix_reservation/bus/pages/client/bus_ticket_page.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/models/booking_model.dart';

class BusTicketPage extends StatelessWidget {
  final BookingModel booking;
  const BusTicketPage({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final trip = booking.trip;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: const Text('Mon billet'), backgroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(trip?.agency?.name??'Agence', style: const TextStyle(fontWeight: FontWeight.bold)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text(booking.status.toUpperCase(), style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11)))]),
          const SizedBox(height: 16),
          QrImageView(data: booking.qrCode, size: 180, version: QrVersions.auto),
          const SizedBox(height: 8), Text(booking.qrCode, style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
          const Divider(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(trip?.departureCity??'', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), Text('${trip?.departureTime.hour}:${trip?.departureTime.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 13))]), const Icon(Icons.arrow_forward), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(trip?.arrivalCity??'', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), Text('${trip?.arrivalTime.hour}:${trip?.arrivalTime.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 13))])]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Sièges: ${booking.seats.join(', ')}'), Text('${booking.totalPriceFcfa} FCFA', style: const TextStyle(fontWeight: FontWeight.bold))]),
        ])),
        const SizedBox(height: 12),
        Text('Présentez ce QR à l\'embarquement. Lié à votre THIX ID.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ])),
    );
  }
}
