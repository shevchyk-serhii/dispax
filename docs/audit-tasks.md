# Задачи аудита проекта

Чеклист направлений аудита. Отмечай выполненные галочкой.

---

## 1. Поиск кода, непокрытого юнит-тестами

- [ ] Найти классы и методы application-слоя (сервисы, валидаторы) и доменную логику без unit-тестов.

Ориентир по уже покрытым областям — наличие in-memory реализаций репозиториев (`InMemoryRideRepository`, `MockPersonRepository` и т.п.) и соответствующих `*Spec`. Цель — список непокрытой бизнес-логики по модулям (core, auth, ride, driver, schedule, notification, billing).

## 2. Поиск кода, непокрытого интеграционными тестами

- [ ] Найти репозитории и HTTP-эндпоинты без интеграционных тестов на Testcontainers.

Проверять Doobie-реализации в `infrastructure/repository/` и route-хендлеры. Интеграционные тесты должны идти против реального PostgreSQL (Testcontainers), без моков БД. Цель — список репозиториев/эндпоинтов без интеграционного покрытия.

## 3. Поиск уязвимостей

- [ ] Найти нарушения безопасности.

Что искать: нарушения tenant-изоляции (фильтрация по `CompanyId` в каждом запросе, включая SQL-слой — `findById`/`delete`/`update`), утечки чувствительных данных в логах, SQL/CSV-инъекции, хардкод секретов, слабую обработку JWT. Цель — список уязвимостей с указанием места и серьёзности.

## 4. Поиск нарушений SOLID

- [ ] Найти нарушения принципов SOLID.

Что искать: бизнес-логику в route-хендлерах (должна быть в application-слое), перегруженные «god»-сервисы, нарушение разделения слоёв domain/application/infrastructure, неверные зависимости между слоями. Цель — список нарушений с указанием файла и принципа.

---

## Найденные баги — 2026-06-19

> Проверено по коду (компиляция OK, 1147 тестов зелёные). Severity: HIGH / MEDIUM / LOW.
> Полный отчёт с обоснованиями: `docs/audit-report-2026-06-19.md`.

- [ ] **[HIGH] `getRidesForUser` теряет поездки у мультироль-пользователей** — `ride/src/main/scala/com/shevchyk/ride/application/service/RideService.scala:170` — `findByClientId(userId).orElse(findByDriverId(userId))`: `.orElse` отдаёт driver-поездки только если client-запрос УПАЛ, а не объединяет списки. Для диспетчера-водителя driver-поездки молча пропадают. Фикс — объединить списки + `distinctBy(_.id)`. _Категория: Functional._
- [ ] **[HIGH] `assignDriver` не валидирует ScheduleDay** — `ride/src/main/scala/com/shevchyk/ride/application/service/RideService.scala` (метод assignDriver) — заявленное правило «назначение должно ссылаться на валидный ScheduleDay» (CLAUDE.md constraint #3) не реализовано: поездку с `scheduleDayId` можно назначить, даже если день отсутствует/отменён/чужой. _Категория: Functional._
- [ ] **[HIGH] ChatService на `Task` + `RuntimeException`** — `ride/src/main/scala/com/shevchyk/ride/application/service/ChatService.scala:10-12` — нарушает «ZIO typed, no throw»: `sendMessage/getMessages: Task[...]`, ошибки кидаются как `new RuntimeException(...)`. Нужен `sealed trait ChatError` + `IO[ChatError, _]`. _Категория: SOLID._
- [ ] **[MEDIUM] `InvoiceStatus.fromString` молча → `Draft`** — `billing/src/main/scala/com/shevchyk/billing/domain/Invoice.scala` (`case _ => Draft`), используется при чтении из БД `billing/.../repository/PostgresInvoiceRepository.scala:82`. Неизвестный/повреждённый статус читается как черновик (оплаченный счёт → Draft). Фикс — Option/Either + явный fail. _Категория: Functional._
- [ ] **[MEDIUM] Неисчерпывающий match по `PersonRole`** — `ride/src/main/scala/com/shevchyk/ride/application/service/RideService.scala` (`validateCancelPermission`) — нет `case _`; новая роль даст MatchError в рантайме. Добавить явный deny-`case _`. _Категория: Functional._
- [ ] **[MEDIUM] Ошибки уведомлений/аудита глушатся при назначении** — `ride/src/main/scala/com/shevchyk/ride/application/service/RideService.scala` (assignDriver) — `eventHub.publish(...).ignore` (без tapError), `emailSmsService.send...().ignore`, `auditService.log(...).ignore`: водитель может не узнать о назначении, нет алерта. Добавить единообразный `.tapError(logWarning)`. _Категория: Functional._
- [ ] **[MEDIUM] Пагинация не валидирует отрицательные offset/limit** — `ride/src/main/scala/com/shevchyk/ride/openapi/RideApi.scala` (listRides) — `limit=-1`/`offset=-10` уходят в SQL без проверки. Клампить (limit 1..200, offset ≥ 0). _Категория: Functional._
- [ ] **[MEDIUM] RideService — god-object (SRP/ISP)** — `ride/src/main/scala/com/shevchyk/ride/application/service/RideService.scala` — trait ~27 методов / ~786 строк (CRUD + статус-машина + статистика + платежи + company-запросы); `RideRepository` ~29 методов. Выделить `RideStatsService`/`RideStatsRepository` и платежи. _Категория: SOLID._
- [ ] **[MEDIUM] Дублирование инфраструктуры между модулями** — `Validator` trait продублирован (`ride/.../validation/Validator.scala` и `schedule/.../validation/Validator.scala`); два расходящихся `ClientCompanyRepository` (core vs billing); DATEV CSV скопирован в `ride/.../openapi/ExportApi.scala`; `checkRole`/`requireCompanyId` переопределены в `RideSecure` и `UserApi`. Вынести общее в `core`. _Категория: SOLID._
- [ ] **[MEDIUM] Бизнес-логика в HTTP-хендлерах** — `ride/src/main/scala/com/shevchyk/ride/openapi/RideApi.scala` (createRide) — override clientId по роли и валидация рейтинга 1..5 в хендлере вместо application/validator-слоя. _Категория: SOLID._
- [ ] **[LOW] Self-data чтения без company-фильтра (defense-in-depth)** — `api/src/main/scala/com/shevchyk/app/openapi/GdprApi.scala` (export) и `ride/src/main/scala/com/shevchyk/ride/openapi/ExpenseApi.scala:83` — `findByClientId/findByDriverId(user.userId)` без company-фильтра. НЕ эксплуатируется (один PersonId = одна компания), но перейти на `*AndCompany`-варианты. _Категория: Security._
- [ ] **[LOW] Неотфильтрованные repo-методы провоцируют будущие tenant-баги** — `ride/.../repository/PostgresRideRepository.scala` (`findAll/findByClientId/findByDriverId`) и `PostgresExpenseRepository.findByDriverId` — нет `company_id` в WHERE. Сейчас не утечка (зовут по своему id), но ловушка. Добавить фильтр или задепрекейтить в пользу `*AndCompany`. _Категория: Security._
- [ ] **[LOW] `PaymentChecker` — постоянный мок** — `billing/src/main/scala/com/shevchyk/billing/application/PaymentChecker.scala` — `isPaid` всегда `false` по дизайну; авто-сверка с банком не происходит, только ручной `markPaid`. Известно/намеренно, зафиксировано чтобы не приняли за баг. _Категория: Functional._
