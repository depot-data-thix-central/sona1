// lib/presentation/chat/widgets/chat_input_bar.dart
import 'package:flutter/material.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isSending;
  final VoidCallback onAttach;
  final VoidCallback onAudio;
  final VoidCallback onSecureMessage;
  final VoidCallback onEphemeralToggle;
  final bool isEphemeral;
  final ValueChanged<String>? onTyping;
  final VoidCallback? onInternalNoteToggle;
  final VoidCallback? onStickerTap;
  final bool isInternalNote;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.isSending,
    required this.onAttach,
    required this.onAudio,
    required this.onSecureMessage,
    required this.onEphemeralToggle,
    required this.isEphemeral,
    this.onTyping,
    this.onInternalNoteToggle,
    this.onStickerTap,
    this.isInternalNote = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color gold = Color(0xFFE3B23C);

  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isInternalNote ? Colors.orange.shade50 : Colors.white;
    final hintText = widget.isInternalNote ? 'Écrire une note interne...' : 'Écrire un message...';

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: widget.isInternalNote ? const Color(0xFFFED7AA) : Colors.grey.shade200, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BANDE DES BOUTONS 100% CLIQUABLE
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  _buildActionButton(
                    icon: Icons.attach_file_rounded,
                    label: 'Fichier',
                    onTap: widget.onAttach,
                  ),
                  const SizedBox(width: 4),
                  _buildActionButton(
                    icon: Icons.emoji_emotions_outlined,
                    label: 'Sticker',
                    onTap: widget.onStickerTap ?? () {},
                  ),
                  const SizedBox(width: 4),
                  _buildActionButton(
                    icon: widget.isEphemeral ? Icons.timer_rounded : Icons.timer_outlined,
                    label: 'Éphémère',
                    onTap: widget.onEphemeralToggle,
                    isActive: widget.isEphemeral,
                    activeColor: gold,
                  ),
                  const SizedBox(width: 4),
                  _buildActionButton(
                    icon: Icons.lock_outline_rounded,
                    label: 'Protégé',
                    onTap: widget.onSecureMessage,
                  ),
                  const SizedBox(width: 4),
                  _buildActionButton(
                    icon: Icons.mic_none_rounded,
                    label: 'Audio',
                    onTap: widget.onAudio,
                  ),
                  if (widget.onInternalNoteToggle != null) ...[
                    const SizedBox(width: 4),
                    _buildActionButton(
                      icon: Icons.speaker_notes,
                      label: 'Note',
                      onTap: widget.onInternalNoteToggle!,
                      isActive: widget.isInternalNote,
                      activeColor: Colors.orange,
                    ),
                  ],
                  if (_hasText) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${widget.controller.text.length}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    ),
                  ],
                ],
              ),
            ),

            // ZONE DE SAISIE
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 40,
                        maxHeight: 120,
                      ),
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        onChanged: widget.onTyping,
                        maxLines: null,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: widget.isInternalNote ? Colors.orange.shade100 : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bouton Envoi
                  GestureDetector(
                    onTap: (widget.isSending || !_hasText) ? null : widget.onSend,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (_hasText && !widget.isSending) 
                            ? (widget.isInternalNote ? Colors.orange : navyDeep) 
                            : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: widget.isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    final color = isActive ? (activeColor ?? gold) : Colors.grey.shade600;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: isActive 
              ? BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)) 
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
