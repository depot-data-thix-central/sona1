// lib/presentation/education/pages/certificate_detail_page.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:thix_id/presentation/education/models/certificate.dart';

class CertificateDetailPage extends StatelessWidget {
  final Certificate certificate;

  const CertificateDetailPage({super.key, required this.certificate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        title: const Text('Certificat', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2D6CDF), Color(0xFF123B7A)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: Colors.white, size: 64),
              ),
              const SizedBox(height: 24),
              const Text(
                'Certificat de formation',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A1F44).withOpacity(0.06),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _infoRow('ID de vérification', certificate.verificationHash),
                    const Divider(),
                    _infoRow('Délivré le', '${certificate.issuedAt.day}/${certificate.issuedAt.month}/${certificate.issuedAt.year}'),
                    if (certificate.certificateUrl != null) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Télécharger le certificat
                        },
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Télécharger le PDF'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // QR Code
                    QrImageView(
                      data: certificate.verificationHash,
                      size: 120,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF2D6CDF),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF2D6CDF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Scannez pour vérifier l\'authenticité',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7386A8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF7386A8))),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
        ],
      ),
    );
  }
}
