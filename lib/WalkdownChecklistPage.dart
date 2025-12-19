import 'package:flutter/material.dart';
import 'package:walkdown_app/l10n/app_localizations.dart';
import 'models.dart';
import 'occurrences_page.dart';
import 'database.dart';
import 'pdf_generator.dart';

class WalkdownChecklistPage extends StatefulWidget {
  final WalkdownData walkdown;

  const WalkdownChecklistPage({super.key, required this.walkdown});

  @override
  State<WalkdownChecklistPage> createState() => _WalkdownChecklistPageState();
}

class _WalkdownChecklistPageState extends State<WalkdownChecklistPage> {
  late final List<ChecklistSection> _sections;
  final Map<String, String> _answers = {};

  bool _isChecklistComplete() {
    int totalItems = 0;
    for (final section in _sections) {
      totalItems += section.items.length;
    }
    return _answers.length == totalItems;
  }

  @override
  void initState() {
    super.initState();
    _sections = buildChecklistForWalkdown(widget.walkdown);
    _loadAnswers();
  }

  Future<void> _loadAnswers() async {
    if (widget.walkdown.id == null) return;

    final savedAnswers = await WalkdownDatabase.instance.getChecklistAnswers(
      widget.walkdown.id!,
    );

    setState(() {
      _answers.addAll(savedAnswers);
    });
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

  @override
  Widget build(BuildContext context) {
    final info = widget.walkdown.projectInfo;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${loc.checklistTitle} - ${info.projectName} - ${info.towerNumber}',
        ),
      ),
      body: ListView.builder(
        itemCount: _sections.length,
        itemBuilder: (context, index) {
          final section = _sections[index];
          final title = appLanguage.value == AppLanguage.pt
              ? section.titlePt
              : section.titleEn;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...section.items.map((item) {
                final text = appLanguage.value == AppLanguage.pt
                    ? item.textPt
                    : item.textEn;

                return ListTile(
                  title: Text(
                    text,
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _yesColor(item.id),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(50, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          setState(() {
                            _answers[item.id] = 'YES';
                          });

                          if (widget.walkdown.id != null) {
                            await WalkdownDatabase.instance.saveChecklistAnswer(
                              widget.walkdown.id!,
                              item.id,
                              'YES',
                            );
                          }
                        },
                        child: const Text(
                          'YES',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _noColor(item.id),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(50, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          setState(() {
                            _answers[item.id] = 'NO';
                          });

                          if (widget.walkdown.id != null) {
                            await WalkdownDatabase.instance.saveChecklistAnswer(
                              widget.walkdown.id!,
                              item.id,
                              'NO',
                            );
                          }

                          final itemText = appLanguage.value == AppLanguage.pt
                              ? item.textPt
                              : item.textEn;
                          final initial = '$title – $itemText';

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WalkdownOccurrencesPage(
                                walkdown: widget.walkdown,
                                initialText: initial,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'NO',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _naColor(item.id),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(50, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          setState(() {
                            _answers[item.id] = 'NA';
                          });

                          if (widget.walkdown.id != null) {
                            await WalkdownDatabase.instance.saveChecklistAnswer(
                              widget.walkdown.id!,
                              item.id,
                              'NA',
                            );
                          }
                        },
                        child: const Text(
                          'N/A',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
      bottomNavigationBar: _isChecklistComplete()
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 245, 245, 246),
                border: Border(
                  top: BorderSide(color: Colors.blue.shade700, width: 2),
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (widget.walkdown.id == null) return;

                  await WalkdownDatabase.instance.markWalkdownCompleted(
                    widget.walkdown.id!,
                  );

                  final occurrences = await WalkdownDatabase.instance
                      .getOccurrencesForWalkdown(widget.walkdown.id!);

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    final pdfFile = await PdfGenerator.generateWalkdownPdf(
                      walkdown: widget.walkdown,
                      occurrences: occurrences,
                    );

                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('TESTE'),
                        content: Text(
                          'PDF criado! Chegou aqui?\nPath: ${pdfFile.path}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx); // fecha dialog
                              Navigator.pop(context); // fecha loading
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao gerar PDF: $e'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(
                  '${loc.checklistTitle} - ${info.projectName} - ${info.towerNumber}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            )
          : null,
    );
  }
}
