// lib/presentation/thix_reservation/bus/providers/seat_selection_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/seat_model.dart';
import '../data/services/bus_public_service.dart';

class SeatSelectionProvider extends ChangeNotifier {
  final BusPublicService _service = BusPublicService();

  String? tripId;
  List<SeatModel> seats = [];
  final Set<String> selectedSeats = {};
  int maxSelectable = 1;

  bool isLoading = false;
  String? error;
  StreamSubscription? _sub;
  Timer? _lockTimer;
  int lockRemainingSeconds = 0;

  void init(String tripIdParam, int passengers) {
    tripId = tripIdParam;
    maxSelectable = passengers;
    selectedSeats.clear();
    listenSeats();
    notifyListeners();
  }

  void listenSeats() {
    if (tripId == null) return;
    isLoading = true;
    notifyListeners();

    _sub?.cancel();
    _sub = _service.watchSeats(tripId!).listen((data) {
      seats = data;
      isLoading = false;
      // Nettoie sélection si siège devenu indisponible
      selectedSeats.removeWhere((num) {
        final s = seats.firstWhere((e) => e.seatNumber == num, orElse: () => seats.first);
        return !s.isAvailable && !selectedSeats.contains(s.seatNumber);
      });
      notifyListeners();
    }, onError: (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
    });
  }

  bool canSelectMore() => selectedSeats.length < maxSelectable;

  void toggleSeat(SeatModel seat) {
    if (!seat.isAvailable) return;
    if (selectedSeats.contains(seat.seatNumber)) {
      selectedSeats.remove(seat.seatNumber);
    } else {
      if (!canSelectMore()) return; // bloque
      selectedSeats.add(seat.seatNumber);
    }
    notifyListeners();
    _handleLock();
  }

  Future<void> _handleLock() async {
    if (tripId == null || selectedSeats.isEmpty) return;
    try {
      await _service.lockSeats(tripId: tripId!, seatNumbers: selectedSeats.toList());
      _startLockTimer();
    } catch (e) {
      error = 'Impossible de bloquer le siège: $e';
      notifyListeners();
    }
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    lockRemainingSeconds = 600; // 10 min
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      lockRemainingSeconds--;
      if (lockRemainingSeconds <= 0) {
        t.cancel();
        selectedSeats.clear();
      }
      notifyListeners();
    });
  }

  Future<void> confirmAndUnlockForPayment() async {
    _lockTimer?.cancel();
    // On garde le lock, le paiement va convertir en booked côté backend via trigger
    notifyListeners();
  }

  Future<void> cancelSelection() async {
    if (tripId != null && selectedSeats.isNotEmpty) {
      await _service.unlockSeats(tripId: tripId!, seatNumbers: selectedSeats.toList());
    }
    _lockTimer?.cancel();
    selectedSeats.clear();
    notifyListeners();
  }

  int get totalVipSupplement {
    int sup = 0;
    for (final num in selectedSeats) {
      final seat = seats.firstWhere((s) => s.seatNumber == num);
      if (seat.isVip) sup += 1000;
    }
    return sup;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _lockTimer?.cancel();
    super.dispose();
  }
}
