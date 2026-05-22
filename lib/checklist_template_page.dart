import 'package:flutter/material.dart';
import 'package:walkdown_app/l10n/app_localizations.dart';

import 'database.dart';
import 'models.dart';

class ChecklistTemplatePage extends StatefulWidget {
  const ChecklistTemplatePage({super.key});

  @override
  State<ChecklistTemplatePage> createState() => _ChecklistTemplatePageState();
}

class _ChecklistTemplatePageState extends State<ChecklistTemplatePage> {
  final WalkdownDatabase _database = WalkdownDatabase.instance;
  List<ChecklistSection> _sections = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    setState(() => _isLoading = true);

    try {
      final sections = await _database.getChecklistSections(
        includeEmptySections: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sections = sections;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.checklistTemplateLoadError('$e'))),
      );
    }
  }

  bool _isEnglish(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'en';
  }

  String _displaySectionTitle(BuildContext context, ChecklistSection section) {
    if (_isEnglish(context) && (section.titleEn?.trim().isNotEmpty ?? false)) {
      return section.titleEn!;
    }

    return section.titlePt;
  }

  String _displayItemText(BuildContext context, ChecklistItem item) {
    if (_isEnglish(context) && (item.textEn?.trim().isNotEmpty ?? false)) {
      return item.textEn!;
    }

    return item.textPt;
  }

  String _secondaryItemText(BuildContext context, ChecklistItem item) {
    final loc = AppLocalizations.of(context)!;

    if (_isEnglish(context)) {
      return item.textPt;
    }

    if (item.textEn?.trim().isNotEmpty ?? false) {
      return item.textEn!;
    }

    return loc.checklistTemplateNoEnglishTranslation;
  }

  Future<void> _createSection() async {
    final section = await showDialog<ChecklistSection>(
      context: context,
      builder: (_) => const _ChecklistSectionDialog(),
    );

    if (section == null) {
      return;
    }

    await _database.upsertChecklistSection(section);
    await _loadSections();
  }

  Future<void> _editSection(ChecklistSection section) async {
    final updated = await showDialog<ChecklistSection>(
      context: context,
      builder: (_) => _ChecklistSectionDialog(initialSection: section),
    );

    if (updated == null) {
      return;
    }

    await _database.upsertChecklistSection(updated);
    await _loadSections();
  }

  Future<void> _deleteSection(ChecklistSection section) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.checklistTemplateSectionDeleteTitle),
        content: Text(
          loc.checklistTemplateSectionDeleteMessage(
            _displaySectionTitle(context, section),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.deleteButtonLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _database.deleteChecklistSection(section.id);
    await _loadSections();
  }

  Future<void> _createItem(ChecklistSection section) async {
    final item = await showDialog<_ChecklistItemDraft>(
      context: context,
      builder: (_) => _ChecklistItemDialog(section: section),
    );

    if (item == null) {
      return;
    }

    await _database.upsertChecklistItem(
      id: item.id,
      sectionId: section.id,
      textPt: item.textPt,
      textEn: item.textEn,
      sortOrder: section.items.length,
    );
    await _loadSections();
  }

  Future<void> _editItem(ChecklistSection section, ChecklistItem item) async {
    final updated = await showDialog<_ChecklistItemDraft>(
      context: context,
      builder: (_) => _ChecklistItemDialog(
        section: section,
        initialItem: item,
      ),
    );

    if (updated == null) {
      return;
    }

    await _database.upsertChecklistItem(
      id: updated.id,
      sectionId: section.id,
      textPt: updated.textPt,
      textEn: updated.textEn,
      sortOrder: item.sortOrder,
    );
    await _loadSections();
  }

  Future<void> _deleteItem(ChecklistSection section, ChecklistItem item) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.checklistTemplateItemDeleteTitle),
        content: Text(
          loc.checklistTemplateItemDeleteMessage(
            _displayItemText(context, item),
            _displaySectionTitle(context, section),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.deleteButtonLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _database.deleteChecklistItem(item.id);
    await _loadSections();
  }

  String _requirementLabel(ChecklistTowerRequirement requirement) {
    final loc = AppLocalizations.of(context)!;

    switch (requirement) {
      case ChecklistTowerRequirement.all:
        return loc.checklistTemplateAllTowers;
      case ChecklistTowerRequirement.fourSections:
        return loc.checklistTemplateFourSectionsOnly;
      case ChecklistTowerRequirement.fiveSections:
        return loc.checklistTemplateFiveSectionsOnly;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.checklistTemplatePageTitle),
        actions: [
          IconButton(
            onPressed: _loadSections,
            icon: const Icon(Icons.refresh),
            tooltip: loc.checklistTemplateRefreshTooltip,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSection,
        icon: const Icon(Icons.playlist_add),
        label: Text(loc.checklistTemplateNewSectionLabel),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sections.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.format_list_bulleted, size: 52),
                        const SizedBox(height: 12),
                        Text(
                          loc.checklistTemplateEmptyState,
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSections,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    itemCount: _sections.length,
                    itemBuilder: (context, index) {
                      final section = _sections[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          title: Text(
                            _displaySectionTitle(context, section),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            loc.checklistTemplateSectionSummary(
                              section.items.length,
                              _requirementLabel(section.towerRequirement),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _createItem(section),
                                icon: const Icon(Icons.add),
                                tooltip: loc.checklistTemplateNewPhraseTooltip,
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editSection(section);
                                  } else if (value == 'delete') {
                                    _deleteSection(section);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(
                                      loc.checklistTemplateEditSectionLabel,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      loc.checklistTemplateDeleteSectionLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          children: section.items.isEmpty
                              ? [
                                  ListTile(
                                    title:
                                        Text(loc.checklistTemplateEmptySection),
                                  ),
                                ]
                              : section.items.map((item) {
                                  return ListTile(
                                    title:
                                        Text(_displayItemText(context, item)),
                                    subtitle: Text(
                                      _secondaryItemText(context, item),
                                    ),
                                    trailing: Wrap(
                                      spacing: 4,
                                      children: [
                                        IconButton(
                                          onPressed: () =>
                                              _editItem(section, item),
                                          icon: const Icon(Icons.edit_outlined),
                                          tooltip: loc
                                              .checklistTemplateEditPhraseTooltip,
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _deleteItem(section, item),
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          tooltip: loc
                                              .checklistTemplateDeletePhraseTooltip,
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _ChecklistSectionDialog extends StatefulWidget {
  final ChecklistSection? initialSection;

  const _ChecklistSectionDialog({this.initialSection});

  @override
  State<_ChecklistSectionDialog> createState() =>
      _ChecklistSectionDialogState();
}

class _ChecklistSectionDialogState extends State<_ChecklistSectionDialog> {
  late final TextEditingController _titlePtController;
  late final TextEditingController _titleEnController;
  late ChecklistTowerRequirement _requirement;

  bool get _isEditing => widget.initialSection != null;

  @override
  void initState() {
    super.initState();
    _titlePtController =
        TextEditingController(text: widget.initialSection?.titlePt ?? '');
    _titleEnController =
        TextEditingController(text: widget.initialSection?.titleEn ?? '');
    _requirement = widget.initialSection?.towerRequirement ??
        ChecklistTowerRequirement.all;
  }

  @override
  void dispose() {
    _titlePtController.dispose();
    _titleEnController.dispose();
    super.dispose();
  }

  void _submit() {
    final titlePt = _titlePtController.text.trim();
    final titleEn = _titleEnController.text.trim();
    if (titlePt.isEmpty) {
      return;
    }

    final initial = widget.initialSection;
    final sectionId = initial?.id ?? _generateId(titlePt, 'section');

    Navigator.of(context).pop(
      ChecklistSection(
        id: sectionId,
        titlePt: titlePt,
        titleEn: titleEn.isEmpty ? null : titleEn,
        towerRequirement: _requirement,
        sortOrder: initial?.sortOrder ?? 9999,
        items: initial?.items ?? const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(
        _isEditing
            ? loc.checklistTemplateEditSectionTitle
            : loc.checklistTemplateCreateSectionTitle,
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titlePtController,
              decoration:
                  InputDecoration(labelText: loc.checklistTemplateTitlePtLabel),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleEnController,
              decoration:
                  InputDecoration(labelText: loc.checklistTemplateTitleEnLabel),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ChecklistTowerRequirement>(
              initialValue: _requirement,
              decoration:
                  InputDecoration(labelText: loc.checklistTemplateApplyToLabel),
              items: [
                DropdownMenuItem(
                  value: ChecklistTowerRequirement.all,
                  child: Text(loc.checklistTemplateAllTowersOption),
                ),
                DropdownMenuItem(
                  value: ChecklistTowerRequirement.fourSections,
                  child: Text(loc.checklistTemplateFourSectionsOption),
                ),
                DropdownMenuItem(
                  value: ChecklistTowerRequirement.fiveSections,
                  child: Text(loc.checklistTemplateFiveSectionsOption),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _requirement = value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(loc.saveButtonLabel),
        ),
      ],
    );
  }
}

class _ChecklistItemDialog extends StatefulWidget {
  final ChecklistSection section;
  final ChecklistItem? initialItem;

  const _ChecklistItemDialog({
    required this.section,
    this.initialItem,
  });

  @override
  State<_ChecklistItemDialog> createState() => _ChecklistItemDialogState();
}

class _ChecklistItemDialogState extends State<_ChecklistItemDialog> {
  late final TextEditingController _textPtController;
  late final TextEditingController _textEnController;

  bool get _isEditing => widget.initialItem != null;

  @override
  void initState() {
    super.initState();
    _textPtController =
        TextEditingController(text: widget.initialItem?.textPt ?? '');
    _textEnController =
        TextEditingController(text: widget.initialItem?.textEn ?? '');
  }

  @override
  void dispose() {
    _textPtController.dispose();
    _textEnController.dispose();
    super.dispose();
  }

  void _submit() {
    final textPt = _textPtController.text.trim();
    final textEn = _textEnController.text.trim();
    if (textPt.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      _ChecklistItemDraft(
        id: widget.initialItem?.id ?? _generateId(textPt, widget.section.id),
        textPt: textPt,
        textEn: textEn.isEmpty ? null : textEn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(
        _isEditing
            ? loc.checklistTemplateEditPhraseTitle
            : loc.checklistTemplateCreatePhraseTitle,
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _textPtController,
              decoration: InputDecoration(
                  labelText: loc.checklistTemplatePhrasePtLabel),
              autofocus: true,
              maxLines: 3,
              minLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textEnController,
              decoration: InputDecoration(
                  labelText: loc.checklistTemplatePhraseEnLabel),
              maxLines: 3,
              minLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(loc.saveButtonLabel),
        ),
      ],
    );
  }
}

class _ChecklistItemDraft {
  final String id;
  final String textPt;
  final String? textEn;

  const _ChecklistItemDraft({
    required this.id,
    required this.textPt,
    this.textEn,
  });
}

String _generateId(String seed, String prefix) {
  final normalized = seed
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  final base = normalized.isEmpty ? prefix : '${prefix}_$normalized';
  return '${base}_${DateTime.now().microsecondsSinceEpoch}';
}
