// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as app_provider;
import 'package:go_router/go_router.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/locale_controller.dart';
import 'package:thix_id/app_router.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/theme.dart';
import 'package:thix_id/presentation/chat/call/global_call_listener.dart';

/// Clé globale pour ouvrir IncomingCallPage depuis n'importe où
final rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final AuthController _auth;
  late final LocaleController _locale;
  GoRouter? _router;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _locale = LocaleController()..init();
    _auth = AuthController.instance;
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      await _auth.init();
    } catch (_) {}

    final merged = Listenable.merge([_auth, _locale]);

    // ⚠️ Passe le navigatorKey au router
    _router = AppRouter.create(
      _auth,
      extraRefreshListenable: merged,
      navigatorKey: rootNavigatorKey, // ← à ajouter dans AppRouter.create
    );

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _router == null) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return app_provider.MultiProvider(
      providers: [
        app_provider.ChangeNotifierProvider<AuthController>.value(
          value: _auth,
        ),
        app_provider.ChangeNotifierProvider<LocaleController>.value(
          value: _locale,
        ),
        app_provider.Provider<ProfileService>(
          create: (_) => ProfileService(),
        ),
      ],
      child: MaterialApp.router(
        title: 'THIX ID CENTRAL',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        routerConfig: _router!,
        locale: _locale.locale,
        supportedLocales: LocaleController.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // GlobalCallListener enveloppe toute l'app
        builder: (context, child) {
          return GlobalCallListener(
            navigatorKey: rootNavigatorKey,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
