# Dispax — Claude Code Instructions

## Project Overview

Dispax — платформа диспетчеризации поездок для малого и среднего транспортного бизнеса (такси, корпоративные трансферы). MVP нацелен на Мюнхен и пригороды (до 100 км). Бизнес-клиенты: время критично, клиент не ждёт.

**Роли:** Driver, Client, Secretary, Dispatcher, Admin  
**Мультитенантность:** все данные изолированы по `CompanyId`  
**Требования к продукту:** `docs/requirements.md`

---

## Architecture

```
Flutter (web/mobile)
        ↓ HTTPS / WebSocket
    api (ZIO-HTTP, port 8080)
        ↓ ZIO Layers
  ┌─────┬──────┬────────┬──────────┬──────────┬─────────┐
core  auth  ride  driver  schedule  notification  billing
        ↓
  PostgreSQL 16 (Doobie + HikariCP + Flyway)
        ↓
  GCP Cloud Run (europe-west1)
```

**Backend:** Scala 3.3.7 + ZIO 2 + ZIO-HTTP 3 + Doobie + ZIO-JSON  
**Frontend:** Flutter 3.8+ + flutter_bloc + Google Maps + Mapbox + Firebase Messaging  
**Auth:** JWT (stateless) + JBCrypt  
**Push:** Firebase Cloud Messaging  
**Migrations:** Flyway (`api/src/main/resources/db/migration/`)

---

## Module Map

| Module | Назначение |
|--------|-----------|
| `core` | Shared domain: IDs (UUID v7), Location, Person, Company, сессии, DB utils, конфиг |
| `auth` | JWT-аутентификация, управление пользователями, rate limiting |
| `ride` | Lifecycle поездок: CRUD, назначение водителей, статусная машина, рейтинги, расходы |
| `driver` | Отслеживание локации водителей, расчёт близости |
| `schedule` | Расписание водителей (дни, смены, доступность) |
| `notification` | Firebase Cloud Messaging, оркестрация уведомлений |
| `billing` | Счета, клиентские компании, DATEV-экспорт |
| `api` | HTTP entry point: агрегация маршрутов (14 route-файлов), DI wiring в `Application.scala` |
| `web` | Flutter app: BLoC, экраны, сервисы, тема, локализация (DE/EN/UK) |

---

## Key Patterns

### Layered Architecture (каждый модуль)
```
domain/          — чистые case class, enum, value object (без зависимостей)
application/     — сервисы, бизнес-логика, валидаторы (ZIO layers)
infrastructure/
  http/          — route handlers + DTO
    dto/         — Request/Response DTO
  repository/    — Doobie + PostgreSQL
```

### ZIO Layers (DI)
Все сервисы и репозитории предоставляются через `ZLayer`. Точка сборки — `api/src/main/scala/com/shevchyk/Application.scala`.

### Authenticated Routes
Используй `authenticatedHandler` / `authenticatedJsonHandler` из core middleware. Хелперы извлекают JWT-claims и `CompanyId` автоматически.

### Company Isolation
**Обязательно** для каждого запроса: фильтруй данные по `CompanyId` из JWT-claims. Нарушение изоляции — критическая ошибка безопасности.

### Repository Pattern
Trait в корне модуля → PostgreSQL-реализация в `infrastructure/repository/`. Для тестов — in-memory реализация в `src/test/`.

### Ride Status Machine
```
Requested → Assigned → InProgress → Completed
                     ↘ Cancelled
```
Только поездки со статусом `Requested` можно назначать водителю.

### Validation
Typeclass `Validator` с `given`-инстансами для каждого request DTO. Валидация — в `application/validation/`.

---

## Build & Run

```bash
# Локальная разработка
docker-compose up -d          # PostgreSQL на порту 5432
make dev                      # Запуск сервера с .env.dev (порт 8080)

# Flutter
make flutter-dev              # Запуск на подключённом устройстве (→ local backend)
make flutter-dev-android      # Android emulator
make flutter-dev-ios          # iOS simulator
make dev-all                  # Backend + Flutter на обоих устройствах

# Сборка
sbt assembly                  # Fat JAR → dispax-server.jar
make deploy                   # Build JAR → Docker push → Cloud Run deploy

# Форматирование
make fmt                      # Scalafmt
make fmtAll                   # Scala + Dart
```

---

## Testing

```bash
make test                     # Unit + integration (без Cucumber)
make test-bdd                 # Cucumber BDD сценарии
make test-all                 # Все тесты
make flutter-test-integration # Flutter integration tests → local TestApplication
```

**Стратегия:**
- **Unit**: in-memory реализации репозиториев (например, `InMemoryRideRepository`, `MockPersonRepository`)
- **Integration**: Testcontainers + реальный PostgreSQL — **не мокать БД в интеграционных тестах**
- **BDD**: Cucumber сценарии в `api/src/test/scala/com/shevchyk/app/`
- **Flutter**: `bloc_test` + `mocktail`

**Тестовые данные:** Flyway-миграция `V1001__Insert_dev_data.sql` (только dev-окружение)

---

## Business Rules & Constraints

Полные требования: `docs/requirements.md`

**Ключевые ограничения:**
1. Компании изолированы — водители назначаются только на поездки своей компании
2. Назначить можно только поездку со статусом `Requested`
3. Назначение должно ссылаться на валидный `ScheduleDay`
4. Расчёт времени в пути через Google API для валидации расписания
5. Клиент не ждёт — приоритет пунктуальности над утилизацией водителей
6. Поездки создаёт: секретарь, диспетчер, водитель или клиент

---

## Coding Conventions

- Scala 3: prefer `given`/`using`, opaque types для ID, extension methods
- ZIO effect system везде — никаких Future, никаких `throw`
- DTO отделены от доменных объектов; маппинг в route-handler или application layer
- JSON: ZIO-JSON (`@jsonField`, `JsonDecoder`/`JsonEncoder`) — основной; Circe только где уже используется
- IDs: UUID v7 (time-ordered) через UUID Creator
- Логирование: ZIO Logging (`ZIO.logInfo`, `ZIO.logError`)
- Для маршрутов: группируй public и authenticated эндпоинты в отдельные методы внутри одного route-класса
- Flutter: BLoC pattern для всего состояния, `Repository` абстракция для API-вызовов

---

## Environment & Config

```bash
# .env.dev (dev) / env vars в Cloud Run (prod)
DATABASE_URL=jdbc:postgresql://localhost:5432/oktopus
DATABASE_USER=oktopus
DATABASE_PASSWORD=oktopus
JWT_SECRET=dev-secret-change-in-production
APP_ENV=development
PORT=8080
```

**docker-compose.yml** поднимает PostgreSQL 16 (порт 5432, БД: `oktopus`)  
**Production URL:** `https://oktopus-456043977402.europe-west1.run.app`  
**CI/CD:** GitHub Actions → push to `main` → sbt assembly → Docker → Cloud Run

---

## What NOT to Do

- Не мокать БД в интеграционных тестах — используй Testcontainers
- Не нарушать изоляцию компаний (`CompanyId`) ни в одном запросе
- Не использовать `Future` или `throw` — только ZIO effects
- Не добавлять бизнес-логику в route handlers — только в application layer
- Не хардкодить секреты — только через env vars
