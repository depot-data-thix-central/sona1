// models/certificate.dart
class Certificate {
  final String id;
  final String enrollmentId;
  final String userId;
  final String formationId;
  final DateTime issuedAt;
  final String? certificateUrl;
  final String verificationHash;
  final DateTime? createdAt;

  Certificate({
    required this.id,
    required this.enrollmentId,
    required this.userId,
    required this.formationId,
    required this.issuedAt,
    this.certificateUrl,
    required this.verificationHash,
    this.createdAt,
  });

  factory Certificate.fromJson(Map<String, dynamic> json) => Certificate(
        id: json['id'],
        enrollmentId: json['enrollment_id'],
        userId: json['user_id'],
        formationId: json['formation_id'],
        issuedAt: DateTime.parse(json['issued_at']),
        certificateUrl: json['certificate_url'],
        verificationHash: json['verification_hash'],
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'enrollment_id': enrollmentId,
        'user_id': userId,
        'formation_id': formationId,
        'issued_at': issuedAt.toIso8601String(),
        'certificate_url': certificateUrl,
        'verification_hash': verificationHash,
        'created_at': createdAt?.toIso8601String(),
      };

  Certificate copyWith({
    String? certificateUrl,
  }) =>
      Certificate(
        id: id,
        enrollmentId: enrollmentId,
        userId: userId,
        formationId: formationId,
        issuedAt: issuedAt,
        certificateUrl: certificateUrl ?? this.certificateUrl,
        verificationHash: verificationHash,
        createdAt: createdAt,
      );
}
