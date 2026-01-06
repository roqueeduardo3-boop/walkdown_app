import 'dart:io';
import 'package:flutter/material.dart';
import 'sqflite_stub.dart' if (dart.library.ffi) 'sqflite_desktop.dart';
import 'WalkdownChecklistPage.dart';
import 'models.dart';
import 'database.dart';
import 'pdf_generator.dart';
import 'services/excel_api_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:walkdown_app/l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/cache_cleanup_service.dart';
import 'services/excel_syncfusion_service.dart';
import 'config.dart';
import 'services/excel_syncfusion_service.dart';

// ========== SYNCCONTROLLER ==========
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

// ========== MAIN ==========
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: firebaseOptions,
    );
    print('✅ Firebase inicializado');
  } catch (e) {
    print('❌ Erro Firebase: $e');
  }

  try {
    await FirebaseAuth.instance.authStateChanges().first;
    print('✅ Firebase Auth inicializado');
  } catch (e) {
    print('⚠️ Auth init warning: $e');
  }

  await CacheCleanupService.fullCleanup();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  FlutterError.onError = (details) {
    if (details.exception.toString().contains('KeyUpEvent') ||
        details.exception.toString().contains('KeyDownEvent') ||
        details.exception.toString().contains('parse JSON message')) {
      return;
    }
    FlutterError.dumpErrorToConsole(details);
  };

  runApp(const MyApp());
}

// ========== APP ==========
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<void> _initializeDatabase() async {
    try {
      await WalkdownDatabase.instance.database;
    } catch (e) {
      print('Erro ao inicializar DB: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    _initializeDatabase();

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        final locale =
            lang == AppLanguage.en ? const Locale('en') : const Locale('pt');

        return MaterialApp(
          title: 'Wind Turbine Walkdown App',
          debugShowCheckedModeBanner: false,
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
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5C7CBA),
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color.fromARGB(255, 240, 233, 243),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color.fromARGB(235, 226, 222, 222),
              foregroundColor: Color(0xFF333333),
              elevation: 8,
              centerTitle: true,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black45,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5C7CBA),
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: Colors.black45,
              ).copyWith(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return const Color(0xFF4CAF50);
                  }
                  return const Color(0xFF5C7CBA);
                }),
              ),
            ),
          ),
          home: const RootPage(),
        );
      },
    );
  }
}

// ========== ROOT PAGE (DETECTA LOGIN) ==========
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
          return const LoginPage(); // ✅ COM BLOQUEIO DEV
        }

        return const LanguageSelectionPage();
      },
    );
  }
}

// ========== LOGIN PAGE (COM BLOQUEIO DEV) ==========
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
      // 1. FAZER LOGIN NO FIREBASE
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final user = credential.user;

      // 2. ✅ VERIFICAR SE É DEV E SE EMAIL É PERMITIDO
      if (kUseDevFirebase) {
        if (!isEmailAllowedInDev(user?.email)) {
          // ❌ EMAIL NÃO AUTORIZADO NO DEV
          await FirebaseAuth.instance.signOut();

          if (!mounted) return;
          setState(() {
            _error = '🚫 Acesso DEV bloqueado!\n\n'
                'Apenas estes emails podem entrar:\n'
                '${allowedDevEmails.join('\n')}';
          });
          return;
        }

        // ✅ EMAIL AUTORIZADO NO DEV
        print('✅ DEV: Email autorizado - ${user?.email}');
      }

      // 3. LOGIN ACEITE - StreamBuilder detecta automaticamente
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
        title: Text(kUseDevFirebase ? '🧪 Walkdown DEV' : '🚀 Walkdown App'),
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
                // LOGO
                Image.asset(
                  'assets/1logo_2ws.png',
                  height: 100,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.wind_power, size: 80),
                ),
                const SizedBox(height: 32),

                // TÍTULO
                Text(
                  'Login',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // INDICADOR DEV/PROD
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

                // EMAIL
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

                // PASSWORD
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

                // ERRO
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

                // BOTÃO LOGIN
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C7CBA),
                      foregroundColor: Colors.white,
                    ),
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

                // INFO DEV
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

// ========== RESTO DO CÓDIGO IGUAL (LanguageSelectionPage, WalkdownHomePage, etc) ==========
// [O restante do código do teu main.dart atual continua aqui...]

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

// ✅ TODO O RESTO DO TEU CÓDIGO (WalkdownHomePage, _NewWalkdownDialog, etc)
// CONTINUA EXATAMENTE IGUAL - NÃO MUDES NADA!

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
        print('📋 Loaded ${items.length} walkdowns');
      }
    } catch (e) {
      print('❌ Erro ao carregar walkdowns: $e');
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
      final id = await WalkdownDatabase.instance.insertWalkdown(result);
      print('✅ Walkdown criado com ID: $id');
      await _loadWalkdownsFromDb();
    } catch (e) {
      print('❌ Erro ao criar walkdown: $e');
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
            if (value == 'logout') {
              final unsyncedCount =
                  await WalkdownDatabase.instance.countUnsyncedWalkdowns();

              if (unsyncedCount > 0) {
                final confirmUnsynced = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('⚠️ Dados não sincronizados'),
                    content: Text(
                        '$unsyncedCount ponto(s) não foram enviados.\n\nQueres sair mesmo assim?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange),
                        child: const Text('Sair sem sincronizar'),
                      ),
                    ],
                  ),
                );

                if (confirmUnsynced != true) return;
              }

              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Tens a certeza que queres sair?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Sair'),
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
                  print('❌ Erro no signOut: $e');
                }
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Logout'),
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
                tooltip: 'Enviar dados',
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
                tooltip: 'Baixar dados',
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
                          '${w.occurrences.isNotEmpty ? ' · 📋 ${w.occurrences.length} ocorrências' : ''}'
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
                            // ✅ BOTÃO EXCEL - CÓDIGO LIMPO
                            if (Platform.isWindows ||
                                Platform.isLinux ||
                                Platform.isMacOS)
                              IconButton(
                                icon: const Icon(Icons.table_chart,
                                    color: Colors.green),
                                onPressed: () async {
                                  if (w.id == null) return;

                                  // Mostrar loading
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );

                                  try {
                                    // ✅ SÓ SYNCFUSION (fotos embutidas)
                                    final filePath =
                                        await ExcelSyncfusionService
                                            .generateExcelWithEmbeddedImages(w);

                                    if (!mounted) return;
                                    Navigator.pop(context); // Fecha loading

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('✅ Excel gerado: $filePath'),
                                        backgroundColor: Colors.green,
                                        action: SnackBarAction(
                                          label: 'Abrir',
                                          onPressed: () async {
                                            try {
                                              await Process.run(
                                                  'explorer', [filePath]);
                                            } catch (e) {
                                              print('Erro ao abrir: $e');
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    Navigator.pop(context); // Fecha loading

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('❌ Erro ao gerar Excel: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                tooltip: 'Gerar Excel',
                              ),
                            // DELETE BUTTON
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
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFFB0BEC5)),
          ),
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
