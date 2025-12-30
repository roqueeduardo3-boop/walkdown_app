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

// ✅ CORREÇÃO DOS IMPORTS DO FIREBASE
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // ✅ IMPORT CRÍTICO
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ INICIALIZAÇÃO FIREBASE CORRIGIDA
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, // ✅ AGORA FUNCIONA
    );
    print('✅ Firebase inicializado com sucesso');
  } catch (e) {
    print('❌ Erro Firebase: $e');
  }

  // 🔓 FORÇA Firebase Auth init (solução oficial)
  try {
    await FirebaseAuth.instance.authStateChanges().first;
    print('✅ Firebase Auth inicializado');
  } catch (e) {
    print('⚠️ Auth init warning: $e');
  }

  // SQFLite FFI para Windows/Linux
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Filtro de erros de teclado / JSON
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

// Resto do código permanece IGUAL...
class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

// [Resto do código do RootPage, LoginPage, etc. permanece EXATAMENTE IGUAL ao teu original]

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
          print('🚫 User NULL - mostrando LoginPage');
          return const LoginPage();
        }

        print('✅ User autenticado: ${user.email}');
        return const LanguageSelectionPage();
      },
    );
  }
}

Future<void> _initializeDatabase() async {
  try {
    await WalkdownDatabase.instance.database;
  } catch (e) {
    print('Erro ao inicializar DB: $e');
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

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
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
      appBar: AppBar(title: const Text('Login Walkdown')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _signIn,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Entrar'),
            ),
          ],
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

// ========== PÁGINA PRINCIPAL ==========
class WalkdownHomePage extends StatefulWidget {
  const WalkdownHomePage({super.key});

  @override
  State<WalkdownHomePage> createState() => _WalkdownHomePageState();
}

class _WalkdownHomePageState extends State<WalkdownHomePage> {
  final List<WalkdownData> _walkdowns = [];
  bool _isLoading = false;
  bool _isSyncing = false;

  Future<int> _getOccurrenceCount(int? walkdownId) async {
    if (walkdownId == null) return 0;
    final occs =
        await WalkdownDatabase.instance.getOccurrencesForWalkdown(walkdownId);
    return occs.length;
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

  Future<void> _syncNewWalkdowns() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      // Sync walkdowns novos
      final count =
          await WalkdownDatabase.instance.syncNewWalkdownsToFirestore();

      // 🔥 FORÇA sync de walkdowns EXISTENTES (checklist + occurrences)
      for (final w in _walkdowns) {
        if (w.id != null && w.firestoreId != null) {
          await WalkdownDatabase.instance.forceSyncWalkdown(w.id!);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Sincronizados $count novos walkdowns + dados atualizados.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadWalkdownsFromDb();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao sincronizar: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _pullFromFirestore() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final count =
          await WalkdownDatabase.instance.pullWalkdownsFromFirestore();

      // RECARREGAR LISTA DEPOIS DO PULL
      await _loadWalkdownsFromDb();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $count walkdowns sincronizados do Firestore.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro no pull: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
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

    Future<int> _countUnsyncedData() async {
      return await WalkdownDatabase.instance
          .countUnsyncedWalkdowns(); // ✅ VERDE!
    }

    return PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) async {
          if (didPop) return;

          final unsyncedData = await _countUnsyncedData();

          if (unsyncedData > 0) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Dados não sincronizados'),
                content: Text(
                    '$unsyncedData pontos não enviados para Firestore. Sair mesmo assim?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      child: const Text('Sair')),
                ],
              ),
            );
            if (confirm != true) return;
          }

          Navigator.pop(context);
        },
        child: Scaffold(
          // ← TODO o teu Scaffold IGUAL!

          appBar: AppBar(
            centerTitle: true,
            title: Image.asset('assets/logo_turbina.png', height: 100),
            leading: PopupMenuButton<String>(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onSelected: (value) async {
                print('🔘 Menu selecionado: $value');

                if (value == 'logout') {
                  print('🚪 Iniciando logout...');

                  // ← resto do logout IGUAL (confirm logout, clear DB, signOut...)

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Tens a certeza que queres sair?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar')),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.red),
                          child: const Text('Sair'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    print('🔓 Fazendo signOut...');
                    try {
                      print('🗑️ Limpando base de dados local...');
                      await WalkdownDatabase.instance.clearAllData();
                      await FirebaseAuth.instance.signOut();
                      print('✅ SignOut concluído!');

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
              // PUSH (enviar novos para Firestore)
              IconButton(
                icon: _isSyncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                tooltip: 'Enviar novos walkdowns',
                onPressed: _isSyncing ? null : _syncNewWalkdowns,
              ),
              // PULL (baixar do Firestore)
              IconButton(
                icon: _isSyncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download),
                tooltip: 'Baixar do Firestore',
                onPressed: _isSyncing ? null : _pullFromFirestore,
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
                          Material(
                            elevation: 10,
                            shadowColor: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            child: FilledButton.icon(
                              onPressed: _openNewWalkdownForm,
                              icon: const Icon(Icons.add),
                              label: Text(loc.newWalkdownButton),
                              style: ButtonStyle(
                                padding: WidgetStateProperty.all(
                                  const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 16),
                                ),
                              ),
                            ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: w.isCompleted
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 30,
                                  )
                                : const Icon(
                                    Icons.radio_button_unchecked,
                                    color: Colors.grey,
                                    size: 30,
                                  ),
                            title: Text(
                              w.projectInfo.projectName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${w.projectInfo.towerNumber} · ${_formatDate(w.projectInfo.date)}'),
                                FutureBuilder<int>(
                                  future: _getOccurrenceCount(
                                      w.id), // ← NOVA função!
                                  builder: (context, snapshot) {
                                    final count = snapshot.data ?? 0;
                                    return Text(
                                      '${count > 0 ? '📋 $count ocorrências' : ''}'
                                      '${w.isCompleted ? ' · ${loc.walkdownCompletedLabel}' : ''}'
                                      '${w.firestoreId != null && DateTime.now().difference(w.projectInfo.date).inDays < 7 ? ' 🆕' : ''}',
                                      style: const TextStyle(
                                          color: Colors.orange, fontSize: 12),
                                    );
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              if (w.id == null) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      WalkdownChecklistPage(walkdown: w),
                                ),
                              );
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // PDF
                                IconButton(
                                  icon: const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.red,
                                  ),
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
                                      final pdfFile = await PdfGenerator
                                          .generateWalkdownPdf(
                                        walkdown: w,
                                        occurrences: occurrences,
                                      );

                                      if (!mounted) return;
                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            loc.pdfGenerated(pdfFile.path),
                                          ),
                                          action: SnackBarAction(
                                            label: loc.pdfOpenLabel,
                                            onPressed: () async {
                                              await PdfGenerator.previewPdf(
                                                walkdown: w,
                                                occurrences: occurrences,
                                              );
                                            },
                                          ),
                                          duration: const Duration(seconds: 5),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${loc.pdfErrorLabel}: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  tooltip: loc.pdfTooltip,
                                ),
                                // EXCEL
                                IconButton(
                                  icon: const Icon(
                                    Icons.table_chart,
                                    color: Colors.green,
                                  ),
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
                                      await ExcelApiService.generateExcel(w);

                                      if (!mounted) return;
                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(loc.excelSuccessLabel),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              '${loc.excelErrorLabel}: $e'),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 5),
                                        ),
                                      );
                                    }
                                  },
                                  tooltip: loc.excelTooltip,
                                ),
                                // DELETE
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    if (w.id == null) return;

                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: Text(loc.deleteWalkdownTitle),
                                          content:
                                              Text(loc.deleteWalkdownQuestion),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .pop(false),
                                              child:
                                                  Text(loc.cancelButtonLabel),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .pop(true),
                                              child:
                                                  Text(loc.deleteButtonLabel),
                                            ),
                                          ],
                                        );
                                      },
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
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        ));
  }
}

// ========== DIALOG NOVO WALKDOWN ==========
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
                decoration: InputDecoration(
                  labelText: loc.projectNameLabel,
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? loc.fieldRequiredLabel
                    : null,
              ),
              TextFormField(
                controller: _projectNumberController,
                decoration: InputDecoration(
                  labelText: loc.projectNumberLabel,
                ),
              ),
              TextFormField(
                controller: _supervisorController,
                decoration: InputDecoration(
                  labelText: loc.supervisorLabel,
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? loc.fieldRequiredLabel
                    : null,
              ),
              TextFormField(
                controller: _roadController,
                decoration: InputDecoration(
                  labelText: loc.roadLabel,
                ),
              ),
              TextFormField(
                controller: _towerController,
                decoration: InputDecoration(
                  labelText: loc.towerLabel,
                ),
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
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(10),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xFFB0BEC5)),
            ),
            child: Text(loc.cancelButtonLabel),
          ),
        ),
        Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(10),
          child: FilledButton(
            onPressed: () {
              if (_formKey.currentState?.validate() != true) return;

              final data = WalkdownData(
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
        ),
      ],
    );
  }
}
