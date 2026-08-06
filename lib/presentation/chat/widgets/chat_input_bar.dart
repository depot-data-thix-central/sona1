// lib/presentation/chat/widgets/chat_input_bar.dart
import 'package:flutter/material.dart';

class _C {
  static const navy = Color(0xFF0A1F44);
  static const primary = Color(0xFF1D4ED8);
  static const gold = Color(0xFFE3B23C);
  static const orange = Color(0xFFF59E0B);
  static const border = Color(0xFFE2E8F0);
  static const muted = Color(0xFF64748B);
  static const surface = Colors.white;
}

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
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
    widget.onTyping?.call(widget.controller.text);
  }

  bool get _canSend => _hasText && !widget.isSending;

  @override
  Widget build(BuildContext context) {
    final isNote = widget.isInternalNote;
    final bg = isNote ? const Color(0xFFFFF7ED) : _C.surface;
    final topBorder =
        isNote ? const Color(0xFFFED7AA) : _C.border;
    final sendColor = isNote ? _C.orange : _C.navy;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: topBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Toolbar actions ──
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ActionChip(
                      icon: Icons.attach_file_rounded,
                      label: 'Fichier',
                      onTap: widget.onAttach,
                    ),
                    _ActionChip(
                      icon: Icons.emoji_emotions_outlined,
                      label: 'Sticker',
                      onTap: widget.onStickerTap ?? () {},
                    ),
                    _ActionChip(
                      icon: Icons.timer_outlined,
                      label: 'Éphémère',
                      isActive: widget.isEphemeral,
                      activeColor: _C.gold,
                      onTap: widget.onEphemeralToggle,
                    ),
                    _ActionChip(
                      icon: Icons.lock_outline_rounded,
                      label: 'Protégé',
                      onTap: widget.onSecureMessage,
                    ),
                    if (widget.onInternalNoteToggle != null)
                      _ActionChip(
                        icon: Icons.sticky_note_2_outlined,
                        label: 'Note',
                        isActive: isNote,
                        activeColor: _C.orange,
                        onTap: widget.onInternalNoteToggle!,
                      ),
                  ],
                ),
              ),
            ),

            // ── Banner modes ──
            if (widget.isEphemeral || isNote)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Row(
                  children: [
                    if (widget.isEphemeral)
                      _ModeBanner(
                        icon: Icons.timer_outlined,
                        label: 'Message éphémère actif',
                        color: _C.gold,
                      ),
                    if (widget.isEphemeral && isNote) const SizedBox(width: 8),
                    if (isNote)
                      _ModeBanner(
                        icon: Icons.lock_outline,
                        label: 'Note interne (agents)',
                        color: _C.orange,
                      ),
                  ],
                ),
              ),

            // ── Input row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Champ texte
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: isNote
                            ? Colors.white.withValues(alpha: 0.9)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isNote
                              ? const Color(0xFFFED7AA)
                              : _C.border,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              focusNode: widget.focusNode,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.newline,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                                height: 1.35,
                              ),
                              decoration: InputDecoration(
                                hintText: isNote
                                    ? 'Écrire une note interne…'
                                    : 'Écrire un message…',
                                hintStyle: const TextStyle(
                                  color: _C.muted,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  10,
                                  8,
                                  10,
                                ),
                              ),
                              onSubmitted: (_) {
                                if (_canSend) widget.onSend();
                              },
                            ),
                          ),
                          // Micro (si pas de texte)
                          if (!_hasText)
                            IconButton(
                              onPressed: widget.onAudio,
                              icon: const Icon(
                                Icons.mic_none_rounded,
                                color: _C.muted,
                              ),
                              tooltip: 'Message audio',
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Bouton envoi
                  Material(
                    color: _canSend ? sendColor : const Color(0xFFCBD5E1),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _canSend ? widget.onSend : null,
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Center(
                          child: widget.isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? (activeColor ?? _C.gold) : _C.muted;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: isActive
                ? BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: color),
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
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ModeBanner({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
