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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
          home: const LanguageSelectionPage(),
        );
      },
    );
  }
}

Future<void> _initializeDatabase() async {
  try {
    await WalkdownDatabase.instance.database;
    // print opcional
  } catch (e) {
    // print opcional
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWalkdownsFromDb(context);
    });
  }

  Future<void> _loadWalkdownsFromDb(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;

    try {
      final items = await WalkdownDatabase.instance.getAllWalkdowns();

      print(loc.walkdownsLoaded(items.length));

      setState(() {
        _walkdowns
          ..clear()
          ..addAll(items);
      });
    } catch (e) {
      print('Erro ao carregar walkdowns: $e');
    }
  }

  Future<void> _openNewWalkdownForm() async {
    final result = await showDialog<WalkdownData>(
      context: context,
      builder: (context) => const _NewWalkdownDialog(),
    );

    if (result == null) return;

    await WalkdownDatabase.instance.insertWalkdown(result);
    await _loadWalkdownsFromDb(context);
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
        title: Image.asset('assets/1logo_2ws.png', height: 100),
      ),
      body: _walkdowns.isEmpty
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
                    shadowColor: const Color.fromARGB(255, 0, 0, 0),
                    borderRadius: BorderRadius.circular(12),
                    child: FilledButton.icon(
                      onPressed: _openNewWalkdownForm,
                      icon: const Icon(Icons.add),
                      label: Text(loc.newWalkdownButton),
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.pressed)) {
                            return const Color(0xFF4CAF50);
                          }
                          return const Color(0xFF5C7CBA);
                        }),
                        foregroundColor:
                            WidgetStateProperty.all<Color>(Colors.white),
                        padding: WidgetStateProperty.all<EdgeInsets>(
                          const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                        ),
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    subtitle: Text(
                      '${w.projectInfo.towerNumber} · ${_formatDate(w.projectInfo.date)}'
                      '${w.isCompleted ? ' · ${loc.walkdownCompletedLabel}' : ''}',
                    ),
                    onTap: () {
                      if (w.id == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WalkdownChecklistPage(walkdown: w),
                        ),
                      );
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // BOTÃO PDF
                        IconButton(
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            if (w.id == null) return;

                            final occurrences = await WalkdownDatabase.instance
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
                              ScaffoldMessenger.of(context).showSnackBar(
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
                        // BOTÃO EXCEL
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

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(loc.excelSuccessLabel),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${loc.excelErrorLabel}: $e'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          },
                          tooltip: loc.excelTooltip,
                        ),
                        // BOTÃO DELETE
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            if (w.id == null) return;

                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text(loc.deleteWalkdownTitle),
                                  content: Text(loc.deleteWalkdownQuestion),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: Text(loc.cancelButtonLabel),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: Text(loc.deleteButtonLabel),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm != true) return;

                            await WalkdownDatabase.instance
                                .deleteWalkdown(w.id!);
                            await _loadWalkdownsFromDb(context);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(10),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.pressed)) {
                  return const Color(0xFFE53935);
                }
                return const Color(0xFFB0BEC5);
              }),
              foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
              padding: WidgetStateProperty.all<EdgeInsets>(
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            child: Text(loc.cancelButtonLabel),
          ),
        ),
        Material(
          elevation: 8,
          shadowColor: Colors.black45,
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
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.pressed)) {
                  return const Color(0xFF4CAF50);
                }
                return const Color(0xFF5C7CBA);
              }),
              foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
              padding: WidgetStateProperty.all<EdgeInsets>(
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            child: Text(loc.saveButtonLabel),
          ),
        ),
      ],
    );
  }
}
