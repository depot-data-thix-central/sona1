// lib/presentation/thix_reservation/bus/providers/bus_search_provider.dart
import 'package:flutter/foundation.dart';
import '../data/models/bus_trip_model.dart';
import '../data/models/city_model.dart';
import '../data/services/bus_public_service.dart';

class BusSearchProvider extends ChangeNotifier {
  final BusPublicService _service = BusPublicService();

  // --- State recherche ---
  String? departureCity;
  String? arrivalCity;
  DateTime departureDate = DateTime.now().add(const Duration(days: 1));
  int passengers = 1;

  List<CityModel> cities = [];
  List<BusTripModel> allResults = []; // PUBLIC pour filtre agences
  List<BusTripModel> filteredResults = [];

  bool isLoading = false;
  bool isSearching = false;
  String? error;

  // Filtres
  double minPrice = 0;
  double maxPrice = 50000;
  Set<String> selectedAgencies = {};
  String? selectedBusType;
  String sortBy = 'departure'; // departure, price, rating

  BusSearchProvider() {
    loadCities();
  }

  Future<void> loadCities() async {
    try {
      isLoading = true;
      notifyListeners();
      cities = await _service.getCities();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void swapCities() {
    final tmp = departureCity;
    departureCity = arrivalCity;
    arrivalCity = tmp;
    notifyListeners();
  }

  void setDeparture(String city) {
    departureCity = city;
    notifyListeners();
  }

  void setArrival(String city) {
    arrivalCity = city;
    notifyListeners();
  }

  void setDate(DateTime date) {
    departureDate = date;
    notifyListeners();
  }

  void setPassengers(int count) {
    passengers = count.clamp(1, 6);
    notifyListeners();
  }

  // --- Recherche principale SaaS ---
  Future<void> search() async {
    if (departureCity == null || arrivalCity == null) {
      error = 'Veuillez choisir départ et arrivée';
      notifyListeners();
      return;
    }
    try {
      isSearching = true;
      error = null;
      notifyListeners();

      allResults = await _service.searchTrips(
        from: departureCity!,
        to: arrivalCity!,
        date: departureDate,
        passengers: passengers,
      );
      filteredResults = List.from(allResults);
      _applyFiltersAndSort();
    } catch (e) {
      error = 'Erreur recherche: $e';
      filteredResults = [];
    } finally {
      isSearching = false;
      notifyListeners();
    }
  }

  void _applyFiltersAndSort() {
    var list = allResults.where((t) {
      final priceOk = t.priceFcfa >= minPrice && t.priceFcfa <= maxPrice;
      final agencyOk = selectedAgencies.isEmpty || selectedAgencies.contains(t.agencyId);
      final typeOk = selectedBusType == null || t.busType == selectedBusType;
      return priceOk && agencyOk && typeOk;
    }).toList();

    switch (sortBy) {
      case 'price':
        list.sort((a, b) => a.priceFcfa.compareTo(b.priceFcfa));
        break;
      case 'duration':
        list.sort((a, b) => a.departureTime.compareTo(b.departureTime));
        break;
      default:
        list.sort((a, b) => a.departureTime.compareTo(b.departureTime));
    }
    filteredResults = list;
    notifyListeners();
  }

  void updatePriceFilter(double min, double max) {
    minPrice = min;
    maxPrice = max;
    _applyFiltersAndSort();
  }

  void toggleAgency(String agencyId) {
    if (selectedAgencies.contains(agencyId)) {
      selectedAgencies.remove(agencyId);
    } else {
      selectedAgencies.add(agencyId);
    }
    _applyFiltersAndSort();
  }

  void setSort(String value) {
    sortBy = value;
    _applyFiltersAndSort();
  }

  void clearFilters() {
    minPrice = 0;
    maxPrice = 50000;
    selectedAgencies.clear();
    selectedBusType = null;
    sortBy = 'departure';
    filteredResults = List.from(allResults);
    notifyListeners();
  }
}
