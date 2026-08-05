// lib/presentation/thix_reservation/bus/pages/agency/agency_qr_scan_page.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/agency_dashboard_provider.dart';

class AgencyQrScanPage extends StatefulWidget {
  const AgencyQrScanPage({super.key});
  @override
  State<AgencyQrScanPage> createState() => _AgencyQrScanPageState();
}

class _AgencyQrScanPageState extends State<AgencyQrScanPage> {
  bool _handled = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner billet')),
      body: Stack(children: [
        MobileScanner(onDetect: (capture) async {
          if(_handled) return;
          final code = capture.barcodes.first.rawValue;
          if(code==null) return;
          setState(()=> _handled=true);
          final provider = context.read<AgencyDashboardProvider>();
          final booking = await provider.validateQr(code);
          if(!mounted) return;
          if(booking!=null){
            showDialog(context: context, builder: (_)=> AlertDialog(title: const Text('Billet valide ✅'), content: Text('Passager: ${booking.userId}\nSièges: ${booking.seats.join(', ')}\nTotal: ${booking.totalPriceFcfa} FCFA\nStatut mis à: Terminé'), actions: [TextButton(onPressed: (){ Navigator.pop(context); setState(()=> _handled=false); }, child: const Text('Scanner suivant'))]));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error??'QR invalide')));
            setState(()=> _handled=false);
          }
        }),
        Align(alignment: Alignment.bottomCenter, child: Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12)), child: const Text('Placez le QR du client au centre', style: TextStyle(color: Colors.white)))),
      ]),
    );
  }
}
