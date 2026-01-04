// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get occurrencesTitle => 'Ocorrências';

  @override
  String get languageChooseTitle => 'Escolha o idioma';

  @override
  String get walkdownCompletedLabel => 'Walkdown Completo';

  @override
  String get newOccurrenceTitle => 'Nova ocorrência';

  @override
  String get locationLabel => 'Localização / Secção / Item';

  @override
  String get locationRequired => 'Indica a localização / secção / item';

  @override
  String get descriptionLabel => 'Descrição / Problema';

  @override
  String get descriptionRequired => 'Descrição é obrigatória';

  @override
  String get dragPhotosHint => 'Arrasta aqui as fotos (PC)';

  @override
  String get editOccurrenceMessage =>
      'A editar ocorrência. Clica Cancelar para criar nova.';

  @override
  String get occurrenceUpdatedMessage => 'Ocorrência atualizada';

  @override
  String get occurrenceSavedMessage => 'Ocorrência guardada';

  @override
  String get maxPhotosMessage => 'Máximo de 4 fotos por ocorrência';

  @override
  String photoAddedMessage(int current) {
    return 'Foto adicionada (máximo 4).';
  }

  @override
  String get cameraButtonLabel => 'Câmara';

  @override
  String get galleryButtonLabel => 'Galeria';

  @override
  String photosCountLabel(int count) {
    return 'Fotos: 4';
  }

  @override
  String get updateButtonLabel => 'Atualizar';

  @override
  String get saveButtonLabel => 'Guardar';

  @override
  String get editCanceledMessage => 'Edição cancelada';

  @override
  String get cancelEditButtonLabel => 'Cancelar edição';

  @override
  String get cancelButtonLabel => 'Cancel';

  @override
  String get createdAtLabel => 'Criado em:';

  @override
  String attachedPhotosLabel(int count) {
    return 'Fotos anexadas:';
  }

  @override
  String get noOccurrencesLabel => 'Nenhuma ocorrência registada ainda.';

  @override
  String walkdownsLoaded(int count) {
    return 'Carregado da BD: $count registos';
  }

  @override
  String get newWalkdownButton => 'New Walkdown';

  @override
  String get walkdownWelcomeTitle => 'Welcome to Walkdown 2WS';

  @override
  String get deleteWalkdownTitle => 'Delete walkdown';

  @override
  String get deleteWalkdownQuestion =>
      'Are you sure you want to delete this walkdown?';

  @override
  String get deleteButtonLabel => 'Delete';

  @override
  String pdfGenerated(String path) {
    return 'PDF generated: $path';
  }

  @override
  String get pdfOpenLabel => 'Open';

  @override
  String get pdfErrorLabel => 'Error generating PDF';

  @override
  String get pdfTooltip => 'Generate PDF';

  @override
  String get excelSuccessLabel => 'Excel generated successfully';

  @override
  String get excelErrorLabel => 'Error generating Excel';

  @override
  String get excelTooltip => 'Export to Excel';

  @override
  String get towerTypeLabel => 'Tower type';

  @override
  String get towerTypeFourSections => '4 sections (up to S4)';

  @override
  String get towerTypeFiveSections => '5 sections (up to S5)';

  @override
  String get dateLabel => 'Date';

  @override
  String get chooseDateButtonLabel => 'Choose date';

  @override
  String get newWalkdownDialogTitle => 'New Walkdown';

  @override
  String get projectNameLabel => 'Project';

  @override
  String get projectNumberLabel => 'Number';

  @override
  String get supervisorLabel => 'Supervisor';

  @override
  String get roadLabel => 'Road';

  @override
  String get towerLabel => 'Tower';

  @override
  String get fieldRequiredLabel => 'Required';

  @override
  String get checklistTitle => 'Checklist Completo - Gerar PDF';
}
