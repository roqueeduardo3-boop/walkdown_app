import 'package:flutter/material.dart';
import 'models.dart';
import 'occurrences_page.dart'; // ✅ arquivo occurrences_page.dart
import 'database.dart';
import 'pdf_generator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class WalkdownChecklistPage extends StatefulWidget {
  final WalkdownData walkdown;

  const WalkdownChecklistPage({super.key, required this.walkdown});

  @override
  State<WalkdownChecklistPage> createState() => _WalkdownChecklistPageState();
}

class _WalkdownChecklistPageState extends State<WalkdownChecklistPage> {
  late final List<ChecklistSection> _sections;
  final Map<String, String> _answers = {};
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    print('🚀 initState EXECUTADO!');
    print('Walkdown ID: ${widget.walkdown.id}');
    _sections = buildChecklistForWalkdown(widget.walkdown);
    _loadAnswers();
    _checkConnectivity();
    _listenConnectivity();
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
    return _answers.length == totalItems;
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

  Color _yesColor(String itemId) => _answers[itemId] == 'YES'
      ? const Color.fromARGB(255, 166, 255, 158)
      : Colors.grey.shade300;

  Color _noColor(String itemId) => _answers[itemId] == 'NO'
      ? const Color.fromARGB(255, 253, 3, 3)
      : Colors.grey.shade300;

  Color _naColor(String itemId) => _answers[itemId] == 'NA'
      ? const Color.fromARGB(255, 155, 154, 154)
      : Colors.grey.shade300;

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
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$sectionDone/$sectionTotal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 30,
                    height: 6,
                    child: LinearProgressIndicator(
                      value: sectionProgress,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade600,
                      ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _yesColor(item.id),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(38, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('YES',
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 38,
                  height: 26,
                  child: ElevatedButton(
                    onPressed: () async => _saveAnswer(item.id, 'NO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _noColor(item.id),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(38, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('NO',
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 38,
                  height: 26,
                  child: ElevatedButton(
                    onPressed: () => _saveAnswer(item.id, 'NA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _naColor(item.id),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(38, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('N/A',
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w600)),
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
          content: Text('PDF gerado: ${pdfFile.path}'),
          action: SnackBarAction(
            label: 'Abrir',
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
        SnackBar(content: Text('Erro ao gerar PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = calculateProgress();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist'),
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
            tooltip: 'Ocorrências',
          ),
          // Botão de PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePdf,
            tooltip: 'Gerar PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de progresso global
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progresso',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$doneItems/$totalItems (${progressPercent.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progressPercent / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Lista de seções expansíveis
          Expanded(
            child: ListView.builder(
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
                    title: const Text('Checklist Completo'),
                    content: const Text('Marcar este walkdown como completo?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Confirmar'),
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
                    const SnackBar(
                      content: Text('✅ Walkdown marcado como completo!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Marcar Completo'),
              backgroundColor: Colors.green,
            )
          : null,
    );
  }
}
