import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';

// Top-level pour compute
Future<Uint8List> compressImageBytes(Uint8List bytes) {
  return FlutterImageCompress.compressWithList(
    bytes,
    minHeight: 1080,
    minWidth: 1080,
    quality: 85,
    rotate: 0,
  );
}

class CreateStoryDialog extends ConsumerStatefulWidget {
  const CreateStoryDialog({super.key});
  @override ConsumerState<CreateStoryDialog> createState() => _CreateStoryDialogState();
}

class _CreateStoryDialogState extends ConsumerState<CreateStoryDialog> {
  final _textController = TextEditingController();
  Uint8List? _mediaBytes;
  String? _mediaExt;
  String? _mediaType; // image | video
  bool _isUploading = false;
  int _duration = 24;

  final _thixBlue = const Color(0xFF1B3B7A);
  final _thixLightBlue = const Color(0xFFF0F4FA);
  final _thixGold = const Color(0xFFE7BE59);
  final _picker = ImagePicker();

  @override void dispose() { _textController.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result?.files.first.bytes != null) {
        final f = result!.files.first;
        if (f.size > 10 * 1024 * 1024) { _showError('Image > 10 Mo'); return; }
        setState(() { _mediaBytes = f.bytes; _mediaExt = f.extension?? 'jpg'; _mediaType = 'image'; });
      }
    } catch (e) { debugPrint('pickImage $e'); }
  }

  Future<void> _pickVideo() async {
    try {
      // Sur web on évite withData pour 50Mo
      final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: kIsWeb? false : true);
      if (result == null) return;
      final f = result.files.first;
      if (f.size > 50 * 1024 * 1024) { _showError('Vidéo > 50 Mo'); return; }
      Uint8List? bytes = f.bytes;
      if (bytes == null && f.path != null) { bytes = await FilePicker.platform.pickFiles(type: FileType.video).then((_) => null); }
      // Fallback web : on lit via bytes si dispo
      if (bytes == null && kIsWeb) { _showError('Vidéo trop lourde pour Web, utilise < 30Mo'); return; }
      setState(() { _mediaBytes = bytes?? f.bytes; _mediaExt = f.extension?? 'mp4'; _mediaType = 'video'; });
    } catch (e) { debugPrint('pickVideo $e'); _showError('Erreur vidéo'); }
  }

  Future<void> _recordShortVideo() async {
    if (kIsWeb) { _showError('Caméra non supportée sur Web'); return; }
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.camera, maxDuration: Duration(seconds: 45));
      if (video != null) {
        final bytes = await video.readAsBytes();
        if (bytes.lengthInBytes > 50 * 1024) { _showError('Vidéo > 50 Mo'); return; }
        setState(() { _mediaBytes = bytes; _mediaExt = 'mp4'; _mediaType = 'video'; });
      }
    } catch (e) { debugPrint('record $e'); _showError('Caméra indisponible'); }
  }

  Future<void> _createStory() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _mediaBytes == null) { _showError('Ajoutez texte ou média'); return; }
    setState(() => _isUploading = true);
    try {
      final service = ref.read(networkServiceProvider);
      String? mediaUrl;
      if (_mediaBytes != null) {
        Uint8List uploadBytes = _mediaBytes!;
        if (_mediaType == 'image') {
          uploadBytes = await compute(compressImageBytes, _mediaBytes!);
        }
        mediaUrl = await service.uploadImageBytes(uploadBytes, fileExtension: _mediaExt!, bucket: 'stories');
      }
      await service.createStory(mediaUrl, text: text, duration: _duration, mediaType: _mediaType?? 'text');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('createStory $e');
      _showError('Erreur publication: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red)); }

  @override Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width,
        constraints: BoxConstraints(maxWidth: 500, maxHeight: 650),
        padding: EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Créer une publication', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _thixBlue)),
            Container(decoration: BoxDecoration(color: _thixLightBlue, shape: BoxShape.circle), child: IconButton(icon: Icon(Icons.close, color: _thixBlue, size: 20), onPressed: () => Navigator.pop(context))),
          ]),
          SizedBox(height: 16),
          Expanded(child: Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: _thixLightBlue, borderRadius: BorderRadius.circular(16)), child: TextField(controller: _textController, maxLines: null, keyboardType: TextInputType.multiline, decoration: InputDecoration(border: InputBorder.none, hintText: "Quoi de neuf dans votre monde pro ?", hintStyle: TextStyle(color: _thixBlue.withOpacity(0.5))), style: TextStyle(color: _thixBlue)))),
          SizedBox(height: 12),
          if (_mediaBytes != null) Stack(children: [
            Container(height: 80, width: 80, margin: EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12), image: _mediaType == 'image'? DecorationImage(image: MemoryImage(_mediaBytes!), fit: BoxFit.cover) : null), child: _mediaType == 'video'? Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 36)) : null),
            Positioned(top: -8, right: -8, child: IconButton(icon: Icon(Icons.cancel, color: Colors.black87), onPressed: () => setState(() { _mediaBytes = null; _mediaType = null; }))),
          ]),
          Row(children: [
            _buildMediaIcon(Icons.image, Colors.green, _pickImage, "Photo"),
            SizedBox(width: 8),
            _buildMediaIcon(Icons.folder_shared, Colors.orange, _pickVideo, "Vidéo"),
            SizedBox(width: 8),
            _buildMediaIcon(Icons.videocam, Colors.red, _recordShortVideo, "Caméra"),
          ]),
          SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: _isUploading? null : _createStory, style: ElevatedButton.styleFrom(backgroundColor: _thixGold, foregroundColor: _thixBlue, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: _isUploading? CircularProgressIndicator(color: _thixBlue) : Text('PUBLIER', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)))),
        ]),
      ),
    );
  }

  Widget _buildMediaIcon(IconData icon, Color c, VoidCallback onTap, String tooltip) => Tooltip(message: tooltip, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: _thixLightBlue, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: c, size: 24))));
}
