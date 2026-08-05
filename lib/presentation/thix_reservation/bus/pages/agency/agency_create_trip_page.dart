// lib/presentation/thix_reservation/bus/pages/agency/agency_create_trip_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/agency_dashboard_provider.dart';

class AgencyCreateTripPage extends StatefulWidget {
  const AgencyCreateTripPage({super.key});
  @override
  State<AgencyCreateTripPage> createState() => _AgencyCreateTripPageState();
}

class _AgencyCreateTripPageState extends State<AgencyCreateTripPage> {
  final _fromC = TextEditingController(text: 'Abidjan');
  final _toC = TextEditingController(text: 'Yamoussoukro');
  final _depStationC = TextEditingController(text: 'Gare Adjamé');
  final _arrStationC = TextEditingController(text: 'Gare Centre');
  final _priceC = TextEditingController(text: '5000');
  final _seatsC = TextEditingController(text: '50');
  DateTime _dep = DateTime.now().add(const Duration(days: 1, hours: 8));
  DateTime _arr = DateTime.now().add(const Duration(days: 1, hours: 11));
  String _type = 'standard';

  @override
  void dispose() { _fromC.dispose(); _toC.dispose(); _depStationC.dispose(); _arrStationC.dispose(); _priceC.dispose(); _seatsC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AgencyDashboardProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau trajet')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [Expanded(child: TextField(controller: _fromC, decoration: const InputDecoration(labelText: 'Départ ville'))), const SizedBox(width: 12), Expanded(child: TextField(controller: _toC, decoration: const InputDecoration(labelText: 'Arrivée ville')))]),
        const SizedBox(height: 12),
        TextField(controller: _depStationC, decoration: const InputDecoration(labelText: 'Station départ')),
        const SizedBox(height: 12),
        TextField(controller: _arrStationC, decoration: const InputDecoration(labelText: 'Station arrivée')),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: TextField(controller: _priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix FCFA'))), const SizedBox(width: 12), Expanded(child: TextField(controller: _seatsC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Places totales')))]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _type, decoration: const InputDecoration(labelText: 'Type bus'), items: const [DropdownMenuItem(value: 'standard', child: Text('Standard')), DropdownMenuItem(value: 'vip', child: Text('VIP')), DropdownMenuItem(value: 'clim', child: Text('Climatisé'))], onChanged: (v)=> setState(()=> _type=v!)),
        const SizedBox(height: 12),
        ListTile(title: Text('Départ: ${_dep.toString().substring(0,16)}'), trailing: const Icon(Icons.calendar_today), onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)), initialDate: _dep); if(d!=null) setState(()=> _dep=DateTime(d.year,d.month,d.day,_dep.hour,_dep.minute)); }),
        ListTile(title: Text('Arrivée: ${_arr.toString().substring(0,16)}'), trailing: const Icon(Icons.calendar_today), onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)), initialDate: _arr); if(d!=null) setState(()=> _arr=DateTime(d.year,d.month,d.day,_arr.hour,_arr.minute)); }),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: p.isCreating? null: () async { final ok = await p.createTrip(from: _fromC.text.trim(), to: _toC.text.trim(), departureStation: _depStationC.text.trim(), arrivalStation: _arrStationC.text.trim(), departureTime: _dep, arrivalTime: _arr, price: int.tryParse(_priceC.text)??5000, totalSeats: int.tryParse(_seatsC.text)??50, busType: _type); if(ok && context.mounted){ Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trajet créé avec succès')));} }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)), child: p.isCreating? const CircularProgressIndicator(color: Colors.white): const Text('Publier le trajet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      ])),
    );
  }
}
