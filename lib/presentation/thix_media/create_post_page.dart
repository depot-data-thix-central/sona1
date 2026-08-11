// lib/presentation/media/create_post_page.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Imports existants
import '../../services/media_service.dart';
import '../../models/media_content.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart'; // Design System THIX

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  // ─── GESTION DES VIDÉOS (Support des Séries) ───
  PlatformFile? _selectedCover;
  List<PlatformFile> _selectedVideos = []; // Support multi-vidéos pour les séries
  int _currentVideoIndex = 0; // Pour la prévisualisation

  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;

  // ─── OPTIONS DU CONTENU ───
  String _selectedContentType = 'Fil'; // 'Fil', 'Série', 'NOVA Originals', etc.
  bool _isPaid = false; 
  String _selectedFilter = 'Normal'; 
  final List<String> _filters = ['Normal', 'Cinématique', 'Éclat', 'Vintage', 'Cyberpunk', 'Beauté Douce'];

  bool _isUploading = false;
  double _progress = 0.0;
  String _uploadStatus = '';

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _priceController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  // --- GESTION VIDÉO & PRÉVISUALISATION ---
  Future<void> _initializeVideoPlayer(PlatformFile file) async {
    if (_videoPlayerController != null) {
      await _videoPlayerController!.dispose();
    }
    setState(() => _isVideoInitialized = false);

    if (kIsWeb) {
      if (file.bytes != null) {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(file.path ?? ''));
      }
    } else {
      if (file.path != null) {
        _videoPlayerController = VideoPlayerController.file(File(file.path!));
      }
    }

    if (_videoPlayerController != null) {
      try {
        await _videoPlayerController!.initialize();
        _videoPlayerController!.setLooping(true);
        _videoPlayerController!.play();
        setState(() => _isVideoInitialized = true);
      } catch (_) {
        setState(() => _isVideoInitialized = false);
      }
    }
  }

  Future<void> _pickVideo() async {
    // Si c'est une série, on permet plusieurs fichiers
    final allowMultiple = _selectedContentType == 'Série' || _selectedContentType == 'Formation';
    
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video, 
      allowMultiple: allowMultiple,
      withData: kIsWeb, // Obligatoire sur le web pour lire la vidéo
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        if (allowMultiple) {
          _selectedVideos.addAll(result.files);
        } else {
          _selectedVideos = [result.files.first];
        }
        _currentVideoIndex = _selectedVideos.length - 1;
      });
      await _initializeVideoPlayer(_selectedVideos.last);
    }
  }

  void _removeVideo(int index) {
    setState(() {
      _selectedVideos.removeAt(index);
      if (_selectedVideos.isEmpty) {
        _videoPlayerController?.dispose();
        _videoPlayerController = null;
        _isVideoInitialized = false;
      } else {
        _currentVideoIndex = 0;
        _initializeVideoPlayer(_selectedVideos.first);
      }
    });
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image, 
      withData: kIsWeb,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedCover = result.files.first);
    }
  }

  void _openCameraWithBeautyFilters() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Module Caméra (En développement)"),
        backgroundColor: ThixPolicy.primary,
      ),
    );
  }

  // --- PUBLICATION ET ENVOI SUR SUPABASE ---
  Future<void> _publishPost() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Veuillez ajouter un titre.');
      return;
    }
    if (_selectedVideos.isEmpty) {
      _showError('Veuillez ajouter au moins une vidéo.');
      return;
    }
    if (_selectedCover == null) {
      _showError('Veuillez ajouter une image de couverture.');
      return;
    }

    double price = 0.0;
    if (_isPaid) {
      price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      if (price <= 0) {
        _showError('Veuillez indiquer un prix valide.');
        return;
      }
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showError('Vous devez être connecté pour publier.');
      return;
    }

    setState(() { 
      _isUploading = true; 
      _progress = 0.0; 
      _uploadStatus = 'Préparation des fichiers...';
    });

    try {
      // 1. Gérer l'upload multiple si c'est une série
      final mediaService = MediaService();
      
      // On crée l'objet initial (sans les URLs qui seront ajoutées par le service)
      final newContent = MediaContent(
        id: '', // Sera généré par le backend
        userId: userId,
        title: _titleController.text.trim(),
        subtitle: _subtitleController.text.trim().isEmpty ? null : _subtitleController.text.trim(),
        videoUrl: '', // Injecté après upload
        coverUrl: '', // Injecté après upload
        episodesUrls: [], // Injecté après upload
        type: _selectedContentType, 
        isPaid: _isPaid,
        price: price,
        filterApplied: _selectedFilter,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 2. Upload personnalisé gérant 1 ou plusieurs vidéos
      setState(() => _uploadStatus = 'Envoi en cours...');
      
      await mediaService.insertComplexMedia(
        newContent,
        videos: _selectedVideos,
        coverFile: _selectedCover!,
        onProgress: (p) => setState(() => _progress = p),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publication réussie !'), backgroundColor: ThixPolicy.success),
      );

    } catch (e) {
      if (!mounted) return;
      _showError('Erreur lors de la publication : $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ThixPolicy.danger),
    );
  }

  // =======================================================================
  // INTERFACE UTILISATEUR
  // =======================================================================
  @override
  Widget build(BuildContext context) {
    final bool isSeries = _selectedContentType == 'Série' || _selectedContentType == 'Formation';

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Studio THIX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. SECTION PREVIEW & CAMERA
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: ThixPolicy.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: _isVideoInitialized && _videoPlayerController != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _videoPlayerController!.value.size.width,
                              height: _videoPlayerController!.value.size.height,
                              child: VideoPlayer(_videoPlayerController!),
                            ),
                          ),
                          Center(
                            child: IconButton(
                              icon: Icon(
                                _videoPlayerController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: Colors.white70,
                                size: 50,
                              ),
                              onPressed: () => setState(() {
                                _videoPlayerController!.value.isPlaying
                                    ? _videoPlayerController!.pause()
                                    : _videoPlayerController!.play();
                              }),
                            ),
                          ),
                          // Badge de l'épisode en cours
                          if (_selectedVideos.length > 1)
                            Positioned(
                              top: 10, left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                child: Text('Partie ${_currentVideoIndex + 1}/${_selectedVideos.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            )
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.movie_creation_outlined, color: ThixPolicy.textSecondary, size: 48),
                        const SizedBox(height: 12),
                        const Text('Aucune vidéo', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickVideo,
                              icon: const Icon(Icons.folder_open, size: 16),
                              label: const Text('Importer'),
                              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.surfaceSoft, foregroundColor: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _openCameraWithBeautyFilters,
                              icon: const Icon(Icons.camera_alt, size: 16),
                              label: const Text('Caméra'),
                              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
                            ),
                          ],
                        )
                      ],
                    ),
            ),

            // ── LISTE DES ÉPISODES (Si série) ──
            if (isSeries && _selectedVideos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedVideos.length + 1, // +1 pour le bouton Ajouter
                  itemBuilder: (context, index) {
                    if (index == _selectedVideos.length) {
                      return GestureDetector(
                        onTap: _pickVideo,
                        child: Container(
                          width: 70,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                          child: const Icon(Icons.add_rounded, color: Colors.white54),
                        ),
                      );
                    }
                    
                    final isSelected = index == _currentVideoIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _currentVideoIndex = index);
                        _initializeVideoPlayer(_selectedVideos[index]);
                      },
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: ThixPolicy.surface, 
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? ThixPolicy.primary : Colors.white12, width: isSelected ? 2 : 1),
                        ),
                        child: Stack(
                          children: [
                            Center(child: Text('Pt. ${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            Positioned(
                              top: -2, right: -2,
                              child: GestureDetector(
                                onTap: () => _removeVideo(index),
                                child: const Icon(Icons.cancel, color: ThixPolicy.danger, size: 18),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 2. CHOIX DU TYPE DE FORMAT
            DropdownButtonFormField<String>(
              value: _selectedContentType,
              dropdownColor: ThixPolicy.surfaceSoft,
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: ThixPolicy.textSecondary),
              decoration: InputDecoration(
                labelText: 'Format du contenu',
                labelStyle: const TextStyle(color: ThixPolicy.textSecondary),
                filled: true,
                fillColor: ThixPolicy.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: ['Fil', 'Série', 'NOVA Originals', 'Musique', 'Gaming', 'Formation']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedContentType = val ?? 'Fil';
                  // Si on repasse en Fil, on ne garde qu'une seule vidéo
                  if (_selectedContentType != 'Série' && _selectedContentType != 'Formation' && _selectedVideos.length > 1) {
                    _selectedVideos = [_selectedVideos.first];
                    _currentVideoIndex = 0;
                  }
                });
              },
            ),

            const SizedBox(height: 20),

            // 3. INFORMATIONS PRINCIPALES
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Titre de la publication',
                labelStyle: const TextStyle(color: ThixPolicy.textSecondary),
                filled: true,
                fillColor: ThixPolicy.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtitleController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Description / Synopsis / #Tags',
                labelStyle: const TextStyle(color: ThixPolicy.textSecondary),
                filled: true,
                fillColor: ThixPolicy.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 20),

            // 4. FILTRES ESTHÉTIQUES
            if (_selectedVideos.isNotEmpty) ...[
              const Text('Filtre esthétique (Thème)', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) => setState(() => _selectedFilter = filter),
                        selectedColor: ThixPolicy.primary,
                        backgroundColor: ThixPolicy.surface,
                        side: BorderSide.none,
                        showCheckmark: false,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : ThixPolicy.textSecondary, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 5. GRATUIT OU PAYANT (MONÉTISATION)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.monetization_on_rounded, color: ThixPolicy.gold, size: 20),
                          SizedBox(width: 8),
                          Text('Monétiser ce contenu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      Switch(
                        value: _isPaid,
                        activeColor: ThixPolicy.gold,
                        activeTrackColor: ThixPolicy.gold.withOpacity(0.3),
                        inactiveTrackColor: ThixPolicy.surfaceSoft,
                        onChanged: (val) => setState(() => _isPaid = val),
                      ),
                    ],
                  ),
                  if (_isPaid) ...[
                    const SizedBox(height: 12),
                    const Text('Un extrait de 30s sera gratuit. Ensuite, l\'utilisateur devra payer pour débloquer la vidéo.', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 12)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Prix de déblocage',
                        labelStyle: const TextStyle(color: ThixPolicy.textSecondary),
                        filled: true,
                        fillColor: ThixPolicy.surfaceSoft,
                        prefixText: '\$ ',
                        prefixStyle: const TextStyle(color: ThixPolicy.gold, fontWeight: FontWeight.bold, fontSize: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 6. COUVERTURE
            GestureDetector(
              onTap: _pickCover,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: ThixPolicy.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _selectedCover == null ? ThixPolicy.primary.withOpacity(0.3) : Colors.transparent, width: 2),
                  image: _selectedCover != null 
                    ? DecorationImage(
                        image: kIsWeb 
                          ? MemoryImage(_selectedCover!.bytes!) as ImageProvider 
                          : FileImage(File(_selectedCover!.path!)),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                      )
                    : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_selectedCover == null ? Icons.add_photo_alternate_rounded : Icons.check_circle_rounded, color: _selectedCover == null ? ThixPolicy.primary : ThixPolicy.success, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        _selectedCover == null ? 'Ajouter une image de couverture' : 'Couverture prête (Appuyer pour changer)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 7. BOUTON DE PUBLICATION
            if (_isUploading) ...[
              Text(_uploadStatus, textAlign: TextAlign.center, style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: _progress, color: ThixPolicy.primary, backgroundColor: ThixPolicy.surface, minHeight: 8),
              ),
              const SizedBox(height: 8),
              Text('${(_progress * 100).toStringAsFixed(0)}%', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ] else
              ElevatedButton(
                onPressed: _publishPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  shadowColor: ThixPolicy.primary.withOpacity(0.5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Mettre en ligne', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
