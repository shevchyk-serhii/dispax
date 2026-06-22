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
}
