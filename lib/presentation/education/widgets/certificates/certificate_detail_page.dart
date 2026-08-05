// lib/presentation/education/pages/certificate_detail_page.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/certificate.dart';

class CertificateDetailPage extends StatelessWidget {
  final Certificate certificate;

  const CertificateDetailPage({
    super.key,
    required this.certificate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Certificat',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _downloadCertificate,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareCertificate,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Aperçu du certificat (grand)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A1F44).withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  certificate.certificateUrl,
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      height: 280,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 280,
                    color: const Color(0xFFF0F7FF),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf_rounded, size: 48, color: Color(0xFF7386A8)),
                          SizedBox(height: 8),
                          Text(
                            'Aperçu non disponible',
                            style: TextStyle(color: Color(0xFF7386A8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Informations du certificat
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A1F44).withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Détails du certificat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('ID', certificate.id),
                  _buildInfoRow('Délivré à', certificate.userId), // À remplacer par le nom réel de l'utilisateur
                  _buildInfoRow('Formation', certificate.formationId), // À remplacer par le vrai nom de la formation
                  _buildInfoRow('Date d\'émission', _formatDate(certificate.issuedAt)),
                  const Divider(height: 24),
                  // Bouton de vérification
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _verifyCertificate,
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('Vérifier l\'authenticité'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6CDF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7386A8),
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}h${date.minute.toString().padLeft(2, '0')}';
  }

  void _downloadCertificate() {
    // Télécharger le certificat (à implémenter avec un package de téléchargement)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Téléchargement en cours de développement...')),
    );
  }

  void _shareCertificate() {
    Share.share(
      'Consultez mon certificat : ${certificate.certificateUrl}',
      subject: 'Certificat de formation',
    );
  }

  void _verifyCertificate() {
    // Vérifier l'authenticité (appel API ou redirection)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vérification en cours de développement...')),
    );
  }
}
