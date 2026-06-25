# Testing

Как запускать тесты локально и что в проекте вообще тестируется.

## TL;DR — что запускать

```bash
make test-unit        # быстрый inner-loop: только unit, без Docker (секунды)
make test-watch       # живая sbt-сессия: unit-тесты на каждое сохранение (см. ниже)
make test             # unit + integration (нужен Docker/Postgres) — ПЕРЕД мержем
make test-bdd         # Cucumber BDD-сценарии (нужен Docker; освободить порт 8080)
make test-everything  # ВСЁ что гейтит CI: backend + BDD + Flutter (последовательно)
make test-unit-all    # Scala unit + Flutter (web) unit/widget тесты
```

**Параллельные варианты** (быстрее, но через изолированные git-worktree — детали
ниже в разделе «Параллельный запуск»):

```bash
make test-bdd-parallel        # BDD в 3 шарда параллельно (~67s → ~47s warm)
make test-everything-parallel # все тиры разом: unit|integration|BDD|Flutter (~−40% warm)
```

CI (GitHub Actions) гоняет **только тесты** (Scala test+coverage, Cucumber BDD,
Flutter analyze+test). Деплой делается вручную: `make deploy`.

---

## Уровни тестов

| Уровень                 | Где                                                       | Чем                                           | Нужен Docker            |
|-------------------------|-----------------------------------------------------------|-----------------------------------------------|-------------------------|
| **Unit**                | `*/src/test` (in-memory репозитории)                      | ZIO Test                                      | нет                     |
| **Integration**         | `*/src/test` со специями, помеченными тегом `integration` | ZIO Test + Testcontainers (реальный Postgres) | **да**                  |
| **BDD**                 | `api/src/test/.../app/` + `*.feature`                     | Cucumber 7.15                                 | да                      |
| **Flutter unit/widget** | `web/test/`                                               | `flutter_test` + `bloc_test` + `mocktail`     | нет (нужен Flutter SDK) |
| **Flutter e2e**         | `web/integration_test/`                                   | живой backend (TestApplication)               | да                      |

**Ключевой механизм:** unit и integration живут в одних модулях и различаются
**тегом** `@@ TestAspect.tag("integration")`, а не папкой. Фильтрация:
- `-ignore-tags integration` → только unit (`make test-unit`)
- `-tags integration` → только integration (`make test-integration`)

---

## Что есть в проекте (ориентир по объёму)

**Scala unit-тесты** (`make test-unit`, ~800 кейсов):

| Модуль | ~unit-кейсов |
|--------|-------------|
| ride | ~275 |
| core | ~144 |
| auth | ~110 |
| api (проект `root`, `api/src/test`) | ~110 |
| schedule | ~85 |
| notification | ~53 |
| driver | ~33 |
| billing | ~18 |

> Модуль `api` физически не отдельный sbt-проект — он живёт в `root`
> (`api/src/test`), поэтому в `make test-unit` подключён как
> `root/testOnly *Spec` (glob `*Spec` берёт ZIO-специи, но НЕ JUnit
> `CucumberRunner`).

**BDD:** ~170 `.feature`-файлов, ~1280 Cucumber-сценариев (`make test-bdd`).

**Flutter:** ~28 unit/widget тестов в `web/test/`; ~43 e2e в `web/integration_test/`
(против живого backend).

---

## Команды подробно

### Backend (sbt через make)

```bash
make test-unit        # = test-fast. Только unit, in-memory репо, без Docker.
                      #   Это команда для повседневной разработки.
make test             # unit + integration (Testcontainers). Перед мержем.
make test-integration # только integration (Testcontainers). Нужен Docker.
make test-bdd         # Cucumber. Перед запуском освободить порт 8080.
make test-all         # make test + make test-bdd.
```

Один модуль / один тест напрямую через sbt:
```bash
sbt "ride/testOnly * -- -ignore-tags integration"      # все unit ride
sbt "ride/testOnly *RideServiceSpec"                    # один спек
sbt "root/testOnly *Spec -- -ignore-tags integration"  # api unit
```

### Flutter

```bash
make test-unit-all          # Scala unit + Flutter unit (web/test)
make flutter-test-unit      # только Flutter unit/widget (= flutter test test/)
make flutter-test-integration  # e2e против локального TestApplication (порт 8090)
```

---

## Inner-loop: `make test-watch`

Для цикла «правка → тест» держит **одну живую sbt-сессию** и перезапускает
только затронутые unit-тесты на каждое сохранение файла. Так цикл занимает ~1с
вместо ~8с, которые каждый отдельный `make test-unit` тратит на старт JVM +
проверку компиляции.

```bash
make test-watch              # все модули, unit-тир (-ignore-tags integration)
make test-watch MOD=ride     # только один модуль
```

Ctrl-C останавливает наблюдение. Это инструмент разработки — перед мержем всё
равно гонять `make test` (unit + integration).

---

## Параллельный запуск

Тесты намеренно идут **последовательно** ради изоляции общего состояния (общая
схема Postgres у integration, общий in-memory сервер у BDD). Ускорить можно
только настоящим параллелизмом, а он требует, чтобы у каждого параллельного
прогона был **свой каталог проекта** — иначе два `sbt` в одной папке дерутся за
boot-lock и server-socket. Поэтому параллельные цели запускают тиры в отдельных
**git-worktree**.

### `make test-bdd-parallel` — BDD в 3 шарда

Бьёт 343 BDD-сценария на 3 сбалансированные трети (`CucumberShard1/2/3Runner`) и
гоняет их в 3 worktree на портах 8101–8103. `CucumberShardCoverageSpec`
гарантирует, что шарды вместе покрывают все `.feature` (новый файл, не попавший в
шард, → красный тест). `make test-bdd-parallel-clean` удаляет worktree.

### `make test-everything-parallel` — все тиры разом

Опциональный быстрый аналог `make test-everything`: запускает
**unit | integration | BDD | Flutter** одновременно, каждый backend-тир в своём
worktree (`../dispax-tap-{unit,int,bdd}`). BDD работает на порту **8090**, поэтому
не конфликтует с запущенным `make dev` (8080). `make test-all-parallel-clean`
удаляет worktree.

### Важные оговорки (для обеих параллельных целей)

- **Worktree переиспользуются между прогонами.** Первый прогон компилирует проект
  в каждом worktree заново (≈ втрое медленнее последовательного); выигрыш — на
  втором и последующих («warm»). Числа выше (47s, −40%) — для warm.
- **Под пиковой нагрузкой возможна flakiness.** При одновременной холодной
  компиляции нескольких worktree машина перегружена: BDD-сервер может не успеть
  стартовать (лечится `BDD_SERVER_STARTUP_MS`, цель ставит 90с вместо дефолтных
  15с), а отдельные тайминг-чувствительные Flutter bloc-тесты — мигать. На warm не
  воспроизводится.
- **Канонический гейт — последовательные `make test` / `make test-everything`.**
  Параллельные цели — это удобная опция для скорости, а не замена гейта.

---

## Требования

- **Docker** — для `make test`, `make test-integration`, `make test-bdd`
  (Testcontainers поднимает реальный Postgres). `docker compose up -d` для dev-БД.
- **Flutter SDK** — для Flutter-целей.
- **Порт 8080** должен быть свободен перед `make test-bdd` (или задать
  `PORT=8090 make test-bdd-port`, чтобы гонять рядом с `make dev`).
- **Порты 8090 / 8101–8103** используют параллельные цели
  (`test-everything-parallel` / `test-bdd-parallel`) — их BDD не трогает 8080,
  так что параллельный прогон уживается с запущенным `make dev`.

---

## Форматирование (проверяется в CI вместе с тестами)

```bash
make fmt       # scalafmt (вся Scala)
make fmtAll    # Scala + Dart
```

CI запускает `sbt scalafmtCheckAll scalafmtSbtCheck` — это **две** проверки:
`scalafmtCheckAll` для исходников и **отдельный** `scalafmtSbtCheck` для
`build.sbt`. После правок `build.sbt` запускать `sbt scalafmtSbt`.
Flutter: `dart format --set-exit-if-changed lib/` + `flutter analyze`
(падает на любых issues, включая info).

---

## Стратегия и принципы

1. **Unit** — in-memory реализации репозиториев (`InMemoryRideRepository`,
   `MockPersonRepository` и т.п.). Быстро, без БД.
2. **Integration** — Testcontainers + реальный Postgres. **Не мокать БД** в
   интеграционных тестах.
3. **BDD** — Cucumber-сценарии в `api/src/test/scala/com/shevchyk/app/`,
   на in-memory репозиториях (TestApplication), Postgres не нужен.
4. **Изоляция** — unit-тесты не зависят от состояния БД; чистая архитектура
   (production-код не содержит тестовых данных).
5. **Тестовые данные** — Flyway dev-миграция
   `api/src/main/resources/db/migration-dev/V1001__Insert_dev_data.sql`
   (только dev-окружение), всегда детерминированная.

---

## Test framework

- **ZIO Test** — основной фреймворк unit/integration
- **Cucumber 7.15** — BDD acceptance
- **Testcontainers** — Postgres для integration
- **flutter_test / bloc_test / mocktail** — Flutter
