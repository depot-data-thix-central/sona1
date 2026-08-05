import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/failure.dart';
import '../../domain/entities/wedding_entity.dart';
import '../../models/program_item_model.dart'; 

final weddingRepositoryProvider = Provider<WeddingRepository>((ref) => WeddingRepositoryImpl());

abstract class WeddingRepository {
  Future<WeddingEntity> getWeddingById(String id);
  Future<List<String>> getGallery(String weddingId, {int page = 1});
  Future<void> submitRsvp(RsvpEntity rsvp);
  Future<void> submitLivreOr(String weddingId, String name, String message);
  Future<List<GiftItem>> getGifts(String weddingId);
  Future<List<ProgramItem>> getProgram(String weddingId); 
}

class WeddingRepositoryImpl implements WeddingRepository {
  
  @override
  Future<WeddingEntity> getWeddingById(String id) async {
    final cleanId = id.trim().toUpperCase();
    
    if (cleanId.length < 4) {
      throw const Failure('ID de mariage invalide');
    }

    try {
      final response = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select()
          .eq('id', cleanId)
          .maybeSingle();

      if (response == null) {
        throw const Failure('Aucun mariage trouvé avec cet ID. Veuillez vérifier votre code.');
      }

      return WeddingEntity(
        id: response['id'] ?? cleanId,
        locationName: response['location_name'] ?? '',
        locationAddress: response['location_address'] ?? '',
        latitude: (response['latitude'] ?? 0).toDouble(),
        longitude: (response['longitude'] ?? 0).toDouble(),
        coupleNames: response['couple_names'] ?? '',
        welcomeMessage: response['welcome_message'] ?? '',
        announcement: response['announcement'] ?? '',
        date: DateTime.parse(response['date']),
        coverImageUrl: 'https://picsum.photos/800/600', 
      );

    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure('Erreur de connexion : ${e.toString()}');
    }
  }

  @override
  Future<List<String>> getGallery(String weddingId, {int page = 1}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.generate(20, (i) => 'https://picsum.photos/400/400?random=${page * 20 + i}');
  }

  @override
  Future<void> submitRsvp(RsvpEntity rsvp) async {
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Future<void> submitLivreOr(String weddingId, String name, String message) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<List<GiftItem>> getGifts(String weddingId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      const GiftItem(id: '1', name: 'Lune de miel', imageUrl: 'https://picsum.photos/200', price: 500000, contributed: 150000),
      const GiftItem(id: '2', name: 'Service à vaisselle', imageUrl: 'https://picsum.photos/200', price: 200000, contributed: 200000),
    ];
  }

  @override
  Future<List<ProgramItem>> getProgram(String weddingId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return <ProgramItem>[]; 
  }
} // 👈 La fameuse accolade manquante est bien là !
