# Аудит юнит-тестов Oktopus — июнь 2026

## Резюме

Бэкенд покрыт **890 тест-кейсами в 76 файлах** на ZIO Test (Scala 3.3.7, ZIO 2.1.9).
Покрытие в целом зрелое: статусная машина поездок, изоляция по `CompanyId`, валидаторы,
репозитории (in-memory + Testcontainers). Аудит сфокусирован на **edge cases в критичной
для бизнеса и безопасности логике**, где возможны скрытые баги.

### Статистика по модулям

| Модуль        | Файлов | Тест-кейсов | Фокус |
|---------------|--------|-------------|-------|
| ride          | 20     | 288         | Lifecycle, назначение, доход, чат, локации |
| api           | 13     | 165         | HTTP-маршруты, интеграция |
| core          | 15     | 124         | Репозитории, Audit, Geofence, EventHub |
| auth          | 8      | 97          | JWT, rate limiting, middleware |
| schedule      | 6      | 74          | Расписание, валидация |
| billing       | 5      | 64          | Счета, PDF, DATEV |
| notification  | 5      | 41          | FCM, оркестрация |
| driver        | 4      | 37          | Локация, маршруты |
| **Итого**     | **76** | **890**     | |

---

## Найденные пробелы покрытия

Легенда: ✅ закрыто новым тестом · 🐛 кандидат на баг-фикс (поведение требует решения).

### 1. Ride — `RideServiceImpl`
`ride/src/main/scala/com/shevchyk/ride/application/service/RideService.scala`

- ✅ **Schedule conflict — граница интервала.** `ridesOverlap` (порог `gap < 90 min`):
  были тесты на 10 мин и 90 мин, но отсутствовал тест ровно на границе (89/90/91 мин) —
  классический off-by-one.
- ✅ **Конфликт без `scheduledTime`.** Fallback на `requestTime` не был покрыт.
- ✅ **`updateRideStatus` — роли Secretary/Client.** Метод разрешает смену статуса только
  Driver и Dispatcher; отказ для остальных ролей не тестировался.
- ✅ **`updateRideStatus` → недопустимый целевой статус** (`Requested`/`Assigned`):
  ветка `case target` → `InvalidStatusTransition` не была покрыта явно.
- ✅ **`earningsWindow`** — границы Week при `anchor = воскресенье` и Month на стыке
  декабрь→январь (пересечение года через `plusMonths`).
- ✅ **`markPayment`** — `paidAt` ставится только при статусе `Paid`; `paymentMethod = None`
  сохраняет прежнее значение.

### 2. Auth/JWT — `JwtServiceImpl`
`auth/src/main/scala/com/shevchyk/auth/service/JwtService.scala`

- ✅ **Absolute session expiry.** `refreshToken` должен падать `ExpiredTokenError`, когда
  `now - originalIat > maxSessionDuration` — ранее не тестировалось вообще.
- ✅ **`originalIat` сохраняется при refresh.** Если бы обновлялся — сессия жила бы вечно
  (security-баг). Тест фиксирует неизменность.
- ✅ **Refresh истёкшего токена** → ошибка (через внутренний `validateToken`).
- ✅ **issuer валидируется в `validateToken`.** Раньше токен с чужим issuer, но тем же secret,
  проходил проверку. Исправлено: `validateToken` сверяет `claim.issuer` с конфигом и падает
  `InvalidTokenError` при несовпадении. **Примечание:** audience не enforced — jwt-scala
  декодирует одиночный `aud` обратно в `None`, поэтому надёжной проверкой является issuer.

### 3. Billing — `InvoiceServiceImpl.recalculate`
`billing/src/main/scala/com/shevchyk/billing/application/InvoiceService.scala`

- ✅ **Tax rounding.** Раньше `tax = subtotal * taxRate / 100` хранился без округления
  (`33.33 × 19% = 6.3327`), расходясь с PDF (2 знака). Исправлено: `recalculate` округляет
  `subtotalAmount`/`taxAmount`/`totalAmount` через `setScale(2, HALF_UP)`.
- ✅ **`taxRate = 0`** → `taxAmount = 0`, `total = subtotal`.
- ✅ **`autoFillFromPeriod` на не-Draft** → `NotDraft`.

### 4. Геолокация / валидация координат

- ✅ **Валидация диапазона lat/lng.** Раньше `ClientLocationService.updateClientLocation`,
  `DriverLocationService.updateLocation` и DTO-валидаторы принимали любые координаты
  (должно быть lat ∈ [−90, 90], lng ∈ [−180, 180]) — мусор попадал в БД и ломал
  Haversine/geofence. Исправлено: guard в `ClientLocationService` (`RideError.ValidationError`)
  и в `DriverLocationService` (`IllegalArgumentException`) + тесты на отклонение и границы.
- ✅ **`GeofenceService`** — geofence с `radiusMeters = 0` (граница окружности; `distance < radius`
  строгое, поэтому даже в центре driver не «внутри»). **Дедупликация уже была покрыта**
  существующими тестами «no duplicate entries on second call» и «no re-trigger for same
  threshold» — добавлять не потребовалось.
- ✅ **`DriverLocationService.checkGeofences`** — driver с поездками в разных компаниях
  использует companyId первой поездки (поведение зафиксировано тестом).

---

## Баг-фиксы (все исправлены)

1. ✅ **JWT issuer** — `validateToken` теперь отклоняет токен с чужим issuer, даже при том же
   secret (`InvalidTokenError`). Audience не enforced из-за ограничения jwt-scala (одиночный
   `aud` декодируется в `None`). Тесты: отказ по issuer + приёмка валидного токена.
2. ✅ **Tax rounding в InvoiceService** — `recalculate` округляет `subtotalAmount`/`taxAmount`/
   `totalAmount` до 2 знаков (`setScale(2, HALF_UP)`). Тест: `33.33 × 19% → tax 6.33, total 39.66`,
   scale == 2.
3. ✅ **Валидация координат в `DriverLocationService.updateLocation`** — guard на диапазон
   lat ∈ [−90, 90] / lng ∈ [−180, 180]; при выходе — `IllegalArgumentException` (сигнатура
   метода `Task[Unit]`). Тесты на отклонение и на граничные значения.
4. ✅ **`ClientLocationService.updateClientLocation`** — отклоняет координаты вне диапазона
   (`RideError.ValidationError`).

Эти пункты затрагивают продакшн-логику и денежные/безопасностные инварианты — вынесены
отдельно, чтобы решение принималось осознанно, а не «по ходу» правки тестов.
