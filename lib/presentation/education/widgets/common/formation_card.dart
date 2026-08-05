// lib/presentation/education/widgets/common/formation_card.dart
import 'package:flutter/material.dart';
import 'package:thix_id/presentation/education/models/formation.dart';

class FormationCard extends StatelessWidget {
  final Formation formation;
  final VoidCallback? onTap;
  final double? progress;

  const FormationCard({
    super.key,
    required this.formation,
    this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // Sécurisation de l'URL de l'image (évite les crashs si l'URL est une chaîne vide)
    final bool hasValidImage = formation.imageUrl != null && formation.imageUrl!.trim().isNotEmpty;
    final String displayImageUrl = hasValidImage ? formation.imageUrl! : 'https://via.placeholder.com/300x120';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)), // Bordure subtile d'entreprise
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04), // Ombre plus douce
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE DE COUVERTURE
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Image.network(
                displayImageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 120,
                    color: const Color(0xFFF8FAFC),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2D6CDF)),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: const Color(0xFFF8FAFC),
                  child: const Center(
                    child: Icon(Icons.image_not_supported_rounded, color: Color(0xFF94A3B8), size: 32),
                  ),
                ),
              ),
            ),
            
            // CONTENU DE LA CARTE
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formation.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  Text(
                    formation.category?.name ?? 'Non catégorisé',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  
                  Row(
                    children: [
                      const Icon(Icons.school_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        formation.level == 'beginner' ? 'Débutant' :
                        formation.level == 'intermediate' ? 'Intermédiaire' : 'Avancé',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      if (formation.price > 0)
                        Text(
                          '${formation.price.toInt()} FC',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D6CDF),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D6CDF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Gratuit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2D6CDF),
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  // BARRE DE PROGRESSION (Si applicable)
                  if (progress != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progression',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(progress! * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            // Devient vert si terminé
                            color: progress! >= 1.0 ? const Color(0xFF10B981) : const Color(0xFF2D6CDF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress!.clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: progress! >= 1.0 ? const Color(0xFF10B981) : const Color(0xFF2D6CDF),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
