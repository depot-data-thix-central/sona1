// lib/presentation/education/instructor/create_book_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

class _C {
  static const bg = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const primary = Color(0xFF2D6CDF);
  static const textMain = Color(0xFF1E293B);
  static const textMuted = Color(0xFF7386A8);
  static const border = Color(0xFFE2E8F0);
  static const red = Color(0xFFEF4444);
  static const green = Color(0xFF2ECC71);
}

class CreateBookPage extends ConsumerStatefulWidget {
  final String? bookId;
  const CreateBookPage({super.key, this.bookId});

  @override
  ConsumerState<CreateBookPage> createState() => _CreateBookPageState();
}

class _CreateBookPageState extends ConsumerState<CreateBookPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  
  String _imageUrl = '';
  String _fileUrl = '';
  String _fileName = '';
  
  String _selectedCurrency = 'FC';
  bool _isLoading = false;
  bool _isInitLoading = false;
  bool _isUploadingImage = false;
  bool _isUploadingFile = false;

  @override
  void initState() {
    super.initState();
    if (widget.bookId != null) {
      _loadExistingBook();
    } else {
      // Pré-remplir l'auteur avec le nom de l'utilisateur connecté si disponible
      final userMeta = Supabase.instance.client.auth.currentUser?.userMetadata;
      if (userMeta != null && userMeta['name'] != null) {
        _authorController.text = userMeta['name'];
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingBook() async {
    setState(() => _isInitLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('books')
          .select()
          .eq('id', widget.bookId!)
          .single();

      if (mounted) {
        setState(() {
          _titleController.text = data['title']?.toString() ?? '';
          _authorController.text = data['author']?.toString() ?? '';
          _descriptionController.text = data['description']?.toString() ?? '';
          _priceController.text = data['price']?.toString() ?? '0';
          _selectedCurrency = data['currency']?.toString() ?? 'FC';
          _imageUrl = data['image_url']?.toString() ?? '';
          _fileUrl = data['file_url']?.toString() ?? '';
          if (_fileUrl.isNotEmpty) {
            _fileName = _fileUrl.split('/').last;
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement livre : $e');
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  // Upload de l'image de couverture vers Supabase Storage
  Future<void> _pickAndUploadCoverImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes == null) return;

        setState(() => _isUploadingImage = true);

        final ext = file.extension ?? 'jpg';
        final fileName = 'book_cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final filePath = 'books/covers/$fileName';

        await Supabase.instance.client.storage
            .from('course-media') // Assurez-vous que ce bucket existe dans Supabase
            .uploadBinary(filePath, bytes);

        final publicUrl = Supabase.instance.client.storage
            .from('course-media')
            .getPublicUrl(filePath);

        setState(() {
          _imageUrl = publicUrl;
          _isUploadingImage = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couverture uploadée avec succès !'), backgroundColor: _C.green),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload image : $e'), backgroundColor: _C.red),
        );
      }
    }
  }

  // Upload du fichier PDF/EPUB vers Supabase Storage
  Future<void> _pickAndUploadBookFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'mobi'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes == null) return;

        setState(() => _isUploadingFile = true);

        final ext = file.extension ?? 'pdf';
        final cleanName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
        final fileName = 'book_file_${DateTime.now().millisecondsSinceEpoch}_$cleanName';
        final filePath = 'books/files/$fileName';

        await Supabase.instance.client.storage
            .from('course-media')
            .uploadBinary(filePath, bytes);

        final publicUrl = Supabase.instance.client.storage
            .from('course-media')
            .getPublicUrl(filePath);

        setState(() {
          _fileUrl = publicUrl;
          _fileName = file.name;
          _isUploadingFile = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fichier du livre uploadé avec succès !'), backgroundColor: _C.green),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingFile = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload fichier : $e'), backgroundColor: _C.red),
        );
      }
    }
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_isUploadingImage || _isUploadingFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez patienter pendant la fin des transferts de fichiers.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté.');

      final payload = {
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'currency': _selectedCurrency,
        'image_url': _imageUrl.isEmpty ? null : _imageUrl,
        'file_url': _fileUrl.isEmpty ? null : _fileUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.bookId == null) {
        payload['instructor_id'] = userId;
        payload['created_at'] = DateTime.now().toIso8601String();
        await Supabase.instance.client.from('books').insert(payload);
      } else {
        await Supabase.instance.client.from('books').update(payload).eq('id', widget.bookId!);
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.bookId == null ? 'Livre publié avec succès !' : 'Livre mis à jour !'),
          backgroundColor: _C.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Retour propre sans stack accumulation
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: _C.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.bookId != null;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier le livre' : 'Ajouter un livre', style: const TextStyle(fontWeight: FontWeight.w800, color: _C.textMain, fontSize: 18)),
        backgroundColor: _C.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isInitLoading
          ? const Center(child: CircularProgressIndicator(color: _C.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // INFORMATIONS GÉNÉRALES
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Informations générales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.textMain)),
                          const SizedBox(height: 16),
                          
                          _buildTextField(
                            controller: _titleController,
                            label: 'Titre du livre',
                            icon: Icons.title_rounded,
                            validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 16),
                          
                          _buildTextField(
                            controller: _authorController,
                            label: 'Auteur',
                            icon: Icons.person_outline_rounded,
                            validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 16),
                          
                          _buildTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            icon: Icons.description_outlined,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildTextField(
                                  controller: _priceController,
                                  label: 'Prix',
                                  icon: Icons.payments_outlined,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  hintText: '0',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedCurrency,
                                  dropdownColor: _C.surface,
                                  style: const TextStyle(color: _C.textMain, fontWeight: FontWeight.w600),
                                  items: const [
                                    DropdownMenuItem(value: 'FC', child: Text('FC')),
                                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                                  ],
                                  onChanged: (v) => setState(() => _selectedCurrency = v!),
                                  decoration: _inputDecoration('Devise', Icons.currency_exchange_rounded),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // SECTION MÉDIAS & FICHIERS (UPLOADS NATIFS)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Médias & Fichiers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.textMain)),
                          const SizedBox(height: 16),
                          
                          // UPLOAD DE LA COUVERTURE
                          const Text('Image de couverture', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.textMuted)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _isUploadingImage ? null : _pickAndUploadCoverImage,
                            child: Container(
                              height: 160,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: _C.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _C.border, width: 2),
                                image: _imageUrl.isNotEmpty
                                    ? DecorationImage(image: NetworkImage(_imageUrl), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: _isUploadingImage
                                  ? const Center(child: CircularProgressIndicator(color: _C.primary))
                                  : (_imageUrl.isEmpty
                                      ? const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_photo_alternate_rounded, size: 40, color: _C.textMuted),
                                            SizedBox(height: 8),
                                            Text('Appuyer pour choisir une image', style: TextStyle(color: _C.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
                                          ],
                                        )
                                      : const Align(
                                          alignment: Alignment.topRight,
                                          child: Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.edit, color: Colors.white, size: 16)),
                                          ),
                                        )),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // UPLOAD DU DOCUMENT (PDF/EPUB)
                          const Text('Fichier du livre (PDF / EPUB)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.textMuted)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _isUploadingFile ? null : _pickAndUploadBookFile,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _C.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _C.border, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: _C.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.picture_as_pdf_rounded, color: _C.primary, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _fileName.isNotEmpty ? _fileName : (_fileUrl.isNotEmpty ? 'Fichier attaché (Enregistré)' : 'Aucun fichier sélectionné'),
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _fileName.isNotEmpty || _fileUrl.isNotEmpty ? _C.textMain : _C.textMuted),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        const Text('Appuyer pour parcourir les fichiers', style: TextStyle(fontSize: 11.5, color: _C.textMuted)),
                                      ],
                                    ),
                                  ),
                                  if (_isUploadingFile)
                                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary))
                                  else
                                    const Icon(Icons.cloud_upload_rounded, color: _C.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveBook,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(isEditing ? 'Mettre à jour' : 'Publier le livre', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: _C.textMain, fontWeight: FontWeight.w500),
      decoration: _inputDecoration(label, icon, hintText: hintText),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: const TextStyle(color: _C.textMuted, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: _C.textMuted, size: 20),
      filled: true,
      fillColor: _C.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.red, width: 1.0)),
    );
  }
}
