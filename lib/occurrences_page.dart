import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'database.dart';
import 'models.dart';
import 'package:walkdown_app/l10n/app_localizations.dart';
import 'services/firebase_storage_service.dart';

class WalkdownOccurrencesPage extends StatefulWidget {
  final WalkdownData walkdown;
  final String? initialText;

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
  final List<String> tempPhotos = [];
  Occurrence? _editingOccurrence;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      locationController.text = widget.initialText!;
    }
    _loadOccurrences();
  }

  @override
  void dispose() {
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  // ========== CARREGAR OCORRÊNCIAS ==========
  Future<void> _loadOccurrences() async {
    if (widget.walkdown.id == null) return;

    final loaded = await WalkdownDatabase.instance
        .getOccurrencesForWalkdown(widget.walkdown.id!);

    if (mounted) {
      setState(() {
        occurrences
          ..clear()
          ..addAll(loaded)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
    }
  }

  // ========== ADICIONAR/ATUALIZAR OCORRÊNCIA ==========
  Future<void> _addOccurrence() async {
    final loc = AppLocalizations.of(context)!;

    if (!formKey.currentState!.validate()) return;

    if (_editingOccurrence != null) {
      // EDITAR EXISTENTE
      final updateOcc = Occurrence(
        id: _editingOccurrence!.id,
        walkdownId: widget.walkdown.id!,
        location: locationController.text.trim(),
        description: descriptionController.text.trim(),
        createdAt: _editingOccurrence!.createdAt,
        photos: [
          ..._editingOccurrence!.photos,
          ...tempPhotos,
        ],
      );

      await WalkdownDatabase.instance.updateOccurrence(
        updateOcc,
        widget.walkdown.id!,
      );

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.occurrenceUpdatedMessage)),
        );
      }
    } else {
      // CRIAR NOVA OCORRÊNCIA COM ID ÚNICO
      final now = DateTime.now();
      final uniqueId =
          '${now.millisecondsSinceEpoch}_${now.microsecondsSinceEpoch}';

      final occ = Occurrence(
        id: uniqueId,
        walkdownId: widget.walkdown.id!,
        location: locationController.text.trim(),
        description: descriptionController.text.trim(),
        createdAt: now,
        photos: List<String>.from(tempPhotos),
      );

      await WalkdownDatabase.instance.insertOccurrence(
        occ,
        widget.walkdown.id!,
      );

      setState(() {
        occurrences
          ..add(occ)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        locationController.clear();
        descriptionController.clear();
        tempPhotos.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.occurrenceSavedMessage)),
        );
      }
    }
  }

  // ========== REMOVER OCORRÊNCIA ==========
  Future<void> _removeOccurrence(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar ocorrência'),
        content:
            const Text('Tem a certeza que deseja eliminar esta ocorrência?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await WalkdownDatabase.instance.deleteOccurrence(id);
    setState(() {
      occurrences.removeWhere((o) => o.id == id);
    });
  }

  // ========== EDITAR OCORRÊNCIA ==========
  void _editOccurrence(Occurrence occ) {
    final loc = AppLocalizations.of(context)!;

    setState(() {
      _editingOccurrence = occ;
      locationController.text = occ.location;
      descriptionController.text = occ.description;
      tempPhotos
        ..clear()
        ..addAll(occ.photos);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.editOccurrenceMessage)),
    );
  }

// ========== ADICIONAR FOTO COM UPLOAD PARA FIREBASE STORAGE ==========
  Future<void> _pickPhoto(ImageSource source) async {
    final loc = AppLocalizations.of(context)!;

    if (tempPhotos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.maxPhotosMessage)),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: source);

    if (picked == null) return;

    // ✅ MOSTRAR LOADING DURANTE UPLOAD
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // ✅ UPLOAD PARA FIREBASE STORAGE
      final downloadUrl = await FirebaseStorageService.uploadPhoto(
        localPath: picked.path,
        walkdownId: widget.walkdown.id!,
        occurrenceId: _editingOccurrence?.id ??
            'temp_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      Navigator.pop(context); // Fechar loading

      setState(() {
        tempPhotos.add(downloadUrl); // ✅ GUARDAR URL EM VEZ DE PATH LOCAL
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.photoAddedMessage(tempPhotos.length)),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Fechar loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro no upload: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ========== BUILD UI ==========
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.occurrencesTitle),
      ),
      body: Column(
        children: [
          _buildFormSection(loc),
          const Divider(thickness: 2),
          _buildOccurrencesList(loc),
        ],
      ),
    );
  }

  // ========== SECÇÃO DO FORMULÁRIO ==========
  Widget _buildFormSection(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.newOccurrenceTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // LOCATION
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

            // DESCRIPTION
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
            const SizedBox(height: 12),

            // DRAG & DROP (Desktop)
            if (!kIsWeb &&
                (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
              _buildDragDropArea(loc),

            const SizedBox(height: 8),

            // MINIATURAS DE FOTOS
            if (tempPhotos.isNotEmpty) _buildPhotoThumbnails(),

            const SizedBox(height: 12),

            // BOTÕES DE AÇÃO
            _buildActionButtons(loc),
          ],
        ),
      ),
    );
  }

  // ========== DRAG & DROP AREA ==========
  Widget _buildDragDropArea(AppLocalizations loc) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 350,
        height: 120,
        child: DropTarget(
          onDragDone: (detail) async {
            for (final file in detail.files) {
              if (tempPhotos.length >= 4) break;

              // ✅ MOSTRAR LOADING
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                // ✅ UPLOAD PARA FIREBASE
                final downloadUrl = await FirebaseStorageService.uploadPhoto(
                  localPath: file.path,
                  walkdownId: widget.walkdown.id!,
                  occurrenceId: _editingOccurrence?.id ??
                      'temp_${DateTime.now().millisecondsSinceEpoch}',
                );

                setState(() => tempPhotos.add(downloadUrl));

                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Erro: $e'), backgroundColor: Colors.red),
                  );
                }
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
                  const Icon(Icons.photo_camera, size: 32, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(loc.dragPhotosHint),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

// ========== MINIATURAS DAS FOTOS ==========
  Widget _buildPhotoThumbnails() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tempPhotos.length,
        itemBuilder: (context, index) {
          final photoPath = tempPhotos[index];
          final isUrl = photoPath.startsWith('http');

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
                  child: isUrl
                      ? Image.network(
                          photoPath,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(child: Icon(Icons.error));
                          },
                        )
                      : Image.file(
                          File(photoPath),
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
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ========== BOTÕES DE AÇÃO ==========
  Widget _buildActionButtons(AppLocalizations loc) {
    return SingleChildScrollView(
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
                  SnackBar(content: Text(loc.editCanceledMessage)),
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
    );
  }

  // ========== LISTA DE OCORRÊNCIAS ==========
  Widget _buildOccurrencesList(AppLocalizations loc) {
    return Expanded(
      child: occurrences.isEmpty
          ? Center(
              child: Text(
                loc.noOccurrencesLabel,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
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
                    subtitle: _buildOccurrenceSubtitle(occ, loc),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeOccurrence(occ.id),
                    ),
                    onTap: () => _editOccurrence(occ),
                  ),
                );
              },
            ),
    );
  }

// ========== CONTEÚDO DO CARD ==========
  Widget _buildOccurrenceSubtitle(Occurrence occ, AppLocalizations loc) {
    final firstPhoto = occ.photos.isNotEmpty ? occ.photos.first : null;
    final isUrl = firstPhoto != null && firstPhoto.startsWith('http');

    return Row(
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
                '${loc.createdAtLabel} ${_formatDateTime(occ.createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (occ.photos.isNotEmpty)
                Text(
                  loc.attachedPhotosLabel(occ.photos.length),
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
            ],
          ),
        ),
        if (firstPhoto != null)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 4),
            child: SizedBox(
              width: 70,
              height: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: isUrl
                    ? Image.network(
                        firstPhoto,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(child: Icon(Icons.broken_image));
                        },
                      )
                    : Image.file(
                        File(firstPhoto),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
      ],
    );
  }

  // ========== FORMATAR DATA/HORA ==========
  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
