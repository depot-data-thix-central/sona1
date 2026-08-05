// lib/presentation/thix_reservation/bus/providers/agency_dashboard_provider.dart
import 'package:flutter/foundation.dart';
import '../data/models/agency_model.dart';
import '../data/models/bus_trip_model.dart';
import '../data/models/booking_model.dart';
import '../data/services/bus_agency_service.dart';

class AgencyDashboardProvider extends ChangeNotifier {
  final BusAgencyService _service = BusAgencyService();

  AgencyModel? myAgency;
  List<BusTripModel> myTrips = [];
  List<BookingModel> agencyBookings = [];

  Map<String, dynamic>? stats;

  bool isLoading = true;
  bool isCreating = false;
  String? error;

  bool get hasAgency => myAgency!= null;
  bool get isAgencyActive => myAgency?.status == 'active';
  bool get isPending => myAgency?.status == 'pending';

  // --- INIT : Chargé dès que l'utilisateur clique sur "Espace Agence" ---
  Future<void> init() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      myAgency = await _service.getMyAgency();

      if (myAgency!= null) {
        // Charge tout en parallèle pour performance
        final results = await Future.wait([
          _service.getMyTrips(myAgency!.id),
          _service.getAgencyBookings(myAgency!.id),
          _service.getDashboardStats(myAgency!.id),
        ]);

        myTrips = results[0] as List<BusTripModel>;
        agencyBookings = results[1] as List<BookingModel>;
        stats = results[2] as Map<String, dynamic>;
      }
    } catch (e) {
      error = 'Erreur chargement agence: $e';
      debugPrint(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // --- Création Agence (Onboarding SaaS) ---
  Future<bool> createMyAgency({
    required String name,
    required String countryCode,
    String? description,
  }) async {
    try {
      isCreating = true;
      error = null;
      notifyListeners();

      myAgency = await _service.createAgency(
        name: name,
        countryCode: countryCode,
        description: description,
      );

      // Recharge après création
      await init();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    } finally {
      isCreating = false;
      notifyListeners();
    }
  }

  // --- Création Trajet ---
  Future<bool> createTrip({
    required String from,
    required String to,
    required String departureStation,
    required String arrivalStation,
    required DateTime departureTime,
    required DateTime arrivalTime,
    required int price,
    required int totalSeats,
    required String busType,
  }) async {
    if (myAgency == null) return false;
    try {
      isCreating = true;
      notifyListeners();

      final newTrip = await _service.createTrip(
        agencyId: myAgency!.id,
        from: from,
        to: to,
        departureStation: departureStation,
        arrivalStation: arrivalStation,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        price: price,
        totalSeats: totalSeats,
        busType: busType,
      );

      myTrips.insert(0, newTrip);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    } finally {
      isCreating = false;
      notifyListeners();
    }
  }

  // --- Validation Ticket QR ---
  Future<BookingModel?> validateQr(String qrCode) async {
    if (myAgency == null) return null;
    try {
      final booking = await _service.validateTicketByQr(myAgency!.id, qrCode);
      // Met à jour la liste locale
      final index = agencyBookings.indexWhere((b) => b.id == booking.id);
      if (index!= -1) {
        agencyBookings[index] = booking;
        notifyListeners();
      }
      return booking;
    } catch (e) {
      error = 'Ticket invalide ou déjà utilisé: $e';
      notifyListeners();
      return null;
    }
  }

  // Stats rapides pour UI
  int get todayBookingsCount => stats?['bookings_today']?? 0;
  int get todayRevenue => stats?['revenue_today']?? 0;
  int get pendingDepartures => myTrips.where((t) => t.status == 'scheduled' && t.departureTime.isAfter(DateTime.now())).length;
}
