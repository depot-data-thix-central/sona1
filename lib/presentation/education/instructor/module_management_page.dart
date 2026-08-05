// lib/presentation/education/instructor/content/module_management_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/education/models/module.dart';
import 'package:thix_id/presentation/education/models/lesson.dart';
import 'package:thix_id/presentation/education/instructor/content/lesson_management_page.dart';
import 'package:thix_id/presentation/education/instructor/evaluations/question_management_page.dart'; 

class ModuleManagementPage extends StatefulWidget {
  final Module? module;
  final String? courseId;
  const ModuleManagementPage({super.key, this.module, this.courseId});

  @override
  State<ModuleManagementPage> createState() => _ModuleManagementPageState();
}

class _ModuleManagementPageState extends State<ModuleManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  List<Lesson> _lessons = [];

  @override
  void initState() {
    super.initState();
    if (widget.module != null) {
      _titleController.text = widget.module!.title;
      _descriptionController.text = widget.module!.description ?? '';
      _lessons = List.from(widget.module!.lessons ?? []);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveModule() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final moduleToSave = Module(
        id: widget.module?.id ?? '',
        formationId: widget.courseId ?? widget.module?.formationId ?? '',
        title: _titleController.text,
        description: _descriptionController.text,
        order: widget.module?.order ?? 0,
        lessons: _lessons,
      );

      if (!mounted) return;
      Navigator.pop(context, moduleToSave);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addLesson() async {
    final newLesson = await Navigator.push<Lesson>(
      context, 
      MaterialPageRoute(
        builder: (_) => LessonManagementPage(
          moduleId: widget.module?.id ?? '',
        )
      )
    );
    
    if (newLesson != null && mounted) {
      setState(() => _lessons.add(newLesson));
    }
  }

  void _editLesson(Lesson lesson) async {
    // 1. Si la leçon est un Quiz (ou evaluation)
    if (lesson.type == 'quiz' || lesson.type == 'evaluation') {
      setState(() => _isLoading = true);
      String currentLessonId = lesson.id;

      try {
        // 🔒 CORRECTION : Si la leçon n'a pas encore d'ID en base, on l'insère d'office pour éviter l'erreur
        if (currentLessonId.isEmpty) {
          final targetModuleId = widget.module?.id;
          if (targetModuleId == null || targetModuleId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              constSnackBar(content: const Text('Veuillez d\'abord donner un titre et enregistrer/fermer le module parent.'), backgroundColor: Colors.red),
            );
            setState(() => _isLoading = false);
            return;
          }

          final newLessonRes = await Supabase.instance.client.from('lessons').insert({
            'module_id': targetModuleId,
            'title': lesson.title,
            'description': lesson.description ?? '',
            'type': lesson.type,
            'duration_minutes': lesson.durationMinutes,
            'content': lesson.content ?? '',
            'order': lesson.order,
            'created_at': DateTime.now().toIso8601String(),
          }).select('id').single();

          currentLessonId = newLessonRes['id'];
          
          // Met à jour l'ID localement dans la liste
          final index = _lessons.indexOf(lesson);
          if (index != -1) {
            setState(() {
              _lessons[index] = lesson.copyWith(id: currentLessonId);
              lesson = _lessons[index];
            });
          }
        }
        
        String? targetEvaluationId;

        // 2. Chercher si une évaluation existe déjà pour cette leçon
        final evalList = await Supabase.instance.client
            .from('evaluations')
            .select('id')
            .eq('lesson_id', currentLessonId)
            .maybeSingle();

        if (evalList != null && evalList.isNotEmpty) {
          targetEvaluationId = evalList['id'];
        } else {
          // 3. Créer une nouvelle évaluation si elle n'existe pas
          final evalRes = await Supabase.instance.client
              .from('evaluations')
              .insert({
                'lesson_id': currentLessonId,
                'title': 'Quiz - ${lesson.title}',
                'type': lesson.type,
              })
              .select('id')
              .single();
          targetEvaluationId = evalRes['id'];
        }

        if (targetEvaluationId != null && mounted) {
          // Ouvrir le gestionnaire de questions
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuestionManagementPage(evaluationId: targetEvaluationId!),
            ),
          );
        }
      } catch (e) {
        debugPrint('Erreur init quiz: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'initialiser le quiz. Vérifiez la connexion.'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // Pour les autres types (video, texte...), ouvrir l'éditeur de leçon standard
      final updatedLesson = await Navigator.push<Lesson>(
        context, 
        MaterialPageRoute(
          builder: (_) => LessonManagementPage(
            moduleId: widget.module?.id ?? '',
            lesson: lesson,
          )
        )
      );
      
      if (updatedLesson != null && mounted) {
        final index = _lessons.indexOf(lesson);
        if (index != -1) {
          setState(() => _lessons[index] = updatedLesson);
        }
      }
    }
  }

  void _deleteLesson(Lesson lesson) {
    setState(() => _lessons.remove(lesson));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.module == null ? 'Ajouter un module' : 'Modifier le module', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.save_rounded, color: Color(0xFF2D6CDF)), onPressed: _isLoading ? null : _saveModule),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D6CDF)))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Configuration', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Titre du module*',
                              labelStyle: const TextStyle(color: Color(0xFF64748B)),
                              filled: true, fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            validator: (v) => v!.isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              labelStyle: const TextStyle(color: Color(0xFF64748B)),
                              filled: true, fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Leçons', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      ElevatedButton.icon(
                        onPressed: _addLesson,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Ajouter'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D6CDF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _lessons.isEmpty
                        ? const Center(child: Text('Aucune leçon. Ajoutez-en une.', style: TextStyle(color: Color(0xFF64748B))))
                        : ListView.builder(
                            itemCount: _lessons.length,
                            itemBuilder: (context, index) {
                              final lesson = _lessons[index];
                              final isQuiz = lesson.type == 'quiz' || lesson.type == 'evaluation';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: isQuiz ? const Color(0xFFF59E0B).withOpacity(0.1) : const Color(0xFF2D6CDF).withOpacity(0.1),
                                    child: Icon(isQuiz ? Icons.quiz_rounded : Icons.play_arrow_rounded, color: isQuiz ? const Color(0xFFF59E0B) : const Color(0xFF2D6CDF)),
                                  ),
                                  title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  subtitle: Text(isQuiz ? 'Évaluation (Quiz)' : 'Leçon standard', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(icon: const Icon(Icons.edit_rounded, color: Color(0xFF64748B)), onPressed: () => _editLesson(lesson)),
                                      IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)), onPressed: () => _deleteLesson(lesson)),
                                    ],
                                  ),
                                  onTap: () => _editLesson(lesson),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
