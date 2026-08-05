// lib/presentation/thix_reservation/bus/providers/booking_provider.dart
import 'package:flutter/foundation.dart';
import '../data/models/booking_model.dart';
import '../data/services/bus_public_service.dart';

class BookingProvider extends ChangeNotifier {
  final BusPublicService _service = BusPublicService();

  List<BookingModel> myBookings = [];
  bool isLoading = false;
  bool isPaying = false;
  String? error;
  BookingModel? lastBooking;

  Future<void> loadMyBookings() async {
    try {
      isLoading = true;
      notifyListeners();
      myBookings = await _service.getMyBookings();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<BookingModel> createBookingAndPay({
    required String agencyId,
    required String tripId,
    required List<String> seats,
    required int basePrice,
    required int vipSupplement,
  }) async {
    try {
      isPaying = true;
      error = null;
      notifyListeners();

      const serviceFee = 300;
      final total = (basePrice * seats.length) + vipSupplement + serviceFee;

      // 1. Crée booking pending_payment
      final booking = await _service.createBooking(
        agencyId: agencyId,
        tripId: tripId,
        seats: seats,
        totalPrice: total,
      );

      // 2. Ici tu branches ton Thix Money / Mobile Money
      // await _thixMoneyService.pay(amount: total, reference: booking.qrCode);
      // Pour l'instant on simule succès et on confirme côté DB via RPC
      // await _service.confirmPayment(booking.id);

      lastBooking = booking;
      myBookings.insert(0, booking);
      return booking;
    } catch (e) {
      error = 'Paiement échoué: $e';
      rethrow;
    } finally {
      isPaying = false;
      notifyListeners();
    }
  }

  List<BookingModel> get upcoming => myBookings.where((b) => b.status == 'confirmed' || b.status == 'pending_payment').toList();
  List<BookingModel> get completed => myBookings.where((b) => b.status == 'completed').toList();
  List<BookingModel> get cancelled => myBookings.where((b) => b.status == 'cancelled').toList();
}
