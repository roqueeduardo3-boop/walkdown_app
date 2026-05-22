import 'package:flutter/material.dart';
import 'models.dart';
import 'occurrences_page.dart'; // ✅ arquivo occurrences_page.dart
import 'database.dart';
import 'pdf_generator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:walkdown_app/l10n/app_localizations.dart';

class WalkdownChecklistPage extends StatefulWidget {
  final WalkdownData walkdown;

  const WalkdownChecklistPage({super.key, required this.walkdown});

  @override
  State<WalkdownChecklistPage> createState() => _WalkdownChecklistPageState();
}

class _WalkdownChecklistPageState extends State<WalkdownChecklistPage> {
  List<ChecklistSection> _sections = const [];
  final Map<String, String> _answers = {};
  bool _isOnline = true;
  bool _isChecklistLoading = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    print('🚀 initState EXECUTADO!');
    print('Walkdown ID: ${widget.walkdown.id}');
    _loadChecklist();
    _checkConnectivity();
    _listenConnectivity();
  }

  Future<void> _loadChecklist() async {
    try {
      final results = await Future.wait<dynamic>([
        WalkdownDatabase.instance
            .getChecklistSectionsForWalkdown(widget.walkdown),
        _loadAnswers(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _sections = results[0] as List<ChecklistSection>;
        _isChecklistLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _isChecklistLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar checklist: $e')),
      );
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      final online = result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile);
      if (mounted) {
        setState(() => _isOnline = online);
      }
      return online;
    } catch (e) {
      if (mounted) setState(() => _isOnline = false);
      return false;
    }
  }

  void _listenConnectivity() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) async {
      final online = result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile);
      if (mounted) {
        setState(() => _isOnline = online);
      }
    });
  }

  Future<void> _saveAnswer(String itemId, String answer) async {
    if (widget.walkdown.id == null) return;

    print(
        '💾 SAVING: walkdownId=${widget.walkdown.id}, itemId=$itemId, answer=$answer');

    setState(() {
      _answers[itemId] = answer;
    });

    await WalkdownDatabase.instance.saveChecklistAnswer(
      widget.walkdown.id!,
      itemId,
      answer,
    );

    print('✅ SAVED $answer');

    // Se responder NO, navegar para WalkdownOccurrencesPage COM LOCALIZAÇÃO
    if (answer == 'NO') {
      // Encontrar a seção e item correspondente
      String locationText = '';

      for (final section in _sections) {
        final item = section.items.firstWhere(
          (i) => i.id == itemId,
          orElse: () => section.items.first,
        );

        if (item.id == itemId) {
          final sectionTitle = appLanguage.value == AppLanguage.pt
              ? section.titlePt
              : section.titleEn ?? section.titlePt;

          final itemText = appLanguage.value == AppLanguage.pt
              ? item.textPt
              : item.textEn ?? item.textPt;

          locationText = '$sectionTitle – $itemText';
          break;
        }
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WalkdownOccurrencesPage(
            walkdown: widget.walkdown,
            initialText: locationText,
            checkItemId: itemId, // ✅ NOVO - passa o ID do item
          ),
        ),
      );
    }
  }

  double calculateProgress() {
    if (_sections.isEmpty) return 0.0;

    int totalItems = 0;
    int doneItems = 0;

    for (final section in _sections) {
      totalItems += section.items.length;
      for (final item in section.items) {
        if (_answers.containsKey(item.id)) {
          doneItems++;
        }
      }
    }

    if (totalItems == 0) return 0.0;
    return (doneItems / totalItems) * 100.0;
  }

  int get totalItems {
    int total = 0;
    for (final section in _sections) {
      total += section.items.length;
    }
    return total;
  }

  int get doneItems {
    int done = 0;
    for (final section in _sections) {
      for (final item in section.items) {
        if (_answers.containsKey(item.id)) {
          done++;
        }
      }
    }
    return done;
  }

  bool _isChecklistComplete() {
    return totalItems > 0 && doneItems == totalItems;
  }

  Future<void> _loadAnswers() async {
    if (widget.walkdown.id == null) return;

    final savedAnswers = await WalkdownDatabase.instance.getChecklistAnswers(
      widget.walkdown.id!,
    );

    print('🔍 DEBUG loadAnswers: walkdownId=${widget.walkdown.id}');
    print('🔍 DEBUG savedAnswers.length=${savedAnswers.length}');

    if (mounted) {
      setState(() {
        _answers.addAll(savedAnswers);
      });
    }

    print('🔍 DEBUG _answers.length=${_answers.length}');
  }

  ButtonStyle _answerButtonStyle() {
    const radius = BorderRadius.all(Radius.circular(7));

    return ButtonStyle(
      foregroundColor: WidgetStateProperty.all(const Color(0xFF232A33)),
      backgroundColor: WidgetStateProperty.all(Colors.transparent),
      shadowColor: WidgetStateProperty.all(const Color(0x2A11151B)),
      elevation: WidgetStateProperty.all(0),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: WidgetStateProperty.all(const Size(38, 26)),
      padding: WidgetStateProperty.all(EdgeInsets.zero),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(
            color: Color(0xCCF5F6F8),
            width: 0.95,
          ),
        ),
      ),
      backgroundBuilder: (context, states, child) {
        final isPressed = states.contains(WidgetState.pressed);
        final top =
            isPressed ? const Color(0xFFE2E6EB) : const Color(0xFFF8F9FB);
        final mid =
            isPressed ? const Color(0xFFC4CAD3) : const Color(0xFFD8DDE5);
        final base =
            isPressed ? const Color(0xFFADB4BF) : const Color(0xFFBFC6CF);

        return Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                top,
                mid,
                base,
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3311171F),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
              BoxShadow(
                color: Color(0x7AFFFFFF),
                offset: Offset(0, -1),
                blurRadius: 1,
              ),
            ],
            border: Border.all(
              color:
                  isPressed ? const Color(0xAA9EA7B3) : const Color(0xCCF5F6F8),
              width: 0.95,
            ),
          ),
          child: child,
        );
      },
    );
  }

  Widget _answerContent({
    required String label,
    required bool isSelected,
    required IconData selectedIcon,
    required Color selectedColor,
  }) {
    if (isSelected) {
      return Icon(selectedIcon, size: 13, color: selectedColor);
    }

    return Text(
      label,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: Color(0xFF2C323A),
      ),
    );
  }

  Widget _buildSectionTile(ChecklistSection section) {
    final title = appLanguage.value == AppLanguage.pt
        ? section.titlePt
        : section.titleEn ?? section.titlePt;

    final sectionTotal = section.items.length;
    final sectionDone =
        section.items.where((item) => _answers.containsKey(item.id)).length;
    final sectionProgress = sectionDone / sectionTotal;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white70),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$sectionDone/$sectionTotal',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3338),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 30,
                    height: 6,
                    child: LinearProgressIndicator(
                      value: sectionProgress,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF8E959C)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        children: section.items.map((item) {
          final text = appLanguage.value == AppLanguage.pt
              ? item.textPt
              : item.textEn ?? item.textPt;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // TEXTO À ESQUERDA
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 6),
                // 3 BOTÕES ULTRA MINI À DIREITA
                SizedBox(
                  width: 38,
                  height: 26,
                  child: ElevatedButton(
                    onPressed: () => _saveAnswer(item.id, 'YES'),
                    style: _answerButtonStyle(),
                    child: _answerContent(
                      label: 'YES',
                      isSelected: _answers[item.id] == 'YES',
                      selectedIcon: Icons.check,
                      selectedColor: const Color(0xFF2FA84F),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 38,
                  height: 26,
                  child: ElevatedButton(
                    onPressed: () async => _saveAnswer(item.id, 'NO'),
                    style: _answerButtonStyle(),
                    child: _answerContent(
                      label: 'NO',
                      isSelected: _answers[item.id] == 'NO',
                      selectedIcon: Icons.close,
                      selectedColor: const Color(0xFFD63A3A),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 38,
                  height: 26,
                  child: ElevatedButton(
                    onPressed: () => _saveAnswer(item.id, 'NA'),
                    style: _answerButtonStyle(),
                    child: _answerContent(
                      label: 'N/A',
                      isSelected: _answers[item.id] == 'NA',
                      selectedIcon: Icons.remove,
                      selectedColor: const Color(0xFF6F7580),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _generatePdf() async {
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final occurrences = await WalkdownDatabase.instance
          .getOccurrencesForWalkdown(widget.walkdown.id!);

      final pdfFile = await PdfGenerator.generateWalkdownPdf(
        walkdown: widget.walkdown,
        occurrences: occurrences,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pdfGenerated(pdfFile.path)),
          action: SnackBarAction(
            label: loc.pdfOpenLabel,
            onPressed: () async {
              await PdfGenerator.previewPdf(
                walkdown: widget.walkdown,
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
        SnackBar(content: Text('${loc.pdfErrorLabel}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final progressPercent = calculateProgress();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.checklistPageTitle),
        actions: [
          // Indicador de conectividade
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              _isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: _isOnline ? Colors.green : Colors.red,
            ),
          ),
          // Botão de ocorrências
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      WalkdownOccurrencesPage(walkdown: widget.walkdown),
                ),
              );
              _loadAnswers();
            },
            tooltip: loc.checklistOccurrencesTooltip,
          ),
          // Botão de PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePdf,
            tooltip: loc.pdfTooltip,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de progresso global
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.transparent,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loc.checklistProgressLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$doneItems/$totalItems (${progressPercent.toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2E3338),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progressPercent / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF8E959C)),
                ),
              ],
            ),
          ),
          // Lista de seções expansíveis
          Expanded(
            child: _isChecklistLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _sections.length,
                    itemBuilder: (context, index) {
                      return _buildSectionTile(_sections[index]);
                    },
                  ),
          ),
        ],
      ),
      // Botão de finalizar
      floatingActionButton: _isChecklistComplete()
          ? FloatingActionButton.extended(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(loc.checklistCompleteTitle),
                    content: Text(loc.checklistCompleteQuestion),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(loc.cancelButtonLabel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(loc.checklistCompleteConfirmLabel),
                      ),
                    ],
                  ),
                );

                if (confirm == true && widget.walkdown.id != null) {
                  await WalkdownDatabase.instance
                      .markWalkdownCompleted(widget.walkdown.id!);

                  if (!mounted) return;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.checklistMarkedCompletedMessage),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_circle),
              label: Text(loc.checklistMarkCompletedLabel),
              backgroundColor: Colors.green,
            )
          : null,
    );
  }
}
