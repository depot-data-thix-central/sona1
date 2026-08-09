// lib/presentation/education/instructor/courses/course_create_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'package:thix_id/presentation/education/providers/education_provider.dart';
import 'package:thix_id/presentation/education/models/formation.dart';
import 'package:thix_id/presentation/education/models/module.dart';
import 'package:thix_id/presentation/education/models/lesson.dart';
import 'package:thix_id/presentation/education/instructor/content/module_management_page.dart';
import 'package:thix_id/presentation/education/widgets/common/education_category_chip.dart';

class CourseCreatePage extends ConsumerStatefulWidget {
  final String? courseId;
  const CourseCreatePage({super.key, this.courseId});

  @override
  ConsumerState<CourseCreatePage> createState() => _CourseCreatePageState();
}

class _CourseCreatePageState extends ConsumerState<CourseCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructorController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController(); 
  final _tagsController = TextEditingController();
  
  String _level = 'beginner';
  String? _categoryId;
  String _currency = 'USD';
  bool _isFree = false;
  bool _isCertifying = false;
  bool _isLoading = false;
  bool _isInitLoading = false;
  List<Module> _modules = [];

  Uint8List? _coverImageBytes;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    if (widget.courseId != null) {
      _loadCourse();
    } else {
      final userName = Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'] 
                    ?? Supabase.instance.client.auth.currentUser?.userMetadata?['name'];
      if (userName != null) {
        _instructorController.text = userName;
      }
    }
  }

  Future<void> _loadCourse() async {
    setState(() => _isInitLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('formations')
          .select('*, modules(*, lessons(*))')
          .eq('id', widget.courseId!)
          .single();

      if (mounted) {
        setState(() {
          _titleController.text = data['title'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _instructorController.text = data['instructor_name'] ?? '';
          _priceController.text = (data['price'] ?? 0).toString();
          _categoryId = data['category_id'];
          _level = data['level'] ?? 'beginner';
          _currency = data['currency'] ?? 'USD';
          _imageUrlController.text = data['image_url'] ?? '';
          _isFree = data['is_free'] ?? false;
          _isCertifying = data['is_certifying'] ?? false;
          
          if (data['tags'] != null && data['tags'] is List) {
            _tagsController.text = (data['tags'] as List).join(', ');
          }

          if (data['modules'] != null) {
            _modules = (data['modules'] as List).map((mJson) {
              final module = Module.fromJson(mJson);
              if (mJson['lessons'] != null) {
                module.lessons = (mJson['lessons'] as List).map((lJson) => Lesson.fromJson(lJson)).toList();
                module.lessons!.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
              }
              return module;
            }).toList();
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur de chargement pour édition : $e');
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
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

        setState(() {
          _coverImageBytes = bytes; 
          _isUploadingImage = true;
        });

        final ext = file.extension ?? 'jpg';
        final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final filePath = 'courses/covers/$fileName';

        await Supabase.instance.client.storage
            .from('course-media')
            .uploadBinary(filePath, bytes);

        final publicUrl = Supabase.instance.client.storage
            .from('course-media')
            .getPublicUrl(filePath);

        setState(() {
          _imageUrlController.text = publicUrl; 
          _isUploadingImage = false;
        });
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors du téléchargement de l\'image'), backgroundColor: ThixPolicy.danger));
      }
    }
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir les champs obligatoires.'), backgroundColor: ThixPolicy.warning));
      return;
    }

    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner une catégorie.'), backgroundColor: ThixPolicy.warning));
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté.');

      final totalDuration = _modules.fold<int>(0, (sum, m) {
        final lessons = m.lessons ?? [];
        return sum + lessons.fold<int>(0, (s, l) => s + l.durationMinutes);
      });

      final formationData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category_id': _categoryId,
        'user_id': userId, 
        'instructor_id': userId,
        'instructor_name': _instructorController.text,
        'level': _level,
        'duration': totalDuration,
        'price': _isFree ? 0.0 : (double.tryParse(_priceController.text) ?? 0.0),
        'currency': _currency,
        'image_url': _imageUrlController.text.trim(),
        'tags': _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'is_free': _isFree,
        'is_certifying': _isCertifying,
        'status': 'draft',
      };

      if (widget.courseId == null) {
        final res = await Supabase.instance.client.from('formations').insert(formationData).select('id').single();
        if (!mounted) return;
        context.pushReplacement('/instructor/courses/edit/${res['id']}');
      } else {
        await Supabase.instance.client.from('formations').update(formationData).eq('id', widget.courseId!);
        if (!mounted) return;
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: ThixPolicy.danger));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addModule() async {
    final newModule = await Navigator.push<Module>(context, MaterialPageRoute(builder: (_) => ModuleManagementPage(courseId: widget.courseId)));
    if (newModule != null) setState(() => _modules.add(newModule));
  }

  void _editModule(Module module) async {
    final updated = await Navigator.push<Module>(context, MaterialPageRoute(builder: (_) => ModuleManagementPage(module: module, courseId: widget.courseId)));
    if (updated != null) {
      final index = _modules.indexOf(module);
      if (index != -1) setState(() => _modules[index] = updated);
    }
  }

  void _deleteModule(Module module) {
    setState(() => _modules.remove(module));
  }

  InputDecoration _inputDeco(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: ThixPolicy.textSecondary),
      filled: true,
      fillColor: ThixPolicy.surfaceSoft,
      prefixIcon: icon != null ? Icon(icon, color: ThixPolicy.textSecondary, size: 20) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final isNewCourse = widget.courseId == null;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(isNewCourse ? 'Créer un cours' : 'Modifier le cours', style: const TextStyle(fontWeight: FontWeight.w800, color: ThixPolicy.textMain, fontSize: 18, letterSpacing: -0.5)),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: ThixPolicy.textMain), onPressed: () => context.pop()),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _isLoading || _isInitLoading ? null : _saveCourse,
              icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isLoading ? 'Sauvegarde...' : 'Enregistrer', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd))),
            ),
          )
        ],
      ),
      body: _isInitLoading 
        ? const Center(child: CircularProgressIndicator(color: ThixPolicy.primary))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(ThixPolicy.s20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── IMAGE DE COUVERTURE ───
              const Text('Couverture du cours', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ThixPolicy.textMain)),
              const SizedBox(height: ThixPolicy.s12),
              GestureDetector(
                onTap: _pickAndUploadImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: ThixPolicy.tint,
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                    border: Border.all(color: ThixPolicy.primary.withOpacity(0.3), width: 1.5),
                    image: _imageUrlController.text.isNotEmpty
                        ? DecorationImage(image: NetworkImage(_imageUrlController.text), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _imageUrlController.text.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isUploadingImage)
                              const CircularProgressIndicator(color: ThixPolicy.primary)
                            else ...[
                              const Icon(Icons.add_photo_alternate_rounded, size: 48, color: ThixPolicy.primaryDeep),
                              const SizedBox(height: ThixPolicy.s8),
                              const Text('Ajouter une image', style: TextStyle(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.bold)),
                            ]
                          ],
                        )
                      : Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(ThixPolicy.s8),
                            child: CircleAvatar(
                              backgroundColor: Colors.black.withOpacity(0.6),
                              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: ThixPolicy.s24),

              // ─── INFORMATIONS GÉNÉRALES ───
              Container(
                padding: const EdgeInsets.all(ThixPolicy.s20),
                decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Informations Générales', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ThixPolicy.textMain)),
                    const SizedBox(height: ThixPolicy.s16),
                    TextFormField(controller: _titleController, decoration: _inputDeco('Titre du cours *'), validator: (v) => v!.isEmpty ? 'Requis' : null),
                    const SizedBox(height: ThixPolicy.s12),
                    TextFormField(controller: _descriptionController, decoration: _inputDeco('Description globale'), maxLines: 4),
                    const SizedBox(height: ThixPolicy.s12),
                    TextFormField(controller: _instructorController, decoration: _inputDeco('Nom affiché du formateur *', icon: Icons.person_rounded), validator: (v) => v!.isEmpty ? 'Requis' : null),
                    const SizedBox(height: ThixPolicy.s12),
                    TextFormField(controller: _tagsController, decoration: _inputDeco('Mots-clés (séparés par des virgules)', icon: Icons.tag_rounded)),
                  ],
                ),
              ),

              const SizedBox(height: ThixPolicy.s24),

              // ─── CATÉGORIE (ALIGNÉ SUR LA HOME) ───
              Container(
                padding: const EdgeInsets.all(ThixPolicy.s20),
                decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Catégorie *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ThixPolicy.textMain)),
                    const SizedBox(height: ThixPolicy.s16),
                    categoriesAsync.when(
                      data: (cats) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cats.map((c) => EducationCategoryChip(
                          label: c.name,
                          isSelected: _categoryId == c.id,
                          onTap: () => setState(() => _categoryId = c.id),
                        )).toList(),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
                      error: (_, __) => const Text('Erreur de chargement des catégories', style: TextStyle(color: ThixPolicy.danger)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: ThixPolicy.s24),

              // ─── DÉTAILS & TARIFICATION ───
              Container(
                padding: const EdgeInsets.all(ThixPolicy.s20),
                decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Détails & Tarification', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ThixPolicy.textMain)),
                    const SizedBox(height: ThixPolicy.s16),
                    DropdownButtonFormField<String>(
                      value: _level, 
                      items: const [DropdownMenuItem(value: 'beginner', child: Text('Débutant')), DropdownMenuItem(value: 'intermediate', child: Text('Intermédiaire')), DropdownMenuItem(value: 'advanced', child: Text('Avancé'))], 
                      onChanged: (v) => setState(() => _level = v!), 
                      decoration: _inputDeco('Niveau de difficulté', icon: Icons.leaderboard_rounded)
                    ),
                    const SizedBox(height: ThixPolicy.s16),
                    SwitchListTile(
                      title: const Text('Cours Gratuit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Ce cours sera accessible gratuitement.', style: TextStyle(fontSize: 12)),
                      value: _isFree,
                      activeColor: ThixPolicy.success,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) {
                        setState(() {
                          _isFree = v;
                          if (v) _priceController.clear();
                        });
                      },
                    ),
                    if (!_isFree) ...[
                      const SizedBox(height: ThixPolicy.s12),
                      Row(
                        children: [
                          Expanded(flex: 3, child: TextFormField(controller: _priceController, decoration: _inputDeco('Prix', icon: Icons.sell_rounded), keyboardType: TextInputType.number)),
                          const SizedBox(width: ThixPolicy.s12),
                          Expanded(flex: 2, child: DropdownButtonFormField<String>(
                            value: _currency, 
                            items: const [DropdownMenuItem(value: 'USD', child: Text('USD \$')), DropdownMenuItem(value: 'FC', child: Text('FC'))], 
                            onChanged: (v) => setState(() => _currency = v!), 
                            decoration: _inputDeco('Devise')
                          )),
                        ],
                      ),
                    ],
                    const Divider(height: 24, color: ThixPolicy.border),
                    SwitchListTile(
                      title: const Text('Cours Certifiant', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Délivre un certificat à la fin.', style: TextStyle(fontSize: 12)),
                      value: _isCertifying,
                      activeColor: ThixPolicy.domainLearning,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setState(() => _isCertifying = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: ThixPolicy.s24),

              // ─── GESTION DES MODULES ───
              if (isNewCourse)
                 Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(ThixPolicy.s24), 
                  decoration: BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.primary.withOpacity(0.2))),
                  child: const Column(
                    children: [
                      Icon(Icons.lock_rounded, size: 40, color: ThixPolicy.primaryDeep),
                      SizedBox(height: ThixPolicy.s12),
                      Text('Sauvegardez d\'abord le cours pour pouvoir y ajouter vos modules et leçons.', textAlign: TextAlign.center, style: TextStyle(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w600)),
                    ],
                  )
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Modules du cours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)), 
                    ElevatedButton.icon(
                      onPressed: _addModule, 
                      icon: const Icon(Icons.add_rounded, size: 18), 
                      label: const Text('Ajouter'), 
                      style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.inkDeep, foregroundColor: ThixPolicy.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)))
                    )
                  ]
                ),
                const SizedBox(height: ThixPolicy.s16),
                
                if (_modules.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('Aucun module. Commencez par en ajouter un.', style: TextStyle(color: ThixPolicy.textSecondary))),
                  ),

                ..._modules.asMap().entries.map((entry) {
                  final index = entry.key;
                  final module = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: ThixPolicy.s12), 
                    decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: 8),
                      leading: CircleAvatar(backgroundColor: ThixPolicy.tint, child: Text('${index + 1}', style: const TextStyle(color: ThixPolicy.primaryDeep, fontWeight: FontWeight.bold))), 
                      title: Text(module.title, style: const TextStyle(fontWeight: FontWeight.bold, color: ThixPolicy.textMain)), 
                      subtitle: Text('${(module.lessons ?? []).length} leçon(s)', style: const TextStyle(color: ThixPolicy.textSecondary)), 
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min, 
                        children: [
                          IconButton(icon: const Icon(Icons.edit_rounded, color: ThixPolicy.textSecondary), onPressed: () => _editModule(module)), 
                          IconButton(icon: const Icon(Icons.delete_outline_rounded, color: ThixPolicy.danger), onPressed: () => _deleteModule(module))
                        ]
                      ), 
                      onTap: () => _editModule(module)
                    )
                  );
                }),
              ],
              
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
