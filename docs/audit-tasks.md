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

---

## Найденные баги — конкурентность/деньги — 2026-06-20

> Проверено по коду (находки агентов отфильтрованы; ложные срабатывания исключены — повтор-отмены fee, таймзона isInThePast). Severity: HIGH / MEDIUM / LOW.

- [x] **[MEDIUM] Отрицательный `fee` при отмене не валидируется** — `ride/src/main/scala/com/shevchyk/ride/domain/RideDomain.scala:185` (`CancelRideRequest.fee: Option[BigDecimal]`) + `ride/.../openapi/RideApi.scala:484-495` (`cancelRideServer` не вызывает `.validate`, передаёт `fee` напрямую) — диспетчер может передать `fee = -100` → отрицательная «комиссия» = по сути рефанд клиенту. Прямо влияет на деньги. Фикс — валидатор `CancelRideApiRequest` с проверкой `fee >= 0` (по аналогии с `validatePrice` в `RideValidators`). _Категория: Functional._ — **ИСПРАВЛЕНО** (master 79776a3): `cancelRideApiRequestValidator` + `.validate` в хендлере + гард в `cancelRideWithReason`; тесты валидатора и сервиса.
- [ ] **[MEDIUM] `markPayment` перетирает зафиксированный способ оплаты** — `ride/src/main/scala/com/shevchyk/ride/application/service/RideService.scala:614-641` — `paymentMethod.orElse(ride.paymentMethod)` (632-633): повторный вызов с `Some(Card)` перетрёт уже сохранённый `Cash`; нет гарда «способ оплаты уже зафиксирован для оплаченной поездки». Важно для DATEV/бухгалтерии. Фикс — не менять `paymentMethod`/`paidAt` если ride уже `Paid`. _Категория: Functional._
- [ ] **[MEDIUM] TOCTOU при cancel/start/complete (безусловный `update`)** — `ride/src/main/scala/com/shevchyk/ride/application/service/RideService.scala` — `cancelRide:225-236`, `cancelRideWithReason:246-265`, `startRide:~205`, `completeRide:210-220` читают ride, проверяют статус, затем делают **безусловный** `rideRepository.update(...)`. Между read и update конкурентный переход (напр. → Completed) перетирается. Контраст с `assignDriver`/`reassignDriver`, где есть атомарный `updateIfStatus`. Фикс — перевести на `updateIfStatus(updated, Set(допустимые исходные статусы))`. _Категория: Functional._
- [ ] **[LOW] TOCTOU проверки конфликта расписания** — `ride/src/main/scala/com/shevchyk/ride/application/service/RideService.scala:731-753` (`checkScheduleConflict`) — читает активные поездки водителя ДО атомарного `updateIfStatus` в `assignDriver:445`/`reassignDriver:543`. `updateIfStatus` гейтит только статус назначаемой поездки, не пересечение расписания: два диспетчера могут одновременно назначить одного водителя на пересекающиеся слоты, оба пройдут. Узкое окно. Фикс — SQL-level exclusion constraint или проверка внутри транзакции назначения. _Категория: Functional._
- [ ] **[LOW] TOCTOU blacklist при reassign** — `ride/src/main/scala/com/shevchyk/ride/application/service/RideService.scala:539-550` (`reassignDriver`) — проверка `isBlacklisted` (539) выполняется до `updateIfStatus` (550), который blacklist не гейтит. Если водителя добавят в blacklist ровно между проверкой и записью — reassign всё равно пройдёт. Очень узкое окно, низкий импакт. _Категория: Functional._

---

## Бизнес-нестыковки (требования ↔ реализация) — 2026-06-21

> Аудит против `docs/requirements.md` + инвариантов CLAUDE.md. Помечено, что проверено лично по коду, а что — находка агента (требует доперепроверки перед фиксом). Дедуп с разделами выше: ScheduleDay-валидация уже зафиксирована (см. `[HIGH] assignDriver не валидирует ScheduleDay`); пункт по мультироли ниже шире, чем `getRidesForUser` (стр. с `[HIGH] getRidesForUser теряет поездки`).

- [ ] **[HIGH] Мультироль игнорируется во всех Tapir secure-слоях, кроме `AppSecure`** _(проверено лично)_ — `ride/.../openapi/RideSecure.scala:38-61`, `driver/.../openapi/DriverApi.scala:75-99`, `schedule/.../openapi/ScheduleApi.scala:58-79` (`requireDispatcherOrAdmin`), `api/.../openapi/UserApi.scala:93-104` — строят `AuthenticatedUser` без `roles` и проверяют права только по primary-роли (`user.role`), хотя JWT несёт `roles` и эталон `api/.../openapi/AppSecure.scala:15-65` использует `effectiveRoles`. Заявлено «диспетчер может быть водителем» (`Person.roles: Set[PersonRole]`). Эффект: dispatcher-as-driver (primary=Dispatcher) получает 403 на driver-эндпоинтах поездок/расписания и не может вести свои поездки как водитель. Системная причина — копия `checkRole` без `effectiveRoles`. _Категория: Functional/Security._
- [ ] **[HIGH] Цена и оценка теряются при создании поездки** _(проверено лично)_ — `ride/.../infrastructure/http/dto/RideApiModels.scala:99` (`CreateRideApiRequest.price`) + `toDomain` `:351-380` не переносит `price`; `CreateRideRequest` (`ride/.../domain/RideDomain.scala:229-239`) поля цены не имеет; `RideService.createRide` не вызывает `RideEstimateService`. Поездка всегда создаётся с `estimatedPrice=None`/`finalPrice=None`. Эффект: `/estimate` показывает клиенту цену, но в поездке она не сохраняется → vehicle-class multiplier и ночная надбавка не доходят до биллинга, счёт без цены/надбавок. _Категория: Functional._
- [ ] **[HIGH] Противоречие Netto/Brutto: счёт vs квитанция** _(проверено лично)_ — `billing/.../application/InvoiceService.scala:45` (комментарий «ride price treated as gross/Brutto») против `recalculate` `:361-366`, где `ride.price` → `item.total` → `subtotal` трактуется как Netto и НДС накручивается сверху (`tax = subtotal*rate/100`, `total = subtotal+tax`); при этом квитанция `billing/.../application/PdfGenerator.scala:245-247` трактует ту же цену как Brutto (`net = gross/(1+rate)`). Одна цена → в счёте завышенный итог и неверный MwSt (юридически значимый документ, DATEV). _Категория: Functional._
- [ ] **[MEDIUM] Лимит поездок на водителя в день не реализован** _(находка агента — доперепроверить)_ — `ride/.../application/service/RideService.scala:447-602` (`assignDriver`/`reassignDriver`) — Business Rule #5 «Respect maximum rides per driver per day» не проверяется при назначении. _Категория: Functional._
- [ ] **[MEDIUM] Travel time захардкожен 60 мин вместо routing-API** _(находка агента — доперепроверить)_ — `ride/.../application/service/RideService.scala:~752-800` (`checkScheduleConflict`/`ridesOverlap`) — `DefaultRideDurationMinutes = 60` для всех поездок независимо от расстояния (покрытие до 100 км). Требование #12 предполагает расчёт через Google/HERE. Недостоверный буфер → риск опозданий при приоритете «client should not wait». _Категория: Functional._
- [ ] **[MEDIUM] Таймзона UTC вместо Europe/Berlin в документах/границах суток** _(частично проверено)_ — `billing/.../application/PdfGenerator.scala:183,241` форматирует дату/время квитанции через `ZoneOffset.UTC`; Мюнхен = UTC+1/+2, дата/время в Quittung смещается на 1-2 часа. Тот же риск для границ суток ночной надбавки и «today's rides». _Категория: Functional._
- [ ] **[MEDIUM] Фиксированные тарифы по клиент-компании не реализованы** _(находка агента — доперепроверить)_ — ride-модуль считает цену только distance/time-based; логики fixed-price по `clientCompanyId` нет. Требование #9 «agreements with companies, price is fixed». _Категория: Functional._
- [ ] **[LOW] `cancellationFee` не применяется автоматически; waiting fee отсутствует** _(находка агента)_ — `cancellationFee` сохраняется при отмене, но не подтягивается из `core/.../domain/CompanySettings.scala` (`cancellationFeeDefault`) и не попадает в биллинг; платы за ожидание (клиент опоздал 30+ мин) нет вовсе. _Категория: Functional._
- [ ] **[LOW] Несогласованность wire-формата роли в ride/driver-слоях** _(проверено лично)_ — `ride/.../openapi/RideSecure.scala:78-86` (`toPersonRole`) не знает `CLIENT_SECRETARY`/`SUPER_ADMIN` → молча `case _ => Client`; `driver/.../openapi/DriverApi.scala:302` зовёт `PersonRole.valueOf(user.role)` на `.toString`-форме роли — рассогласование форматов сервер↔слой. _Категория: Functional._
