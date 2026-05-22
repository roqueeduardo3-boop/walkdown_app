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
  String get descriptionRequired => 'A descrição é obrigatória';

  @override
  String get dragPhotosHint => 'Arrasta aqui as fotos (PC)';

  @override
  String get editOccurrenceMessage => 'A editar ocorrência. Clica em Cancelar para criar uma nova.';

  @override
  String get occurrenceUpdatedMessage => 'Ocorrência atualizada';

  @override
  String get occurrenceSavedMessage => 'Ocorrência guardada';

  @override
  String get maxPhotosMessage => 'Máximo de 4 fotos por ocorrência';

  @override
  String photoAddedMessage(int current) {
    return 'Foto adicionada ($current/4).';
  }

  @override
  String get cameraButtonLabel => 'Câmara';

  @override
  String get galleryButtonLabel => 'Galeria';

  @override
  String photosCountLabel(int count) {
    return 'Fotos: $count';
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
  String get cancelButtonLabel => 'Cancelar';

  @override
  String get createdAtLabel => 'Criado em:';

  @override
  String attachedPhotosLabel(int count) {
    return 'Fotos anexadas ($count)';
  }

  @override
  String get noOccurrencesLabel => 'Nenhuma ocorrência registada ainda.';

  @override
  String walkdownsLoaded(int count) {
    return 'Carregado da BD: $count registos';
  }

  @override
  String get newWalkdownButton => 'Novo Walkdown';

  @override
  String get walkdownWelcomeTitle => 'Bem-vindo ao Walkdown 2WS';

  @override
  String get deleteWalkdownTitle => 'Apagar walkdown';

  @override
  String get deleteWalkdownQuestion => 'Tens a certeza de que queres apagar este walkdown?';

  @override
  String get logoutLabel => 'Terminar sessão';

  @override
  String get unsyncedDataTitle => 'Dados por sincronizar';

  @override
  String unsyncedDataMessage(int count) {
    return '$count item(ns) ainda não foram enviados.\n\nQueres sair mesmo assim?';
  }

  @override
  String get exitWithoutSyncLabel => 'Sair sem sincronizar';

  @override
  String get logoutConfirmMessage => 'Tens a certeza de que queres terminar sessão?';

  @override
  String get exitLabel => 'Sair';

  @override
  String get syncUploadTooltip => 'Enviar dados';

  @override
  String get syncDownloadTooltip => 'Baixar dados';

  @override
  String walkdownOccurrencesCount(int count) {
    return '$count ocorrências';
  }

  @override
  String get deleteButtonLabel => 'Apagar';

  @override
  String pdfGenerated(String path) {
    return 'PDF gerado: $path';
  }

  @override
  String get pdfOpenLabel => 'Abrir';

  @override
  String get pdfErrorLabel => 'Erro ao gerar PDF';

  @override
  String get pdfTooltip => 'Gerar PDF';

  @override
  String get excelSuccessLabel => 'Excel gerado com sucesso';

  @override
  String excelGenerated(String path) {
    return 'Excel gerado: $path';
  }

  @override
  String get excelErrorLabel => 'Erro ao gerar Excel';

  @override
  String get excelTooltip => 'Exportar para Excel';

  @override
  String get checklistPdfTooltip => 'PDF da checklist';

  @override
  String checklistPdfOpenError(String error) {
    return 'Erro ao abrir o PDF da checklist: $error';
  }

  @override
  String get towerTypeLabel => 'Tipo de torre';

  @override
  String get towerTypeFourSections => '4 secções (até S4)';

  @override
  String get towerTypeFiveSections => '5 secções (até S5)';

  @override
  String get dateLabel => 'Data';

  @override
  String get chooseDateButtonLabel => 'Escolher data';

  @override
  String get newWalkdownDialogTitle => 'Novo Walkdown';

  @override
  String get projectNameLabel => 'Projeto';

  @override
  String get projectNumberLabel => 'Número';

  @override
  String get supervisorLabel => 'Supervisor';

  @override
  String get roadLabel => 'Estrada';

  @override
  String get towerLabel => 'Torre';

  @override
  String get fieldRequiredLabel => 'Obrigatório';

  @override
  String get checklistTitle => 'Checklist Completo - Gerar PDF';

  @override
  String get editWalkdownChecklistLabel => 'Editar checklist do walkdown';

  @override
  String checklistTemplateLoadError(String error) {
    return 'Erro ao carregar o editor da checklist: $error';
  }

  @override
  String get checklistTemplatePageTitle => 'Editar checklist do walkdown';

  @override
  String get checklistTemplateRefreshTooltip => 'Atualizar';

  @override
  String get checklistTemplateNewSectionLabel => 'Nova secção';

  @override
  String get checklistTemplateEmptyState => 'Ainda não existem secções configuradas.';

  @override
  String get checklistTemplateSectionDeleteTitle => 'Apagar secção';

  @override
  String checklistTemplateSectionDeleteMessage(String sectionTitle) {
    return 'A secção \"$sectionTitle\" e todas as frases associadas serão apagadas. Continuar?';
  }

  @override
  String get checklistTemplateItemDeleteTitle => 'Apagar frase';

  @override
  String checklistTemplateItemDeleteMessage(String itemText, String sectionTitle) {
    return 'Apagar a frase \"$itemText\" da secção $sectionTitle?';
  }

  @override
  String get checklistTemplateAllTowers => 'Todas as torres';

  @override
  String get checklistTemplateFourSectionsOnly => 'Só torres de 4 secções';

  @override
  String get checklistTemplateFiveSectionsOnly => 'Só torres de 5 secções';

  @override
  String checklistTemplateSectionSummary(int count, String scope) {
    return '$count frase(s) • $scope';
  }

  @override
  String get checklistTemplateNewPhraseTooltip => 'Nova frase';

  @override
  String get checklistTemplateEditSectionLabel => 'Editar secção';

  @override
  String get checklistTemplateDeleteSectionLabel => 'Apagar secção';

  @override
  String get checklistTemplateEmptySection => 'Sem frases nesta secção.';

  @override
  String get checklistTemplateNoEnglishTranslation => 'Sem tradução em inglês';

  @override
  String get checklistTemplateEditPhraseTooltip => 'Editar frase';

  @override
  String get checklistTemplateDeletePhraseTooltip => 'Apagar frase';

  @override
  String get checklistTemplateEditSectionTitle => 'Editar secção';

  @override
  String get checklistTemplateCreateSectionTitle => 'Nova secção';

  @override
  String get checklistTemplateTitlePtLabel => 'Título em português';

  @override
  String get checklistTemplateTitleEnLabel => 'Título em inglês';

  @override
  String get checklistTemplateApplyToLabel => 'Aplicar a';

  @override
  String get checklistTemplateAllTowersOption => 'Todas as torres';

  @override
  String get checklistTemplateFourSectionsOption => 'Torres de 4 secções';

  @override
  String get checklistTemplateFiveSectionsOption => 'Torres de 5 secções';

  @override
  String get checklistTemplateEditPhraseTitle => 'Editar frase';

  @override
  String get checklistTemplateCreatePhraseTitle => 'Nova frase';

  @override
  String get checklistTemplatePhrasePtLabel => 'Frase em português';

  @override
  String get checklistTemplatePhraseEnLabel => 'Frase em inglês';

  @override
  String get checklistPageTitle => 'Checklist';

  @override
  String get checklistOccurrencesTooltip => 'Ocorrências';

  @override
  String get checklistProgressLabel => 'Progresso';

  @override
  String get checklistCompleteTitle => 'Checklist completo';

  @override
  String get checklistCompleteQuestion => 'Marcar este walkdown como completo?';

  @override
  String get checklistCompleteConfirmLabel => 'Confirmar';

  @override
  String get checklistMarkedCompletedMessage => 'Walkdown marcado como completo!';

  @override
  String get checklistMarkCompletedLabel => 'Marcar completo';

  @override
  String get uploadCompressionProgressLabel => 'A comprimir e a enviar...';

  @override
  String get noPhotosLabel => 'Sem fotos';

  @override
  String uploadPhotoSuccessMessage(int current) {
    return 'Foto comprimida e enviada ($current/4).';
  }

  @override
  String genericErrorLabel(String error) {
    return 'Erro: $error';
  }
}
