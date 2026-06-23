// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Dispax';

  @override
  String get login => 'Увійти';

  @override
  String get logout => 'Вийти';

  @override
  String get email => 'Електронна пошта';

  @override
  String get password => 'Пароль';

  @override
  String get invalidCredentials => 'Невірна пошта або пароль';

  @override
  String get today => 'Сьогодні';

  @override
  String get tomorrow => 'Завтра';

  @override
  String get yesterday => 'Вчора';

  @override
  String get week => 'Тиждень';

  @override
  String get month => 'Місяць';

  @override
  String get all => 'Все';

  @override
  String get myRides => 'Мої поїздки';

  @override
  String get history => 'Історія';

  @override
  String get map => 'Карта';

  @override
  String get flights => 'Рейси';

  @override
  String get profile => 'Профіль';

  @override
  String get calendar => 'Календар';

  @override
  String get upcoming => 'Майбутні';

  @override
  String get settings => 'Налаштування';

  @override
  String get pendingRides => 'Очікуючі поїздки';

  @override
  String ridesAwaiting(int count) {
    return '$count поїздка(ок) очікує призначення';
  }

  @override
  String get driverSchedules => 'Графіки водіїв';

  @override
  String get noDriversScheduled => 'Водіїв не заплановано';

  @override
  String get noPendingRides => 'Немає очікуючих поїздок';

  @override
  String get allRidesAssigned => 'Всі поїздки призначено';

  @override
  String get selectDriver => 'Обрати водія';

  @override
  String get reassignRide => 'Перепризначити поїздку';

  @override
  String get confirmReassignment => 'Підтвердити перепризначення';

  @override
  String get reassign => 'Перепризначити';

  @override
  String get assign => 'Призначити';

  @override
  String get cancel => 'Скасувати';

  @override
  String get confirm => 'Підтвердити';

  @override
  String get retry => 'Повторити';

  @override
  String get save => 'Зберегти';

  @override
  String get delete => 'Видалити';

  @override
  String get searchClientAddress => 'Пошук клієнта, адреси...';

  @override
  String get searchDriverName => 'Пошук імені водія...';

  @override
  String get airport => 'Аеропорт';

  @override
  String get available => 'Вільний';

  @override
  String get moderate => 'Середній';

  @override
  String get busy => 'Зайнятий';

  @override
  String get sortTimeEarliest => 'Час (найраніші)';

  @override
  String get sortTimeLatest => 'Час (найпізніші)';

  @override
  String get sortClientName => 'Ім\'я клієнта';

  @override
  String nRidesAssigned(int count) {
    return '$count поїздка(ок) призначено';
  }

  @override
  String timeConflicts(int count) {
    return '$count конфлікт(ів) часу';
  }

  @override
  String get dropHereToAssign => 'Перетягніть сюди для призначення';

  @override
  String get todaysHistory => 'Історія за сьогодні';

  @override
  String get thisWeeksHistory => 'Історія за тиждень';

  @override
  String get thisMonthsHistory => 'Історія за місяць';

  @override
  String get allTimeHistory => 'Вся історія';

  @override
  String get rideHistory => 'Історія поїздок';

  @override
  String get myRideHistory => 'Моя історія поїздок';

  @override
  String get noRideHistory => 'Немає історії поїздок';

  @override
  String get completedRidesAppearHere => 'Завершені поїздки з\'являться тут';

  @override
  String get noRidesForPeriod => 'Немає поїздок за цей період';

  @override
  String get completed => 'Завершено';

  @override
  String get cancelled => 'Скасовано';

  @override
  String get earned => 'Зароблено';

  @override
  String get spent => 'Витрачено';

  @override
  String get analytics => 'Аналітика';

  @override
  String get totalRides => 'Всього поїздок';

  @override
  String get completedRides => 'Завершено';

  @override
  String get cancelledRides => 'Скасовано';

  @override
  String get inProgressRides => 'В дорозі';

  @override
  String get requestedRides => 'Запитано';

  @override
  String get assignedRides => 'Призначено';

  @override
  String get activeDrivers => 'Активних водіїв';

  @override
  String get totalClients => 'Всього клієнтів';

  @override
  String get todayRevenue => 'Дохід за сьогодні';

  @override
  String get monthlyRevenue => 'Дохід за місяць';

  @override
  String get avgAssignmentTime => 'Сер. час призначення';

  @override
  String get cancellationRate => '% скасувань';

  @override
  String get driverLoad => 'Завантаженість водіїв';

  @override
  String get dailyOverview => 'Щоденний огляд';

  @override
  String get chat => 'Чат';

  @override
  String get typeMessage => 'Введіть повідомлення...';

  @override
  String get send => 'Надіслати';

  @override
  String get chatUnavailable => 'Чат доступний лише під час активних поїздок';

  @override
  String get noMessages => 'Повідомлень поки немає';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get accountSettings => 'Обліковий запис';

  @override
  String get changePassword => 'Змінити пароль';

  @override
  String get currentPassword => 'Поточний пароль';

  @override
  String get newPassword => 'Новий пароль';

  @override
  String get confirmNewPassword => 'Підтвердити новий пароль';

  @override
  String get passwordChanged => 'Пароль успішно змінено';

  @override
  String get passwordsDoNotMatch => 'Паролі не збігаються';

  @override
  String get passwordTooShort => 'Пароль повинен містити щонайменше 6 символів';

  @override
  String get notifications => 'Сповіщення';

  @override
  String get pushNotifications => 'Push-сповіщення';

  @override
  String get rideUpdates => 'Оновлення поїздок';

  @override
  String get chatMessages => 'Повідомлення чату';

  @override
  String get appearance => 'Зовнішній вигляд';

  @override
  String get theme => 'Тема';

  @override
  String get lightTheme => 'Світла';

  @override
  String get darkTheme => 'Темна';

  @override
  String get systemTheme => 'Системна';

  @override
  String get language => 'Мова';

  @override
  String get english => 'English';

  @override
  String get german => 'Deutsch';

  @override
  String get ukrainian => 'Українська';

  @override
  String get editProfile => 'Редагувати профіль';

  @override
  String get name => 'Ім\'я';

  @override
  String get phone => 'Телефон';

  @override
  String get profileUpdated => 'Профіль успішно оновлено';

  @override
  String get uploadPhoto => 'Завантажити фото';

  @override
  String get changePhoto => 'Змінити фото';

  @override
  String get removePhoto => 'Видалити фото';

  @override
  String get photoUploadedSuccessfully => 'Фото успішно завантажено';

  @override
  String get failedToUploadPhoto => 'Не вдалося завантажити фото';

  @override
  String get security => 'Безпека';

  @override
  String get biometricLogin => 'Біометричний вхід';

  @override
  String get about => 'Про додаток';

  @override
  String get version => 'Версія';

  @override
  String get privacyPolicy => 'Політика конфіденційності';

  @override
  String get termsOfService => 'Умови використання';

  @override
  String get superAdminDashboard => 'Адміністратор платформи';

  @override
  String get companies => 'Компанії';

  @override
  String get companiesList => 'Список компаній';

  @override
  String get platformAnalytics => 'Аналітика платформи';

  @override
  String get platformRevenue => 'Дохід платформи';

  @override
  String get activeConnections => 'Активні з\'єднання';

  @override
  String get companyStatus => 'Статус компанії';

  @override
  String get subscriptionPlan => 'План підписки';

  @override
  String get billingAnalytics => 'Аналітика рахунків';

  @override
  String get connectionAnalytics => 'Аналітика підключень';

  @override
  String get superAdminSettings => 'Налаштування платформи';

  @override
  String get addCompany => 'Додати компанію';

  @override
  String get editCompany => 'Редагувати компанію';

  @override
  String get deleteCompany => 'Деактивувати компанію';

  @override
  String get deactivateCompanyConfirm =>
      'Ви впевнені, що хочете деактивувати цю компанію? Компанію буде позначено як Неактивну, але всі дані будуть збережені.';

  @override
  String get companyName => 'Назва компанії';

  @override
  String get companyEmail => 'Email компанії';

  @override
  String get companyPhone => 'Телефон компанії';

  @override
  String get companyAddress => 'Адреса компанії';

  @override
  String get checkpointLanded => 'Приземлився';

  @override
  String get checkpointArrivalsHall => 'Зал прильотів';

  @override
  String get checkpointTerminalExit => 'Вихід з терміналу';

  @override
  String get markCheckpointButton => 'Я тут';

  @override
  String get airportCheckpointPanelTitle => 'Моє місце в терміналі';

  @override
  String checkpointNotifTitle(String checkpoint) {
    return 'Клієнт досяг $checkpoint';
  }

  @override
  String checkpointNotifBody(String checkpointName) {
    return 'Ваш клієнт знаходиться біля $checkpointName.';
  }

  @override
  String get airportExits => 'Виходи з аеропорту';

  @override
  String get addAirport => 'Додати аеропорт';

  @override
  String get editAirport => 'Редагувати аеропорт';

  @override
  String get deleteAirport => 'Деактивувати аеропорт';

  @override
  String get airportCode => 'Код аеропорту (напр. MUC)';

  @override
  String get airportName => 'Назва аеропорту';

  @override
  String get addZone => 'Додати зону';

  @override
  String get editZone => 'Редагувати зону';

  @override
  String get deleteZone => 'Видалити зону';

  @override
  String get terminalCode => 'Термінал (T1, T2, …)';

  @override
  String get checkpointType => 'Тип контрольної точки';

  @override
  String get displayName => 'Назва для відображення';

  @override
  String get latitude => 'Широта';

  @override
  String get longitude => 'Довгота';

  @override
  String get radiusMeters => 'Радіус (метри)';

  @override
  String get landingGeofence => 'Геозона посадки';

  @override
  String get pickOnMap => 'Вибрати на карті';

  @override
  String get scheduleVisibility => 'Видимість розкладу';

  @override
  String get allowViewOtherSchedules => 'Дозволити перегляд розкладів колег';

  @override
  String viewingDriverSchedule(String driverName) {
    return 'Перегляд: $driverName';
  }

  @override
  String get flightDepartureTime => 'Час відправлення рейсу';

  @override
  String get manualPickupTimeOptional =>
      'Час подачі (необов\'язково — буде розраховано, якщо не вказано)';

  @override
  String confirmedPickupTime(String time) {
    return 'Підтверджена подача: $time';
  }

  @override
  String get pickupTimeComputedAuto =>
      'Розраховано автоматично на основі часу відправлення рейсу';

  @override
  String get markUnavailable => 'Позначити як недоступний';

  @override
  String get driverUnavailable => 'Водій недоступний';

  @override
  String get unavailabilityReason => 'Причина';

  @override
  String get unavailabilityNote => 'Нотатка (необов\'язково)';

  @override
  String get unavailabilityFrom => 'Від';

  @override
  String get unavailabilityTo => 'До';

  @override
  String get unavailabilityReasonLunch => 'Обід';

  @override
  String get unavailabilityReasonVacation => 'Відпустка';

  @override
  String get unavailabilityReasonPersonal => 'Особисте';

  @override
  String get driverHasScheduleConflict => 'Водій зайнятий у цей час';

  @override
  String get assignAnywayTitle => 'Водій зайнятий';

  @override
  String assignAnywayMessage(String reason) {
    return 'У цього водія є конфлікт розкладу: $reason. Все одно призначити?';
  }

  @override
  String get assignAnyway => 'Призначити все одно';

  @override
  String get unavailabilityCreated => 'Недоступність успішно позначена';

  @override
  String get unavailabilityDeleted => 'Недоступність видалена';

  @override
  String get noUnavailability => 'Немає вікон недоступності';

  @override
  String get preferences => 'Налаштування';

  @override
  String get faceIdUnlock => 'Face ID розблокування';

  @override
  String get darkMode => 'Темний режим';

  @override
  String get general => 'Загальне';

  @override
  String get activeSessions => 'Активні сесії';

  @override
  String get earnings => 'Заробіток';

  @override
  String get myEarnings => 'Мій заробіток';

  @override
  String get privacy => 'Конфіденційність';

  @override
  String get privacyDataGdpr => 'Конфіденційність та дані (GDPR)';

  @override
  String get signOut => 'Вийти';

  @override
  String get signOutConfirm => 'Ви впевнені, що хочете вийти?';

  @override
  String get required => 'Обов\'язкове поле';

  @override
  String get change => 'Змінити';

  @override
  String get failedToChangePassword => 'Не вдалося змінити пароль';

  @override
  String get welcomeBack => 'З поверненням';

  @override
  String get signInSubtitle => 'Увійдіть у свій обліковий запис диспетчера.';

  @override
  String get signIn => 'Увійти';

  @override
  String get forgotPassword => 'Забули пароль?';

  @override
  String get faceId => 'Face ID';

  @override
  String get roleDriver => 'Водій';

  @override
  String get roleClient => 'Клієнт';

  @override
  String get roleSecretary => 'Секретар';

  @override
  String get roleClientSecretary => 'Секретар клієнта';

  @override
  String get roleDispatcher => 'Диспетчер';

  @override
  String get roleAdmin => 'Адмін';

  @override
  String get roleSuperAdmin => 'Супер Адмін';

  @override
  String get languageSaveFailed => 'Не вдалося зберегти мову в обліковий запис';

  @override
  String get billingScreenTitle => 'Білінг';

  @override
  String get invoicesTab => 'Рахунки';

  @override
  String get companiesTab => 'Компанії';

  @override
  String get billingRidesTab => 'Поїздки';

  @override
  String invoicesCountSubtitle(String month, int count) {
    return '$month · $count Рахунків';
  }

  @override
  String get outstandingInvoices => 'Непогашено';

  @override
  String get paidThisMonth => 'Сплачено (Місяць)';

  @override
  String get overdueInvoices => 'Прострочено';

  @override
  String get collectionRate => 'Коефіцієнт збору';

  @override
  String get exportDatevButton => 'Експорт DATEV';

  @override
  String get createNewInvoiceButton => '+ Новий рахунок';

  @override
  String get datevExportOpening => 'Відкриття DATEV Export...';

  @override
  String get createCompanyFirst => 'Будь ласка, спочатку створіть компанію.';

  @override
  String get newInvoiceTitle => 'Новий рахунок';

  @override
  String get companiesLabel => 'Компанія *';

  @override
  String get createInvoiceButton => 'Створити рахунок';

  @override
  String get allInvoicesFilter => 'Всі';

  @override
  String get draftStatusFilter => 'Чернетка';

  @override
  String get sentStatusFilter => 'Відправлено';

  @override
  String get paidStatusFilter => 'Оплачено';

  @override
  String get invoiceTableHeaderNumber => 'РАХУНОК';

  @override
  String get invoiceTableHeaderClient => 'КЛІЄНТ';

  @override
  String get invoiceTableHeaderAmount => 'СУМА';

  @override
  String get overdueStatus => 'Прострочено';

  @override
  String get paymentReminderSent => 'Нагадування про оплату відправлено';

  @override
  String get viewDetailsMenu => 'Деталі';

  @override
  String get gobdCompliant =>
      'GoBD-відповідність — рахунки незмінно заархівовані.';

  @override
  String get noCompanies => 'Немає компаній';

  @override
  String get noInvoices => 'Немає рахунків';

  @override
  String get editCompanyMenu => 'Редагувати';

  @override
  String get deleteCompanyMenu => 'Видалити';

  @override
  String get addCompanyTitle => 'Додати компанію';

  @override
  String get editCompanyTitle => 'Редагувати компанію';

  @override
  String get companyNameLabel => 'Назва *';

  @override
  String get companyEmailLabel => 'Електронна пошта';

  @override
  String get companyPhoneLabel => 'Телефон';

  @override
  String get companyAddressLabel => 'Адреса';

  @override
  String get invoiceLanguageLabel => 'Мова рахунку';

  @override
  String get languageStandard => 'За замовчуванням';

  @override
  String get languageGerman => 'Німецька';

  @override
  String get languageEnglish => 'Англійська';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get addCompanyButton => 'Додати';

  @override
  String get deleteCompanyConfirmTitle => 'Видалити компанію?';

  @override
  String deleteCompanyConfirmMsg(String name) {
    return '$name буде видалено.';
  }

  @override
  String get downloadPdfTooltip => 'Завантажити';

  @override
  String get closeTooltip => 'Закрити';

  @override
  String get closeButton => 'Закрити';

  @override
  String pdfPreviewTitle(String number) {
    return 'Перегляд · $number';
  }

  @override
  String get invoiceLineItems => 'Позиції';

  @override
  String get subtotalLabel => 'Проміжний підсумок';

  @override
  String vatLineLabel(String rate) {
    return 'ПДВ $rate%';
  }

  @override
  String totalLabel(String currency) {
    return 'Разом ($currency)';
  }

  @override
  String get autoFillRidesButton => 'Автозавантажити поїздки';

  @override
  String get sendInvoiceButton => 'Відправити рахунок';

  @override
  String get markAsPaidButton => 'Позначити як оплачено';

  @override
  String get pdfDownloadSuccess => 'PDF завантажено';

  @override
  String get downloadPdfButton => 'Завантажити PDF';

  @override
  String get previewButton => 'Перегляд';

  @override
  String reminderBadgeLabel(String date) {
    return 'Нагадано $date';
  }

  @override
  String get invoicesRailLabel => 'Рахунки';

  @override
  String get clientsRailLabel => 'Клієнти';

  @override
  String get datevRailLabel => 'DATEV';

  @override
  String genericError(String error) {
    return 'Помилка: $error';
  }

  @override
  String get unbilledRidesTitle => 'Нерозрахованих поїздок';

  @override
  String get selectRidesToBill => 'Оберіть поїздки для виставлення рахунку';

  @override
  String ridesBillingCountSelected(int count) {
    return '$count вибрано';
  }

  @override
  String ridesBillingCountAvailable(int count) {
    return '$count поїздок';
  }

  @override
  String get selectCompanyForBilling =>
      'Виберіть компанію для перегляду поїздок.';

  @override
  String get noBillableRides => 'Немає поїздок для виставлення рахунку';

  @override
  String get receiptTooltip => 'Квитанція';

  @override
  String get receiptTitle => 'Квитанція';

  @override
  String selectedRidesSummary(String subtotal, String total) {
    return 'Вибрано: $subtotal нетто · $total всього';
  }

  @override
  String get noRidesSelected => 'Поїздок не вибрано';

  @override
  String get vatPercentLabel => 'ПДВ %';

  @override
  String get invoiceCreatedTitle => 'Рахунок створено';

  @override
  String invoiceCreatedMsg(String number, int count, String amount) {
    return '$number · $count поїздок · €$amount';
  }

  @override
  String pdfDownloadError(String error) {
    return 'Помилка PDF: $error';
  }

  @override
  String receiptDownloadError(String error) {
    return 'Помилка квитанції: $error';
  }

  @override
  String get datevExportTitle => 'DATEV Експорт';

  @override
  String noDataForMonth(String monthLabel) {
    return 'Немає даних за $monthLabel';
  }

  @override
  String get revenueSection => 'Доходи';

  @override
  String rowsCountLabel(int count) {
    return '$count рядків';
  }

  @override
  String get copyCsvTooltip => 'Копіювати CSV';

  @override
  String get revenueCsvLabel => 'CSV доходів';

  @override
  String get expensesSection => 'Витрати';

  @override
  String get expensesCsvLabel => 'CSV витрат';

  @override
  String get summarySection => 'Підсумок';

  @override
  String netIncomeResult(String amount) {
    return 'Результат: $amount';
  }

  @override
  String get copySummaryCsvTooltip => 'Копіювати підсумок';

  @override
  String get summaryCsvLabel => 'Підсумок';

  @override
  String copiedToClipboard(String label) {
    return '$label скопійовано в буфер обміну';
  }

  @override
  String get copyAllRevenueHeader => '=== Доходи ===';

  @override
  String get copyAllExpensesHeader => '=== Витрати ===';

  @override
  String get copyAllSummaryHeader => '=== Підсумок ===';

  @override
  String get allDatevDataLabel => 'Всі дані DATEV';

  @override
  String downloadFailed(String code) {
    return 'Завантаження не вдалось: $code';
  }

  @override
  String get netIncomeLabel => 'Чистий дохід';

  @override
  String get copyAllButton => 'Копіювати все';

  @override
  String get downloadCsvExtfButton => 'Завантажити .csv (EXTF)';

  @override
  String get datevExtfFormatInfo =>
      'Формат DATEV Buchungsstapel – Імпорт через DATEV Unternehmen Online';

  @override
  String expensesScreenTitle(String monthLabel) {
    return 'Витрати · $monthLabel';
  }

  @override
  String get addExpenseTooltip => 'Записати витрату';

  @override
  String get captureExpenseTitle => 'Записати витрату';

  @override
  String get expenseCategoryLabel => 'Категорія';

  @override
  String get expenseAmountLabel => 'Сума (EUR)';

  @override
  String get expenseDescriptionLabel => 'Опис (необов\'язково)';

  @override
  String get invalidAmountError => 'Введіть коректну суму';

  @override
  String get deleteExpenseConfirmTitle => 'Видалити витрату?';

  @override
  String deleteExpenseConfirmMsg(String category, String amount) {
    return '$category · €$amount буде видалено.';
  }

  @override
  String get noExpenses => 'Немає витрат';

  @override
  String get noReceiptWarning => 'Немає квитанції';

  @override
  String get totalExpensesLabel => 'Всього';

  @override
  String get newRideAssigned => 'Нова поїздка призначена';

  @override
  String get newRideAssignedContent => 'Вам призначено нову поїздку. Прийняти?';

  @override
  String get decline => 'Відхилити';

  @override
  String get accept => 'Прийняти';

  @override
  String get call => 'Зателефонувати';

  @override
  String get sms => 'SMS';

  @override
  String get completeRideTitle => 'Завершити поїздку';

  @override
  String get navigate => 'Навігація';

  @override
  String get navigateTo => 'Маршрут до';

  @override
  String get googleMapsPickup => 'Google Maps — Посадка';

  @override
  String get googleMapsDropoff => 'Google Maps — Висадка';

  @override
  String get openingNavigation => 'Відкриття навігації в Google Maps...';

  @override
  String arrivingInMinutes(int etaMinutes) {
    return 'Прибуття через $etaMinutes хв';
  }

  @override
  String get noCompletedRides => 'Ще немає завершених поїздок';

  @override
  String get refresh => 'Оновити';

  @override
  String get youreOnline => 'Ви онлайн';

  @override
  String get youreOffline => 'Ви офлайн';

  @override
  String get discardChangesTitle => 'Відхилити зміни?';

  @override
  String get discardChangesMessage =>
      'У вас є незбережені деталі поїздки. Якщо ви підете, вони будуть втрачені.';

  @override
  String get stay => 'Залишитись';

  @override
  String get discard => 'Відхилити';

  @override
  String get bookLabel => 'Замовити';

  @override
  String get monthView => 'Перегляд місяця';

  @override
  String get weekView => 'Перегляд тижня';

  @override
  String get dayView => 'Перегляд дня';

  @override
  String get board => 'Дошка';

  @override
  String get goToday => 'До сьогодні';

  @override
  String get todaysSchedule => 'Розклад на сьогодні';

  @override
  String get noRidesScheduled => 'Поїздок не заплановано';

  @override
  String get enjoyYourFreeDay => 'Насолоджуйтесь вихідним днем!';

  @override
  String get callClient => 'Зателефонувати клієнту';

  @override
  String get startNavigation => 'Розпочати навігацію';

  @override
  String get start => 'Старт';

  @override
  String get completeRideButton => 'Завершити';

  @override
  String get pickupLocation => 'Місце посадки';

  @override
  String get dropoffLocation => 'Місце висадки';

  @override
  String couldNotOpenNavigation(String error) {
    return 'Не вдалося відкрити навігацію: $error';
  }

  @override
  String travelTimeMinutes(int minutes) {
    return '$minutes хв їзди';
  }

  @override
  String failedToSetPrice(String error) {
    return 'Не вдалося встановити ціну: $error';
  }

  @override
  String get setRidePrice => 'Встановити ціну поїздки';

  @override
  String get setPrice => 'Встановити ціну';

  @override
  String get offline => 'Офлайн';

  @override
  String get acceptingRides => 'Ви приймаєте поїздки';

  @override
  String get notAcceptingRides => 'Ви не приймаєте поїздки';

  @override
  String failedToUpdate(String error) {
    return 'Не вдалося оновити: $error';
  }

  @override
  String get homeTab => 'Головна';

  @override
  String get scheduleTab => 'Розклад';

  @override
  String get calendarTab => 'Календар';

  @override
  String get newRideTab => 'Нова поїздка';

  @override
  String get moreTab => 'Ще';

  @override
  String get billingTab => 'Виставлення рахунків';

  @override
  String get moreScreenTitle => 'Ще';

  @override
  String get dispatchBoardTitle => 'Дошка диспетчера';

  @override
  String dispatcherSubtitle(String weekday, String date, int count) {
    return '$weekday, $date · $count активних поїздок';
  }

  @override
  String get searchRidesDrivers => 'Пошук поїздок, водіїв…';

  @override
  String get newRideButtonLabel => 'Нова поїздка';

  @override
  String get activeRidesLabel => 'Активні поїздки';

  @override
  String get atRiskLabel => 'Під загрозою';

  @override
  String get driversOnlineLabel => 'Водіїв онлайн';

  @override
  String get onTimeLabel => 'Вчасно';

  @override
  String get earningsMenuItem => 'Заробіток';

  @override
  String get peakHoursMenuItem => 'Пік годин';

  @override
  String get clientValueMenuItem => 'Цінність клієнта';

  @override
  String get driversMenuItem => 'Водії';

  @override
  String get ratingsMenuItem => 'Рейтинги';

  @override
  String get auditLogMenuItem => 'Журнал аудиту';

  @override
  String get adminMenuItem => 'Адміністрування';

  @override
  String get companyMenuItem => 'Компанія';

  @override
  String get expensesMenuItem => 'Витрати';

  @override
  String get exportMenuItem => 'Експорт';

  @override
  String get templatesMenuItem => 'Шаблони';

  @override
  String get paymentsMenuItem => 'Платежі';

  @override
  String get payrollMenuItem => 'Відомість зарплат';

  @override
  String get settingsMenuItem => 'Налаштування';

  @override
  String get geofencesMenuItem => 'Геозони';

  @override
  String get datevMenuItem => 'DATEV';

  @override
  String get blacklistMenuItem => 'Чорний список';

  @override
  String get emergencyMenuItem => 'Аварійне';

  @override
  String get ridePoolsMenuItem => 'Пули поїздок';

  @override
  String get notificationsMenuItem => 'Сповіщення';

  @override
  String get gdprMenuItem => 'GDPR';

  @override
  String get sessionsMenuItem => 'Сесії';

  @override
  String get schedVisibilityMenuItem => 'Видимість розкладу';

  @override
  String get analyticsMenuItem => 'Аналітика';

  @override
  String get driverBoardMenuItem => 'Дошка водіїв';

  @override
  String get driverMapMenuItem => 'Карта водія';

  @override
  String assignRideDialogTitle(String rideId) {
    return 'Призначити поїздку #$rideId';
  }

  @override
  String get rideDetailsLabel => 'Деталі поїздки';

  @override
  String get clientLabel => 'Клієнт';

  @override
  String get timeLabel => 'Час';

  @override
  String get fromLabel => 'Від';

  @override
  String get toLabel => 'До';

  @override
  String get flightLabel => 'Рейс';

  @override
  String get fareLabel => 'Тариф';

  @override
  String get assigningToLabel => 'Призначення для';

  @override
  String scheduleConflictsCount(int count) {
    return 'Конфлікти розкладу ($count)';
  }

  @override
  String get assignDriverButton => 'Призначити водія';

  @override
  String reassignRideDialogTitle(String rideId) {
    return 'Перепризначити поїздку #$rideId';
  }

  @override
  String get nearestAvailableDriversLabel =>
      'НАЙБЛИЖЧІ ДОСТУПНІ ВОДІЇ · СОРТУВАННЯ ЗА ETA';

  @override
  String get noDriversAvailableForReassignment =>
      'Немає інших водіїв для перепризначення.';

  @override
  String reassignNRides(int count) {
    return 'Перепризначити $count поїздку(-ок)';
  }

  @override
  String driverDelayedMessage(String driverName, String slack) {
    return '$driverName затримується — резерв $slack хв';
  }

  @override
  String ridesToReassignLabel(int selected, int total) {
    return 'Поїздки для перепризначення ($selected/$total)';
  }

  @override
  String get deselectAllButton => 'Зняти вибір';

  @override
  String get selectAllButton => 'Вибрати всі';

  @override
  String get bestMatchBadge => 'Найкращий збіг';

  @override
  String get stillLateLabel => 'все одно пізно';

  @override
  String get slackRestoredLabel => 'резерв відновлено';

  @override
  String get tightLabel => 'щільно';

  @override
  String ridesReassignedMessage(int count, String driverName) {
    return '$count поїздку(-ок) перепризначено водію $driverName';
  }

  @override
  String get reassignAnyway => 'Перепризначити все одно';

  @override
  String get pendingTab => 'Очікування';

  @override
  String get assignedTab => 'Призначені';

  @override
  String get sortTooltip => 'Сортування';

  @override
  String get noAssignedRides => 'Немає призначених поїздок';

  @override
  String get noRidesCurrentlyAssigned =>
      'Наразі жодних поїздок не призначено водіям';

  @override
  String get pendingRequestsHeader => 'Очікувані запити';

  @override
  String unassignedRidesBadge(int count) {
    return '$count не призначено';
  }

  @override
  String get rideAtRiskTitle => 'Поїздка під загрозою затримки';

  @override
  String get etaMonitorBadgeLabel => 'ПРОГНОЗНИЙ МОНІТОР ETA · 60С';

  @override
  String get viewButton => 'Переглянути';

  @override
  String get etaDriverEtaLabel => 'ETA ВОДІЯ';

  @override
  String get etaPickupInLabel => 'ЗАБІР ЧЕРЕЗ';

  @override
  String get etaSlackLabel => 'РЕЗЕРВ';

  @override
  String get driverEarningsTitle => 'Заробіток водіїв';

  @override
  String get sortByEarnings => 'Сортувати за заробітком';

  @override
  String get sortByName => 'Сортувати за іменем';

  @override
  String get sortByRides => 'Сортувати за поїздками';

  @override
  String get driverPayrollTitle => 'Відомість зарплати водіїв';

  @override
  String get payrollSummaryTitle => 'Підсумок зарплати';

  @override
  String get loadPayrollButton => 'Завантажити відомість';

  @override
  String get payrollCsvCopiedMessage => 'CSV зарплатної відомості скопійовано';

  @override
  String get commissionLabel => 'Комісія: ';
}
