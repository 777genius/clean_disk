// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'clean_disk_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class CleanDiskLocalizationsRu extends CleanDiskLocalizations {
  CleanDiskLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Clean Disk';

  @override
  String get scanHomeShellTitle => 'Каркас workspace';

  @override
  String get scanHomeShellDescription =>
      'Нативная интеграция сканирования пока намеренно не подключена.';

  @override
  String get scanAction => 'Сканировать';

  @override
  String get scanAgainAction => 'Сканировать снова';

  @override
  String get pauseAction => 'Пауза';

  @override
  String get cancelScanAction => 'Остановить сканирование';

  @override
  String get searchPlaceholder => 'Поиск файлов и папок...';

  @override
  String get searchUnavailablePlaceholder => 'Поиск после скана';

  @override
  String get sortFilterAction => 'Сортировка / фильтр';

  @override
  String get sortSizeDescLabel => 'Размер';

  @override
  String get sortSizeAscLabel => 'Меньше';

  @override
  String get sortLargestFirstLabel => 'Сначала крупные';

  @override
  String get sortSmallestFirstLabel => 'Сначала мелкие';

  @override
  String get sortNameAscLabel => 'Имя A-Z';

  @override
  String get sortNameDescLabel => 'Имя Z-A';

  @override
  String get searchResultsTitle => 'Результаты поиска';

  @override
  String searchResultsText({required String query}) {
    return 'Поиск: \"$query\"';
  }

  @override
  String get searchBackToTreeAction => 'К дереву';

  @override
  String get topItemsResultsTitle => 'Крупные элементы';

  @override
  String get topItemsResultsText => 'Показан плоский список крупных элементов';

  @override
  String get settingsAction => 'Настройки';

  @override
  String get targetHome => 'Дом';

  @override
  String get targetDownloads => 'Загрузки';

  @override
  String get targetLibrary => 'Библиотека';

  @override
  String get targetApplications => 'Приложения';

  @override
  String get targetCustom => 'Папка';

  @override
  String get targetPickAction => 'Выбрать папку';

  @override
  String get targetChangeAction => 'Сменить папку';

  @override
  String get targetRoot => 'Системный диск';

  @override
  String get targetVolume => 'Диск';

  @override
  String get firstRunTargetTitle => 'Что сканировать?';

  @override
  String get firstRunTargetText =>
      'Выбери папку или диск, чтобы результаты были привязаны к явной цели.';

  @override
  String get totalScannedLabel => 'Просканировано';

  @override
  String get largestFolderLabel => 'Самая большая папка';

  @override
  String get cleanupCandidatesLabel => 'Список проверки';

  @override
  String get skippedLabel => 'Пропущено';

  @override
  String get nameColumn => 'Имя';

  @override
  String get sizeColumn => 'Размер';

  @override
  String get percentColumn => '%';

  @override
  String get itemsColumn => 'Кол.';

  @override
  String get detailsTitle => 'Детали';

  @override
  String get noSelectionTitle => 'Выбери строку';

  @override
  String get noSelectionText => 'Детали появятся после выбора строки.';

  @override
  String get noRowsTitle => 'Данных сканирования пока нет';

  @override
  String get noRowsText => 'Результаты появятся здесь после скана.';

  @override
  String get loadingRowsTitle => 'Загрузка данных сканирования';

  @override
  String get loadingRowsText =>
      'Текущие строки остаются видимыми, пока грузится следующая страница.';

  @override
  String get errorRowsTitle => 'Данные сканирования недоступны';

  @override
  String get staleRowsTitle => 'Данные устарели';

  @override
  String get staleRowsText =>
      'Запусти сканирование снова, чтобы обновить дерево.';

  @override
  String get partialRowsTitle => 'Неполные данные сканирования';

  @override
  String get partialRowsText =>
      'Некоторые пути пропущены или деградировали. Проверь детали перед действиями.';

  @override
  String get revealAction => 'Показать';

  @override
  String get revealBusyAction => 'Открываю...';

  @override
  String get revealUnavailableDisplayPath =>
      'Полный путь для этой строки недоступен. Раскрой дерево от корня, чтобы открыть ее.';

  @override
  String get addToQueueAction => 'В список';

  @override
  String get reviewAddedAction => 'В списке';

  @override
  String get movedToTrashRowLabel => 'В корзине';

  @override
  String get movedToTrashDetailsHint =>
      'Этот элемент уже перемещен в корзину. Запусти новый скан, чтобы обновить дерево перед повторным действием.';

  @override
  String get detailsPathLabel => 'Путь';

  @override
  String get detailsCreatedLabel => 'Создано';

  @override
  String get detailsModifiedLabel => 'Изменено';

  @override
  String get detailsChildrenLabel => 'Файлы / папки';

  @override
  String get detailsWarningsLabel => 'Предупреждения';

  @override
  String get detailsItemsSuffix => 'элементов';

  @override
  String detailsItemsCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента',
      many: '$count элементов',
      few: '$count элемента',
      one: '$count элемент',
      zero: '0 элементов',
    );
    return '$_temp0';
  }

  @override
  String get detailsTypeLabel => 'Тип';

  @override
  String get detailsAccountingLabel => 'Учет размера';

  @override
  String get detailsConfidenceLabel => 'Достоверность';

  @override
  String get detailsFlagsLabel => 'Флаги';

  @override
  String get nodeTypeFile => 'Файл';

  @override
  String get nodeTypeDirectory => 'Папка';

  @override
  String get nodeTypeSymlink => 'Ссылка';

  @override
  String get nodeTypeOther => 'Другое';

  @override
  String get nodeTypeUnknown => 'Неизвестно';

  @override
  String get sizeQuantityApparent => 'Видимый размер';

  @override
  String get sizeQuantityAllocated => 'Занято на диске';

  @override
  String get sizeQuantityBlocks => 'Блоки';

  @override
  String get sizeQuantityUnknown => 'Неизвестно';

  @override
  String get sizeConfidenceExact => 'Точно';

  @override
  String get sizeConfidenceHigh => 'Высокая';

  @override
  String get sizeConfidenceMedium => 'Средняя';

  @override
  String get sizeConfidenceLow => 'Низкая';

  @override
  String get sizeConfidenceUnknown => 'Неизвестно';

  @override
  String get nodeFlagsNone => 'Нет';

  @override
  String get nodeFlagHidden => 'Скрыто';

  @override
  String get nodeFlagSystem => 'Системное';

  @override
  String get nodeFlagPackage => 'Пакет';

  @override
  String get nodeFlagSymlink => 'Ссылка';

  @override
  String get loadMoreRowsAction => 'Показать еще';

  @override
  String get loadMoreRowsBusy => 'Загрузка...';

  @override
  String get deleteQueueTitle => 'Список проверки';

  @override
  String get deleteQueueEmpty =>
      'Отметь строку, чтобы проверить перед перемещением в корзину.';

  @override
  String deleteQueueMoreCount({required int count}) {
    return '+$count еще';
  }

  @override
  String deleteQueueTotalIntent({required String size}) {
    return 'Оценка размера: $size';
  }

  @override
  String get deleteQueueRemoveAction => 'Убрать из списка';

  @override
  String get cleanupPreviewRefreshAction => 'Проверить список';

  @override
  String get cleanupPreviewBlocked =>
      'Нужно проверить блокеры перед любыми действиями.';

  @override
  String get cleanupPreviewReady =>
      'Список проверен. Можно переместить в корзину.';

  @override
  String get cleanupPreviewBlockedShort => 'Проверить';

  @override
  String get cleanupPreviewReadyShort => 'Готово';

  @override
  String get cleanupPreviewTrashAction => 'В корзину';

  @override
  String get cleanupPreviewTrashNoticeTitle => 'Только системная корзина';

  @override
  String get cleanupPreviewTrashNoticeText =>
      'Clean Disk повторно проверяет текущий snapshot перед перемещением. Безвозвратного удаления здесь нет.';

  @override
  String get cleanupConfirmTitle => 'Переместить выбранное в корзину?';

  @override
  String get cleanupConfirmText =>
      'Выбранные файлы или папки будут перемещены в системную корзину. При необходимости их можно восстановить вручную.';

  @override
  String cleanupConfirmSummary({required int count, required String size}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count объекта, $size',
      many: '$count объектов, $size',
      few: '$count объекта, $size',
      one: '1 объект, $size',
    );
    return '$_temp0';
  }

  @override
  String get cleanupConfirmCancel => 'Отмена';

  @override
  String get cleanupConfirmMove => 'В корзину';

  @override
  String get nodeContextRefreshFolderAction => 'Обновить папку';

  @override
  String get cleanupStateStaleSnapshot => 'Устаревшие данные';

  @override
  String get cleanupStateChangedMetadata => 'Метаданные изменились';

  @override
  String get cleanupStateMissingPermission => 'Нет доступа';

  @override
  String get cleanupStatePolicyConflict => 'Нужна проверка';

  @override
  String get cleanupStateUnknownReclaim => 'Размер неизвестен';

  @override
  String get cleanupReceiptReady => 'Receipt записан.';

  @override
  String get cleanupReceiptNeedsReview => 'Receipt требует проверки.';

  @override
  String get cleanupReceiptItemMoved => 'Перемещено в корзину';

  @override
  String get cleanupReceiptItemBlocked => 'Заблокировано';

  @override
  String get cleanupReceiptItemFailed => 'Ошибка';

  @override
  String get cleanupReceiptItemUnknown => 'Результат неизвестен';

  @override
  String get cleanupReceiptItemPending => 'Ожидает';

  @override
  String get reclaimConfidenceHigh => 'Высокая уверен.';

  @override
  String get reclaimConfidenceMedium => 'Средняя уверен.';

  @override
  String get reclaimConfidenceLow => 'Низкая уверен.';

  @override
  String get reclaimConfidenceUnknown => 'Оценка неизвестна';

  @override
  String get progressFilesScannedLabel => 'Файлы';

  @override
  String get progressElapsedLabel => 'Время';

  @override
  String get progressThroughputLabel => 'Скорость';

  @override
  String get progressItemsPerSecondSuffix => 'элем./с';

  @override
  String get metricNoDataValue => 'Нет данных';

  @override
  String get metricRunScanSubtitle => 'После скана';

  @override
  String get filesCountSuffix => 'файлов';

  @override
  String get metricCleanupReviewSubtitle => 'Отмеченные элементы';

  @override
  String get metricSkippedProtectedSubtitle => 'Системная защита';

  @override
  String get driveFreeSpaceText => '108.0 GB свободно';

  @override
  String get permissionProofTitle => 'Проверка доступа';

  @override
  String get permissionWarningTitle => 'Доступ не проверен';

  @override
  String get permissionWarningDevTitle => 'Dev-сборка';

  @override
  String get permissionWarningDeniedText =>
      'Доступ запрещен. Защищенные папки могут быть пропущены.';

  @override
  String get permissionWarningUnverifiedText =>
      'Доступ еще не проверен. Запусти проверку или сканирование.';

  @override
  String get permissionNeutralProbeText => 'Доступ проверим перед сканом.';

  @override
  String get permissionWarningDevIdentityText =>
      'Доступ подтвержден. В подписанной версии Full Disk Access может отличаться.';

  @override
  String get permissionIdentityLabel => 'Подпись';

  @override
  String get permissionProbeLabel => 'Доступ';

  @override
  String get permissionScannerLabel => 'Сканер';

  @override
  String get permissionActionLabel => 'Действие';

  @override
  String get permissionPackageLabel => 'Пакет';

  @override
  String get permissionUpdateLabel => 'Обновл.';

  @override
  String get permissionCheckedLabel => 'Проверено';

  @override
  String get permissionProbeAction => 'Проверить';

  @override
  String get permissionRepairTitle => 'Исправить доступ';

  @override
  String get permissionRepairTrustCopy =>
      'Clean Disk читает имена файлов, размеры, время изменения и структуру папок для выбранной цели. Содержимое файлов не читается.';

  @override
  String get permissionRepairMacosStepOne =>
      'Открой Privacy & Security > Full Disk Access.';

  @override
  String get permissionRepairMacosStepTwo =>
      'Включи Clean Disk или clean-disk-server, если macOS показывает bundled helper.';

  @override
  String get permissionRepairMacosStepThree =>
      'Вернись сюда и нажми Проверить. Сканер подтвердит доступ до статуса Подтверждено.';

  @override
  String get permissionRepairWindowsStepOne =>
      'Сначала используй обычное сканирование от текущего пользователя.';

  @override
  String get permissionRepairWindowsStepTwo =>
      'Если доступ к цели все еще запрещен, используй elevated scan profile только для системных папок.';

  @override
  String get permissionRepairWindowsStepThree =>
      'Перед новым сканированием нажми Проверить.';

  @override
  String get permissionRepairLinuxStepOne =>
      'Проверь права папки для выбранной цели.';

  @override
  String get permissionRepairLinuxStepTwo =>
      'Если app в sandbox, дай доступ через package или portal settings.';

  @override
  String get permissionRepairLinuxStepThree =>
      'Перед новым сканированием нажми Проверить.';

  @override
  String get permissionRepairManualStep =>
      'Проверь platform access для этой цели, затем нажми Проверить.';

  @override
  String get permissionRepairOpenSettings => 'Открыть настройки';

  @override
  String get permissionRepairCancel => 'Отмена';

  @override
  String get permissionIdentityVerified => 'Подтверждено';

  @override
  String get permissionIdentityUnverified => 'Не подтверждено';

  @override
  String get permissionIdentityUnknown => 'Неизвестно';

  @override
  String get permissionProbeVerified => 'Подтверждено';

  @override
  String get permissionProbeDenied => 'Запрещено';

  @override
  String get permissionProbeNotDetermined => 'Не определено';

  @override
  String get permissionProbePending => 'Ожидает проверки';

  @override
  String get permissionProbeDegraded => 'Ограничено';

  @override
  String get permissionProbeUnsupported => 'Не поддерживается';

  @override
  String get permissionProbeUnknown => 'Неизвестно';

  @override
  String get permissionScannerAppBundle => 'App bundle';

  @override
  String get permissionScannerBundledHelper => 'Bundled helper';

  @override
  String get permissionScannerCurrentProcess => 'Текущий процесс';

  @override
  String get permissionScannerExternalProcess => 'Внешний процесс';

  @override
  String get permissionScannerUnknown => 'Сканер неизвестен';

  @override
  String get permissionActionNone => 'Действий не нужно';

  @override
  String get permissionActionMacosFullDiskAccess => 'Full Disk Access';

  @override
  String get permissionActionWindowsAdministrator =>
      'Admin scan только при необходимости';

  @override
  String get permissionActionLinuxPermissions =>
      'Проверь Linux-права и перепроверь';

  @override
  String get permissionActionUnknown => 'Нужна ручная проверка';

  @override
  String get permissionActionReducedPackage => 'Dev - подпись';

  @override
  String get permissionPackageDevelopment => 'Dev';

  @override
  String get permissionPackageAppBundle => 'App bundle';

  @override
  String get permissionPackageBundledDaemon => 'Bundled daemon';

  @override
  String get permissionPackageSystemService => 'System service';

  @override
  String get permissionPackagePortable => 'Portable';

  @override
  String get permissionPackageUnknown => 'Пакет неизвестен';

  @override
  String get permissionSignedBuild => 'Подписано';

  @override
  String get permissionUnsignedBuild => 'Без подп.';

  @override
  String get permissionUpdateQuiesceRequired => 'Нужна пауза';

  @override
  String get permissionUpdateNoQuiesce => 'Пауза не нужна';

  @override
  String get permissionUpdateUnknown => 'Обновл. неизвестно';

  @override
  String get permissionCheckedNever => 'Не проверено';

  @override
  String get permissionCheckedUnknown => 'Время неизвестно';

  @override
  String get scanReadyStatus => 'Готово';

  @override
  String get scanRunningStatus => 'Сканирование...';

  @override
  String get scanCompletedStatus => 'Сканирование завершено';

  @override
  String get scanOfflineStatus => 'Daemon недоступен';

  @override
  String get scanIncompatibleStatus => 'Протокол несовместим';
}
