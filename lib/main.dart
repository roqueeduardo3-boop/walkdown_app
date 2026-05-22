import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'checklist_template_page.dart';
import 'sqflite_stub.dart' if (dart.library.ffi) 'sqflite_desktop.dart';
import 'WalkdownChecklistPage.dart';
import 'models.dart';
import 'database.dart';
import 'pdf_generator.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:walkdown_app/l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/cache_cleanup_service.dart';
import 'services/excel_syncfusion_service.dart';
import 'config.dart';
import 'services/checklist_pdf_service.dart';
import 'firebase_options.dart';

class SyncController extends ChangeNotifier {
  bool _isSyncing = false;
  double _progress = 0.0;
  String _status = 'Pronto';

  bool get isSyncing => _isSyncing;
  double get progress => _progress;
  String get status => _status;

  final WalkdownDatabase _db = WalkdownDatabase.instance;

  Future<void> syncUpBackground(VoidCallback onComplete) async {
    if (_isSyncing) return;

    _isSyncing = true;
    _progress = 0.0;
    _status = 'Sincronizando...';
    notifyListeners();

    try {
      final count = await _db.syncNewWalkdownsToFirestore();
      _progress = 1.0;
      _status = '✅ $count walkdowns enviados';
      await Future.delayed(const Duration(seconds: 1));
      onComplete();
    } catch (e) {
      _status = '❌ Erro: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> pullDownBackground(VoidCallback onComplete) async {
    if (_isSyncing) return;

    _isSyncing = true;
    _progress = 0.0;
    _status = 'Baixando do Firestore...';
    notifyListeners();

    try {
      final count = await _db.pullWalkdownsFromFirestore();
      _progress = 1.0;
      _status = '✅ $count walkdowns baixados';
      await Future.delayed(const Duration(seconds: 1));
      onComplete();
    } catch (e) {
      _status = '❌ Erro: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  try {
    await FirebaseAuth.instance.authStateChanges().first;
  } catch (e) {
    debugPrint('Auth init warning: $e');
  }

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await CacheCleanupService.fullCleanup();

  FlutterError.onError = (details) {
    final msg = details.exception.toString();
    if (msg.contains('KeyUpEvent') ||
        msg.contains('KeyDownEvent') ||
        msg.contains('parse JSON message')) {
      return;
    }
    FlutterError.dumpErrorToConsole(details);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const _buttonRadius = BorderRadius.all(Radius.circular(16));

  ButtonStyle _glassGradientButtonStyle({
    required Color foregroundColor,
    required Color borderColor,
  }) {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.all(foregroundColor),
      backgroundColor: WidgetStateProperty.all(Colors.transparent),
      shadowColor: WidgetStateProperty.all(const Color(0x40191D24)),
      elevation: WidgetStateProperty.all(0),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: _buttonRadius,
          side: BorderSide(color: borderColor, width: 1.1),
        ),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      backgroundBuilder: (context, states, child) {
        final isDisabled = states.contains(WidgetState.disabled);
        final isPressed = states.contains(WidgetState.pressed);
        final opacity = isDisabled ? 0.48 : (isPressed ? 0.9 : 1.0);

        final metallicTop =
            isPressed ? const Color(0xFFD4D7DD) : const Color(0xFFF7F8FA);
        final metallicMid =
            isPressed ? const Color(0xFFB8BDC6) : const Color(0xFFD9DCE2);
        final metallicBase =
            isPressed ? const Color(0xFF8E949F) : const Color(0xFFAAB0BA);
        final metallicBottom =
            isPressed ? const Color(0xFFC6CAD2) : const Color(0xFFE7E9ED);

        return Ink(
          decoration: BoxDecoration(
            borderRadius: _buttonRadius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                metallicTop.withOpacity(opacity),
                metallicMid.withOpacity(opacity),
                metallicBase.withOpacity(opacity),
                metallicBottom.withOpacity(opacity),
              ],
              stops: const [0.0, 0.38, 0.62, 1.0],
            ),
            border: Border.all(
              color: borderColor.withOpacity(isPressed ? 0.7 : 0.95),
              width: 1.15,
            ),
            boxShadow: isDisabled
                ? const []
                : [
                    BoxShadow(
                      color: const Color(0x3312171D),
                      offset: const Offset(0, 1.5),
                      blurRadius: 3,
                    ),
                    const BoxShadow(
                      color: Color(0x66FFFFFF),
                      offset: Offset(0, -1),
                      blurRadius: 1,
                    ),
                  ],
          ),
          child: child,
        );
      },
    );
  }

  Future<void> _initializeDatabase() async {
    try {
      await WalkdownDatabase.instance.database;
    } catch (e) {
      debugPrint('Database init error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    _initializeDatabase();

    const glassWhite = Color(0xCCFFFFFF);
    const glassPanel = Color(0x80FFFFFF);
    const glassStroke = Color(0x8ADAD8D4);
    const ink = Color(0xFF2E3338);
    const accent = Color(0xFF727980);

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final locale =
            lang == AppLanguage.en ? const Locale('en') : const Locale('pt');

        return MaterialApp(
          title: 'Wind Turbine Walkdown App',
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return _GlassBackdrop(
              child: child ?? const SizedBox.shrink(),
            );
          },
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('pt'),
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: accent).copyWith(
              surface: glassWhite,
              primary: accent,
              onSurface: ink,
              onPrimary: Colors.white,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.transparent,
            appBarTheme: const AppBarTheme(
              backgroundColor: glassPanel,
              foregroundColor: ink,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              titleTextStyle: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.w500,
                color: ink,
              ),
            ),
            cardTheme: CardThemeData(
              color: glassPanel,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: glassStroke, width: 1.1),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: glassWhite,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: glassStroke),
              ),
            ),
            listTileTheme: const ListTileThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            dividerTheme: DividerThemeData(
              color: ink.withOpacity(0.18),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: glassWhite,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: glassStroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: glassStroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: accent, width: 1.6),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: _glassGradientButtonStyle(
                foregroundColor: const Color(0xFF1E252E),
                borderColor: const Color(0xB3F5F2EB),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: _glassGradientButtonStyle(
                foregroundColor: const Color(0xFF2E3338),
                borderColor: const Color(0x99FFFFFF),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: _glassGradientButtonStyle(
                foregroundColor: const Color(0xFF1E252E),
                borderColor: const Color(0xB3F5F2EB),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: _glassGradientButtonStyle(
                foregroundColor: const Color(0xFF1E252E),
                borderColor: const Color(0x99FFFFFF),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xE6192430),
              contentTextStyle: const TextStyle(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          home: const RootPage(),
        );
      },
    );
  }
}

class _GlassBackdrop extends StatelessWidget {
  final Widget child;

  const _GlassBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEAF8FF),
                Color(0xFFDFF4EF),
                Color(0xFFF2ECFF),
              ],
            ),
          ),
        ),
        const Positioned(
          left: -40,
          top: -30,
          child: _GlassGlow(
            size: 210,
            color: Color(0x66FFFFFF),
          ),
        ),
        const Positioned(
          right: -70,
          top: 110,
          child: _GlassGlow(
            size: 260,
            color: Color(0x4D9BE7FF),
          ),
        ),
        const Positioned(
          left: 40,
          bottom: -85,
          child: _GlassGlow(
            size: 230,
            color: Color(0x59B5FFD9),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlassGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _GlassGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.transparent,
              color.withOpacity(0.08),
              color,
            ],
            stops: const [0.58, 0.84, 1],
          ),
          border: Border.all(
            color: color.withOpacity(0.75),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        return const LanguageSelectionPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final user = credential.user;

      if (kUseDevFirebase) {
        if (!isEmailAllowedInDev(user?.email)) {
          await FirebaseAuth.instance.signOut();

          if (!mounted) return;
          setState(() {
            _error = '🚫 Acesso DEV bloqueado!\n\n'
                'Apenas estes emails podem entrar:\n'
                '${allowedDevEmails.join('\n')}';
          });
          return;
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'user-not-found') {
          _error = '❌ Utilizador não encontrado';
        } else if (e.code == 'wrong-password') {
          _error = '❌ Password incorreta';
        } else if (e.code == 'invalid-email') {
          _error = '❌ Email inválido';
        } else {
          _error = '❌ Erro: ${e.message}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '❌ Erro: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(kUseDevFirebase ? '🧪 Walkdown DEV' : 'Walkdown App'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/1logo_2ws.png',
                  height: 100,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.wind_power, size: 80),
                ),
                const SizedBox(height: 32),
                Text(
                  'Login',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (kUseDevFirebase)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, size: 16, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          'Modo DEV',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_error != null) const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signIn,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Entrar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                if (kUseDevFirebase) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info, size: 16, color: Colors.blue),
                            SizedBox(width: 4),
                            Text(
                              'Emails autorizados no DEV:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...allowedDevEmails.map((email) => Padding(
                              padding: const EdgeInsets.only(left: 20, top: 2),
                              child: Text(
                                '• $email',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LanguageSelectionPage extends StatelessWidget {
  const LanguageSelectionPage({super.key});

  void _setLanguageAndGo(BuildContext context, AppLanguage lang) {
    appLanguage.value = lang;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WalkdownHomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/1logo_2ws.png', height: 120),
            const SizedBox(height: 32),
            Text(
              loc.languageChooseTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: () => _setLanguageAndGo(context, AppLanguage.pt),
                  child: const Text('Português'),
                ),
                const SizedBox(width: 16),
                FilledButton.tonal(
                  onPressed: () => _setLanguageAndGo(context, AppLanguage.en),
                  child: const Text('English'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WalkdownHomePage extends StatefulWidget {
  const WalkdownHomePage({super.key});

  @override
  State<WalkdownHomePage> createState() => _WalkdownHomePageState();
}

class _WalkdownHomePageState extends State<WalkdownHomePage> {
  final List<WalkdownData> _walkdowns = [];
  final SyncController _syncController = SyncController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWalkdownsFromDb();
    });
  }

  @override
  void dispose() {
    _syncController.dispose();
    super.dispose();
  }

  Future<void> _loadWalkdownsFromDb() async {
    setState(() => _isLoading = true);

    try {
      final items = await WalkdownDatabase.instance.getAllWalkdowns();
      if (mounted) {
        setState(() {
          _walkdowns
            ..clear()
            ..addAll(items);
        });
      }
    } catch (e) {
      debugPrint('Load walkdowns error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _syncNewWalkdowns() {
    _syncController.syncUpBackground(() async {
      for (final w in _walkdowns) {
        if (w.id != null && w.firestoreId != null) {
          await WalkdownDatabase.instance.forceSyncWalkdown(w.id!);
        }
      }

      await _loadWalkdownsFromDb();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_syncController.status),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _pullFromFirestore() {
    _syncController.pullDownBackground(() async {
      await _loadWalkdownsFromDb();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_syncController.status),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  Future<void> _openNewWalkdownForm() async {
    final result = await showDialog<WalkdownData>(
      context: context,
      builder: (context) => const _NewWalkdownDialog(),
    );

    if (result == null) return;

    setState(() => _isLoading = true);

    try {
      await WalkdownDatabase.instance.insertWalkdown(result);
      await _loadWalkdownsFromDb();
    } catch (e) {
      debugPrint('Create walkdown error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset('assets/logo_turbina.png', height: 100),
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.menu),
          onSelected: (value) async {
            if (value == 'manage_checklist') {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ChecklistTemplatePage(),
                ),
              );
              return;
            }

            if (value == 'logout') {
              final unsyncedCount =
                  await WalkdownDatabase.instance.countUnsyncedWalkdowns();

              if (unsyncedCount > 0) {
                final confirmUnsynced = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(loc.unsyncedDataTitle),
                    content: Text(loc.unsyncedDataMessage(unsyncedCount)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(loc.cancelButtonLabel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(loc.exitWithoutSyncLabel),
                      ),
                    ],
                  ),
                );

                if (confirmUnsynced != true) return;
              }

              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(loc.logoutLabel),
                  content: Text(loc.logoutConfirmMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(loc.cancelButtonLabel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(loc.exitLabel),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await WalkdownDatabase.instance.clearAllData();
                  await FirebaseAuth.instance.signOut();

                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const RootPage()),
                    (route) => false,
                  );
                } catch (e) {
                  debugPrint('Sign out error: $e');
                }
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'manage_checklist',
              child: Row(
                children: [
                  const Icon(Icons.edit_note),
                  const SizedBox(width: 8),
                  Text(loc.editWalkdownChecklistLabel),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(Icons.logout, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(loc.logoutLabel),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: _syncController,
            builder: (context, _) {
              return IconButton(
                icon: _syncController.isSyncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                tooltip: loc.syncUploadTooltip,
                onPressed: _syncController.isSyncing ? null : _syncNewWalkdowns,
              );
            },
          ),
          ListenableBuilder(
            listenable: _syncController,
            builder: (context, _) {
              return IconButton(
                icon: _syncController.isSyncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download),
                tooltip: loc.syncDownloadTooltip,
                onPressed:
                    _syncController.isSyncing ? null : _pullFromFirestore,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_walkdowns.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.walkdownWelcomeTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _openNewWalkdownForm,
                        icon: const Icon(Icons.add),
                        label: Text(loc.newWalkdownButton),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _walkdowns.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final w = _walkdowns[index];

                    return Card(
                      color: Colors.white,
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: w.isCompleted
                            ? const Icon(Icons.check_circle,
                                color: Colors.green, size: 30)
                            : const Icon(Icons.radio_button_unchecked,
                                color: Colors.grey, size: 30),
                        title: Text(
                          w.projectInfo.projectName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        subtitle: Text(
                          '${w.projectInfo.towerNumber} · ${_formatDate(w.projectInfo.date)}'
                          '${w.occurrences.isNotEmpty ? ' · 📋 ${loc.walkdownOccurrencesCount(w.occurrences.length)}' : ''}'
                          '${w.isCompleted ? ' · ${loc.walkdownCompletedLabel}' : ''}',
                        ),
                        onTap: () async {
                          if (w.id == null) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  WalkdownChecklistPage(walkdown: w),
                            ),
                          );
                          await _loadWalkdownsFromDb();
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf,
                                  color: Colors.red),
                              onPressed: () async {
                                if (w.id == null) return;

                                final occurrences = await WalkdownDatabase
                                    .instance
                                    .getOccurrencesForWalkdown(w.id!);

                                if (!mounted) return;

                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                try {
                                  final pdfFile =
                                      await PdfGenerator.generateWalkdownPdf(
                                    walkdown: w,
                                    occurrences: occurrences,
                                  );

                                  if (!mounted) return;
                                  Navigator.pop(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text(loc.pdfGenerated(pdfFile.path)),
                                      action: SnackBarAction(
                                        label: loc.pdfOpenLabel,
                                        onPressed: () async {
                                          await PdfGenerator.previewPdf(
                                            walkdown: w,
                                            occurrences: occurrences,
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('${loc.pdfErrorLabel}: $e')),
                                  );
                                }
                              },
                              tooltip: loc.pdfTooltip,
                            ),
                            IconButton(
                              icon: const Icon(Icons.checklist,
                                  color: Colors.green),
                              tooltip: loc.checklistPdfTooltip,
                              onPressed: () async {
                                if (w.id == null) return;

                                final occurrences = await WalkdownDatabase
                                    .instance
                                    .getOccurrencesForWalkdown(w.id!);

                                if (!mounted) return;

                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => const Center(
                                      child: CircularProgressIndicator()),
                                );

                                try {
                                  await ChecklistPdfService.previewChecklistPdf(
                                    walkdown: w,
                                    occurrences: occurrences,
                                  );

                                  if (!mounted) return;
                                  Navigator.pop(context);
                                } catch (e) {
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        loc.checklistPdfOpenError('$e'),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            if (Platform.isWindows ||
                                Platform.isLinux ||
                                Platform.isMacOS)
                              IconButton(
                                icon: const Icon(Icons.table_chart,
                                    color: Colors.green),
                                onPressed: () async {
                                  if (w.id == null) return;

                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );

                                  try {
                                    final filePath =
                                        await ExcelSyncfusionService
                                            .generateExcelWithEmbeddedImages(w);

                                    if (!mounted) return;
                                    Navigator.pop(context);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          loc.excelGenerated(filePath),
                                        ),
                                        backgroundColor: Colors.green,
                                        action: SnackBarAction(
                                          label: loc.pdfOpenLabel,
                                          onPressed: () async {
                                            try {
                                              await Process.run(
                                                  'explorer', [filePath]);
                                            } catch (e) {
                                              debugPrint(
                                                  'Open Excel error: $e');
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    Navigator.pop(context);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          loc.genericErrorLabel('$e'),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                tooltip: loc.excelTooltip,
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                if (w.id == null) return;

                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(loc.deleteWalkdownTitle),
                                    content: Text(loc.deleteWalkdownQuestion),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(loc.cancelButtonLabel),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(loc.deleteButtonLabel),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm != true) return;

                                await WalkdownDatabase.instance
                                    .deleteWalkdown(w.id!);
                                await _loadWalkdownsFromDb();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )),
      floatingActionButton: _walkdowns.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: _openNewWalkdownForm,
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _NewWalkdownDialog extends StatefulWidget {
  const _NewWalkdownDialog();

  @override
  State<_NewWalkdownDialog> createState() => _NewWalkdownDialogState();
}

class _NewWalkdownDialogState extends State<_NewWalkdownDialog> {
  final _formKey = GlobalKey<FormState>();
  final _projectNameController = TextEditingController();
  final _projectNumberController = TextEditingController();
  final _supervisorController = TextEditingController();
  final _roadController = TextEditingController();
  final _towerController = TextEditingController();

  TowerType _towerType = TowerType.fourSections;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _projectNameController.dispose();
    _projectNumberController.dispose();
    _supervisorController.dispose();
    _roadController.dispose();
    _towerController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );

    if (result != null) {
      setState(() {
        _selectedDate = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(loc.newWalkdownDialogTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _projectNameController,
                decoration: InputDecoration(labelText: loc.projectNameLabel),
                validator: (value) => (value == null || value.isEmpty)
                    ? loc.fieldRequiredLabel
                    : null,
              ),
              TextFormField(
                controller: _projectNumberController,
                decoration: InputDecoration(labelText: loc.projectNumberLabel),
              ),
              TextFormField(
                controller: _supervisorController,
                decoration: InputDecoration(labelText: loc.supervisorLabel),
                validator: (value) => (value == null || value.isEmpty)
                    ? loc.fieldRequiredLabel
                    : null,
              ),
              TextFormField(
                controller: _roadController,
                decoration: InputDecoration(labelText: loc.roadLabel),
              ),
              TextFormField(
                controller: _towerController,
                decoration: InputDecoration(labelText: loc.towerLabel),
                validator: (value) => (value == null || value.isEmpty)
                    ? loc.fieldRequiredLabel
                    : null,
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.towerTypeLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  RadioListTile<TowerType>(
                    title: Text(loc.towerTypeFourSections),
                    value: TowerType.fourSections,
                    groupValue: _towerType,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _towerType = value);
                    },
                  ),
                  RadioListTile<TowerType>(
                    title: Text(loc.towerTypeFiveSections),
                    value: TowerType.fiveSections,
                    groupValue: _towerType,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _towerType = value);
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${loc.dateLabel}: '
                      '${_selectedDate.day.toString().padLeft(2, '0')}/'
                      '${_selectedDate.month.toString().padLeft(2, '0')}/'
                      '${_selectedDate.year}',
                    ),
                  ),
                  TextButton(
                    onPressed: _pickDate,
                    child: Text(loc.chooseDateButtonLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;

            final data = WalkdownData(
              ownerUid: FirebaseAuth.instance.currentUser?.uid,
              projectInfo: ProjectInfo(
                projectName: _projectNameController.text.trim(),
                projectNumber: _projectNumberController.text.trim(),
                supervisorName: _supervisorController.text.trim(),
                road: _roadController.text.trim(),
                towerNumber: _towerController.text.trim(),
                date: _selectedDate,
              ),
              occurrences: [],
              towerType: _towerType,
              turbineName: '',
            );
            Navigator.of(context).pop(data);
          },
          child: Text(loc.saveButtonLabel),
        ),
      ],
    );
  }
}
