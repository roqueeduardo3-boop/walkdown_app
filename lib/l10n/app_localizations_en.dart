// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get occurrencesTitle => 'Occurrences';

  @override
  String get languageChooseTitle => 'Choose a language';

  @override
  String get walkdownCompletedLabel => 'Walkdown Complete';

  @override
  String get newOccurrenceTitle => 'New occurrence';

  @override
  String get locationLabel => 'Location / Section / Item';

  @override
  String get locationRequired => 'Please enter the location / section / item';

  @override
  String get descriptionLabel => 'Description / Problem';

  @override
  String get descriptionRequired => 'Description is required';

  @override
  String get dragPhotosHint => 'Drag photos here (PC)';

  @override
  String get editOccurrenceMessage => 'Editing occurrence. Tap Cancel to create a new one.';

  @override
  String get occurrenceUpdatedMessage => 'Occurrence updated';

  @override
  String get occurrenceSavedMessage => 'Occurrence saved';

  @override
  String get maxPhotosMessage => 'Maximum of 4 photos per occurrence';

  @override
  String photoAddedMessage(int current) {
    return 'Photo added (max 4).';
  }

  @override
  String get cameraButtonLabel => 'Camera';

  @override
  String get galleryButtonLabel => 'Gallery';

  @override
  String photosCountLabel(int count) {
    return 'Photos: 4';
  }

  @override
  String get updateButtonLabel => 'Update';

  @override
  String get saveButtonLabel => 'Save';

  @override
  String get editCanceledMessage => 'Edit canceled';

  @override
  String get cancelEditButtonLabel => 'Cancel edit';

  @override
  String get cancelButtonLabel => 'Cancel';

  @override
  String get createdAtLabel => 'Created at:';

  @override
  String attachedPhotosLabel(int count) {
    return 'Attached photos';
  }

  @override
  String get noOccurrencesLabel => 'No occurrences registered yet.';

  @override
  String walkdownsLoaded(int count) {
    return 'Loaded from DB: $count records';
  }

  @override
  String get newWalkdownButton => 'New Walkdown';

  @override
  String get walkdownWelcomeTitle => 'Welcome to Walkdown 2WS';

  @override
  String get deleteWalkdownTitle => 'Delete walkdown';

  @override
  String get deleteWalkdownQuestion => 'Are you sure you want to delete this walkdown?';

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
  String get checklistTitle => 'Checklist Complete - Generate PDF';
}
