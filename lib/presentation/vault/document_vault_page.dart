import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/document_service.dart';
import '../../theme.dart';

// =============================================================
// Charte THIX ID — palette confiance / document (version épurée)
// =============================================================
const Color _navyDeep = Color(0xFF0A1F44);
const Color _navy = Color(0xFF123B7A);
const Color _primary = Color(0xFF2D6CDF);
const Color _gold = Color(0xFFE3B23C);
const Color _ivory = Color(0xFFF6F7FB);

// Couleurs douces par type de fichier (façon vignette colorée)
Color typeAccentColor(String? mime, String? docType) {
  final m = (mime ?? '').toLowerCase();
  final t = (docType ?? '').toLowerCase();
  if (m.contains('image')) return const Color(0xFFFF9F43); // orange doux
  if (m.contains('pdf')) return const Color(0xFFEE5253); // rouge doux
  if (t.contains('diplome') || t.contains('diplôme') || t.contains('attestation')) {
    return const Color(0xFF10AC84); // vert doux
  }
  if (t == 'cin' || t == 'passeport' || t == 'permis') return const Color(0xFF2D6CDF); // bleu
  return const Color(0xFF9C88FF); // violet par défaut
}

IconData typeIcon(String? mime, String? docType) {
  final m = (mime ?? '').toLowerCase();
  if (m.contains('pdf')) return Icons.picture_as_pdf_rounded;
  if (m.contains('image')) return Icons.image_rounded;
  final t = (docType ?? '').toLowerCase();
  if (t.contains('diplome') || t.contains('diplôme')) return Icons.school_rounded;
  if (t == 'cin' || t == 'passeport' || t == 'permis') return Icons.badge_rounded;
  return Icons.description_rounded;
}

// =============================================================
// Widgets réutilisables
// =============================================================

class FolderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FolderChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? _primary : _ivory,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: selected ? Colors.transparent : context.theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : _navy),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: context.textStyles.labelSmall?.copyWith(
                color: selected ? Colors.white : LightModeColors.secondaryText,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte document carrée épurée : vraie vignette image si disponible,
/// sinon icône colorée douce selon le type. QR + Numéro accessibles.
class DocSquareCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String docId;
  final String subtitle;
  final bool isPublic;
  final Future<String>? previewUrlFuture;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final VoidCallback? onShowQr;
  final VoidCallback? onShowId;

  const DocSquareCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.docId,
    required this.subtitle,
    required this.isPublic,
    this.previewUrlFuture,
    this.onTap,
    this.onMore,
    this.onShowQr,
    this.onShowId,
  });

  Widget _buildPreview() {
    if (previewUrlFuture == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: accentColor.withValues(alpha: 0.12),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: accentColor, size: 32),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: FutureBuilder<String>(
        future: previewUrlFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done || !snap.hasData || snap.data!.isEmpty) {
            return Container(
              color: accentColor.withValues(alpha: 0.12),
              alignment: Alignment.center,
              child: Icon(icon, color: accentColor, size: 32),
            );
          }
          return Image.network(
            snap.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => Container(
              color: accentColor.withValues(alpha: 0.12),
              alignment: Alignment.center,
              child: Icon(icon, color: accentColor, size: 32),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onMore,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: context.theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(
            children: [
              // Zone preview
              Positioned.fill(
                bottom: 44,
                child: Padding(padding: const EdgeInsets.all(8), child: _buildPreview()),
              ),
              if (isPublic)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: const Text('PUBLIC', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: _navyDeep)),
                  ),
                ),
              // Bandeau titre + subtitle
              Positioned(
                left: 0,
                right: 0,
                bottom: 44,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: context.textStyles.bodySmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 12)),
                      Text(subtitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, fontSize: 10)),
                    ],
                  ),
                ),
              ),
              // Barre d'actions bas : QR + ID
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: _ivory,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppRadius.lg),
                      bottomRight: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: onShowQr,
                          child: const Center(child: Icon(Icons.qr_code_2_rounded, size: 18, color: _navy)),
                        ),
                      ),
                      Container(width: 1, height: 18, color: Colors.black.withValues(alpha: 0.06)),
                      Expanded(
                        child: InkWell(
                          onTap: onShowId,
                          child: const Center(child: Icon(Icons.badge_outlined, size: 18, color: _navy)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DocItem extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String? trailing;
  final bool hasPassword;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final Widget? progress;

  const DocItem({
    super.key,
    required this.icon,
    this.accentColor = _primary,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.hasPassword = false,
    this.onTap,
    this.onMore,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        color: accentColor.withValues(alpha: 0.12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: accentColor, size: 20),
                    ),
                    if (hasPassword)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: _navy,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.theme.colorScheme.surface, width: 2),
                          ),
                          child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(trailing!,
                        style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.secondaryText, fontSize: 10)),
                  ),
                if (onMore != null)
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: LightModeColors.secondaryText, size: 18),
                    onPressed: onMore,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              progress!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Barre de temps animée : montre l'écoulement vers une échéance
/// (auto-destruction OU ouverture programmée).
class CountdownBar extends StatefulWidget {
  final DateTime start;
  final DateTime target;
  final String label;
  final Color color;

  const CountdownBar({
    super.key,
    required this.start,
    required this.target,
    required this.label,
    this.color = _primary,
  });

  @override
  State<CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<CountdownBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final total = widget.target.difference(widget.start).inMilliseconds;
    final elapsed = now.difference(widget.start).inMilliseconds;
    final progress = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
    final remaining = widget.target.difference(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label, style: const TextStyle(fontSize: 10, color: LightModeColors.secondaryText)),
            Text(_fmt(remaining), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.color)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: widget.color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(widget.color),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// Dialogues utilitaires : QR, Numéro
// =============================================================

void showQrDialog(BuildContext context, {required String title, required String value}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 16),
            QrImageView(
              data: value,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _navyDeep),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _navy),
            ),
            const SizedBox(height: 12),
            SelectableText(value, style: const TextStyle(fontSize: 11, color: LightModeColors.secondaryText)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showDocIdDialog(BuildContext context, {required String docId, required String title}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      content: SelectableText(docId, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _navy)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
    ),
  );
}

// =============================================================
// PAGE PRINCIPALE
// =============================================================

class DocumentVaultPage extends StatefulWidget {
  const DocumentVaultPage({super.key});

  @override
  State<DocumentVaultPage> createState() => _DocumentVaultPageState();
}

class _DocumentVaultPageState extends State<DocumentVaultPage>
    with SingleTickerProviderStateMixin {
  final _docs = DocumentService();
  late TabController _tabController;

  bool _checkingLock = true;
  bool _unlocked = false;
  String? _folderFilter; // null = "Tout"

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLock());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkLock() async {
    final me = context.read<AuthController>().currentUser;
    if (me == null) {
      setState(() {
        _checkingLock = false;
        _unlocked = true;
      });
      return;
    }
    final has = await _docs.hasVaultLock(me.id);
    if (!mounted) return;
    if (!has) {
      final pin = await _promptSetPin(context);
      if (pin != null) {
        await _docs.setVaultPin(uid: me.id, pin: pin);
        setState(() {
          _checkingLock = false;
          _unlocked = true;
        });
      } else {
        setState(() {
          _checkingLock = false;
          _unlocked = false;
        });
      }
      return;
    }
    setState(() {
      _checkingLock = false;
      _unlocked = false;
    });
  }

  Future<String?> _promptSetPin(BuildContext context) async {
    final ctrl = TextEditingController();
    final ctrl2 = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Sécuriser THIX VAULT'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Définissez un code d\'accès pour protéger votre coffre de documents.',
              style: TextStyle(fontSize: 12, color: LightModeColors.secondaryText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Code (4 à 6 chiffres)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl2,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Confirmer le code'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Plus tard')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
            onPressed: () {
              if (ctrl.text.trim().length < 4 || ctrl.text.trim() != ctrl2.text.trim()) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Les codes ne correspondent pas.')));
                return;
              }
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _unlock() async {
    final me = context.read<AuthController>().currentUser;
    if (me == null) return;
    final ctrl = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: const Text('Code d\'accès THIX VAULT'),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Code', errorText: error),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
              onPressed: () async {
                final valid = await _docs.verifyVaultPin(uid: me.id, pin: ctrl.text.trim());
                if (valid) {
                  Navigator.pop(ctx, true);
                } else {
                  setDlg(() => error = 'Code incorrect');
                }
              },
              child: const Text('Déverrouiller'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) setState(() => _unlocked = true);
  }

  // ---------------------------------------------------------------------------
  // Ouverture / URL
  // ---------------------------------------------------------------------------

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(
        uri,
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_blank' : null,
      );
      if (!ok) throw Exception('launch failed');
    } catch (e) {
      debugPrint('Vault: openUrl failed url=$url err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ouverture impossible.')));
    }
  }

  Future<void> _openDoc(Map<String, dynamic> row) async {
    try {
      final url = await _docs.resolveRowDownloadUrl(row);
      if (url.trim().isEmpty) throw Exception('URL vide');
      await _openUrl(url);
    } catch (e) {
      debugPrint('Vault: openDoc failed err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Téléchargement / ouverture impossible.')));
    }
  }

  String _formatDate(dynamic createdAt) {
    final date = createdAt is DateTime
        ? createdAt
        : (createdAt is String)
            ? DateTime.tryParse(createdAt)
            : null;
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatSize(int sizeBytes) {
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ---------------------------------------------------------------------------
  // DÉPÔT — dossiers + upload
  // ---------------------------------------------------------------------------

  Future<void> _createFolder(String uid) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Nouveau dossier'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nom du dossier')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _docs.createFolder(uid: uid, name: name);
  }

  Future<void> _pickAndUpload() async {
    final me = context.read<AuthController>().currentUser;
    if (me == null) return;

    final picked = await FilePicker.platform.pickFiles(withData: kIsWeb);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;

    if (!mounted) return;
    final folders = await _docs.fetchFolders(me.id);
    if (!mounted) return;

    final res = await showModalBottomSheet<_UploadDocPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UploadDocumentSheet(
        fileName: file.name,
        folders: folders,
        preselectedFolderId: _folderFilter,
        onCreateFolder: (name) => _docs.createFolder(uid: me.id, name: name),
      ),
    );
    if (res == null) return;

    try {
      // Dépôt toujours privé par défaut — la visibilité publique se change ensuite depuis le menu du document.
      final generatedId = await _docs.uploadPickedFileSimple(
        uid: me.id,
        file: file,
        docType: res.docType,
        expiresAt: res.expiresAt,
        title: res.title,
        folderId: res.folderId,
        isPublic: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Document déposé • $generatedId')));
    } catch (e) {
      debugPrint('Vault: upload failed err=$e');
      if (!mounted) return;
      final msg = DocumentService.isBucketNotFound(e)
          ? 'Upload impossible : bucket Storage manquant ("${DocumentService.bucket}").'
          : 'Upload impossible.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ---------------------------------------------------------------------------
  // ENVOYER
  // ---------------------------------------------------------------------------

  Future<void> _openSendSheet() async {
    final me = context.read<AuthController>().currentUser;
    if (me == null) return;

    final docs = await _docs.fetchDocuments(me.id, limit: 50);
    if (!mounted) return;

    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun document à envoyer. Déposez-en un d\'abord.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SendDocumentSheet(
        documents: docs,
        docsService: _docs,
        onSend: (payload) async {
          try {
            await _docs.shareDocument(
              senderId: me.id,
              documentId: payload.documentId,
              docId: payload.docIdLabel,
              recipientThixIds: payload.recipients,
              subject: payload.subject,
              body: payload.body,
              password: payload.password,
              availableFrom: payload.availableFrom,
              autoDestructIn: payload.autoDestructIn,
            );
            if (!mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document envoyé.')));
          } catch (e) {
            debugPrint('Vault: share failed err=$e');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Envoi impossible : $e')));
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECHERCHE PAR ID (documents publics) — carte enrichie avec avatar
  // ---------------------------------------------------------------------------

  Future<void> _searchById() async {
    final ctrl = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Rechercher un document'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Identifiant THIX-DOC-...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Rechercher'),
          ),
        ],
      ),
    );
    if (query == null || query.isEmpty) return;

    final res = await _docs.searchPublicDocument(query);
    if (!mounted) return;

    if (res == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun document public trouvé pour cet identifiant.')),
      );
      return;
    }

    final storagePath = (res['storage_path'] as String?) ?? '';
    final mime = (res['mime_type'] as String?) ?? '';
    final avatarUrl = (res['owner_avatar_url'] as String?) ?? '';
    final isImage = mime.toLowerCase().contains('image');
    final accent = typeAccentColor(mime, res['doc_type'] as String?);

    Future<String>? downloadFuture;
    if (storagePath.isNotEmpty) {
      downloadFuture = _docs.createDownloadUrl(storagePath: storagePath);
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _primary.withValues(alpha: 0.12),
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            ((res['owner_name'] as String?)?.isNotEmpty == true
                                    ? (res['owner_name'] as String).substring(0, 1)
                                    : '?')
                                .toUpperCase(),
                            style: const TextStyle(color: _navy, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((res['owner_name'] as String?) ?? 'Propriétaire inconnu',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text((res['owner_thix_id'] as String?) ?? '—',
                            style: const TextStyle(fontSize: 11, color: LightModeColors.secondaryText)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: downloadFuture == null
                    ? null
                    : () async {
                        try {
                          final url = await downloadFuture!;
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          await _openUrl(url);
                        } catch (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ouverture impossible.')),
                          );
                        }
                      },
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isImage && downloadFuture != null
                        ? FutureBuilder<String>(
                            future: downloadFuture,
                            builder: (context, snap) {
                              if (!snap.hasData) return Center(child: Icon(typeIcon(mime, res['doc_type'] as String?), color: accent, size: 36));
                              return Image.network(snap.data!, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(child: Icon(typeIcon(mime, res['doc_type'] as String?), color: accent, size: 36)));
                            },
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(typeIcon(mime, res['doc_type'] as String?), color: accent, size: 36),
                                const SizedBox(height: 6),
                                Text('Toucher pour ouvrir', style: TextStyle(fontSize: 11, color: accent)),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(res['title'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text('${res['doc_type'] ?? '—'} • ${res['generated_doc_id'] ?? '—'}',
                  style: const TextStyle(fontSize: 11, color: LightModeColors.secondaryText)),
              const SizedBox(height: 2),
              Text('Créé le : ${_formatDate(res['created_at'])}',
                  style: const TextStyle(fontSize: 11, color: LightModeColors.secondaryText)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MENU DOCUMENT
  // ---------------------------------------------------------------------------

  Future<void> _showDocMenu({required Map<String, dynamic> row}) async {
    final title = (row['title'] as String?) ?? 'Document';
    final storagePath = (row['storage_path'] as String?) ?? '';
    final docId = (row['generated_doc_id'] as String?) ?? (row['doc_id'] as String?) ?? '';
    final me = context.read<AuthController>().currentUser;
    bool isPublic = (row['is_public'] as bool?) ?? false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            decoration: BoxDecoration(
              color: context.theme.colorScheme.surface,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.lg), topRight: Radius.circular(AppRadius.lg)),
              border: Border.all(color: context.theme.dividerColor),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title,
                          style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded, size: 18)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: () => _openDoc(row),
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 16),
                  label: const Text('Ouvrir', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Visibilité : jamais choisie au dépôt — uniquement ici, activable puis désactivable.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _ivory,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      isPublic ? 'Document public (visible via la recherche)' : 'Document privé',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      isPublic ? 'Retirer pour le rendre privé' : 'Activer pour le rendre accessible via la recherche',
                      style: const TextStyle(fontSize: 10, color: LightModeColors.secondaryText),
                    ),
                    value: isPublic,
                    activeColor: _primary,
                    onChanged: me == null
                        ? null
                        : (v) async {
                            setSheet(() => isPublic = v);
                            await _docs.togglePublic(
                              uid: me.id,
                              documentId: row['id'].toString(),
                              docId: docId,
                              isPublic: v,
                            );
                          },
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: me == null
                      ? null
                      : () async {
                          try {
                            final docRowId = (row['id'] ?? '').toString();
                            if (docRowId.trim().isEmpty) throw Exception('id manquant');
                            await _docs.deleteDocument(uid: me.id, documentId: docRowId, storagePath: storagePath, docId: docId);
                            if (!mounted) return;
                            context.pop();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document supprimé.')));
                          } catch (e) {
                            debugPrint('Vault: delete failed err=$e');
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suppression impossible.')));
                          }
                        },
                  icon: Icon(Icons.delete_outline_rounded, color: context.theme.colorScheme.error, size: 16),
                  label: Text('Supprimer',
                      style: context.textStyles.labelMedium?.copyWith(color: context.theme.colorScheme.error, fontSize: 13)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: context.theme.colorScheme.error.withValues(alpha: 0.5))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_checkingLock) {
      return const Scaffold(backgroundColor: _navyDeep, body: Center(child: CircularProgressIndicator(color: _gold)));
    }
    if (!_unlocked) {
      return _LockScreen(onUnlock: _unlock);
    }

    final me = context.watch<AuthController>().currentUser;

    return Scaffold(
      backgroundColor: _ivory,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== HEADER =====
            Container(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navyDeep, _navy]),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(AppRadius.lg), bottomRight: Radius.circular(AppRadius.lg)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                          onPressed: () {
                            final auth = context.read<AuthController>();
                            if (auth.isAuthenticated) {
                              final t = auth.currentUser?.accountType;
                              context.go(t == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard);
                              return;
                            }
                            context.go(AppRoutes.home);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: _gold, size: 16),
                            const SizedBox(width: 6),
                            Text("THIX VAULT",
                                style: context.textStyles.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                          onPressed: _searchById,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      height: 36,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.full)),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.full)),
                        labelColor: _navy,
                        unselectedLabelColor: Colors.white70,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: 'Dépôt'),
                          Tab(text: 'Envoyer'),
                          Tab(text: 'Reçu'),
                          Tab(text: 'Historique'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _DepotTab(
                    me: me,
                    docsService: _docs,
                    formatDate: _formatDate,
                    formatSize: _formatSize,
                    onOpenDoc: _openDoc,
                    onMore: (row) => _showDocMenu(row: row),
                    onDeposit: _pickAndUpload,
                    folderFilter: _folderFilter,
                    onFolderSelected: (id) => setState(() => _folderFilter = id),
                    onCreateFolder: _createFolder,
                  ),
                  _EnvoyerTab(me: me, docsService: _docs, formatDate: _formatDate, onOpenSend: _openSendSheet),
                  _RecuTab(me: me, docsService: _docs, onOpenDoc: _openDoc, formatDate: _formatDate),
                  _HistoriqueTab(me: me, docsService: _docs, formatDate: _formatDate),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _pickAndUpload,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              label: Text("DÉPOSER",
                  style: context.textStyles.labelLarge?.copyWith(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            )
          : null,
    );
  }
}

// =============================================================
// ÉCRAN DE VERROUILLAGE
// =============================================================

class _LockScreen extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockScreen({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navyDeep,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(color: _navy, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.lock_rounded, color: _gold, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('THIX VAULT est verrouillé',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Vos documents sont protégés par un code d\'accès.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Déverrouiller'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _navyDeep,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// ONGLET DÉPÔT
// =============================================================

class _DepotTab extends StatelessWidget {
  final AppUser? me;
  final DocumentService docsService;
  final String Function(dynamic) formatDate;
  final String Function(int) formatSize;
  final Future<void> Function(Map<String, dynamic>) onOpenDoc;
  final void Function(Map<String, dynamic>) onMore;
  final VoidCallback onDeposit;
  final String? folderFilter;
  final void Function(String?) onFolderSelected;
  final Future<void> Function(String uid) onCreateFolder;

  const _DepotTab({
    required this.me,
    required this.docsService,
    required this.formatDate,
    required this.formatSize,
    required this.onOpenDoc,
    required this.onMore,
    required this.onDeposit,
    required this.folderFilter,
    required this.onFolderSelected,
    required this.onCreateFolder,
  });

  @override
  Widget build(BuildContext context) {
    if (me == null) {
      return const Center(child: Text('Connectez-vous pour voir vos documents.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Dossiers", style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: AppSpacing.sm),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: docsService.streamFolders(me!.id),
            builder: (context, snap) {
              final folders = snap.data ?? const [];
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FolderChip(icon: Icons.apps_rounded, label: "Tout", selected: folderFilter == null, onTap: () => onFolderSelected(null)),
                    ...folders.map((f) => FolderChip(
                          icon: Icons.folder_rounded,
                          label: f['name'] as String? ?? 'Dossier',
                          selected: folderFilter == f['id'],
                          onTap: () => onFolderSelected(f['id'] as String),
                        )),
                    FolderChip(
                      icon: Icons.create_new_folder_rounded,
                      label: "Nouveau",
                      selected: false,
                      onTap: () => onCreateFolder(me!.id),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text("Mes documents", style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: AppSpacing.sm),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: docsService.streamDocuments(me!.id),
            builder: (context, snap) {
              var docs = snap.data ?? const <Map<String, dynamic>>[];
              if (folderFilter != null) {
                docs = docs.where((d) => d['folder_id'] == folderFilter).toList();
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
              }
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Aucun document.', style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.secondaryText, fontSize: 13)),
                      const SizedBox(height: 12),
                      TextButton.icon(onPressed: onDeposit, icon: const Icon(Icons.add, size: 16), label: const Text('Déposer mon premier document')),
                    ],
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                ),
                itemBuilder: (context, i) {
                  final data = docs[i];
                  final title = (data['title'] as String?) ?? (data['generated_doc_id'] as String?) ?? (data['doc_id'] as String?) ?? 'Document';
                  final mime = (data['mime_type'] as String?) ?? (data['mimeType'] as String?);
                  final docType = data['doc_type'] as String?;
                  final sizeBytes = (data['size_bytes'] as num?)?.toInt() ?? (data['sizeBytes'] as num?)?.toInt() ?? 0;
                  final dateStr = formatDate(data['created_at']);
                  final sizeStr = formatSize(sizeBytes);
                  final docId = (data['generated_doc_id'] as String?) ?? (data['doc_id'] as String?) ?? '';
                  final isPublic = (data['is_public'] as bool?) ?? false;
                  final isImage = (mime ?? '').toLowerCase().contains('image');

                  return DocSquareCard(
                    icon: typeIcon(mime, docType),
                    accentColor: typeAccentColor(mime, docType),
                    title: title,
                    docId: docId,
                    subtitle: '$dateStr • $sizeStr',
                    isPublic: isPublic,
                    previewUrlFuture: isImage ? docsService.resolveRowDownloadUrl(data) : null,
                    onTap: () => onOpenDoc(data),
                    onMore: () => onMore(data),
                    onShowQr: () => showQrDialog(context, title: title, value: docId.isNotEmpty ? docId : title),
                    onShowId: () => showDocIdDialog(context, docId: docId.isNotEmpty ? docId : '—', title: title),
                  );
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: _primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: _primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(Icons.verified_user_rounded, color: _navy, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SÉCURITÉ INSTITUTIONNELLE", style: context.textStyles.labelSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text("Chiffrement AES-256 • Coffre verrouillé par code • Vos données ne quittent jamais le territoire.",
                          style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, fontSize: 10, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// =============================================================
// ONGLET ENVOYER (avec disparition auto des envois expirés)
// =============================================================

class _EnvoyerTab extends StatefulWidget {
  final AppUser? me;
  final DocumentService docsService;
  final String Function(dynamic) formatDate;
  final VoidCallback onOpenSend;

  const _EnvoyerTab({required this.me, required this.docsService, required this.formatDate, required this.onOpenSend});

  @override
  State<_EnvoyerTab> createState() => _EnvoyerTabState();
}

class _EnvoyerTabState extends State<_EnvoyerTab> {
  final Set<String> _autoDestroyed = {};

  String _statusLabel(String status) {
    switch (status) {
      case 'available':
        return 'Disponible';
      case 'opened':
        return 'Vu';
      case 'pending':
        return 'Verrouillé';
      case 'expired':
        return 'Expiré';
      case 'destroyed':
        return 'Détruit';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.me == null) {
      return const Center(child: Text('Connectez-vous pour envoyer des documents.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Icon(Icons.send_rounded, size: 44, color: _primary.withValues(alpha: 0.7)),
                const SizedBox(height: 12),
                Text('Envoyer un document sécurisé',
                    style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('Mot de passe • Auto-destruction optionnelle • Disponibilité différée\nNotification d\'ouverture',
                    style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, height: 1.4), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: widget.onOpenSend,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('NOUVEL ENVOI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text("Suivi des envois", style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: AppSpacing.sm),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.docsService.streamSentShares(widget.me!.id),
            builder: (context, snap) {
              final shares = snap.data ?? const [];
              final now = DateTime.now();
              final visible = <Map<String, dynamic>>[];

              for (final s in shares) {
                final status = (s['status'] as String?) ?? 'pending';
                final shareId = s['id']?.toString();
                final autoDestructAt = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());

                if (status == 'destroyed' || status == 'expired') continue; // disparu

                if (autoDestructAt != null && autoDestructAt.isBefore(now)) {
                  if (shareId != null && _autoDestroyed.add(shareId)) {
                    widget.docsService.markShareDestroyed(shareId);
                  }
                  continue; // disparaît immédiatement de la liste
                }
                visible.add(s);
              }

              if (visible.isEmpty) {
                return Text('Aucun envoi actif pour le moment.',
                    style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText));
              }
              return Column(
                children: visible.map((s) {
                  final status = (s['status'] as String?) ?? 'pending';
                  final hasPassword = (s['password_hash'] as String?)?.isNotEmpty == true;
                  final autoDestructAt = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
                  final createdAt = DateTime.tryParse((s['created_at'] ?? '').toString()) ?? DateTime.now();
                  Widget? progress;
                  if (autoDestructAt != null) {
                    progress = CountdownBar(start: createdAt, target: autoDestructAt, label: 'Auto-destruction', color: Colors.redAccent);
                  }
                  return DocItem(
                    icon: status == 'opened' ? Icons.mark_email_read_rounded : Icons.mail_outline_rounded,
                    accentColor: status == 'opened' ? const Color(0xFF10AC84) : _primary,
                    title: (s['recipient_thix_id'] as String?) ?? '—',
                    subtitle: (s['subject'] as String?)?.isNotEmpty == true ? s['subject'] as String : 'Sans objet',
                    trailing: _statusLabel(status),
                    hasPassword: hasPassword,
                    progress: progress,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================
// ONGLET REÇU (avec disparition auto des envois expirés)
// =============================================================

class _RecuTab extends StatefulWidget {
  final AppUser? me;
  final DocumentService docsService;
  final Future<void> Function(Map<String, dynamic>) onOpenDoc;
  final String Function(dynamic) formatDate;

  const _RecuTab({required this.me, required this.docsService, required this.onOpenDoc, required this.formatDate});

  @override
  State<_RecuTab> createState() => _RecuTabState();
}

class _RecuTabState extends State<_RecuTab> {
  final Set<String> _autoDestroyed = {};

  Future<void> _handleOpenShare(BuildContext context, Map<String, dynamic> share) async {
    final status = (share['status'] as String?) ?? 'pending';
    final availableFromRaw = share['available_from'];
    final autoDestructRaw = share['auto_destruct_at'];
    final hasPassword = (share['password_hash'] as String?)?.isNotEmpty == true;
    final shareId = share['id']?.toString();
    final documentId = share['document_id']?.toString();

    if (shareId == null || documentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Données du partage invalides.')));
      return;
    }

    if (autoDestructRaw != null) {
      final autoAt = DateTime.tryParse(autoDestructRaw.toString());
      if (autoAt != null && autoAt.isBefore(DateTime.now())) {
        await widget.docsService.markShareDestroyed(shareId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce document a été auto-détruit.')));
        return;
      }
    }

    if (status == 'pending' || status == 'available') {
      if (availableFromRaw != null) {
        final avail = DateTime.tryParse(availableFromRaw.toString());
        if (avail != null && avail.isAfter(DateTime.now())) {
          final d = '${avail.day.toString().padLeft(2, '0')}/${avail.month.toString().padLeft(2, '0')}/${avail.year}';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Document disponible à partir du $d.')));
          return;
        }
      }
    }

    if (status == 'destroyed' || status == 'expired') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce document n\'est plus disponible.')));
      return;
    }

    if (hasPassword) {
      final stored = share['password_hash'] as String?;
      final ctrl = TextEditingController();
      String? error;
      final entered = await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            title: const Text('Mot de passe requis'),
            content: TextField(
              controller: ctrl,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Mot de passe', border: const OutlineInputBorder(), errorText: error),
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  if (stored == null) {
                    Navigator.pop(ctx, ctrl.text);
                    return;
                  }
                  final valid = await widget.docsService.verifyPassword(password: ctrl.text, hash: stored);
                  if (valid) {
                    Navigator.pop(ctx, ctrl.text);
                  } else {
                    setDlg(() => error = 'Mot de passe incorrect');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primary),
                child: const Text('Ouvrir', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
      if (entered == null) return;
    }

    try {
      final docRow = await widget.docsService.fetchDocumentById(documentId);
      if (docRow == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document introuvable.')));
        return;
      }
      await widget.docsService.markShareOpened(shareId, uid: docRow['user_id']?.toString(), docId: docRow['generated_doc_id']?.toString());
      await widget.onOpenDoc(docRow);
    } catch (e) {
      debugPrint('Open received share failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir le document.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.me == null) {
      return const Center(child: Text('Connectez-vous pour voir les documents reçus.'));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.docsService.streamReceivedShares(widget.me!.id, widget.me!.thixId),
      builder: (context, snap) {
        final shares = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final now = DateTime.now();
        final visible = <Map<String, dynamic>>[];
        for (final s in shares) {
          final status = (s['status'] as String?) ?? 'pending';
          final shareId = s['id']?.toString();
          final autoDestructAt = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());

          if (status == 'destroyed' || status == 'expired') continue;

          if (autoDestructAt != null && autoDestructAt.isBefore(now)) {
            if (shareId != null && _autoDestroyed.add(shareId)) {
              widget.docsService.markShareDestroyed(shareId);
            }
            continue;
          }
          visible.add(s);
        }

        if (visible.isEmpty) {
          return Center(child: Text('Aucun document reçu.', style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.secondaryText)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: visible.length,
          itemBuilder: (context, i) {
            final s = visible[i];
            final subject = (s['subject'] as String?)?.trim().isNotEmpty == true ? s['subject'] as String : 'Document partagé';
            final status = (s['status'] as String?) ?? 'pending';
            final hasPassword = (s['password_hash'] as String?)?.isNotEmpty == true;
            final screenshotCount = (s['screenshot_count'] as num?)?.toInt() ?? 0;
            final createdAt = DateTime.tryParse((s['created_at'] ?? '').toString()) ?? DateTime.now();
            final autoDestructAt = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
            final availableFrom = DateTime.tryParse((s['available_from'] ?? '').toString());

            String statusLabel;
            switch (status) {
              case 'available':
                statusLabel = 'Disponible';
                break;
              case 'opened':
                statusLabel = 'Ouvert';
                break;
              case 'pending':
                statusLabel = 'Verrouillé';
                break;
              default:
                statusLabel = status;
            }

            Widget? progress;
            if (status == 'pending' && availableFrom != null && availableFrom.isAfter(DateTime.now())) {
              progress = CountdownBar(start: createdAt, target: availableFrom, label: 'Disponible dans', color: _primary);
            } else if (autoDestructAt != null) {
              progress = CountdownBar(start: createdAt, target: autoDestructAt, label: 'Auto-destruction dans', color: Colors.redAccent);
            }

            return DocItem(
              icon: Icons.mail_outline_rounded,
              accentColor: _primary,
              title: subject,
              subtitle: '${widget.formatDate(s['created_at'])}${screenshotCount > 0 ? ' • 📸 $screenshotCount' : ''}',
              trailing: statusLabel,
              hasPassword: hasPassword,
              onTap: () => _handleOpenShare(context, s),
              progress: progress,
            );
          },
        );
      },
    );
  }
}

// =============================================================
// ONGLET HISTORIQUE
// =============================================================

class _HistoriqueTab extends StatelessWidget {
  final AppUser? me;
  final DocumentService docsService;
  final String Function(dynamic) formatDate;

  const _HistoriqueTab({required this.me, required this.docsService, required this.formatDate});

  IconData _iconForAction(String action) {
    switch (action) {
      case 'upload':
        return Icons.upload_file_rounded;
      case 'send':
        return Icons.send_rounded;
      case 'open':
        return Icons.visibility_rounded;
      case 'delete':
        return Icons.delete_outline_rounded;
      case 'screenshot':
        return Icons.camera_alt_rounded;
      case 'public_toggle':
        return Icons.public_rounded;
      case 'folder_create':
        return Icons.create_new_folder_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  String _labelForAction(String action) {
    switch (action) {
      case 'upload':
        return 'Dépôt';
      case 'send':
        return 'Envoi';
      case 'open':
        return 'Ouverture';
      case 'delete':
        return 'Suppression';
      case 'screenshot':
        return 'Capture d\'écran';
      case 'public_toggle':
        return 'Visibilité modifiée';
      case 'folder_create':
        return 'Dossier créé';
      default:
        return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (me == null) {
      return const Center(child: Text('Connectez-vous pour voir l\'historique.'));
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: docsService.streamTransactions(me!.id),
      builder: (context, snap) {
        final tx = snap.data ?? const [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (tx.isEmpty) {
          return Center(child: Text('Aucune activité pour le moment.', style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.secondaryText)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: tx.length,
          itemBuilder: (context, i) {
            final t = tx[i];
            final action = (t['action'] as String?) ?? '';
            return DocItem(
              icon: _iconForAction(action),
              title: _labelForAction(action),
              subtitle: '${(t['detail'] as String?) ?? (t['doc_id'] as String?) ?? ''}',
              trailing: formatDate(t['created_at']),
            );
          },
        );
      },
    );
  }
}

// =============================================================
// SHEET : DÉPÔT (dossier + type — pas de choix de visibilité ici)
// =============================================================

class _UploadDocPayload {
  final String docType;
  final String? title;
  final DateTime? expiresAt;
  final String? folderId;
  const _UploadDocPayload({required this.docType, this.title, this.expiresAt, this.folderId});
}

class _UploadDocumentSheet extends StatefulWidget {
  final String fileName;
  final List<Map<String, dynamic>> folders;
  final String? preselectedFolderId;
  final Future<void> Function(String name) onCreateFolder;

  const _UploadDocumentSheet({
    required this.fileName,
    required this.folders,
    this.preselectedFolderId,
    required this.onCreateFolder,
  });

  @override
  State<_UploadDocumentSheet> createState() => _UploadDocumentSheetState();
}

class _UploadDocumentSheetState extends State<_UploadDocumentSheet> {
  String _type = 'Autre';
  DateTime? _expiresAt;
  String? _folderId;
  final _titleC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _folderId = widget.preselectedFolderId;
  }

  @override
  void dispose() {
    _titleC.dispose();
    super.dispose();
  }

  bool get _needsExpiry => _type == 'CIN' || _type == 'Passeport' || _type == 'Permis';

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 20)),
      lastDate: now.add(const Duration(days: 365 * 50)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expiresAt = DateTime(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final expiryLabel = _expiresAt == null
        ? 'Choisir une date'
        : '${_expiresAt!.year.toString().padLeft(4, '0')}-${_expiresAt!.month.toString().padLeft(2, '0')}-${_expiresAt!.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.lg), topRight: Radius.circular(AppRadius.lg)),
          border: Border.all(color: context.theme.dividerColor),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Déposer un document', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded, size: 18)),
                ],
              ),
              Text(widget.fileName, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, fontSize: 12)),
              const SizedBox(height: 4),
              Text('L\'identifiant unique sera généré automatiquement\n(THIX-DOC-MMAAAA-XXXXXX-XXX/CC)',
                  style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, fontSize: 11)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 12, color: LightModeColors.secondaryText),
                  const SizedBox(width: 4),
                  Text('Déposé en privé par défaut — rendez-le public plus tard si besoin.',
                      style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText, fontSize: 10)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String?>(
                value: _folderId,
                decoration: InputDecoration(
                  labelText: 'Dossier',
                  prefixIcon: const Icon(Icons.folder_rounded, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sans dossier')),
                  ...widget.folders.map((f) => DropdownMenuItem(value: f['id'] as String, child: Text(f['name'] as String? ?? 'Dossier'))),
                ],
                onChanged: (v) => setState(() => _folderId = v),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final ctrl = TextEditingController();
                    final name = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Nouveau dossier'),
                        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nom')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Créer')),
                        ],
                      ),
                    );
                    if (name != null && name.isNotEmpty) await widget.onCreateFolder(name);
                  },
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Créer un dossier', style: TextStyle(fontSize: 12)),
                ),
              ),
              DropdownButtonFormField<String>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'CIN', child: Text('Pièce d\'identité — CIN')),
                  DropdownMenuItem(value: 'Passeport', child: Text('Pièce d\'identité — Passeport')),
                  DropdownMenuItem(value: 'Permis', child: Text('Pièce d\'identité — Permis')),
                  DropdownMenuItem(value: 'Diplôme', child: Text('Diplôme / Attestation')),
                  DropdownMenuItem(value: 'PreuveAdresse', child: Text('Preuve d\'adresse')),
                  DropdownMenuItem(value: 'Autre', child: Text('Autre')),
                ],
                onChanged: (v) => setState(() {
                  _type = v ?? 'Autre';
                  if (!_needsExpiry) _expiresAt = null;
                }),
                decoration: InputDecoration(
                  labelText: 'Type de document',
                  prefixIcon: const Icon(Icons.folder_rounded, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _titleC,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Titre (optionnel)',
                  hintText: 'Ex: Carte d\'identité nationale',
                  prefixIcon: const Icon(Icons.description_rounded, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
              if (_needsExpiry) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: _pickExpiry,
                    icon: const Icon(Icons.event_available_rounded, size: 16),
                    label: Text('Date d\'expiration: $expiryLabel', style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.theme.colorScheme.primary,
                      side: BorderSide(color: context.theme.colorScheme.primary, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_needsExpiry && _expiresAt == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date d\'expiration requise pour cette pièce.')));
                      return;
                    }
                    context.pop(_UploadDocPayload(
                      docType: _type,
                      title: _titleC.text.trim().isEmpty ? null : _titleC.text.trim(),
                      expiresAt: _expiresAt,
                      folderId: _folderId,
                    ));
                  },
                  icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                  label: const Text('DÉPOSER', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// SHEET : ENVOI (vérification THIX ID + auto-destruction optionnelle)
// =============================================================

class _SendPayload {
  final String documentId;
  final String? docIdLabel;
  final List<String> recipients;
  final String? subject;
  final String? body;
  final String? password;
  final DateTime? availableFrom;
  final Duration? autoDestructIn;

  const _SendPayload({
    required this.documentId,
    this.docIdLabel,
    required this.recipients,
    this.subject,
    this.body,
    this.password,
    this.availableFrom,
    this.autoDestructIn,
  });
}

class _SendDocumentSheet extends StatefulWidget {
  final List<Map<String, dynamic>> documents;
  final DocumentService docsService;
  final Future<void> Function(_SendPayload) onSend;

  const _SendDocumentSheet({required this.documents, required this.docsService, required this.onSend});

  @override
  State<_SendDocumentSheet> createState() => _SendDocumentSheetState();
}

class _SendDocumentSheetState extends State<_SendDocumentSheet> {
  String? _selectedDocId;
  final _recipientsC = TextEditingController();
  final _subjectC = TextEditingController();
  final _bodyC = TextEditingController();
  final _passwordC = TextEditingController();
  final _durationValueC = TextEditingController(text: '10');
  String _durationUnit = 'minutes'; // secondes | minutes | heures | jours
  bool _autoDestructEnabled = false; // désactivé par défaut — case à cocher explicite
  DateTime? _availableFrom;
  bool _sending = false;

  Timer? _debounce;
  String? _verifiedName;
  bool _verifying = false;

  @override
  void dispose() {
    _recipientsC.dispose();
    _subjectC.dispose();
    _bodyC.dispose();
    _passwordC.dispose();
    _durationValueC.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onRecipientsChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final ids = value.split(RegExp(r'[,;\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty);
      if (ids.isEmpty) {
        setState(() => _verifiedName = null);
        return;
      }
      setState(() => _verifying = true);
      final profile = await widget.docsService.verifyThixId(ids.last);
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verifiedName = profile == null ? 'Introuvable' : (profile['full_name'] as String? ?? 'Sans nom');
      });
    });
  }

  Duration? _computeDuration() {
    if (!_autoDestructEnabled) return null;
    final v = int.tryParse(_durationValueC.text.trim());
    if (v == null || v <= 0) return null;
    switch (_durationUnit) {
      case 'secondes':
        return Duration(seconds: v);
      case 'heures':
        return Duration(hours: v);
      case 'jours':
        return Duration(days: v);
      case 'minutes':
      default:
        return Duration(minutes: v);
    }
  }

  Future<void> _pickAvailableDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365 * 2)));
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    setState(() {
      _availableFrom = DateTime(picked.year, picked.month, picked.day, time?.hour ?? 0, time?.minute ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.lg), topRight: Radius.circular(AppRadius.lg)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Envoyer un document', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 18)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                value: _selectedDocId,
                decoration: InputDecoration(labelText: 'Document à envoyer', border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                items: widget.documents.map((d) {
                  final id = d['id'].toString();
                  final title = (d['title'] as String?) ?? (d['generated_doc_id'] as String?) ?? 'Document';
                  return DropdownMenuItem(value: id, child: Text(title, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (v) => setState(() => _selectedDocId = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _recipientsC,
                onChanged: _onRecipientsChanged,
                decoration: InputDecoration(
                  labelText: 'THIX ID destinataires',
                  hintText: 'THIX-XXXX, THIX-YYYY (séparés par virgule)',
                  prefixIcon: const Icon(Icons.people_outline, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
              if (_verifying)
                const Padding(padding: EdgeInsets.only(top: 4), child: Text('Vérification...', style: TextStyle(fontSize: 11, color: LightModeColors.secondaryText)))
              else if (_verifiedName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(_verifiedName == 'Introuvable' ? Icons.error_outline : Icons.check_circle,
                          size: 14, color: _verifiedName == 'Introuvable' ? Colors.redAccent : Colors.green),
                      const SizedBox(width: 4),
                      Text(_verifiedName!, style: TextStyle(fontSize: 12, color: _verifiedName == 'Introuvable' ? Colors.redAccent : Colors.green)),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _subjectC,
                decoration: InputDecoration(labelText: 'Objet', border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _bodyC,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Message', border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _passwordC,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mot de passe (optionnel)',
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Auto-destruction : désactivée par défaut, case à cocher explicite
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: _ivory, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: const Text('Activer l\'auto-destruction', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Le document disparaîtra après la durée choisie', style: TextStyle(fontSize: 10, color: LightModeColors.secondaryText)),
                  value: _autoDestructEnabled,
                  activeColor: Colors.redAccent,
                  onChanged: (v) => setState(() => _autoDestructEnabled = v),
                ),
              ),
              if (_autoDestructEnabled) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _durationValueC,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Durée', border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _durationUnit,
                        items: const [
                          DropdownMenuItem(value: 'secondes', child: Text('Secondes')),
                          DropdownMenuItem(value: 'minutes', child: Text('Minutes')),
                          DropdownMenuItem(value: 'heures', child: Text('Heures')),
                          DropdownMenuItem(value: 'jours', child: Text('Jours')),
                        ],
                        onChanged: (v) => setState(() => _durationUnit = v ?? 'minutes'),
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _pickAvailableDate,
                icon: const Icon(Icons.schedule, size: 16),
                label: Text(
                  _availableFrom == null
                      ? 'Disponible dès maintenant (choisir une date/heure différée)'
                      : 'Disponible à partir du ${_availableFrom!.day}/${_availableFrom!.month}/${_availableFrom!.year} ${_availableFrom!.hour.toString().padLeft(2, '0')}:${_availableFrom!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _sending
                      ? null
                      : () async {
                          if (_selectedDocId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez un document.')));
                            return;
                          }
                          final recipients = _recipientsC.text.split(RegExp(r'[,;\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                          if (recipients.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indiquez au moins un THIX ID.')));
                            return;
                          }

                          setState(() => _sending = true);
                          final selectedDoc = widget.documents.firstWhere((d) => d['id'].toString() == _selectedDocId);
                          await widget.onSend(_SendPayload(
                            documentId: _selectedDocId!,
                            docIdLabel: (selectedDoc['generated_doc_id'] as String?) ?? (selectedDoc['doc_id'] as String?),
                            recipients: recipients,
                            subject: _subjectC.text.trim().isEmpty ? null : _subjectC.text.trim(),
                            body: _bodyC.text.trim().isEmpty ? null : _bodyC.text.trim(),
                            password: _passwordC.text.trim().isEmpty ? null : _passwordC.text.trim(),
                            availableFrom: _availableFrom,
                            autoDestructIn: _computeDuration(),
                          ));
                          if (mounted) setState(() => _sending = false);
                        },
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_sending ? 'Envoi...' : 'ENVOYER'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}
