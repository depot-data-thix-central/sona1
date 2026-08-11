import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';

/// Provider pour récupérer la liste des livres
final myBooksProvider = StreamProvider.family<List<Book>, String>((ref, userId) {
  return Supabase.instance.client
      .from('books')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((list) => list.map((data) => Book.fromJson(data)).toList());
});

/// Provider pour vérifier si l'utilisateur possède le livre
final isBookOwnedProvider = FutureProvider.family<bool, String>((ref, bookId) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;

  final response = await Supabase.instance.client
      .from('purchases')
      .select('id')
      .eq('user_id', user.id)
      .eq('book_id', bookId)
      .maybeSingle();

  return response != null;
});
