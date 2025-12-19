import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'database.dart';
import 'models.dart';
import 'package:walkdown_app/l10n/app_localizations.dart';

class WalkdownOccurrencesPage extends StatefulWidget {
  final WalkdownData walkdown;
  final String? initialText; // vem do botão NO

  const WalkdownOccurrencesPage({
    super.key,
    required this.walkdown,
    this.initialText,
  });

  @override
  State<WalkdownOccurrencesPage> createState() =>
      _WalkdownOccurrencesPageState();
}

class _WalkdownOccurrencesPageState extends State<WalkdownOccurrencesPage> {
  final formKey = GlobalKey<FormState>();

  final TextEditingController locationController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final List<Occurrence> occurrences = [];

  // lista temporária de fotos da ocorrência em edição (paths)
  final List<String> tempPhotos = [];

  // Controla se está a editar uma ocorrência existente
  Occurrence? _editingOccurrence;

  Future<File?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result == null || result.files.single.path == null) return null;

    return File(result.files.single.path!);
  }

  void _editOccurrence(Occurrence occ) {
    final loc = AppLocalizations.of(context)!;

    setState(() {
      _editingOccurrence = occ;
      locationController.text = occ.location;
      descriptionController.text = occ.description;
      tempPhotos
        ..clear()
        ..addAll(occ.photos); // paths
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.editOccurrenceMessage)),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      locationController.text = widget.initialText!;
    }
    _loadOccurrences();
  }

  Future<void> _loadOccurrences() async {
    if (widget.walkdown.id == null) return;

    final loaded = await WalkdownDatabase.instance.getOccurrencesForWalkdown(
      widget.walkdown.id!,
    );

    setState(() {
      occurrences
        ..clear()
        ..addAll(loaded)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
  }

  @override
  void dispose() {
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addOccurrence() async {
    final loc = AppLocalizations.of(context)!;

    if (!formKey.currentState!.validate()) {
      return;
    }

    if (_editingOccurrence != null) {
      // EDITAR ocorrência existente
      final updateOcc = Occurrence(
        id: _editingOccurrence!.id,
        walkdownId: widget.walkdown.id!,
        location: locationController.text.trim(),
        description: descriptionController.text.trim(),
        createdAt: _editingOccurrence!.createdAt,
        // se quiseres substituir em vez de juntar, usa: photos: List<String>.from(tempPhotos)
        photos: [
          ..._editingOccurrence!.photos, // paths antigos
          ...tempPhotos, // paths novos
        ],
      );

      if (widget.walkdown.id != null) {
        await WalkdownDatabase.instance.updateOccurrence(
          updateOcc,
          widget.walkdown.id!,
        );
      }

      setState(() {
        final index =
            occurrences.indexWhere((o) => o.id == _editingOccurrence!.id);
        if (index != -1) {
          occurrences[index] = updateOcc;
        }
        _editingOccurrence = null;
        locationController.clear();
        descriptionController.clear();
        tempPhotos.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.occurrenceUpdatedMessage)),
      );
    } else {
      // CRIAR ocorrência nova
      final occ = Occurrence(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        walkdownId: widget.walkdown.id!,
        location: locationController.text.trim(),
        description: descriptionController.text.trim(),
        createdAt: DateTime.now(),
        photos: List<String>.from(tempPhotos), // paths
      );

      if (widget.walkdown.id != null) {
        await WalkdownDatabase.instance.insertOccurrence(
          occ,
          widget.walkdown.id!,
        );
      }

      setState(() {
        occurrences
          ..add(occ)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        locationController.clear();
        descriptionController.clear();
        tempPhotos.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.occurrenceSavedMessage)),
      );
    }
  }

  Future<void> _removeOccurrence(String id) async {
    await WalkdownDatabase.instance.deleteOccurrence(id);

    setState(() {
      occurrences.removeWhere((o) => o.id == id);
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final loc = AppLocalizations.of(context)!;

    if (tempPhotos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.maxPhotosMessage)),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? picked =
        await picker.pickImage(source: source); // câmera/galeria[web:23]

    if (picked == null) return;

    final file = File(picked.path);

    setState(() {
      tempPhotos.add(file.path);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.photoAddedMessage(tempPhotos.length)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final hasOccurrences = occurrences.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.occurrencesTitle),
      ),
      body: Column(
        children: [
          // Formulário no topo
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.newOccurrenceTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: loc.locationLabel,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return loc.locationRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: loc.descriptionLabel,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return loc.descriptionRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Zona Drag & Drop (só desktop)
                  if (!kIsWeb &&
                      (Platform.isWindows ||
                          Platform.isLinux ||
                          Platform.isMacOS))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 350,
                        height: 120,
                        child: DropTarget(
                          onDragDone: (detail) {
                            for (final file in detail.files) {
                              final path = file.path;
                              if (tempPhotos.length < 4) {
                                setState(() => tempPhotos.add(path));
                              }
                            }
                          },
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 241, 234, 247),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.photo_camera,
                                    size: 32,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(loc.dragPhotosHint),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Faixa de miniaturas (sempre abaixo do D&D)
                  if (tempPhotos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: tempPhotos.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(tempPhotos[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        tempPhotos.removeAt(index);
                                      });
                                    },
                                    child: const CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Colors.red,
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Botões
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickPhoto(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: Text(loc.cameraButtonLabel),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _pickPhoto(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: Text(loc.galleryButtonLabel),
                        ),
                        const SizedBox(width: 24),
                        ElevatedButton(
                          onPressed: _addOccurrence,
                          child: Text(
                            _editingOccurrence != null
                                ? loc.updateButtonLabel
                                : loc.saveButtonLabel,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            if (_editingOccurrence != null) {
                              setState(() {
                                _editingOccurrence = null;
                                locationController.clear();
                                descriptionController.clear();
                                tempPhotos.clear();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(loc.editCanceledMessage),
                                ),
                              );
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Text(
                            _editingOccurrence != null
                                ? loc.cancelEditButtonLabel
                                : loc.cancelButtonLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(),

          // Lista de ocorrências já criadas
          Expanded(
            child: hasOccurrences
                ? ListView.builder(
                    itemCount: occurrences.length,
                    itemBuilder: (context, index) {
                      final occ = occurrences[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(
                            '#${index + 1} – ${occ.location}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(occ.description),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${loc.createdAtLabel} ${occ.createdAt}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    if (occ.photos.isNotEmpty)
                                      Text(
                                        loc.attachedPhotosLabel(
                                            occ.photos.length),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                              if (occ.photos.isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 8.0, top: 4),
                                  child: SizedBox(
                                    width: 70,
                                    height: 70,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.file(
                                        File(occ.photos.first),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeOccurrence(occ.id),
                          ),
                          onTap: () => _editOccurrence(occ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Text(loc.noOccurrencesLabel),
                  ),
          ),
        ],
      ),
    );
  }
}
