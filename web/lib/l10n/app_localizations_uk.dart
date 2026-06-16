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
}
