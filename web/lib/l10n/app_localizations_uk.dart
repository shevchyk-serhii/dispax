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
  String get selectDriverToViewSchedule =>
      'Оберіть водія, щоб переглянути його графік';

  @override
  String get noScheduleForDriver => 'Немає записів графіку для цього водія';

  @override
  String get noPendingRides => 'Немає очікуючих поїздок';

  @override
  String get rideAlreadyAssignedInfo =>
      'Цю поїздку вже призначено. Список оновлено.';

  @override
  String get allRidesAssigned => 'Всі поїздки призначено';

  @override
  String get selectDriver => 'Обрати водія';

  @override
  String get reassignDriver => 'Перепризначити водія';

  @override
  String get noDriversFound => 'Водіїв не знайдено';

  @override
  String get reassignRide => 'Перепризначити поїздку';

  @override
  String get confirmReassignment => 'Підтвердити перепризначення';

  @override
  String get reassign => 'Перепризначити';

  @override
  String get assign => 'Призначити';

  @override
  String get driverDashboardTitle => 'Панель водія';

  @override
  String get secretaryDashboardTitle => 'Панель секретаря';

  @override
  String get dispatcherDashboardTitle => 'Панель диспетчера';

  @override
  String get adminDashboardTitle => 'Панель адміністратора';

  @override
  String get platformAdminTitle => 'Адміністратор платформи';

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
  String get forcePasswordChangeTitle => 'Встановіть новий пароль';

  @override
  String get forcePasswordChangeMessage =>
      'Ваш обліковий запис використовує тимчасовий пароль. Будь ласка, встановіть новий пароль, щоб продовжити.';

  @override
  String get updateRequired => 'Потрібне оновлення';

  @override
  String get updateRequiredMessage =>
      'Ця версія застосунку більше не підтримується. Будь ласка, оновіть до останньої версії, щоб продовжити.';

  @override
  String get updateNow => 'Оновити зараз';

  @override
  String get temporaryPassword => 'Тимчасовий пароль';

  @override
  String get temporaryPasswordHint =>
      'Користувача попросять змінити його під час першого входу.';

  @override
  String get setNewPassword => 'Встановити новий пароль';

  @override
  String get userCreatedSharePassword =>
      'Користувача створено. Повідомте йому тимчасовий пароль.';

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
  String get appVersion => 'Версія додатка';

  @override
  String get backendVersion => 'Версія бекенду';

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
  String passengerCheckpointStatus(String checkpoint) {
    return 'Пасажир: $checkpoint';
  }

  @override
  String get markCheckpointButton => 'Я тут';

  @override
  String get airportCheckpointPanelTitle => 'Моє місце в терміналі';

  @override
  String get airportEntryTitle => 'Час в\'їзду в термінал';

  @override
  String get airportDepartIn => 'Виїзд через:';

  @override
  String get airportEntryLabel => 'В\'їзд у термінал:';

  @override
  String airportEntryAt(String time) {
    return 'В\'їзд о $time';
  }

  @override
  String airportLandingAt(String time) {
    return 'Приліт о $time';
  }

  @override
  String airportLandedAt(String time) {
    return 'Приземлився о $time';
  }

  @override
  String airportFlightDelay(int minutes) {
    return '+$minutes хв затримки';
  }

  @override
  String get airportTravelTime => 'Час у дорозі:';

  @override
  String airportParkingSavings(String amount) {
    return 'Економія на паркуванні: $amount';
  }

  @override
  String get airportDepartNow => 'Виїжджайте зараз!';

  @override
  String get airportFlightDelayed =>
      'Рейс затримано. Час в\'їзду перераховано.';

  @override
  String airportTimingError(String error) {
    return 'Помилка завантаження даних: $error';
  }

  @override
  String get airportLoadingTiming => 'Завантаження часу в\'їзду...';

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
  String get moreActions => 'Більше дій';

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
  String get companyVatIdLabel => 'Податковий номер (USt-IdNr.)';

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
  String get refreshFlightStatus => 'Оновити статус рейсу';

  @override
  String get flightStatusRefreshed => 'Статус рейсу оновлено';

  @override
  String get flightStatusUnchanged => 'Вже актуально';

  @override
  String get flightNotFoundYet => 'Рейсу ще немає в системі';

  @override
  String get failedToRefreshFlightStatus => 'Не вдалося оновити статус рейсу';

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

  @override
  String get rideStatusHandedOff => 'Передано';

  @override
  String get handOffRide => 'Передати поїздку';

  @override
  String get handOffRideTitle => 'Передати поїздку';

  @override
  String get handOffPartnerCompany => 'Компанія-партнер';

  @override
  String get handOffExternalDriver => 'Зовнішній водій';

  @override
  String get handOffSelectCompany => 'Оберіть компанію';

  @override
  String get handOffSelectDriver => 'Оберіть водія';

  @override
  String get handOffAddNewCompany => '+ Додати нову компанію';

  @override
  String get handOffAddNewDriver => '+ Додати нового водія';

  @override
  String get handOffCompanyName => 'Назва компанії *';

  @override
  String get handOffDriverName => 'Ім\'я водія *';

  @override
  String get handOffPhoneOptional => 'Телефон (необов\'язково)';

  @override
  String get handOffButton => 'Передати';

  @override
  String get rideHandedOffInfo => 'Поїздку передано зовнішньому партнеру.';

  @override
  String handOffFailed(String message) {
    return 'Не вдалося передати: $message';
  }

  @override
  String get closeRide => 'Закрити';

  @override
  String get closeRideTitle => 'Закрити поїздку?';

  @override
  String get closeRideConfirmMessage =>
      'Це скасує непризначену поїздку. Клієнт отримає сповіщення.';

  @override
  String get closeRideButton => 'Закрити поїздку';

  @override
  String get confirmRide => 'Підтвердити поїздку';

  @override
  String get rejectRide => 'Відхилити поїздку';

  @override
  String get rejectReasonPrompt => 'Причина відмови';

  @override
  String get rejectButton => 'Відхилити';

  @override
  String get rejectReasonTooFar => 'Подача надто далеко';

  @override
  String get rejectReasonBusy => 'Зайнятий іншою поїздкою';

  @override
  String get rejectReasonBreak => 'Перерва / кінець зміни';

  @override
  String get rejectReasonVehicleIssue => 'Проблема з автомобілем';

  @override
  String get rejectReasonOther => 'Інше';

  @override
  String get rideConfirmed => 'Поїздку підтверджено';

  @override
  String get rideRejected => 'Поїздку відхилено';

  @override
  String get confirmationRequestTitle => 'Необхідне підтвердження поїздки';

  @override
  String get confirmationRequestBody =>
      'Будь ласка, підтвердіть або відхиліть призначену поїздку';

  @override
  String get statusConfirmed => 'Підтверджено';

  @override
  String get ridesTab => 'Поїздки';

  @override
  String get createTab => 'Створити';

  @override
  String get frontDeskTitle => 'Ресепшн';

  @override
  String get quickBook => 'Швидке замовлення';

  @override
  String get bookedToday => 'Заброньовано сьогодні';

  @override
  String get awaitingConfirm => 'Очікує підтвердження';

  @override
  String get activeClientsLabel => 'Активні клієнти';

  @override
  String get templatesLabel => 'Шаблони';

  @override
  String get todaysBookings => 'Бронювання на сьогодні';

  @override
  String get noRidesToday => 'Немає поїздок сьогодні';

  @override
  String get loadRidesToSeeBookings =>
      'Завантажте поїздки, щоб побачити бронювання';

  @override
  String get manageClientsTitle => 'Управління клієнтами';

  @override
  String get searchClientsHint => 'Пошук клієнтів...';

  @override
  String get noClientsMatchSearch => 'Жодного клієнта не знайдено';

  @override
  String get noClientsYet => 'Клієнтів ще немає';

  @override
  String get addClientTitle => 'Додати клієнта';

  @override
  String get phoneOptional => 'Телефон (необов\'язково)';

  @override
  String get nameRequired => 'Ім\'я є обов\'язковим';

  @override
  String get emailRequired => 'Email є обов\'язковим';

  @override
  String get invalidEmail => 'Невірний email';

  @override
  String get addButton => 'Додати';

  @override
  String get editAction => 'Редагувати';

  @override
  String get deactivateAction => 'Деактивувати';

  @override
  String get editClientTitle => 'Редагувати клієнта';

  @override
  String get clientUpdatedSuccess => 'Клієнта успішно оновлено';

  @override
  String get clientUpdateFailed =>
      'Не вдалося оновити клієнта. Спробуйте ще раз.';

  @override
  String get deactivateClientTitle => 'Деактивувати клієнта';

  @override
  String deactivateClientConfirmMsg(String name) {
    return 'Ви впевнені, що хочете деактивувати $name?';
  }

  @override
  String get newRideButton => 'Нова поїздка';

  @override
  String get ridesCountLabel => 'поїздок';

  @override
  String get preferredDriverAssigned => 'Призначений бажаний водій';

  @override
  String get noRidesYet => 'Поїздок ще немає';

  @override
  String get vipClientLabel => 'VIP-клієнт';

  @override
  String get vipClientHelpText => 'Пріоритетне обслуговування та бажаний водій';

  @override
  String driverLabel(String name) {
    return 'Водій: $name';
  }

  @override
  String get reportsTitle => 'Звіти';

  @override
  String get totalRidesLabel => 'Всього поїздок';

  @override
  String get inProgressLabel => 'В процесі';

  @override
  String get requestedLabel => 'Запитано';

  @override
  String get assignedLabel => 'Призначено';

  @override
  String get keyMetrics => 'Ключові показники';

  @override
  String get cancellationRateLabel => 'Відсоток скасувань';

  @override
  String get statusBreakdown => 'Розбивка за статусом';

  @override
  String get noRideDataYet => 'Даних про поїздки ще немає';

  @override
  String get noActiveRides => 'У вас немає активних поїздок';

  @override
  String get useBookTabHint => 'Використайте вкладку \"Замовлення\"';

  @override
  String get trackDriver => 'Відстежити водія';

  @override
  String departureTimeReachedFlight(String flightInfo) {
    return 'Час відправлення для рейсу $flightInfo настав';
  }

  @override
  String failedToCancelRide(String error) {
    return 'Помилка скасування поїздки: $error';
  }

  @override
  String get failedToLoadRides => 'Не вдалося завантажити поїздки';

  @override
  String get goodMorning => 'Доброго ранку,';

  @override
  String get goodAfternoon => 'Добрий день,';

  @override
  String get goodEvening => 'Добрий вечір,';

  @override
  String get whereTo => 'Куди?';

  @override
  String get onTrip => 'У дорозі';

  @override
  String get driverOnTheWay => 'Водій їде';

  @override
  String get driverAssigned => 'Водія призначено';

  @override
  String get yourDriver => 'Ваш водій';

  @override
  String get savedPlaces => 'ЗБЕРЕЖЕНІ МІСЦЯ';

  @override
  String get savedPlaceHome => 'Дім';

  @override
  String get savedPlaceOffice => 'Офіс';

  @override
  String get addAddress => 'Додати адресу';

  @override
  String get useThisAddress => 'Використати цю адресу';

  @override
  String get editAddress => 'Редагувати адресу';

  @override
  String get removeAddress => 'Видалити';

  @override
  String get removeAddressConfirm => 'Видалити це збережене місце?';

  @override
  String get myAddresses => 'МОЇ АДРЕСИ';

  @override
  String get manageAddresses => 'Збережені адреси';

  @override
  String get addCustomAddress => 'Додати нове місце';

  @override
  String get addressLabel => 'Назва';

  @override
  String get addressLabelHint => 'напр. Спортзал, Батьки';

  @override
  String get labelRequired => 'Будь ласка, введіть назву';

  @override
  String get bookARide => 'Замовити поїздку';

  @override
  String get scheduled => 'ЗА РОЗКЛАДОМ';

  @override
  String get nowLabel => 'ЗАРАЗ';

  @override
  String get asap => 'ЯКНАЙШВИДШЕ';

  @override
  String get vehicleClass => 'КЛАС АВТО';

  @override
  String get estimatedTotal => 'Орієнтована вартість';

  @override
  String get estimateUnavailableHint =>
      'Не вдалося розрахувати ціну для цієї адреси. Ви все одно можете замовити — вартість буде підтверджена пізніше.';

  @override
  String get confirmBooking => 'Підтвердити замовлення';

  @override
  String get rideBookedSuccessfully => 'Поїздку успішно заброньовано!';

  @override
  String get failedToCreateRide => 'Помилка створення поїздки';

  @override
  String get failedToLoadRideHistory =>
      'Не вдалося завантажити історію поїздок';

  @override
  String get listView => 'Список';

  @override
  String get pastLabel => 'МИНУЛІ';

  @override
  String get confirmedStatus => 'Підтверджено';

  @override
  String get rateThisRide => 'Оцінити поїздку';

  @override
  String get thankYouForRating => 'Дякуємо за вашу оцінку!';

  @override
  String failedToSubmitRating(String error) {
    return 'Помилка надсилання оцінки: $error';
  }

  @override
  String rideCardTimeLabel(String time) {
    return 'Час: $time';
  }

  @override
  String get deleteConfirmationTitle => 'Підтвердження';

  @override
  String deleteRideConfirmMessage(String from, String to) {
    return 'Видалити поїздку $from → $to?';
  }

  @override
  String get cancelRideDialogTitle => 'Скасувати поїздку';

  @override
  String get selectCancellationReason =>
      'Будь ласка, виберіть причину скасування:';

  @override
  String get cancellationReasonLabel => 'Причина';

  @override
  String get cancellationReasonClientRequest => 'За проханням клієнта';

  @override
  String get cancellationReasonWeather => 'Погодні умови';

  @override
  String get cancellationReasonOther => 'Інше';

  @override
  String get cancellationReasonClientNoShow => 'Клієнт не з\'явився';

  @override
  String get cancellationReasonDriverUnavailable => 'Водій недоступний';

  @override
  String get cancellationReasonVehicleIssue => 'Проблема з автомобілем';

  @override
  String get cancellationFeeLabel => 'Штраф за скасування (необов\'язково)';

  @override
  String get rateRideExperienceQuestion => 'Як пройшла ваша поїздка?';

  @override
  String get rateRideCommentLabel => 'Коментар (необов\'язково)';

  @override
  String get rateRideCommentHint => 'Розкажіть про свій досвід...';

  @override
  String get airportTransferLabel => 'Трансфер до аеропорту';

  @override
  String get airportTransferHint => 'Увімкніть, якщо це поїздка до/з аеропорту';

  @override
  String get airportDepartureLabel => 'Відправлення';

  @override
  String get airportDepartureHint => 'До аеропорту';

  @override
  String get airportArrivalLabel => 'Прибуття';

  @override
  String get airportArrivalHint => 'З аеропорту';

  @override
  String get flightNumberLabel => 'Номер рейсу';

  @override
  String get flightNumberHint => 'напр. LH123, BA456';

  @override
  String get flightNumberRequired => 'Номер рейсу обов\'язковий';

  @override
  String get flightNumberInvalidFormat =>
      'Введіть дійсний номер рейсу, напр. LH429';

  @override
  String get gateLabel => 'Гейт';

  @override
  String get terminalLabel => 'Термінал';

  @override
  String get gateRemote => 'Автобусний гейт (віддалена стоянка)';

  @override
  String get creatingRideLabel => 'Створення поїздки...';

  @override
  String get createRideButton => 'Створити поїздку';

  @override
  String get clearFormButton => 'Очистити форму';

  @override
  String get vehicleInformationLabel => 'Інформація про транспортний засіб';

  @override
  String get messageButton => 'Повідомлення';

  @override
  String get routeInformationLabel => 'Інформація про маршрут';

  @override
  String get pickupTimeLabel => 'Час подачі';

  @override
  String get distanceLabel => 'Відстань';

  @override
  String get durationLabel => 'Тривалість';

  @override
  String get etaToClientLabel => 'Очікуваний час до клієнта';

  @override
  String get openInGoogleMapsButton => 'Відкрити в Google Maps';

  @override
  String get rideStatusLabel => 'Статус поїздки';

  @override
  String get rideHasBeenCancelledLabel => 'Цю поїздку скасовано';

  @override
  String get rideStatusRequestedClientLabel => 'Очікування призначення водія';

  @override
  String get rideStatusRequestedStaffLabel => 'Очікує призначення';

  @override
  String get rideStatusAssignedEnRouteLabel => 'Водій у дорозі';

  @override
  String get rideStatusAssignedLabel => 'Водія призначено';

  @override
  String get rideStatusAssignedDriverLabel => 'Вас призначено на цю поїздку';

  @override
  String get rideStatusInProgressClientLabel => 'Поїздка триває';

  @override
  String get rideStatusInProgressDriverLabel => 'Щасливої дороги';

  @override
  String get rideStatusCompletedLabel => 'Успішно завершено';

  @override
  String get rideStatusCancelledLabel => 'Поїздку скасовано';

  @override
  String get rideStatusHandedOffLabel => 'Передано партнеру';

  @override
  String get rideStatusConfirmedClientLabel => 'Водій підтвердив вашу поїздку';

  @override
  String get rideStatusConfirmedDriverLabel => 'Ви підтвердили цю поїздку';

  @override
  String get rideStatusConfirmedDriverReadyLabel =>
      'Ви підтвердили цю поїздку — готові розпочати';

  @override
  String get authenticationRequiredError => 'Необхідна автентифікація';

  @override
  String get selectOrCreateClientError =>
      'Будь ласка, виберіть або створіть клієнта';

  @override
  String get enterClientNameError => 'Будь ласка, введіть ім\'я клієнта';

  @override
  String get editRideDialogTitle => 'Редагувати поїздку';

  @override
  String get pickupDateTimeLabel => 'Дата/час подачі';

  @override
  String get flightNumberOptionalLabel => 'Номер рейсу (необов\'язково)';

  @override
  String get notesOptionalLabel => 'Примітки (необов\'язково)';

  @override
  String serverErrorMessage(String statusCode) {
    return 'Помилка сервера: $statusCode';
  }

  @override
  String get useDispatcherDashboardInfo =>
      'Використовуйте панель диспетчера для призначення водіїв';

  @override
  String get updateLocationTitle => 'Оновити місцезнаходження';

  @override
  String get tellDriverWhereYouAreLabel =>
      'Повідомте водія, де ви зараз знаходитесь:';

  @override
  String get quickSelectLabel => 'Швидкий вибір:';

  @override
  String get locationQuickMainEntrance => 'Біля головного входу';

  @override
  String get locationQuickBaggageClaim => 'На видачі багажу';

  @override
  String get locationQuickCafe => 'У кафе';

  @override
  String get locationQuickParking => 'На парковці';

  @override
  String get locationQuickInformationDesk => 'Біля інформаційної стійки';

  @override
  String get locationQuickSecondFloor => 'На другому поверсі';

  @override
  String get locationQuickExit1 => 'Біля виходу №1';

  @override
  String get locationQuickExit2 => 'Біля виходу №2';

  @override
  String get locationQuickOther => 'Інше місце';

  @override
  String get orSpecifyExactlyLabel => 'Або вкажіть точно:';

  @override
  String get locationExampleHint => 'Приклад: «Біля входу в термінал A»';

  @override
  String get additionalInstructionsLabel =>
      'Додаткові інструкції (необов\'язково):';

  @override
  String get additionalInstructionsExampleHint =>
      'Приклад: «Стою біля кав\'ярні»';

  @override
  String get specifyLocationError =>
      'Будь ласка, вкажіть ваше місцезнаходження';

  @override
  String get failedToUpdateLocationError =>
      'Не вдалося оновити місцезнаходження. Будь ласка, спробуйте ще раз.';

  @override
  String get callClientTooltip => 'Зателефонувати клієнту';

  @override
  String get navigateTooltip => 'Навігація';

  @override
  String get delayByHowLongTitle => 'На скільки затримати?';

  @override
  String minutesLabel(int minutes) {
    return '$minutes хвилин';
  }

  @override
  String get appSubtitle => 'Розумні рішення для мобільності';

  @override
  String get orLabel => 'або';

  @override
  String get touchIdLabel => 'Touch ID';

  @override
  String get biometricsLabel => 'Біометрія';

  @override
  String get biometricSetupTitle => 'Налаштування біометрії';

  @override
  String get biometricSetupMessage =>
      'Хочете увімкнути швидкий вхід за допомогою біометрії?\n\nЦе дозволить вам входити за допомогою Face ID, Touch ID або відбитка пальця.';

  @override
  String get laterButton => 'Пізніше';

  @override
  String get enableButton => 'Увімкнути';

  @override
  String get createButton => 'Створити';

  @override
  String get allLabel => 'Усі';

  @override
  String get statusLabel => 'Статус';

  @override
  String operationFailed(String error) {
    return 'Помилка: $error';
  }

  @override
  String get roleLabel => 'Роль';

  @override
  String get addGeofenceTooltip => 'Додати геозону';

  @override
  String get savedTemplatesTitle => 'Збережені шаблони';

  @override
  String get createTemplateDialogTitle => 'Створити шаблон';

  @override
  String get templateNameLabel => 'Назва шаблону';

  @override
  String get fromAddressLabel => 'Адреса відправлення';

  @override
  String get toAddressLabel => 'Адреса призначення';

  @override
  String get templatePickupTimeLabel => 'Час подачі (ГГ:хх)';

  @override
  String get recurrenceLabel => 'Повторення';

  @override
  String get recurrenceDaily => 'Щодня';

  @override
  String get recurrenceWeekdays => 'Будні дні';

  @override
  String get recurrenceWeeklyMonday => 'Щотижня понеділок';

  @override
  String get recurrenceWeeklyTuesday => 'Щотижня вівторок';

  @override
  String get recurrenceWeeklyWednesday => 'Щотижня середа';

  @override
  String get recurrenceWeeklyThursday => 'Щотижня четвер';

  @override
  String get recurrenceWeeklyFriday => 'Щотижня п\'ятниця';

  @override
  String get recurrenceSaturdayLabel => 'Щотижня субота';

  @override
  String get recurrenceSundayLabel => 'Щотижня неділя';

  @override
  String get priceOptionalLabel => 'Ціна (необов\'язково)';

  @override
  String get generateRidesMenuLabel => 'Генерувати поїздки';

  @override
  String get deactivateTemplateMenuLabel => 'Деактивувати';

  @override
  String get noTemplatesYet => 'Ще немає шаблонів';

  @override
  String get noTemplatesSubtitle => 'Створіть шаблон для регулярних поїздок';

  @override
  String get addTemplateButton => 'Додати шаблон';

  @override
  String get ridesGeneratedSuccess => 'Поїздки успішно створені';

  @override
  String failedToGenerateRides(String error) {
    return 'Помилка генерації: $error';
  }

  @override
  String failedToDeactivateTemplate(String error) {
    return 'Помилка деактивації: $error';
  }

  @override
  String get templateBadgeActive => 'Активний';

  @override
  String get templateBadgePaused => 'Призупинено';

  @override
  String get geofenceScreenTitle => 'Геозони';

  @override
  String get zonesTabLabel => 'Зони';

  @override
  String get recentAlertsTabLabel => 'Нещодавні сповіщення';

  @override
  String get createGeofenceDialogTitle => 'Створити геозону';

  @override
  String get zoneNameLabel => 'Назва зони';

  @override
  String get geofenceTypeLabel => 'Тип';

  @override
  String get geofenceTypeServiceArea => 'Зона обслуговування';

  @override
  String get geofenceTypeClientPickup => 'Точка посадки клієнта';

  @override
  String get geofenceTypeCustomZone => 'Власна зона';

  @override
  String get latitudeLabel => 'Широта';

  @override
  String get longitudeLabel => 'Довгота';

  @override
  String get radiusLabel => 'Радіус';

  @override
  String get notifyOnEntryLabel => 'Сповіщати при вході';

  @override
  String get notifyOnExitLabel => 'Сповіщати при виході';

  @override
  String get noGeofenceZonesYet => 'Геозон ще немає';

  @override
  String get createZonesToMonitorSubtitle =>
      'Створіть зони для моніторингу в\'їздів та виїздів водіїв';

  @override
  String get createZoneButton => 'Створити зону';

  @override
  String get deleteZoneConfirmTitle => 'Видалити зону';

  @override
  String deleteZoneConfirmMsg(String name) {
    return 'Видалити \"$name\"?';
  }

  @override
  String get geofenceDeletedSuccess => 'Геозону видалено';

  @override
  String failedToDeleteGeofence(String error) {
    return 'Помилка видалення: $error';
  }

  @override
  String failedToToggleGeofence(String code) {
    return 'Помилка перемикання ($code)';
  }

  @override
  String failedToCreateGeofence(String code) {
    return 'Помилка створення ($code)';
  }

  @override
  String get geofenceCreatedSuccess => 'Геозону створено';

  @override
  String get fillRequiredFieldsError =>
      'Будь ласка, заповніть усі обов\'язкові поля';

  @override
  String get noAlertsFound => 'Сповіщень не знайдено';

  @override
  String driverEnteredGeofence(String geofenceName) {
    return 'Водій в\'їхав у $geofenceName';
  }

  @override
  String driverLeftGeofence(String geofenceName) {
    return 'Водій виїхав із $geofenceName';
  }

  @override
  String get alertFilterAll => 'Усі';

  @override
  String get alertFilterEntry => 'В\'їзд';

  @override
  String get alertFilterExit => 'Виїзд';

  @override
  String get alertFilterLabel => 'Фільтр:';

  @override
  String geofenceSubtitleAirport(int radius) {
    return 'Зона аеропорту · радіус $radiusм';
  }

  @override
  String geofenceSubtitleServiceArea(int radius) {
    return 'Зона обслуговування · радіус $radiusм';
  }

  @override
  String geofenceSubtitleClientPickup(int radius) {
    return 'Точка посадки · радіус $radiusм';
  }

  @override
  String geofenceSubtitleCustomZone(int radius) {
    return 'Власна зона · радіус $radiusм';
  }

  @override
  String failedToLoadGeofences(String code) {
    return 'Помилка завантаження ($code)';
  }

  @override
  String failedToLoadAlerts(String code) {
    return 'Помилка завантаження сповіщень ($code)';
  }

  @override
  String get notifTabNotifications => 'Сповіщення';

  @override
  String get notifTabSettings => 'Налаштування';

  @override
  String get markAllReadButton => 'Усі прочитані';

  @override
  String get clearAllNotificationsMenuLabel => 'Видалити всі';

  @override
  String get clearAllConfirmTitle => 'Видалити всі сповіщення';

  @override
  String get clearAllConfirmContent =>
      'Ви впевнені, що хочете видалити всі сповіщення?';

  @override
  String get deleteAllNotificationsButton => 'Видалити всі';

  @override
  String get noNotificationsYet => 'Немає сповіщень';

  @override
  String get notifFilterAll => 'Усі';

  @override
  String get notifFilterRides => 'Поїздки';

  @override
  String get notifFilterChat => 'Чат';

  @override
  String get notifFilterGeofence => 'Геозона';

  @override
  String get notifFilterPools => 'Пули';

  @override
  String get notifFilterCheckpoints => 'Контрольні точки';

  @override
  String get notifJustNow => 'Щойно';

  @override
  String notifMinutesAgo(int count) {
    return '$count хв тому';
  }

  @override
  String notifHoursAgo(int count) {
    return '$count год тому';
  }

  @override
  String notifDaysAgo(int count) {
    return '$count дн тому';
  }

  @override
  String get notifPrefSectionPush => 'Push-сповіщення';

  @override
  String get notifPrefSectionAdditional => 'Додаткові канали';

  @override
  String get notifPrefRideUpdatesSubtitle => 'Зміни статусу, призначення';

  @override
  String get notifPrefChatMessagesSubtitle =>
      'Нові повідомлення від водія/клієнта';

  @override
  String get notifPrefDriverApproachingLabel => 'Водій наближається';

  @override
  String get notifPrefDriverApproachingSubtitle => 'Коли водій поблизу';

  @override
  String get notifPrefGeofenceAlertsLabel => 'Сповіщення геозони';

  @override
  String get notifPrefGeofenceAlertsSubtitle => 'Сповіщення про в\'їзд/виїзд';

  @override
  String get notifPrefPoolUpdatesLabel => 'Оновлення пулу';

  @override
  String get notifPrefPoolUpdatesSubtitle => 'Сповіщення пулу поїздок';

  @override
  String get notifPrefEmailLabel => 'Сповіщення електронною поштою';

  @override
  String get notifPrefEmailSubtitle =>
      'Отримувати сповіщення електронною поштою';

  @override
  String get notifPrefSmsLabel => 'SMS-сповіщення';

  @override
  String get notifPrefSmsSubtitle => 'Отримувати сповіщення по SMS';

  @override
  String get notifPrefQuietHours => 'Тихий час';

  @override
  String get notifPrefQuietHoursFrom => 'З';

  @override
  String get notifPrefQuietHoursTo => 'До';

  @override
  String get notifPrefNotSet => 'Не задано';

  @override
  String get savePreferencesButton => 'Зберегти налаштування';

  @override
  String get preferencesSaved => 'Налаштування збережено';

  @override
  String get revokeSessionDialogTitle => 'Відкликати сесію';

  @override
  String get revokeSessionDialogContent =>
      'Це призведе до виходу пристрою з цієї сесії.';

  @override
  String get revokeSessionButton => 'Відкликати';

  @override
  String get revokeAllOtherSessionsDialogTitle => 'Відкликати всі інші сесії';

  @override
  String get revokeAllOtherSessionsDialogContent =>
      'Це призведе до виходу з усіх інших пристроїв. Лише поточна сесія залишиться активною.';

  @override
  String get revokeAllButton => 'Відкликати всі';

  @override
  String get sessionRevoked => 'Сесію відкликано';

  @override
  String get allOtherSessionsRevoked => 'Всі інші сесії відкликані';

  @override
  String get noActiveSessions => 'Немає активних сесій';

  @override
  String get sessionCurrentLabel => 'Поточна';

  @override
  String sessionIpLabel(String ip) {
    return 'IP: $ip';
  }

  @override
  String sessionCreatedLabel(String date) {
    return 'Створено: $date';
  }

  @override
  String sessionLastActiveLabel(String date) {
    return 'Остання активність: $date';
  }

  @override
  String get revokeSessionAction => 'Відкликати';

  @override
  String get userManagementTitle => 'Управління користувачами';

  @override
  String get createUserDialogTitle => 'Створити користувача';

  @override
  String get searchUsersHint => 'Пошук користувачів...';

  @override
  String get changeRoleMenuHeader => 'Змінити роль';

  @override
  String get changeStatusMenuHeader => 'Змінити статус';

  @override
  String get activateUserAction => 'Активувати';

  @override
  String get suspendUserAction => 'Призупинити';

  @override
  String get deactivateUserAction => 'Деактивувати';

  @override
  String get noUsersFound => 'Користувачів не знайдено';

  @override
  String get totalUsersLabel => 'Всього';

  @override
  String get driversStatLabel => 'Водії';

  @override
  String get clientsStatLabel => 'Клієнти';

  @override
  String get staffStatLabel => 'Персонал';

  @override
  String roleChangedSuccess(String role) {
    return 'Роль змінено на $role';
  }

  @override
  String statusChangedSuccess(String status) {
    return 'Статус змінено на $status';
  }

  @override
  String failedToChangeRole(String error) {
    return 'Помилка: $error';
  }

  @override
  String failedToChangeStatus(String error) {
    return 'Помилка: $error';
  }

  @override
  String failedToCreateUser(String error) {
    return 'Помилка: $error';
  }

  @override
  String get blacklistTitle => 'Чорний список';

  @override
  String get addBlacklistEntryDialogTitle => 'Додати до чорного списку';

  @override
  String get clientIdLabel => 'ID клієнта';

  @override
  String get driverIdLabel => 'ID водія';

  @override
  String get reasonOptionalLabel => 'Причина (необов\'язково)';

  @override
  String get clientDriverIdRequired => 'ID клієнта та ID водія обов\'язкові';

  @override
  String get removeBlacklistEntryDialogTitle => 'Видалити запис';

  @override
  String get removeBlacklistEntryContent =>
      'Ви впевнені, що хочете видалити цей запис?';

  @override
  String get removeBlacklistEntryButton => 'Видалити';

  @override
  String get noBlacklistEntries => 'Записів у чорному списку немає';

  @override
  String get tenantsTitle => 'Тенанти';

  @override
  String tenantsWithCount(int count) {
    return 'Тенанти · $count компаній';
  }

  @override
  String get onboardButton => '+ Додати';

  @override
  String get noTenantsFound => 'Тенантів не знайдено';

  @override
  String get onboardCompanyDialogTitle => 'Зареєструвати компанію';

  @override
  String get editCompanyDialogTitle => 'Редагувати компанію';

  @override
  String get subscriptionPlanLabel => 'Тарифний план';

  @override
  String get colHeaderCompany => 'КОМПАНІЯ';

  @override
  String get colHeaderPlan => 'ПЛАН';

  @override
  String get colHeaderDrivers => 'ВОДІЇ';

  @override
  String get colHeaderRidesPerMonth => 'ПОЇЗДКИ / МІС';

  @override
  String get colHeaderStatus => 'СТАТУС';

  @override
  String get deactivateCompanyDialogTitle => 'Деактивувати компанію?';

  @override
  String deactivateCompanyDialogContent(String name) {
    return 'Ви впевнені, що хочете деактивувати \"$name\"?\n\nКомпанія буде позначена як неактивна, але всі дані (поїздки, рахунки, користувачі) будуть збережені.';
  }

  @override
  String get setActiveAction => 'Зробити активною';

  @override
  String get setTrialAction => 'Пробний режим';

  @override
  String get suspendAction => 'Призупинити';

  @override
  String get emergencyReassignmentTitle => 'Екстрені перепризначення';

  @override
  String get emergencyReassignmentDialogTitle => 'Екстрене перепризначення';

  @override
  String get rideIdLabel => 'ID поїздки';

  @override
  String get emergencyReasonLabel => 'Причина';

  @override
  String get availableDriversLabel => 'Доступні водії:';

  @override
  String get newDriverIdLabel => 'Нова ID водія (необов\'язково)';

  @override
  String get newDriverIdHelper => 'Залиште порожнім для скасування призначення';

  @override
  String get reassignButton => 'Перепризначити';

  @override
  String get rideIdRequired => 'ID поїздки обов\'язковий';

  @override
  String get emergencyReassignmentCreated =>
      'Екстрене перепризначення створено';

  @override
  String get noEmergencyReassignments => 'Екстрених перепризначень немає';

  @override
  String get emergencyReasonDriverIllness => 'Хвороба водія';

  @override
  String get emergencyReasonVehicleBreakdown => 'Поломка транспорту';

  @override
  String get emergencyReasonDriverNoShow => 'Водій не з\'явився';

  @override
  String get emergencyReasonAccident => 'Аварія';

  @override
  String get emergencyReasonPersonalEmergency =>
      'Особиста надзвичайна ситуація';

  @override
  String get emergencyReasonOther => 'Інше';

  @override
  String get preferredDriverLabel => 'Пріоритетний';

  @override
  String emergencyRideLabel(String id) {
    return 'Поїздка: $id';
  }

  @override
  String emergencyOriginalDriverLabel(String id) {
    return 'Оригінальний водій: $id';
  }

  @override
  String emergencyNewDriverLabel(String id) {
    return 'Новий водій: $id';
  }

  @override
  String get ridePoolsTitle => 'Пули поїздок';

  @override
  String get createRidePoolDialogTitle => 'Створити пул поїздок';

  @override
  String get poolNameOptionalLabel => 'Назва пулу (необов\'язково)';

  @override
  String get poolNameHint => 'напр., Ранковий шатл до аеропорту';

  @override
  String get routeDirectionOptionalLabel =>
      'Напрямок маршруту (необов\'язково)';

  @override
  String get routeDirectionHint => 'напр., Центр міста → Аеропорт';

  @override
  String get maxPassengersLabel => 'Макс. пасажирів:';

  @override
  String get ridePoolCreated => 'Пул поїздок створено';

  @override
  String get noRidePools => 'Пулів поїздок немає';

  @override
  String get createPoolToCombineRides => 'Створіть пул для об\'єднання поїздок';

  @override
  String errorLoadingPoolDetails(String error) {
    return 'Помилка завантаження деталей пулу: $error';
  }

  @override
  String get poolDetailStatusLabel => 'Статус';

  @override
  String get poolDetailPassengersLabel => 'Пасажири';

  @override
  String get poolDetailRouteLabel => 'Маршрут';

  @override
  String get poolDetailDriverLabel => 'Водій';

  @override
  String get poolMembersLabel => 'Учасники:';

  @override
  String get noRidesInPool => 'Поїздок у цьому пулі ще немає';

  @override
  String get companySettingsTitle => 'Налаштування компанії';

  @override
  String get navItemCompany => 'Компанія';

  @override
  String get navItemUsersRoles => 'Користувачі та ролі';

  @override
  String get navItemCompliance => 'Відповідність';

  @override
  String get navItemBillingDatev => 'Білінг та DATEV';

  @override
  String get navItemGeofences => 'Геозони';

  @override
  String get companyProfileSectionTitle => 'Профіль компанії';

  @override
  String get companyProfileSubtitle =>
      'Юридична інформація, що відображається на рахунках та звітах.';

  @override
  String get complianceSectionTitle => 'Відповідність та безпека';

  @override
  String get complianceSubtitle =>
      'Захист даних, управління доступом та аудит.';

  @override
  String get billingDatevSectionTitle => 'Білінг та DATEV';

  @override
  String get billingDatevSubtitle =>
      'Конфігурація тарифів та налаштування експорту DATEV.';

  @override
  String get tariffSettingsSectionTitle => 'Налаштування тарифу';

  @override
  String get datevIntegrationSectionTitle => 'Інтеграція DATEV';

  @override
  String get datevIntegrationSubtitle =>
      'Beraternummer та Mandantennummer використовуються в заголовку EXTF-Buchungsstapel.';

  @override
  String get legalNameLabel => 'Юридична назва';

  @override
  String get vatIdLabel => 'ІПН / ПДВ';

  @override
  String get defaultCurrencyLabel => 'Валюта за замовчуванням';

  @override
  String get timezoneLabel => 'Часовий пояс';

  @override
  String get commissionRateLabel => 'Комісія (%)';

  @override
  String get cancellationFeeSettingsLabel => 'Плата за скасування (€)';

  @override
  String get noShowFeeLabel => 'Плата за неявку (€)';

  @override
  String get basePriceLabel => 'Базова ціна (€)';

  @override
  String get pricePerKmLabel => 'Ціна за км (€)';

  @override
  String get airportSurchargeLabel => 'Надбавка за аеропорт (€)';

  @override
  String get nightSurchargeLabel => 'Нічна надбавка (€)';

  @override
  String get workStartLabel => 'Початок роботи';

  @override
  String get workEndLabel => 'Кінець роботи';

  @override
  String get settingsSavedSuccess => 'Налаштування успішно збережено';

  @override
  String failedToSaveSettings(String error) {
    return 'Помилка збереження: $error';
  }

  @override
  String get gdprExportTitle => 'Експорт GDPR';

  @override
  String get gdprExportSubtitle => 'Завантажити всі персональні дані';

  @override
  String get auditLogTitle => 'Журнал аудиту';

  @override
  String get auditLogSubtitle => 'Перегляд активності системи';

  @override
  String get activeSessionsCardTitle => 'Активні сесії';

  @override
  String get activeSessionsCardSubtitle => 'Управління підключеними пристроями';

  @override
  String get blacklistCardTitle => 'Чорний список';

  @override
  String get blacklistCardSubtitle => 'Управління заблокованими акаунтами';

  @override
  String comingSoonLabel(String label) {
    return '$label — незабаром';
  }

  @override
  String get settingsCompanyProfile => 'Профіль компанії';

  @override
  String get generalSettingsSectionTitle => 'Загальні налаштування';

  @override
  String get gdprScreenTitle => 'Конфіденційність та дані (GDPR)';

  @override
  String get consentManagementSectionTitle => 'Управління згодами';

  @override
  String get consentDataProcessingLabel => 'Обробка даних';

  @override
  String get consentDataProcessingSubtitle =>
      'Дозволити обробку даних поїздок та акаунту';

  @override
  String get consentMarketingLabel => 'Маркетинг';

  @override
  String get consentMarketingSubtitle =>
      'Отримувати рекламні листи та пропозиції';

  @override
  String get consentAnalyticsLabel => 'Аналітика';

  @override
  String get consentAnalyticsSubtitle =>
      'Допомогти покращити застосунок за допомогою аналітики';

  @override
  String get consentThirdPartySharingLabel => 'Передача третім сторонам';

  @override
  String get consentThirdPartySharingSubtitle =>
      'Ділитися даними з партнерськими сервісами';

  @override
  String get yourDataSectionTitle => 'Ваші дані';

  @override
  String get exportMyDataLabel => 'Експортувати мої дані';

  @override
  String get exportMyDataSubtitle =>
      'Завантажити всі особисті дані, що ми зберігаємо про вас';

  @override
  String get dataDeletionSectionTitle => 'Видалення даних';

  @override
  String get requestDataDeletionLabel => 'Запросити видалення даних';

  @override
  String get requestDataDeletionSubtitle =>
      'Назавжди видалити всі ваші дані та акаунт';

  @override
  String get pendingDeletionSubtitle =>
      'Запит на видалення вже очікує розгляду';

  @override
  String get pendingChipLabel => 'Очікує';

  @override
  String get requestHistoryTitle => 'Історія запитів';

  @override
  String get requestDeletionDialogTitle => 'Запросити видалення даних';

  @override
  String get requestDeletionDialogContent =>
      'Це надішле запит на видалення всіх ваших особистих даних. Цю дію не можна скасувати. Ваш акаунт буде деактивований після обробки запиту.\n\nВи впевнені, що хочете продовжити?';

  @override
  String get requestDeletionButton => 'Запросити видалення';

  @override
  String get dataExportCopied => 'Дані скопійовано в буфер обміну';

  @override
  String exportFailed(String error) {
    return 'Помилка експорту: $error';
  }

  @override
  String get deletionRequestSubmitted => 'Запит на видалення надіслано';

  @override
  String failedToLoadGdprData(String consentsCode, String requestsCode) {
    return 'Помилка завантаження даних GDPR ($consentsCode/$requestsCode)';
  }

  @override
  String get dataDeletionRequestType => 'Видалення даних';

  @override
  String get dataExportRequestType => 'Експорт даних';

  @override
  String get paymentsTitle => 'Платежі';

  @override
  String get unpaidBadgeLabel => 'Не оплачено';

  @override
  String get allRidesPaidLabel => 'Усі поїздки оплачені';

  @override
  String get markAsPaidDialogTitle => 'Позначити як оплачено';

  @override
  String get paymentMethodLabel => 'Спосіб оплати:';

  @override
  String get paymentMethodSelectLabel => 'Спосіб оплати';

  @override
  String get paymentMethodPayment => 'Оплата';

  @override
  String get paymentMethodCash => 'Готівка';

  @override
  String get paymentMethodCard => 'Кредитна картка';

  @override
  String get paymentMethodInvoice => 'Рахунок';

  @override
  String amountLabel(String amount) {
    return 'Сума: $amount EUR';
  }

  @override
  String get confirmPaymentButton => 'Підтвердити оплату';

  @override
  String get paymentRecordedSuccess => 'Платіж зафіксовано';

  @override
  String get failedToLoadUnpaidRides =>
      'Помилка завантаження неоплачених поїздок';

  @override
  String myRideTitle(String id) {
    return 'Моя поїздка #$id';
  }

  @override
  String rideTitle(String id) {
    return 'Поїздка #$id';
  }

  @override
  String get confirmationSentLabel => 'Підтвердження надіслано';

  @override
  String get cancellationDetailsTitle => 'Деталі скасування';

  @override
  String cancellationReasonDetail(String reason) {
    return 'Причина: $reason';
  }

  @override
  String cancelledByLabel(String name) {
    return 'Скасовано: $name';
  }

  @override
  String cancellationFeeDisplay(String fee) {
    return 'Штраф: €$fee';
  }

  @override
  String get ratingTitle => 'Оцінка';

  @override
  String get notesTitle => 'Примітки';

  @override
  String get openChatButton => 'Відкрити чат';

  @override
  String get rideStatusUpdatedSuccess => 'Статус поїздки успішно оновлено';

  @override
  String failedToUpdateRideStatus(String error) {
    return 'Помилка оновлення статусу поїздки: $error';
  }

  @override
  String get driverAssignedSuccess => 'Водія успішно призначено';

  @override
  String failedToAssignDriver(String error) {
    return 'Помилка призначення водія: $error';
  }

  @override
  String get rideCancelledSuccess => 'Поїздку скасовано';

  @override
  String get completeRideDialogTitle => 'Завершити поїздку';

  @override
  String get completeRideDialogContent => 'Позначити цю поїздку як завершену?';

  @override
  String get createNewRideTitle => 'Створити нову поїздку';

  @override
  String get rideCreatedSuccess => 'Поїздку успішно створено!';

  @override
  String get conflictDialogTitle => 'Конфлікт розкладу';

  @override
  String conflictDialogContent(String message) {
    return '$message\n\nПоїздку створено та додано до пулу диспетчера. Все одно призначити собі?';
  }

  @override
  String get conflictDialogContentDefault =>
      'У вас вже є поїздка в цей час. Поїздку створено та додано до пулу. Все одно призначити собі?';

  @override
  String conflictDialogContentRich(String from, String to, String time) {
    return 'Водій уже зайнятий: $from → $to о $time.\n\nПоїздку створено та додано до пулу диспетчера. Все одно призначити?';
  }

  @override
  String get keepInPoolButton => 'Залишити в пулі';

  @override
  String get assignAnywayButton => 'Призначити все одно';

  @override
  String get exportRidesTitle => 'Експорт поїздок';

  @override
  String get copyCsvButton => 'Копіювати CSV';

  @override
  String get dateRangeButton => 'Діапазон дат';

  @override
  String get noRidesMatchFilters => 'Жодна поїздка не відповідає фільтрам';

  @override
  String get exportSummaryTotal => 'Всього';

  @override
  String get exportSummaryCompleted => 'Завершено';

  @override
  String get exportSummaryRevenue => 'Виручка';

  @override
  String csvCopiedSnackbar(int count) {
    return 'Дані CSV скопійовано ($count поїздок)';
  }

  @override
  String get okButton => 'OK';

  @override
  String get flightsMunichAirportTitle => 'Рейси · Аеропорт Мюнхен';

  @override
  String get autoSyncedLabel => 'авто-синхронізація';

  @override
  String get arrivalsTabLabel => 'Прильоти';

  @override
  String get arrivalsBoardTitle => 'Прильоти · Аеропорт Мюнхен';

  @override
  String get departuresTabLabel => 'Відльоти';

  @override
  String get noArrivalsFound => 'Прильотів не знайдено';

  @override
  String get noDeparturesFound => 'Відльотів не знайдено';

  @override
  String get flightDetailsTitle => 'Деталі рейсу';

  @override
  String get gateNotPublished => 'Гейт ще не оголошено';

  @override
  String get trackFlightLive => 'Стежити наживо на Flightradar24';

  @override
  String get couldNotOpenFlightTracker => 'Не вдалося відкрити трекер рейсу';

  @override
  String errorLoadingFlights(String error) {
    return 'Помилка завантаження рейсів: $error';
  }

  @override
  String get flightColumnFlight => 'Рейс';

  @override
  String get flightColumnOriginDest => 'Звідки / Куди';

  @override
  String get flightColumnSched => 'Розклад';

  @override
  String get flightColumnStatus => 'Статус';

  @override
  String get flightColumnLinkedRide => 'Пов\'язана поїздка';

  @override
  String get flightStatusOnTime => 'Вчасно';

  @override
  String get flightStatusDelayed => 'Затримано';

  @override
  String get flightStatusBoarding => 'Посадка';

  @override
  String get flightStatusCancelled => 'Скасовано';

  @override
  String get flightStatusUnknown => 'Невідомо';

  @override
  String get flightStatusScheduled => 'За розкладом';

  @override
  String get flightStatusDeparted => 'Вилетів';

  @override
  String get flightStatusEnRoute => 'У польоті';

  @override
  String get flightStatusLanded => 'Приземлився';

  @override
  String get flightStatusDiverted => 'Перенаправлено';

  @override
  String get flightInformation => 'Інформація про рейс';

  @override
  String get flightNumber => 'Номер рейсу';

  @override
  String get arrivalTime => 'Час прибуття';

  @override
  String get departureTime => 'Час відправлення';

  @override
  String get flightNotLinked => '— не пов\'язано';

  @override
  String get whoCanSeeWhomTitle => 'Хто може бачити кого';

  @override
  String get visibleToAllDispatchers => 'Видимий для всіх диспетчерів';

  @override
  String get scheduleHiddenFromOthers => 'Розклад прихований від інших';

  @override
  String get noDriversInCompany => 'У вашій компанії немає водіїв.';

  @override
  String failedToUpdateVisibilityError(String error) {
    return 'Помилка оновлення видимості: $error';
  }

  @override
  String get auditLogScreenTitle => 'Журнал аудиту';

  @override
  String get searchByEntityIdHint => 'Пошук за ID сутності...';

  @override
  String get noAuditEntriesFound => 'Записів аудиту не знайдено';

  @override
  String onlineOnRideLabel(String id) {
    return 'Онлайн · поїздка #$id';
  }

  @override
  String get startConversationSubtitle => 'Почніть розмову з водієм';

  @override
  String failedToSendMessage(String error) {
    return 'Помилка надсилання: $error';
  }

  @override
  String get totalRidesStatLabel => 'Всього поїздок';

  @override
  String get onTimeStatLabel => 'Вчасно';

  @override
  String get completionRateStatLabel => 'Частка завершених';

  @override
  String get avgSlackStatLabel => 'Сер. запас';

  @override
  String get gmvStatLabel => 'GMV';

  @override
  String get ridesByTenantTitle => 'Поїздки за тенантом';

  @override
  String get rideStatusBreakdownTitle => 'Розбивка за статусом поїздок';

  @override
  String get platformActiveSessionsLabel => 'Активні сесії платформи';

  @override
  String get clientPaymentTitle => 'Оплата';

  @override
  String get paymentMethodsSectionLabel => 'СПОСОБИ ОПЛАТИ';

  @override
  String get corporateInvoiceLabel => 'Корпоративний рахунок';

  @override
  String get addPaymentMethodButton => 'Додати спосіб оплати';

  @override
  String get shareRideLink => 'Поділитися посиланням';

  @override
  String get trackingLinkCopied => 'Посилання скопійовано в буфер обміну';

  @override
  String get bookWithoutClient => 'Без клієнта (з чату)';

  @override
  String get fromChatRide => 'З чату';

  @override
  String get linkClient => 'Додати клієнта';
}
