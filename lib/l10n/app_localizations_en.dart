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
    return 'Photo added ($current/4).';
  }

  @override
  String get cameraButtonLabel => 'Camera';

  @override
  String get galleryButtonLabel => 'Gallery';

  @override
  String photosCountLabel(int count) {
    return 'Photos: $count';
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
    return 'Attached photos ($count)';
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
  String get logoutLabel => 'Logout';

  @override
  String get unsyncedDataTitle => 'Unsynced data';

  @override
  String unsyncedDataMessage(int count) {
    return '$count item(s) have not been sent yet.\n\nDo you want to leave anyway?';
  }

  @override
  String get exitWithoutSyncLabel => 'Leave without syncing';

  @override
  String get logoutConfirmMessage => 'Are you sure you want to sign out?';

  @override
  String get exitLabel => 'Leave';

  @override
  String get syncUploadTooltip => 'Send data';

  @override
  String get syncDownloadTooltip => 'Download data';

  @override
  String walkdownOccurrencesCount(int count) {
    return '$count occurrences';
  }

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
  String excelGenerated(String path) {
    return 'Excel generated: $path';
  }

  @override
  String get excelErrorLabel => 'Error generating Excel';

  @override
  String get excelTooltip => 'Export to Excel';

  @override
  String get checklistPdfTooltip => 'Checklist PDF';

  @override
  String checklistPdfOpenError(String error) {
    return 'Error opening checklist PDF: $error';
  }

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

  @override
  String get editWalkdownChecklistLabel => 'Edit Walkdown Checklist';

  @override
  String checklistTemplateLoadError(String error) {
    return 'Error loading checklist editor: $error';
  }

  @override
  String get checklistTemplatePageTitle => 'Edit Walkdown Checklist';

  @override
  String get checklistTemplateRefreshTooltip => 'Refresh';

  @override
  String get checklistTemplateNewSectionLabel => 'New section';

  @override
  String get checklistTemplateEmptyState => 'There are no configured sections yet.';

  @override
  String get checklistTemplateSectionDeleteTitle => 'Delete section';

  @override
  String checklistTemplateSectionDeleteMessage(String sectionTitle) {
    return 'The section \"$sectionTitle\" and all its phrases will be deleted. Continue?';
  }

  @override
  String get checklistTemplateItemDeleteTitle => 'Delete phrase';

  @override
  String checklistTemplateItemDeleteMessage(String itemText, String sectionTitle) {
    return 'Delete the phrase \"$itemText\" from section $sectionTitle?';
  }

  @override
  String get checklistTemplateAllTowers => 'All towers';

  @override
  String get checklistTemplateFourSectionsOnly => '4-section towers only';

  @override
  String get checklistTemplateFiveSectionsOnly => '5-section towers only';

  @override
  String checklistTemplateSectionSummary(int count, String scope) {
    return '$count phrase(s) • $scope';
  }

  @override
  String get checklistTemplateNewPhraseTooltip => 'New phrase';

  @override
  String get checklistTemplateEditSectionLabel => 'Edit section';

  @override
  String get checklistTemplateDeleteSectionLabel => 'Delete section';

  @override
  String get checklistTemplateEmptySection => 'No phrases in this section.';

  @override
  String get checklistTemplateNoEnglishTranslation => 'No English translation';

  @override
  String get checklistTemplateEditPhraseTooltip => 'Edit phrase';

  @override
  String get checklistTemplateDeletePhraseTooltip => 'Delete phrase';

  @override
  String get checklistTemplateEditSectionTitle => 'Edit section';

  @override
  String get checklistTemplateCreateSectionTitle => 'New section';

  @override
  String get checklistTemplateTitlePtLabel => 'Portuguese title';

  @override
  String get checklistTemplateTitleEnLabel => 'English title';

  @override
  String get checklistTemplateApplyToLabel => 'Apply to';

  @override
  String get checklistTemplateAllTowersOption => 'All towers';

  @override
  String get checklistTemplateFourSectionsOption => '4-section towers';

  @override
  String get checklistTemplateFiveSectionsOption => '5-section towers';

  @override
  String get checklistTemplateEditPhraseTitle => 'Edit phrase';

  @override
  String get checklistTemplateCreatePhraseTitle => 'New phrase';

  @override
  String get checklistTemplatePhrasePtLabel => 'Portuguese phrase';

  @override
  String get checklistTemplatePhraseEnLabel => 'English phrase';

  @override
  String get checklistPageTitle => 'Checklist';

  @override
  String get checklistOccurrencesTooltip => 'Occurrences';

  @override
  String get checklistProgressLabel => 'Progress';

  @override
  String get checklistCompleteTitle => 'Checklist complete';

  @override
  String get checklistCompleteQuestion => 'Mark this walkdown as complete?';

  @override
  String get checklistCompleteConfirmLabel => 'Confirm';

  @override
  String get checklistMarkedCompletedMessage => 'Walkdown marked as complete!';

  @override
  String get checklistMarkCompletedLabel => 'Mark Complete';

  @override
  String get uploadCompressionProgressLabel => 'Compressing and uploading...';

  @override
  String get noPhotosLabel => 'No photos';

  @override
  String uploadPhotoSuccessMessage(int current) {
    return 'Compressed photo uploaded ($current/4).';
  }

  @override
  String genericErrorLabel(String error) {
    return 'Error: $error';
  }
}
