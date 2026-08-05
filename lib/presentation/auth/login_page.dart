// lib/features/auth/presentation/pages/login_page.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/theme.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';

typedef PhoneAuthSession = dynamic;

// ---------------------------------------------------------------------------
// Design System — THIX CENTRAL (Enterprise Level)
// ---------------------------------------------------------------------------
class _AppColors {
  static const Color primary = Color(0xFF0A3D62);
  static const Color primaryLight = Color(0xFF1A5A8C);
  static const Color accent = Color(0xFFF8961E);
  static const Color accentLight = Color(0xFFF9C74F);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF10B981);
  static const Color shadowLight = Color(0x0F000000);
}

// ---------------------------------------------------------------------------
// Page de connexion principale
// ---------------------------------------------------------------------------
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _identifierC = TextEditingController();
  final _passwordC = TextEditingController();
  bool _rememberMe = true;
  PhoneAuthSession? _phoneSession;

  // ---------- Anti brute-force (soft lockout) ----------
  int _failedAttempts = 0;
  int _lockoutSecondsLeft = 0;
  Timer? _lockoutTimer;
  static const int _lockoutThreshold = 5;
  static const int _lockoutDuration = 30;

  // ---------- Réinitialisation de mot de passe ----------
  int _resetCooldown = 0;
  Timer? _resetCooldownTimer;
  static const int _resetCooldownDuration = 45;

  @override
  void initState() {
    super.initState();
    _identifierC.addListener(_onIdentifierChanged);
  }

  void _onIdentifierChanged() {
    if (_phoneSession != null) {
      setState(() => _phoneSession = null);
    }
  }

  @override
  void dispose() {
    _identifierC.removeListener(_onIdentifierChanged);
    _identifierC.dispose();
    _passwordC.dispose();
    _lockoutTimer?.cancel();
    _resetCooldownTimer?.cancel();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? Colors.red.shade700 : _AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _userFacingError(Object e) {
    if (kDebugMode) debugPrint('[Login] erreur brute: $e');
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('rate limit') || msg.contains('too many')) {
        return 'Trop de tentatives. Merci de patienter quelques instants.';
      }
      if (msg.contains('network') || msg.contains('connection')) {
        return 'Problème de connexion. Vérifiez votre réseau et réessayez.';
      }
      return 'Identifiant ou mot de passe incorrect.';
    }
    return 'Une erreur est survenue. Vérifiez vos identifiants et réessayez.';
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    setState(() => _lockoutSecondsLeft = _lockoutDuration);
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutSecondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _lockoutSecondsLeft = 0;
          _failedAttempts = 0;
        });
      } else {
        setState(() => _lockoutSecondsLeft -= 1);
      }
    });
  }

  Future<void> _signIn() async {
    if (_lockoutSecondsLeft > 0) return;

    final identifier = _identifierC.text.trim();
    final password = _passwordC.text;
    if (identifier.isEmpty || password.isEmpty) {
      _snack('Veuillez saisir votre identifiant et mot de passe.', isError: true);
      return;
    }

    final authNotifier = ref.read(authControllerProvider.notifier);

    try {
      if (_looksLikePhone(identifier) && !identifier.contains('@')) {
        if (kIsWeb) {
          _snack('Connexion par SMS non disponible dans la Preview web.', isError: true);
          return;
        }
        if (_phoneSession == null) {
          final session = await authNotifier.startPhoneAuth(phoneNumber: identifier);
          if (!mounted) return;
          setState(() => _phoneSession = session);
          _snack('SMS envoyé. Entrez le code reçu ci-dessous puis validez.');
          return;
        }
        await authNotifier.confirmPhoneCode(session: _phoneSession!, smsCode: password);
      } else {
        await authNotifier.signIn(
          identifier: identifier,
          password: password,
          rememberMe: _rememberMe,
        );
      }

      if (!mounted) return;
      
      final user = ref.read(authControllerProvider).value;
      if (user != null) {
        _failedAttempts = 0;
        final target = user.accountType == AccountType.enterprise
            ? AppRoutes.enterpriseDashboard
            : AppRoutes.userDashboard;
        context.go(target);
      }
      
    } catch (e) {
      debugPrint('Login failed: $e');
      if (!mounted) return;
      _failedAttempts += 1;
      if (_failedAttempts >= _lockoutThreshold) {
        _startLockoutTimer();
        _snack('Trop de tentatives échouées. Réessayez dans ${_lockoutDuration}s.', isError: true);
      } else {
        _snack(_userFacingError(e), isError: true);
      }
    }
  }

  bool _looksLikePhone(String s) => RegExp(r'^\+?[0-9][0-9\s\-]{7,}$').hasMatch(s.trim());
  bool _looksLikeEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());

  // ---------- Réinitialisation de mot de passe ----------
  
  void _startResetCooldown() {
    _resetCooldownTimer?.cancel();
    setState(() => _resetCooldown = _resetCooldownDuration);
    _resetCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_resetCooldown <= 1) { timer.cancel(); setState(() => _resetCooldown = 0); } 
      else { setState(() => _resetCooldown -= 1); }
    });
  }

  Future<bool> _sendPasswordReset(String email) async {
    try { await Supabase.instance.client.auth.resetPasswordForEmail(email); } catch (e) { /* Ignore */ }
    _startResetCooldown();
    return true;
  }

  void _openForgotPasswordDialog() {
    final prefill = _looksLikeEmail(_identifierC.text) ? _identifierC.text.trim() : '';
    final emailC = TextEditingController(text: prefill);
    final otpC = TextEditingController();
    final newPasswordC = TextEditingController();
    
    bool isSending = false;
    bool isOtpSent = false;
    bool isObscured = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSend = !isSending && _resetCooldown == 0;
            
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: _AppColors.surface, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- EN-TÊTE ---
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: _AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(
                            isOtpSent ? Icons.vpn_key_rounded : Icons.lock_reset_rounded, 
                            color: _AppColors.primary
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            isOtpSent ? 'Nouveau mot de passe' : 'Mot de passe oublié', 
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 18, color: _AppColors.textDark)
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // --- TEXTE DESCRIPTIF ---
                    Text(
                      isOtpSent 
                          ? 'Un code à 6 chiffres a été envoyé à ${emailC.text}. Saisissez-le ci-dessous avec votre nouveau mot de passe.'
                          : 'Entrez l\'email associé à votre compte. Si un compte existe, un code de réinitialisation vous sera envoyé.', 
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _AppColors.textMuted, fontSize: 13, height: 1.4)
                    ),
                    const SizedBox(height: 24),
                    
                    // --- ÉTAPE 1 : SAISIE DE L'EMAIL ---
                    if (!isOtpSent) ...[
                      TextFormField(
                        controller: emailC, keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 14, color: _AppColors.textDark, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'votre@email.com',
                          hintStyle: const TextStyle(color: _AppColors.textMuted),
                          filled: true, fillColor: _AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.primary, width: 1.5)),
                        ),
                      ),
                    ] 
                    
                    // --- ÉTAPE 2 : SAISIE OTP + NOUVEAU MOT DE PASSE ---
                    else ...[
                      TextFormField(
                        controller: otpC, keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14, color: _AppColors.textDark, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'Code de vérification (OTP)',
                          hintText: '000000',
                          filled: true, fillColor: _AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.primary, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordC, obscureText: isObscured,
                        style: const TextStyle(fontSize: 14, color: _AppColors.textDark, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'Nouveau mot de passe',
                          hintText: 'Min. 8 caractères',
                          filled: true, fillColor: _AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.primary, width: 1.5)),
                          suffixIcon: IconButton(
                            splashRadius: 20,
                            icon: Icon(isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: _AppColors.textMuted, size: 20),
                            onPressed: () => setDialogState(() => isObscured = !isObscured),
                          )
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),
                    
                    // --- BOUTONS D'ACTION ---
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isSending ? null : () => Navigator.of(dialogContext).pop(), 
                            child: const Text('Annuler', style: TextStyle(color: _AppColors.textMuted, fontWeight: FontWeight.w600))
                          )
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSending ? null : () async {
                              if (!isOtpSent) {
                                if (!canSend) return;
                                final email = emailC.text.trim();
                                if (!_looksLikeEmail(email)) { _snack('Email invalide.', isError: true); return; }
                                
                                setDialogState(() => isSending = true);
                                await _sendPasswordReset(email);
                                
                                if (dialogContext.mounted) {
                                  setDialogState(() {
                                    isSending = false;
                                    isOtpSent = true;
                                  });
                                }
                              } else {
                                final otp = otpC.text.trim();
                                final newPass = newPasswordC.text;
                                
                                if (otp.isEmpty) { _snack('Saisissez le code OTP reçu.', isError: true); return; }
                                if (newPass.length < 8) { _snack('Le mot de passe est trop court.', isError: true); return; }
                                
                                setDialogState(() => isSending = true);
                                
                                try {
                                  final res = await Supabase.instance.client.auth.verifyOTP(
                                    email: emailC.text.trim(),
                                    token: otp,
                                    type: OtpType.recovery,
                                  );
                                  
                                  if (res.user != null) {
                                    await Supabase.instance.client.auth.updateUser(
                                      UserAttributes(password: newPass),
                                    );
                                    
                                    if (dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();
                                      _snack('Mot de passe mis à jour ! Vous allez être connecté.');
                                    }
                                  }
                                } catch (e) {
                                  _snack('Code invalide ou expiré.', isError: true);
                                  setDialogState(() => isSending = false);
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _AppColors.primary, 
                              foregroundColor: Colors.white, 
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                            child: Text(
                              isSending 
                                  ? 'Patientez...' 
                                  : (isOtpSent 
                                      ? 'Confirmer' 
                                      : (!canSend && _resetCooldown > 0 ? 'Attendre ${_resetCooldown}s' : 'Envoyer')),
                              style: const TextStyle(fontWeight: FontWeight.w600)
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inPhoneCodeMode = _phoneSession != null;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: _AppColors.background,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // Header Gradient Design épuré (Intégration du logo complet sans texte redondant)
            Positioned(
              top: 0, left: 0, right: 0, height: 260,
              child: Container(
                padding: const EdgeInsets.only(top: 60),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_AppColors.primary, _AppColors.primaryLight]),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/thix_id_logo.png', // Assurez-vous du chemin correct de votre logo
                      height: 55,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          'THIX CENTRAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 1.0,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            // Scrollable Form Content
            Positioned.fill(
              top: 200,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Main Login Card
                    Container(
                      decoration: BoxDecoration(
                        color: _AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8))],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Connexion', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 20, color: _AppColors.textDark)),
                          const SizedBox(height: 6),
                          Text('Accédez à votre espace sécurisé', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _AppColors.textMuted, fontSize: 13)),
                          const SizedBox(height: 28),
                          
                          _SecureInput(
                            key: const ValueKey('identifier'), label: 'Identifiant THIX ID ou Email', hint: 'Ex: TX-882-091 ou email', icon: Icons.badge_outlined, isPassword: false, type: TextInputType.text, controller: _identifierC, textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          _SecureInput(
                            key: ValueKey(inPhoneCodeMode ? 'sms_code' : 'password'), label: inPhoneCodeMode ? 'Code SMS reçu' : 'Mot de passe', hint: inPhoneCodeMode ? '123456' : '••••••••••••', icon: inPhoneCodeMode ? Icons.sms_outlined : Icons.lock_outline_rounded, isPassword: !inPhoneCodeMode, type: inPhoneCodeMode ? TextInputType.number : TextInputType.text, controller: _passwordC, textInputAction: TextInputAction.done,
                          ),
                          
                          if (inPhoneCodeMode)
                            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() { _phoneSession = null; _passwordC.clear(); }), child: const Text('Changer de numéro', style: TextStyle(color: _AppColors.primary, fontWeight: FontWeight.w600)))),
                          
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: isLoading ? null : () => setState(() => _rememberMe = !_rememberMe),
                                child: Row(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200), width: 18, height: 18,
                                      decoration: BoxDecoration(color: _rememberMe ? _AppColors.primary : _AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: _rememberMe ? _AppColors.primary : _AppColors.border, width: 1.5)),
                                      alignment: Alignment.center,
                                      child: Icon(Icons.check_rounded, size: 14, color: _rememberMe ? Colors.white : Colors.transparent),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Rester connecté', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _openForgotPasswordDialog,
                                child: Text('Oublié ?', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: _AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Primary Action Button
                          ElevatedButton(
                            onPressed: (isLoading || _lockoutSecondsLeft > 0) ? null : _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 4,
                              shadowColor: _AppColors.primary.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isLoading) ...const [
                                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                                  SizedBox(width: 12),
                                ],
                                Text(
                                  _lockoutSecondsLeft > 0 ? 'RÉESSAYER DANS ${_lockoutSecondsLeft}S' : (isLoading ? 'VÉRIFICATION…' : 'SE CONNECTER'),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5),
                                ),
                                if (_lockoutSecondsLeft == 0 && !isLoading) ...const [
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Biometrics Divider
                          Row(
                            children: [
                              const Expanded(child: Divider(color: _AppColors.border)),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('BIOMÉTRIE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: _AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1.0))),
                              const Expanded(child: Divider(color: _AppColors.border)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Social/Biometrics Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              _SocialAuth(icon: Icons.face_rounded, label: 'Face ID'),
                              SizedBox(width: 16),
                              _SocialAuth(icon: Icons.fingerprint_rounded, label: 'Touch ID'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Security Badge
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _AppColors.success.withValues(alpha: 0.3)), boxShadow: [BoxShadow(color: _AppColors.success.withValues(alpha: 0.05), blurRadius: 10)]),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.verified_user_rounded, color: _AppColors.success, size: 20)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Standard de Sécurité Étatique', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: _AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('Chiffrement local de bout en bout', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _AppColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Registration Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Nouvel utilisateur ?', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _AppColors.textMuted, fontSize: 14)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.personalReg),
                          child: Text('Créer un compte', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _AppColors.primary, fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Language Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: _AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: _AppColors.border)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          _LangChip(label: 'FR', active: true),
                          _LangChip(label: 'EN'),
                          _LangChip(label: 'SW'),
                          _LangChip(label: 'LN'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Composants internes UI
// ---------------------------------------------------------------------------
class _SecureInput extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextInputType type;
  final TextEditingController controller;
  final TextInputAction textInputAction;
  
  const _SecureInput({super.key, required this.label, required this.hint, required this.icon, required this.isPassword, required this.type, required this.controller, required this.textInputAction});
  
  @override
  State<_SecureInput> createState() => _SecureInputState();
}

class _SecureInputState extends State<_SecureInput> {
  late bool _obscured = widget.isPassword;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _AppColors.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller, 
          obscureText: _obscured, 
          keyboardType: widget.type, 
          textInputAction: widget.textInputAction, 
          style: const TextStyle(fontSize: 14, color: _AppColors.textDark, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: widget.hint, 
            hintStyle: const TextStyle(color: _AppColors.textMuted, fontWeight: FontWeight.w400),
            prefixIcon: Icon(widget.icon, size: 20, color: _AppColors.textMuted),
            suffixIcon: widget.isPassword 
                ? IconButton(splashRadius: 20, icon: Icon(_obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: _AppColors.textMuted), onPressed: () => setState(() => _obscured = !_obscured)) 
                : null,
            filled: true,
            fillColor: _AppColors.background,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

class _SocialAuth extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SocialAuth({required this.icon, required this.label});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76, height: 60, 
      decoration: BoxDecoration(color: _AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: _AppColors.border)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(icon, color: _AppColors.textDark, size: 22), 
          const SizedBox(height: 4), 
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: _AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600))
        ]
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool active;
  const _LangChip({required this.label, this.active = false});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: active ? _AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: active ? Colors.white : _AppColors.textMuted, fontWeight: active ? FontWeight.w700 : FontWeight.w600, fontSize: 11)),
    );
  }
}
