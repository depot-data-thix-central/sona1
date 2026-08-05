// lib/presentation/thix_reservation/bus/pages/client/bus_home_page.dart
// V2.3 FIX BUILD - Aligné avec BusSearchProvider (departureCity/arrivalCity/setDate)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/bus_search_provider.dart';
import '../../providers/agency_dashboard_provider.dart';
import '../../data/services/bus_public_service.dart';

class BusHomePage extends StatefulWidget {
  const BusHomePage({super.key});
  @override State<BusHomePage> createState() => _BusHomePageState();
}

class _BusHomePageState extends State<BusHomePage> {
  final _publicService = BusPublicService();
  final PageController _heroCtrl = PageController();
  Timer? _timer;
  int _heroIndex = 0;
  List<Map<String, dynamic>> _popularRoutes = [];
  bool _loadingPopular = true;
  String _userName = "Voyageur";
  bool _hasAgency = false;

  static const _heroSlides = [
    {
      "title": "Reservez votre bus en toute simplicite",
      "sub": "Voyagez confortablement",
      "cta": "Reserver un bus",
      "img": "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=1200&q=80",
    },
    {
      "title": "Bus VIP Climatise Wi-Fi a bord",
      "sub": "Confort premium prix mini",
      "cta": "Voir les offres",
      "img": "https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=1200&q=80",
    },
    {
      "title": "Voyagez en securite 24h sur 24",
      "sub": "Chauffeurs verifies GPS",
      "cta": "Reserver maintenant",
      "img": "https://images.unsplash.com/photo-1499856871958-5b9627545d1a?w=1200&q=80",
    },
  ];

  static const _fallbackAmenities = [
    {"label": "Sieges", "icon_name": "seat"},
    {"label": "Wi-Fi", "icon_name": "wifi"},
    {"label": "Clim", "icon_name": "ac"},
    {"label": "Bagages", "icon_name": "luggage"},
    {"label": "Securite", "icon_name": "security"},
  ];

  static const _fallbackCities = [
    "Kinshasa",
    "Lubumbashi",
    "Goma",
    "Bukavu",
    "Kisangani",
    "Mbuji-Mayi",
    "Kananga",
    "Kolwezi",
    "Matadi",
    "Mbandaka",
    "Beni",
    "Butembo",
    "Bunia",
  ];

  @override void initState() {
    super.initState();
    _init();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_heroCtrl.hasClients) return;
      _heroIndex = (_heroIndex + 1) % _heroSlides.length;
      _heroCtrl.animateToPage(_heroIndex, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  Future<void> _init() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final p = await Supabase.instance.client.from("profiles").select("full_name").eq("id", user.id).maybeSingle();
        if (p != null && mounted) {
          setState(() => _userName = (p["full_name"] as String).split(" ").first);
        }
        final a1 = await Supabase.instance.client.from("bus_agencies").select("id").eq("owner_id", user.id).maybeSingle();
        if (a1 != null && mounted) setState(() => _hasAgency = true);
      } catch (_) {}
    }
    if (mounted) Future.microtask(() => context.read<AgencyDashboardProvider>().init());
    try {
      final routes = await _publicService.getPopularRoutes();
      if (mounted) setState(() { _popularRoutes = routes; _loadingPopular = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPopular = false);
    }
  }

  @override void dispose() {
    _timer?.cancel();
    _heroCtrl.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    const kPrimary = Color(0xFF0B4FE3);
    final searchP = context.watch<BusSearchProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () {}),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text("THIX ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))), Text("RESERVATION", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kPrimary))]),
            Text("Reservez simplement", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          ]),
        ]),
        actions: [
          IconButton(
            onPressed: () => _hasAgency ? context.push("/agency/dashboard") : context.push("/agency/onboarding"),
            icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _hasAgency ? const Color(0xFFEAF1FF) : const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(10)), child: Icon(_hasAgency ? Icons.storefront_rounded : Icons.add_business_rounded, size: 18, color: _hasAgency ? kPrimary : const Color(0xFFB7791F))),
          ),
          IconButton(onPressed: () => context.push("/notifications"), icon: const Badge(label: Text("3"), child: Icon(Icons.notifications_none_rounded))),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _init,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 182,
              child: Stack(children: [
                PageView.builder(
                  controller: _heroCtrl,
                  itemCount: _heroSlides.length,
                  onPageChanged: (i) => setState(() => _heroIndex = i),
                  itemBuilder: (_, i) {
                    final s = _heroSlides[i];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(children: [
                        Positioned.fill(child: Image.network(s["img"]!, fit: BoxFit.cover)),
                        Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xFF0B4FE3), Colors.transparent])))),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("Bonjour, $_userName", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 8),
                            Text(s["title"]!, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Text(s["sub"]!, style: const TextStyle(color: Color(0xFFD6E8FF), fontSize: 12)),
                            const Spacer(),
                            ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.directions_bus_filled_rounded, size: 16), label: Text(s["cta"]!), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kPrimary)),
                          ]),
                        ),
                      ]),
                    );
                  },
                ),
                Positioned(bottom: 10, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_heroSlides.length, (i) => Container(margin: const EdgeInsets.symmetric(horizontal: 3), width: i == _heroIndex ? 16 : 6, height: 6, decoration: BoxDecoration(color: i == _heroIndex ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(10)))))),
              ]),
            ),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _Cat(icon: Icons.apartment_rounded, label: "Hotels", color: kPrimary, onTap: () {}),
              _Cat(icon: Icons.flight_rounded, label: "Vols", color: const Color(0xFF0E8A5B), onTap: () {}),
              _Cat(icon: Icons.directions_bus_filled_rounded, label: "Bus", color: kPrimary, active: true, onTap: () {}),
              _Cat(icon: Icons.local_taxi_rounded, label: "Transports", color: const Color(0xFFE67E22), onTap: () {}),
              _Cat(icon: Icons.local_activity_rounded, label: "Events", color: const Color(0xFFDB2777), onTap: () {}),
              _Cat(icon: Icons.restaurant_rounded, label: "Resto", color: const Color(0xFFEA580C), onTap: () {}),
              _Cat(icon: Icons.home_work_rounded, label: "Locations", color: const Color(0xFF0E8A5B), onTap: () {}),
              _Cat(icon: Icons.more_horiz_rounded, label: "Plus", color: const Color(0xFF64748B), onTap: () {}),
            ])),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Row(children: [const Text("Reservation rapide de bus", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), const Spacer(), Text("Voir tout", style: TextStyle(fontSize: 11, color: kPrimary, fontWeight: FontWeight.w700))]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _FieldBox(icon: Icons.my_location_rounded, label: "Depart", value: searchP.departureCity ?? "Choisir", onTap: () => _showCityPicker(context, true))),
                  const SizedBox(width: 8),
                  Expanded(child: _FieldBox(icon: Icons.location_on_rounded, label: "Arrivee", value: searchP.arrivalCity ?? "Choisir", onTap: () => _showCityPicker(context, false))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _FieldBox(icon: Icons.calendar_today_rounded, label: "Date", value: "${searchP.departureDate.day}/${searchP.departureDate.month}", onTap: () => _pickDate(context))),
                  const SizedBox(width: 10),
                  Expanded(child: _FieldBox(icon: Icons.person_outline_rounded, label: "Passagers", value: "${searchP.passengers}", onTap: () => _pickPassengers(context))),
                  const SizedBox(width: 10),
                  SizedBox(height: 46, child: ElevatedButton(onPressed: () async { await searchP.search(); if (context.mounted) context.push("/thix-reservation/bus/search"); }, style: ElevatedButton.styleFrom(backgroundColor: kPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Icon(Icons.search_rounded, color: Colors.white))),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [const Text("Routes populaires", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)), const Spacer(), Text("Voir tout", style: TextStyle(fontSize: 11, color: kPrimary, fontWeight: FontWeight.w700))]),
            const SizedBox(height: 10),
            if (_loadingPopular) const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            else if (_popularRoutes.isEmpty) Container(height: 70, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Text("Aucune route"))
            else SizedBox(height: 170, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _popularRoutes.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (_, i) {
              final r = _popularRoutes[i];
              final dep = r["departure_city"] ?? "Kinshasa";
              final arr = r["arrival_city"] ?? "Matadi";
              final label = r["next_departure_label"] ?? "08:00";
              final price = r["min_price"] ?? 5000;
              final img = r["arrival_city_image"] ?? "https://images.unsplash.com/photo-1480714378408-67cf0d13bc1b?w=400";
              return _RouteCard(from: dep, to: arr, date: label, price: "$price FCFA", img: img, onTap: () {});
            })),
            const SizedBox(height: 16),
            const Text("Nos bus pour votre confort", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 10),
            _buildAmenities(),
          ]),
        ),
      ),
    );
  }

  Widget _buildAmenities() {
    return FutureBuilder(
      future: Supabase.instance.client.from("bus_amenities").select().eq("is_active", true).limit(5),
      builder: (context, snap) {
        List<Map<String, dynamic>> items;
        if (snap.hasData && (snap.data as List).isNotEmpty) {
          items = List<Map<String, dynamic>>.from(snap.data as List);
        } else {
          items = _fallbackAmenities.map((e) => Map<String, dynamic>.from(e)).toList();
        }
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: items.map((a) {
          return _ComfortItem(icon: _iconFrom(a["icon_name"] as String?), label: a["label"] as String);
        }).toList());
      },
    );
  }

  void _showCityPicker(BuildContext context, bool isDep) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))), builder: (_) => _CityPicker(isDep: isDep, fallback: _fallbackCities));
  }

  Future<void> _pickDate(BuildContext context) async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d != null && mounted) context.read<BusSearchProvider>().setDate(d);
  }

  void _pickPassengers(BuildContext context) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), builder: (_) {
      int p = context.read<BusSearchProvider>().passengers;
      return StatefulBuilder(builder: (c, setS) => Container(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Passagers", style: TextStyle(fontWeight: FontWeight.w800)),
          Row(children: [IconButton(onPressed: () => setS(() => p = p > 1 ? p - 1 : 1), icon: const Icon(Icons.remove_circle_outline)), Text("$p", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), IconButton(onPressed: () => setS(() => p++), icon: const Icon(Icons.add_circle_outline))]),
        ]),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { context.read<BusSearchProvider>().setPassengers(p); Navigator.pop(c); }, child: const Text("Confirmer"))),
      ])));
    });
  }

  IconData _iconFrom(String? n) {
    switch (n) {
      case "wifi": return Icons.wifi_rounded;
      case "ac": return Icons.ac_unit_rounded;
      case "luggage": return Icons.work_rounded;
      case "seat": return Icons.airline_seat_recline_extra_rounded;
      case "security": return Icons.verified_user_rounded;
      default: return Icons.check_circle_outline_rounded;
    }
  }
}

class _Cat extends StatelessWidget {
  final IconData icon; final String label; final Color color; final bool active; final VoidCallback onTap;
  const _Cat({required this.icon, required this.label, required this.color, this.active = false, required this.onTap});
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, child: Column(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: active ? const Color(0xFFEAF1FF) : color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: color)), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 9, fontWeight: active ? FontWeight.w800 : FontWeight.w600))]));
}
class _FieldBox extends StatelessWidget {
  final IconData icon; final String label, value; final VoidCallback onTap;
  const _FieldBox({required this.icon, required this.label, required this.value, required this.onTap});
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF8FAFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEEF2F7))), child: Row(children: [Icon(icon, size: 14, color: const Color(0xFF0B4FE3)), const SizedBox(width: 6), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]))])));
}
class _RouteCard extends StatelessWidget {
  final String from, to, date, price, img; final VoidCallback onTap;
  const _RouteCard({required this.from, required this.to, required this.date, required this.price, required this.img, required this.onTap});
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, child: Container(width: 148, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEF2F7))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: Image.network(img, height: 88, width: 148, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 88, color: const Color(0xFFEEF2F7)))), Padding(padding: const EdgeInsets.all(9), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("$from -> $to", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)), Text(date, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))), Text(price, style: const TextStyle(fontSize: 11, color: Color(0xFF0E8A5B), fontWeight: FontWeight.w800))]))])));
}
class _ComfortItem extends StatelessWidget {
  final IconData icon; final String label;
  const _ComfortItem({required this.icon, required this.label});
  @override Widget build(BuildContext context) => Column(children: [Container(width: 38, height: 38, decoration: const BoxDecoration(color: Color(0xFFEEF4FF), shape: BoxShape.circle), child: Icon(icon, size: 16, color: const Color(0xFF0B4FE3))), const SizedBox(height: 4), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600))]);
}
class _CityPicker extends StatefulWidget {
  final bool isDep; final List<String> fallback;
  const _CityPicker({required this.isDep, required this.fallback});
  @override State<_CityPicker> createState() => _CityPickerState();
}
class _CityPickerState extends State<_CityPicker> {
  List<String> all = [], filtered = []; bool loading = true; final ctrl = TextEditingController();
  @override void initState() { super.initState(); _load(); ctrl.addListener(() { setState(() { filtered = all.where((c) => c.toLowerCase().contains(ctrl.text.toLowerCase())).toList(); }); }); }
  Future<void> _load() async {
    try {
      final r = await Supabase.instance.client.from("cities").select("name").order("name").limit(80);
      final list = (r as List).map((e) => e["name"] as String).toList();
      if (list.isNotEmpty) all = list; else all = widget.fallback;
    } catch (_) { all = widget.fallback; }
    setState(() { filtered = all; loading = false; });
  }
  @override Widget build(BuildContext context) {
    return DraggableScrollableSheet(initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.5, expand: false, builder: (_, c) => Column(children: [
      const SizedBox(height: 10),
      Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10))),
      const SizedBox(height: 12),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(controller: ctrl, decoration: InputDecoration(hintText: widget.isDep ? "Depart" : "Arrivee", prefixIcon: const Icon(Icons.search_rounded), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
      const SizedBox(height: 10),
      if (loading) const Expanded(child: Center(child: CircularProgressIndicator())) else Expanded(child: ListView.separated(controller: c, itemCount: filtered.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) => ListTile(title: Text(filtered[i], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), onTap: () { final p = context.read<BusSearchProvider>(); if (widget.isDep) p.setDeparture(filtered[i]); else p.setArrival(filtered[i]); Navigator.pop(context); }))),
    ]));
  }
}
