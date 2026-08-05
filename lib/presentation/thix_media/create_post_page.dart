import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/media_service.dart';
import '../../models/media_content.dart';

const Color kBg = Color(0xFF050507);
const Color kSurface = Color(0xFF121214);
const Color kSurfaceLight = Color(0xFF1E1E28);
const Color kRed = Color(0xFFFF1A1A);
const Color kTextWhite = Color(0xFFFFFFFF);
const Color kTextGrey = Color(0xFF9CA3AF);
const Color kTdiaBlue = Color(0xFF2D6CDF);

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  PlatformFile? _selectedVideo;
  PlatformFile? _selectedCover;
  
  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;

  // Options demandées
  String _selectedContentType = 'Fil'; // 'Fil', 'Série', 'Film', 'Formation', etc.
  bool _isPaid = false; // Gratuit ou Payant
  String _selectedFilter = 'Normal'; // Filtre esthétique appliqué
  final List<String> _filters = ['Normal', 'Cinématique', 'Éclat', 'Vintage', 'Cyberpunk', 'Beauté Douce'];

  bool _isUploading = false;
  double _progress = 0.0;

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _priceController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  // --- GESTION VIDÉO & PRÉVISUALISATION ---
  Future<void> _initializeVideoPlayer() async {
    if (_selectedVideo == null) return;
    
    if (_videoPlayerController != null) {
      await _videoPlayerController!.dispose();
    }

    if (kIsWeb) {
      if (_selectedVideo!.bytes != null) {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(_selectedVideo!.path ?? ''));
      }
    } else {
      if (_selectedVideo!.path != null) {
        _videoPlayerController = VideoPlayerController.file(File(_selectedVideo!.path!));
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
    final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedVideo = result.files.first);
      await _initializeVideoPlayer();
    }
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedCover = result.files.first);
    }
  }

  // Simulation ouverture caméra avec filtres beauté
  void _openCameraWithBeautyFilters() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Module Caméra & Filtres Beauté natifs (Intégrer package 'camera' ici)"),
        backgroundColor: kTdiaBlue,
      ),
    );
  }

  // --- PUBLICATION ---
  Future<void> _publishPost() async {
    if (_titleController.text.trim().isEmpty || _selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter un titre et une vidéo.'), backgroundColor: kRed),
      );
      return;
    }

    double price = 0.0;
    if (_isPaid) {
      price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      if (price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez indiquer un prix valide pour le contenu payant.'), backgroundColor: kRed),
        );
        return;
      }
    }

    setState(() { 
      _isUploading = true; 
      _progress = 0.0; 
    });

    try {
      final newContent = MediaContent(
        id: '',
        title: _titleController.text.trim(),
        subtitle: _subtitleController.text.trim().isEmpty ? null : _subtitleController.text.trim(),
        videoUrl: '',
        coverUrl: '',
        type: _selectedContentType, 
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Note: Tu peux stocker _isPaid et price dans ta table Supabase si tu as ajouté les colonnes correspondantes.
      await MediaService().insertWithFiles(
        newContent,
        videoFile: _selectedVideo,
        coverFile: _selectedCover,
        onProgress: (p) => setState(() => _progress = p),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publication réussie !'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: kRed),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Studio de Publication', style: TextStyle(color: kTextWhite, fontWeight: FontWeight.bold, fontSize: 18)),
        iconTheme: const IconThemeData(color: kTextWhite),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. SECTION PREVIEW & CAMERA
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: kSurface,
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
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.movie_creation_outlined, color: kTextGrey, size: 48),
                        const SizedBox(height: 12),
                        const Text('Aucune vidéo sélectionnée', style: TextStyle(color: kTextGrey, fontSize: 13)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickVideo,
                              icon: const Icon(Icons.folder_open, size: 16),
                              label: const Text('Importer'),
                              style: ElevatedButton.styleFrom(backgroundColor: kSurfaceLight, foregroundColor: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _openCameraWithBeautyFilters,
                              icon: const Icon(Icons.camera_alt, size: 16),
                              label: const Text('Caméra & Beauté'),
                              style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
                            ),
                          ],
                        )
                      ],
                    ),
            ),

            const SizedBox(height: 20),

            // 2. FILTRES ESTHÉTIQUES DE RETRAVAIL VIDÉO
            if (_selectedVideo != null) ...[
              const Text('Filtre esthétique appliqué', style: TextStyle(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
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
                        selectedColor: kTdiaBlue,
                        backgroundColor: kSurfaceLight,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : kTextGrey, fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 3. INFORMATIONS PRINCIPALES
            TextField(
              controller: _titleController,
              style: const TextStyle(color: kTextWhite),
              decoration: InputDecoration(
                labelText: 'Titre de la publication / Série',
                labelStyle: const TextStyle(color: kTextGrey),
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _subtitleController,
              style: const TextStyle(color: kTextWhite),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description / Synopsis',
                labelStyle: const TextStyle(color: kTextGrey),
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 20),

            // 4. CHOIX DU TYPE (Fil, Série, etc.)
            DropdownButtonFormField<String>(
              value: _selectedContentType,
              dropdownColor: kSurfaceLight,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Format de diffusion',
                labelStyle: const TextStyle(color: kTextGrey),
                filled: true,
                fillColor: kSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: ['Fil', 'Série', 'NOVA Originals', 'Musique', 'Gaming', 'Formation']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedContentType = val ?? 'Fil'),
            ),

            const SizedBox(height: 20),

            // 5. GRATUIT OU PAYANT (MONÉTISATION)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      const Text('Contenu Payant (Verrouillé)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Switch(
                        value: _isPaid,
                        activeColor: kRed,
                        onChanged: (val) => setState(() => _isPaid = val),
                      ),
                    ],
                  ),
                  if (_isPaid) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Prix en USD / Équivalent',
                        labelStyle: const TextStyle(color: kTextGrey),
                        filled: true,
                        fillColor: kSurfaceLight,
                        prefixText: '\$ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 6. COUVERTURE
            ElevatedButton.icon(
              onPressed: _pickCover,
              icon: const Icon(Icons.image_outlined),
              label: Text(_selectedCover == null ? 'Choisir une image de couverture' : 'Couverture sélectionnée avec succès'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kSurfaceLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 30),

            // 7. BOUTON DE PUBLICATION OU PROGRESSION
            if (_isUploading) ...[
              LinearProgressIndicator(value: _progress, color: kRed, backgroundColor: kSurfaceLight),
              const SizedBox(height: 12),
              Text(
                'Publication en cours... ${(_progress * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kTextGrey, fontSize: 13),
              ),
            ] else
              ElevatedButton(
                onPressed: _publishPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Publier maintenant', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
