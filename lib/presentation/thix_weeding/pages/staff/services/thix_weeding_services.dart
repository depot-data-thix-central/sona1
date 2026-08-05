// lib/presentation/thix_weeding/staff/services/thix_weeding_services.dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/thix_weeding_models.dart';

// ================= PROVIDERS SERVICES =================
final weddingServiceProvider = Provider((ref) => WeddingService());
final guestServiceProvider = Provider((ref) => GuestService());
final vendorServiceProvider = Provider((ref) => VendorService());
final budgetServiceProvider = Provider((ref) => BudgetService());
final checklistServiceProvider = Provider((ref) => ChecklistService());
final galleryServiceProvider = Provider((ref) => GalleryService());
final guestbookServiceProvider = Provider((ref) => GuestbookService());
final messageServiceProvider = Provider((ref) => MessageService());
final paymentServiceProvider = Provider((ref) => PaymentService());

class WeddingService {
  final _c = Supabase.instance.client;
  Future<WeddingModel> getById(String id) async {
    final res = await _c.from('thix_weeding_weddings').select().eq('id', id).single();
    return WeddingModel.fromJson(res);
  }
  Future<List<WeddingModel>> getByOwner(String ownerId) async {
    final res = await _c.from('thix_weeding_weddings').select().eq('owner_id', ownerId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res).map((e) => WeddingModel.fromJson(e)).toList();
  }
  Future<WeddingModel> create(Map<String, dynamic> data) async {
    final res = await _c.from('thix_weeding_weddings').insert(data).select().single();
    return WeddingModel.fromJson(res);
  }
  Future<void> update(String id, Map<String, dynamic> data) async => await _c.from('thix_weeding_weddings').update(data).eq('id', id);
  Future<void> publish(String id) async => await _c.from('thix_weeding_weddings').update({'invitation_published': true}).eq('id', id);
  Future<void> delete(String id) async => await _c.from('thix_weeding_weddings').delete().eq('id', id);
}

class GuestService {
  final _c = Supabase.instance.client;
  Future<List<GuestModel>> getByWedding(String weddingId) async {
    final res = await _c.from('thix_weeding_guests').select().eq('wedding_id', weddingId).order('created_at');
    return List<Map<String, dynamic>>.from(res).map((e) => GuestModel.fromJson(e)).toList();
  }
  Future<GuestModel> getById(String id) async {
    final res = await _c.from('thix_weeding_guests').select().eq('id', id).single();
    return GuestModel.fromJson(res);
  }
  Future<GuestModel> create(Map<String, dynamic> data) async {
    final res = await _c.from('thix_weeding_guests').insert(data).select().single();
    return GuestModel.fromJson(res);
  }
  Future<void> update(String id, Map<String, dynamic> data) async => await _c.from('thix_weeding_guests').update(data).eq('id', id);
  Future<void> delete(String id) async => await _c.from('thix_weeding_guests').delete().eq('id', id);
  Future<void> togglePresent(String id, bool v) async => await _c.from('thix_weeding_guests').update({'is_present': v}).eq('id', id);
}

class VendorService {
  final _c = Supabase.instance.client;
  Future<List<VendorModel>> getByWedding(String weddingId) async {
    final res = await _c.from('thix_weeding_vendors').select('*, thix_weeding_vendor_packages(*)').eq('wedding_id', weddingId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res).map((e) => VendorModel.fromJson(e)).toList();
  }
  Future<VendorModel> create(Map<String, dynamic> data) async {
    final res = await _c.from('thix_weeding_vendors').insert(data).select().single();
    return VendorModel.fromJson(res);
  }
  Future<void> update(String id, Map<String, dynamic> data) async => await _c.from('thix_weeding_vendors').update(data).eq('id', id);
  Future<void> delete(String id) async => await _c.from('thix_weeding_vendors').delete().eq('id', id);
}

class BudgetService {
  final _c = Supabase.instance.client;
  Future<BudgetModel?> getBudget(String weddingId) async {
    final res = await _c.from('thix_weeding_budget').select().eq('wedding_id', weddingId).maybeSingle();
    return res == null ? null : BudgetModel.fromJson(res);
  }
  Future<BudgetModel> upsert(String weddingId, double total) async {
    final res = await _c.from('thix_weeding_budget').upsert({'wedding_id': weddingId, 'total_budget': total}).select().single();
    return BudgetModel.fromJson(res);
  }
  Future<List<ExpenseModel>> getExpenses(String weddingId) async {
    final res = await _c.from('thix_weeding_expenses').select().eq('wedding_id', weddingId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res).map((e) => ExpenseModel.fromJson(e)).toList();
  }
  Future<ExpenseModel> createExpense(Map<String, dynamic> data) async {
    final res = await _c.from('thix_weeding_expenses').insert(data).select().single();
    return ExpenseModel.fromJson(res);
  }
  Future<void> deleteExpense(String id) async => await _c.from('thix_weeding_expenses').delete().eq('id', id);
}

class ChecklistService {
  final _c = Supabase.instance.client;
  Future<List<ChecklistModel>> getByWedding(String weddingId) async {
    final res = await _c.from('thix_weeding_checklist').select().eq('wedding_id', weddingId).order('order_index');
    return List<Map<String, dynamic>>.from(res).map((e) => ChecklistModel.fromJson(e)).toList();
  }
  Future<ChecklistModel> create(Map<String, dynamic> data) async {
    final res = await _c.from('thix_weeding_checklist').insert(data).select().single();
    return ChecklistModel.fromJson(res);
  }
  Future<void> toggle(String id, bool done) async => await _c.from('thix_weeding_checklist').update({'is_done': done}).eq('id', id);
  Future<void> delete(String id) async => await _c.from('thix_weeding_checklist').delete().eq('id', id);
}

class GalleryService {
  final _c = Supabase.instance.client;
  Future<List<GalleryModel>> getByWedding(String weddingId) async {
    final res = await _c.from('thix_weeding_gallery').select().eq('wedding_id', weddingId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res).map((e) => GalleryModel.fromJson(e)).toList();
  }
  Future<String> uploadFile(String weddingId, File file) async {
    final path = '$weddingId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _c.storage.from('thix-weeding-gallery').upload(path, file);
    return _c.storage.from('thix-weeding-gallery').getPublicUrl(path);
  }
  Future<GalleryModel> createRecord(Map<String, dynamic> data) async {
    final res = await _c.from('thix_weeding_gallery').insert(data).select().single();
    return GalleryModel.fromJson(res);
  }
  Future<void> delete(String id) async => await _c.from('thix_weeding_gallery').delete().eq('id', id);
}

class GuestbookService {
  final _c = Supabase.instance.client;
  Future<List<GuestbookModel>> getByWedding(String weddingId) async {
    final res = await _c.from('thix_weeding_guestbook').select().eq('wedding_id', weddingId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res).map((e) => GuestbookModel.fromJson(e)).toList();
  }
  Future<void> toggleApproval(String id, bool v) async => await _c.from('thix_weeding_guestbook').update({'is_approved': v}).eq('id', id);
  Future<void> delete(String id) async => await _c.from('thix_weeding_guestbook').delete().eq('id', id);
}

class MessageService {
  final _c = Supabase.instance.client;
  Future<List<MessageModel>> getByWedding(String weddingId) async {
    final res = await _c.from('thix_weeding_messages').select().eq('wedding_id', weddingId).order('created_at');
    return List<Map<String, dynamic>>.from(res).map((e) => MessageModel.fromJson(e)).toList();
  }
  Future<MessageModel> send(Map<String, dynamic> data) async {
    final res = await _c.from('thix_weeding_messages').insert(data).select().single();
    return MessageModel.fromJson(res);
  }
  Future<void> markAllRead(String weddingId) async => await _c.from('thix_weeding_messages').update({'is_read': true}).eq('wedding_id', weddingId).eq('is_read', false);
}

class PaymentService {
  final _c = Supabase.instance.client;
  Future<List<PaymentModel>> getByWedding(String weddingId) async {
    final res = await _c.from('thix_weeding_payments').select('*, thix_weeding_vendors(name), thix_weeding_expenses(title)').eq('wedding_id', weddingId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res).map((e) => PaymentModel.fromJson(e)).toList();
  }
  Future<PaymentModel> getById(String id) async {
    final res = await _c.from('thix_weeding_payments').select('*, thix_weeding_vendors(name), thix_weeding_expenses(title)').eq('id', id).single();
    return PaymentModel.fromJson(res);
  }
  Future<PaymentModel> create(Map<String, dynamic> data) async {
    final res = await _c.from('thix_weeding_payments').insert(data).select().single();
    return PaymentModel.fromJson(res);
  }
  Future<void> update(String id, Map<String, dynamic> data) async => await _c.from('thix_weeding_payments').update(data).eq('id', id);
  Future<void> delete(String id) async => await _c.from('thix_weeding_payments').delete().eq('id', id);
}
