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
- 🐛 **issuer/audience не валидируются в `validateToken`.** Токен с чужим issuer/audience,
  но тем же secret, проходит проверку. Тест фиксирует текущее поведение. **Рекомендация:**
  добавить проверку `claim.issuer == config.issuer` и audience в `validateToken`.

### 3. Billing — `InvoiceServiceImpl.recalculate`
`billing/src/main/scala/com/shevchyk/billing/application/InvoiceService.scala`

- 🐛 **Tax rounding.** `tax = subtotal * taxRate / 100` без явного округления до 2 знаков.
  При суммах вроде `33.33 × 19%` хранится «грязная» дробь (`6.3327`), расходящаяся с PDF
  (формат 2 знака). Тест фиксирует текущее поведение. **Рекомендация:** округлять
  `taxAmount`/`totalAmount` через `setScale(2, HALF_UP)`.
- ✅ **`taxRate = 0`** → `taxAmount = 0`, `total = subtotal`.
- ✅ **`autoFillFromPeriod` на не-Draft** → `NotDraft`.

### 4. Геолокация / валидация координат

- 🐛 **Нет валидации диапазона lat/lng.** `ClientLocationService.updateClientLocation`,
  `DriverLocationService.updateLocation` и DTO-валидаторы принимали любые координаты
  (должно быть lat ∈ [−90, 90], lng ∈ [−180, 180]). Мусорные координаты попадали в БД
  и ломали Haversine/geofence. **Баг-фикс:** добавлен guard в `ClientLocationService`
  (`RideError.ValidationError`) + тест на отклонение `lat=91`/`lng=181`.
- ✅ **`GeofenceService`** — geofence с `radiusMeters = 0` (граница окружности; `distance < radius`
  строгое, поэтому даже в центре driver не «внутри»). **Дедупликация уже была покрыта**
  существующими тестами «no duplicate entries on second call» и «no re-trigger for same
  threshold» — добавлять не потребовалось.
- ✅ **`DriverLocationService.checkGeofences`** — driver с поездками в разных компаниях
  использует companyId первой поездки (поведение зафиксировано тестом).

---

## Оставшиеся кандидаты на баг-фикс (требуют решения)

1. **JWT issuer/audience** — добавить проверку в `validateToken` (тест-«пин» текущего
   поведения уже стоит; после фикса перевернуть `isSuccess` → `isFailure`).
2. **Tax rounding в InvoiceService** — округлять `taxAmount`/`totalAmount` до 2 знаков
   (`setScale(2, HALF_UP)`); тест-«пин» сырого результата уже стоит.
3. **Валидация координат в `DriverLocationService.updateLocation`** — guard аналогично
   уже исправленному `ClientLocationService.updateClientLocation`. Текущая сигнатура
   `Task[Unit]` (не типизированный `RideError`), поэтому требуется отдельное решение:
   `IllegalArgumentException`-fail либо обрезка диапазона.

**Уже исправлено в рамках аудита:** `ClientLocationService.updateClientLocation` теперь
отклоняет координаты вне диапазона lat ∈ [−90, 90] / lng ∈ [−180, 180]
(`RideError.ValidationError`).

Эти пункты затрагивают продакшн-логику и денежные/безопасностные инварианты — вынесены
отдельно, чтобы решение принималось осознанно, а не «по ходу» правки тестов.
