import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt')
  ];

  /// No description provided for @occurrencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Occurrences'**
  String get occurrencesTitle;

  /// No description provided for @languageChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a language'**
  String get languageChooseTitle;

  /// No description provided for @walkdownCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Walkdown Complete'**
  String get walkdownCompletedLabel;

  /// No description provided for @newOccurrenceTitle.
  ///
  /// In en, this message translates to:
  /// **'New occurrence'**
  String get newOccurrenceTitle;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location / Section / Item'**
  String get locationLabel;

  /// No description provided for @locationRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the location / section / item'**
  String get locationRequired;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description / Problem'**
  String get descriptionLabel;

  /// No description provided for @descriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Description is required'**
  String get descriptionRequired;

  /// No description provided for @dragPhotosHint.
  ///
  /// In en, this message translates to:
  /// **'Drag photos here (PC)'**
  String get dragPhotosHint;

  /// No description provided for @editOccurrenceMessage.
  ///
  /// In en, this message translates to:
  /// **'Editing occurrence. Tap Cancel to create a new one.'**
  String get editOccurrenceMessage;

  /// No description provided for @occurrenceUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Occurrence updated'**
  String get occurrenceUpdatedMessage;

  /// No description provided for @occurrenceSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Occurrence saved'**
  String get occurrenceSavedMessage;

  /// No description provided for @maxPhotosMessage.
  ///
  /// In en, this message translates to:
  /// **'Maximum of 4 photos per occurrence'**
  String get maxPhotosMessage;

  /// No description provided for @photoAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Photo added ({current}/4).'**
  String photoAddedMessage(int current);

  /// No description provided for @cameraButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraButtonLabel;

  /// No description provided for @galleryButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryButtonLabel;

  /// No description provided for @photosCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Photos: {count}'**
  String photosCountLabel(int count);

  /// No description provided for @updateButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateButtonLabel;

  /// No description provided for @saveButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButtonLabel;

  /// No description provided for @editCanceledMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit canceled'**
  String get editCanceledMessage;

  /// No description provided for @cancelEditButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel edit'**
  String get cancelEditButtonLabel;

  /// No description provided for @cancelButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButtonLabel;

  /// No description provided for @createdAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Created at:'**
  String get createdAtLabel;

  /// No description provided for @attachedPhotosLabel.
  ///
  /// In en, this message translates to:
  /// **'Attached photos ({count})'**
  String attachedPhotosLabel(int count);

  /// No description provided for @noOccurrencesLabel.
  ///
  /// In en, this message translates to:
  /// **'No occurrences registered yet.'**
  String get noOccurrencesLabel;

  /// No description provided for @walkdownsLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded from DB: {count} records'**
  String walkdownsLoaded(int count);

  /// No description provided for @newWalkdownButton.
  ///
  /// In en, this message translates to:
  /// **'New Walkdown'**
  String get newWalkdownButton;

  /// No description provided for @walkdownWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Walkdown 2WS'**
  String get walkdownWelcomeTitle;

  /// No description provided for @deleteWalkdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete walkdown'**
  String get deleteWalkdownTitle;

  /// No description provided for @deleteWalkdownQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this walkdown?'**
  String get deleteWalkdownQuestion;

  /// No description provided for @logoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutLabel;

  /// No description provided for @unsyncedDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsynced data'**
  String get unsyncedDataTitle;

  /// No description provided for @unsyncedDataMessage.
  ///
  /// In en, this message translates to:
  /// **'{count} item(s) have not been sent yet.\n\nDo you want to leave anyway?'**
  String unsyncedDataMessage(int count);

  /// No description provided for @exitWithoutSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Leave without syncing'**
  String get exitWithoutSyncLabel;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get logoutConfirmMessage;

  /// No description provided for @exitLabel.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get exitLabel;

  /// No description provided for @syncUploadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send data'**
  String get syncUploadTooltip;

  /// No description provided for @syncDownloadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download data'**
  String get syncDownloadTooltip;

  /// No description provided for @walkdownOccurrencesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} occurrences'**
  String walkdownOccurrencesCount(int count);

  /// No description provided for @deleteButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButtonLabel;

  /// No description provided for @pdfGenerated.
  ///
  /// In en, this message translates to:
  /// **'PDF generated: {path}'**
  String pdfGenerated(String path);

  /// No description provided for @pdfOpenLabel.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get pdfOpenLabel;

  /// No description provided for @pdfErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error generating PDF'**
  String get pdfErrorLabel;

  /// No description provided for @pdfTooltip.
  ///
  /// In en, this message translates to:
  /// **'Generate PDF'**
  String get pdfTooltip;

  /// No description provided for @excelSuccessLabel.
  ///
  /// In en, this message translates to:
  /// **'Excel generated successfully'**
  String get excelSuccessLabel;

  /// No description provided for @excelGenerated.
  ///
  /// In en, this message translates to:
  /// **'Excel generated: {path}'**
  String excelGenerated(String path);

  /// No description provided for @excelErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error generating Excel'**
  String get excelErrorLabel;

  /// No description provided for @excelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export to Excel'**
  String get excelTooltip;

  /// No description provided for @checklistPdfTooltip.
  ///
  /// In en, this message translates to:
  /// **'Checklist PDF'**
  String get checklistPdfTooltip;

  /// No description provided for @checklistPdfOpenError.
  ///
  /// In en, this message translates to:
  /// **'Error opening checklist PDF: {error}'**
  String checklistPdfOpenError(String error);

  /// No description provided for @towerTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Tower type'**
  String get towerTypeLabel;

  /// No description provided for @towerTypeFourSections.
  ///
  /// In en, this message translates to:
  /// **'4 sections (up to S4)'**
  String get towerTypeFourSections;

  /// No description provided for @towerTypeFiveSections.
  ///
  /// In en, this message translates to:
  /// **'5 sections (up to S5)'**
  String get towerTypeFiveSections;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @chooseDateButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get chooseDateButtonLabel;

  /// No description provided for @newWalkdownDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New Walkdown'**
  String get newWalkdownDialogTitle;

  /// No description provided for @projectNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get projectNameLabel;

  /// No description provided for @projectNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get projectNumberLabel;

  /// No description provided for @supervisorLabel.
  ///
  /// In en, this message translates to:
  /// **'Supervisor'**
  String get supervisorLabel;

  /// No description provided for @roadLabel.
  ///
  /// In en, this message translates to:
  /// **'Road'**
  String get roadLabel;

  /// No description provided for @towerLabel.
  ///
  /// In en, this message translates to:
  /// **'Tower'**
  String get towerLabel;

  /// No description provided for @fieldRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequiredLabel;

  /// No description provided for @checklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Checklist Complete - Generate PDF'**
  String get checklistTitle;

  /// No description provided for @editWalkdownChecklistLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit Walkdown Checklist'**
  String get editWalkdownChecklistLabel;

  /// No description provided for @checklistTemplateLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading checklist editor: {error}'**
  String checklistTemplateLoadError(String error);

  /// No description provided for @checklistTemplatePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Walkdown Checklist'**
  String get checklistTemplatePageTitle;

  /// No description provided for @checklistTemplateRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get checklistTemplateRefreshTooltip;

  /// No description provided for @checklistTemplateNewSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'New section'**
  String get checklistTemplateNewSectionLabel;

  /// No description provided for @checklistTemplateEmptyState.
  ///
  /// In en, this message translates to:
  /// **'There are no configured sections yet.'**
  String get checklistTemplateEmptyState;

  /// No description provided for @checklistTemplateSectionDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete section'**
  String get checklistTemplateSectionDeleteTitle;

  /// No description provided for @checklistTemplateSectionDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'The section \"{sectionTitle}\" and all its phrases will be deleted. Continue?'**
  String checklistTemplateSectionDeleteMessage(String sectionTitle);

  /// No description provided for @checklistTemplateItemDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete phrase'**
  String get checklistTemplateItemDeleteTitle;

  /// No description provided for @checklistTemplateItemDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete the phrase \"{itemText}\" from section {sectionTitle}?'**
  String checklistTemplateItemDeleteMessage(String itemText, String sectionTitle);

  /// No description provided for @checklistTemplateAllTowers.
  ///
  /// In en, this message translates to:
  /// **'All towers'**
  String get checklistTemplateAllTowers;

  /// No description provided for @checklistTemplateFourSectionsOnly.
  ///
  /// In en, this message translates to:
  /// **'4-section towers only'**
  String get checklistTemplateFourSectionsOnly;

  /// No description provided for @checklistTemplateFiveSectionsOnly.
  ///
  /// In en, this message translates to:
  /// **'5-section towers only'**
  String get checklistTemplateFiveSectionsOnly;

  /// No description provided for @checklistTemplateSectionSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} phrase(s) • {scope}'**
  String checklistTemplateSectionSummary(int count, String scope);

  /// No description provided for @checklistTemplateNewPhraseTooltip.
  ///
  /// In en, this message translates to:
  /// **'New phrase'**
  String get checklistTemplateNewPhraseTooltip;

  /// No description provided for @checklistTemplateEditSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit section'**
  String get checklistTemplateEditSectionLabel;

  /// No description provided for @checklistTemplateDeleteSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete section'**
  String get checklistTemplateDeleteSectionLabel;

  /// No description provided for @checklistTemplateEmptySection.
  ///
  /// In en, this message translates to:
  /// **'No phrases in this section.'**
  String get checklistTemplateEmptySection;

  /// No description provided for @checklistTemplateNoEnglishTranslation.
  ///
  /// In en, this message translates to:
  /// **'No English translation'**
  String get checklistTemplateNoEnglishTranslation;

  /// No description provided for @checklistTemplateEditPhraseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit phrase'**
  String get checklistTemplateEditPhraseTooltip;

  /// No description provided for @checklistTemplateDeletePhraseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete phrase'**
  String get checklistTemplateDeletePhraseTooltip;

  /// No description provided for @checklistTemplateEditSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit section'**
  String get checklistTemplateEditSectionTitle;

  /// No description provided for @checklistTemplateCreateSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'New section'**
  String get checklistTemplateCreateSectionTitle;

  /// No description provided for @checklistTemplateTitlePtLabel.
  ///
  /// In en, this message translates to:
  /// **'Portuguese title'**
  String get checklistTemplateTitlePtLabel;

  /// No description provided for @checklistTemplateTitleEnLabel.
  ///
  /// In en, this message translates to:
  /// **'English title'**
  String get checklistTemplateTitleEnLabel;

  /// No description provided for @checklistTemplateApplyToLabel.
  ///
  /// In en, this message translates to:
  /// **'Apply to'**
  String get checklistTemplateApplyToLabel;

  /// No description provided for @checklistTemplateAllTowersOption.
  ///
  /// In en, this message translates to:
  /// **'All towers'**
  String get checklistTemplateAllTowersOption;

  /// No description provided for @checklistTemplateFourSectionsOption.
  ///
  /// In en, this message translates to:
  /// **'4-section towers'**
  String get checklistTemplateFourSectionsOption;

  /// No description provided for @checklistTemplateFiveSectionsOption.
  ///
  /// In en, this message translates to:
  /// **'5-section towers'**
  String get checklistTemplateFiveSectionsOption;

  /// No description provided for @checklistTemplateEditPhraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit phrase'**
  String get checklistTemplateEditPhraseTitle;

  /// No description provided for @checklistTemplateCreatePhraseTitle.
  ///
  /// In en, this message translates to:
  /// **'New phrase'**
  String get checklistTemplateCreatePhraseTitle;

  /// No description provided for @checklistTemplatePhrasePtLabel.
  ///
  /// In en, this message translates to:
  /// **'Portuguese phrase'**
  String get checklistTemplatePhrasePtLabel;

  /// No description provided for @checklistTemplatePhraseEnLabel.
  ///
  /// In en, this message translates to:
  /// **'English phrase'**
  String get checklistTemplatePhraseEnLabel;

  /// No description provided for @checklistPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get checklistPageTitle;

  /// No description provided for @checklistOccurrencesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Occurrences'**
  String get checklistOccurrencesTooltip;

  /// No description provided for @checklistProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get checklistProgressLabel;

  /// No description provided for @checklistCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Checklist complete'**
  String get checklistCompleteTitle;

  /// No description provided for @checklistCompleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Mark this walkdown as complete?'**
  String get checklistCompleteQuestion;

  /// No description provided for @checklistCompleteConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get checklistCompleteConfirmLabel;

  /// No description provided for @checklistMarkedCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Walkdown marked as complete!'**
  String get checklistMarkedCompletedMessage;

  /// No description provided for @checklistMarkCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Mark Complete'**
  String get checklistMarkCompletedLabel;

  /// No description provided for @uploadCompressionProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Compressing and uploading...'**
  String get uploadCompressionProgressLabel;

  /// No description provided for @noPhotosLabel.
  ///
  /// In en, this message translates to:
  /// **'No photos'**
  String get noPhotosLabel;

  /// No description provided for @uploadPhotoSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Compressed photo uploaded ({current}/4).'**
  String uploadPhotoSuccessMessage(int current);

  /// No description provided for @genericErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String genericErrorLabel(String error);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'pt': return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
