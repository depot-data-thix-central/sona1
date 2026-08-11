import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/presentation/education/models/book.dart';
import 'package:thix_id/presentation/education/providers/book_provider.dart';

class BookDetailScreen extends ConsumerWidget {
  final String bookId;
  final Book book; // Vous pouvez passer l'objet Book complet via le Router

  const BookDetailScreen({super.key, required this.bookId, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwnedAsync = ref.watch(isBookOwnedProvider(bookId));
    final isFree = book.price == 0.0;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          // Header Image
          Expanded(flex: 2, child: Image.network(book.imageUrl!, fit: BoxFit.cover, width: double.infinity)),
          
          // Info & Action
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Par ${book.author}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 20),
                Text(book.description ?? 'Pas de description disponible.'),
                const Spacer(),
                
                // BOUTON INTELLIGENT
                isOwnedAsync.when(
                  data: (isOwned) => SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: (isFree || isOwned) ? Colors.green : Colors.blue),
                      onPressed: () {
                        if (isFree || isOwned) {
                          // Action : LIRE
                          _startReading(context, book);
                        } else {
                          // Action : PAYER
                          _initiatePayment(context, book);
                        }
                      },
                      child: Text(isFree || isOwned ? 'Lire maintenant' : 'Acheter pour ${book.price} ${book.currency}'),
                    ),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Erreur'),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _startReading(BuildContext context, Book book) {
    // Redirection vers votre lecteur PDF/Epub
    context.push('/education/reader/${book.id}', extra: book.fileUrl);
  }

  void _initiatePayment(BuildContext context, Book book) {
    // Intégration de votre solution de paiement (Stripe, Flutterwave, etc.)
    showDialog(context: context, builder: (_) => const AlertDialog(title: Text("Paiement"), content: Text("Intégration du paiement ici...")));
  }
}
