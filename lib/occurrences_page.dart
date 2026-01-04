import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'database.dart';
import 'models.dart';
import 'package:walkdown_app/l10n/app_localizations.dart';
import 'services/firebase_storage_service.dart';
import 'services/image_compression_service.dart';

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
  List<String> tempPhotos = [];
  bool isDragging = false;

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
        photos: List<String>.from(tempPhotos), // ✅ CORRIGIDO!
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
        isDragging = false; // 👈 adiciona esta linha
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

      print('✅ SAVED occurrence ID: ${uniqueId}'); // ← ADICIONA1!

      setState(() {
        occurrences
          ..add(occ)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        locationController.clear();
        descriptionController.clear();
        tempPhotos.clear();
      });

      final countAfter = await WalkdownDatabase.instance
          .countOccurrencesForWalkdown(widget.walkdown.id!);
      print('📊 TOTAL após save: $countAfter'); // ← ADICIONA2!

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.occurrenceSavedMessage)),
        );
      }
    }
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
    final XFile? picked = await picker.pickImage(source: source);

    if (picked == null) return;

    String pathToUpload = picked.path;

    // ✅ COMPRESSÃO com FALLBACK para GALERIA
    if (source == ImageSource.camera) {
      // Câmara: sempre comprimir
      final String? compressedPath =
          await ImageCompressionService.compressImage(pathToUpload);
      pathToUpload = compressedPath ?? pathToUpload;
    } else {
      // Galeria: tentar comprimir, mas usar original se falhar
      final String? compressedPath =
          await ImageCompressionService.compressImage(pathToUpload);
      if (compressedPath != null) {
        pathToUpload = compressedPath;
      } else {
        print('⚠️ Compressão da galeria falhou, usando original');
      }
    }

    // Upload do ficheiro (comprimido ou original)
    await _uploadFromPath(pathToUpload);
  }

  /// Usa a MESMA lógica de upload para botão e drag&drop
  Future<void> _uploadFromPath(String localPath) async {
    final loc = AppLocalizations.of(context)!;

    if (tempPhotos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.maxPhotosMessage)),
      );
      return;
    }

    // ✅ MOSTRAR LOADING DURANTE COMPRESSÃO + UPLOAD
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Compress and send...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // ✅ COMPRIMIR IMAGEM (se não estiver já comprimida)
      String pathToUpload = localPath;

      // Se o caminho NÃO contém "compressed_", então comprimir
      if (!localPath.contains('compressed_')) {
        final String? compressedPath =
            await ImageCompressionService.compressImage(localPath);

        if (compressedPath != null) {
          pathToUpload = compressedPath;
        } else {
          // Se falhar compressão, usar original
          print('⚠️ Compressão falhou, a usar imagem original');
        }
      }

      // ✅ UPLOAD PARA FIREBASE STORAGE
      final downloadUrl = await FirebaseStorageService.uploadPhoto(
        localPath: pathToUpload,
        walkdownId: widget.walkdown.id!,
        occurrenceId: _editingOccurrence?.id ??
            'temp_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      Navigator.pop(context); // fechar loading

      setState(() {
        tempPhotos.add(downloadUrl);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Foto comprimida e enviada (${tempPhotos.length}/4)'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // fechar loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ========== REMOVER OCORRÊNCIA ==========
  Future<void> _removeOccurrence(String id) async {
    final db = await WalkdownDatabase.instance.database;
    await db.delete('occurrence_photos',
        where: 'occurrence_id = ?', whereArgs: [id]);
    await db.delete('occurrences', where: 'id = ?', whereArgs: [id]);

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

  bool get _isDesktop {
    if (kIsWeb) return true;
    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (e) {
      return false;
    }
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

            // DESCRIPTION + DRAG&DROP + MINIATURAS
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📝 DESCRIÇÃO (esquerda)
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: loc.descriptionLabel,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return loc.descriptionRequired;
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(width: 12),

// 🖥️ DRAG & DROP - SÓ EM DESKTOP (Windows/Mac/Linux)
                if (_isDesktop) ...[
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 145,
                      child: DropTarget(
                        onDragEntered: (_) {
                          setState(() => isDragging = true);
                        },
                        onDragExited: (_) {
                          setState(() => isDragging = false);
                        },
                        onDragDone: (detail) async {
                          for (final file in detail.files) {
                            if (tempPhotos.length >= 4) break;
                            await _uploadFromPath(file.path);
                          }
                          setState(() => isDragging = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isDragging
                                ? Colors.blue.withOpacity(0.08)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDragging
                                  ? Colors.blue
                                  : const Color.fromARGB(255, 224, 192, 241),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload, size: 24),
                                SizedBox(height: 6),
                                Text(
                                  'Arraste imagens aqui',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                ),
                                SizedBox(height: 2),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // 🖼️ MINIATURAS (direita)
                SizedBox(
                  width: 110,
                  height: 130,
                  child: tempPhotos.isEmpty
                      ? const Center(
                          child: Text(
                            'Sem fotos',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: tempPhotos.length,
                          itemBuilder: (context, index) {
                            final photoPath = tempPhotos[index];
                            final isUrl = photoPath.startsWith('http');

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: isUrl
                                        ? Image.network(
                                            photoPath,
                                            width: 110,
                                            height: 70,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            File(photoPath),
                                            width: 110,
                                            height: 70,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(
                                          () => tempPhotos.removeAt(index),
                                        );
                                      },
                                      child: const CircleAvatar(
                                        radius: 9,
                                        backgroundColor: Colors.red,
                                        child: Icon(
                                          Icons.close,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // BOTÕES DE AÇÃO
            _buildActionButtons(loc),
          ],
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
                    child: Icon(Icons.close,
                        size: 14, color: Color.fromARGB(255, 205, 184, 253)),
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
          // ✅ BOTÕES ORIGINAIS
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
