// lib/presentation/education/instructor/book_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';

// ============================================================
// CONSTANTES UI
// ============================================================
class _C {
  static const bg = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const primary = Color(0xFF2D6CDF);
  static const textMain = Color(0xFF1E293B);
  static const textMuted = Color(0xFF7386A8);
  static const border = Color(0xFFE2E8F0);
  static const red = Color(0xFFEF4444);
}

// ============================================================
// PROVIDER (Logique métier et accès Supabase)
// ============================================================
final instructorBooksProvider = AsyncNotifierProvider<InstructorBooksNotifier, List<Book>>(
  InstructorBooksNotifier.new,
);

class InstructorBooksNotifier extends AsyncNotifier<List<Book>> {
  @override
  Future<List<Book>> build() async {
    return _fetchMyBooks();
  }

  Future<List<Book>> _fetchMyBooks() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final res = await Supabase.instance.client
          .from('books')
          .select('*')
          .eq('instructor_id', userId) 
          .order('created_at', ascending: false);

      return (res as List).map((json) => Book.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Erreur chargement des livres : $e');
      throw Exception('Impossible de charger vos livres.');
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchMyBooks());
  }

  Future<bool> deleteBook(String bookId) async {
    try {
      await Supabase.instance.client.from('books').delete().eq('id', bookId);
      if (state.value != null) {
        state = AsyncData(state.value!.where((b) => b.id != bookId).toList());
      }
      return true;
    } catch (e) {
      debugPrint('❌ Erreur suppression du livre : $e');
      return false;
    }
  }
}

// ============================================================
// WIDGET UI (ConsumerWidget)
// ============================================================
class BookManagementPage extends ConsumerWidget {
  const BookManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(instructorBooksProvider);
    final notifier = ref.read(instructorBooksProvider.notifier);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Text('Mes livres', style: TextStyle(fontWeight: FontWeight.w800, color: _C.textMain, fontSize: 18)),
        backgroundColor: _C.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: _C.primary),
            onPressed: () async {
              await context.push('/instructor/books/create');
              notifier.refresh();
            },
            tooltip: 'Nouveau livre',
          ),
        ],
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _C.primary)),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: _C.red, size: 48),
              const SizedBox(height: 16),
              const Text('Erreur de chargement', style: TextStyle(fontWeight: FontWeight.w700, color: _C.textMain)),
              TextButton(
                onPressed: () => notifier.refresh(),
                child: const Text('Réessayer'),
              )
            ],
          ),
        ),
        data: (books) {
          if (books.isEmpty) {
            return _buildEmptyState(context, notifier);
          }
          return RefreshIndicator(
            color: _C.primary,
            onRefresh: () => notifier.refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final book = books[index];
                return _buildBookCard(context, book, notifier);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, InstructorBooksNotifier notifier) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.library_books_rounded, size: 64, color: _C.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucun livre publié',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.textMain),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Ajoutez votre premier livre pour commencer à le distribuer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.textMuted, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await context.push('/instructor/books/create');
              notifier.refresh();
            },
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('Créer un livre', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBookCard(BuildContext context, Book book, InstructorBooksNotifier notifier) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await context.push('/instructor/books/edit/${book.id}');
            notifier.refresh();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _C.bg,
                    borderRadius: BorderRadius.circular(8),
                    image: book.imageUrl != null 
                        ? DecorationImage(image: NetworkImage(book.imageUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: book.imageUrl == null 
                      ? const Icon(Icons.book_rounded, color: _C.textMuted)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _C.textMain),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author,
                        style: const TextStyle(fontSize: 13, color: _C.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _C.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          book.price == 0 ? 'Gratuit' : '${book.price} ${book.currency}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: _C.textMuted),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await context.push('/instructor/books/edit/${book.id}');
                      notifier.refresh();
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(context, book, notifier);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [Icon(Icons.edit_rounded, size: 20), SizedBox(width: 12), Text('Modifier')]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [Icon(Icons.delete_rounded, color: _C.red, size: 20), SizedBox(width: 12), Text('Supprimer', style: TextStyle(color: _C.red))]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Book book, InstructorBooksNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _C.red),
            SizedBox(width: 8),
            Text('Supprimer ce livre ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Voulez-vous vraiment supprimer "${book.title}" ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: _C.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.red,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await notifier.deleteBook(book.id);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erreur lors de la suppression'), backgroundColor: _C.red),
                );
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
