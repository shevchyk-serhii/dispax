# Dispax iOS — Apple App Store Review (как это сделала бы App Review)

**Дата ревью:** 2026-06-28
**Версия:** 1.0.0 (build 1) · Bundle `de.dispax.app` · Team `D74H38HXXR`
**Платформа:** Universal (iPhone + iPad), iOS deployment target 14.0/15.0
**Тип приложения:** B2B ride-dispatch платформа (Munich) — login-gated, аккаунты создаёт админ/диспетчер.

Отчёт написан как симуляция Apple App Review: что реально **заблокирует** аппрув, что **вероятно отклонит** на тестировании, что — гигиена. Это review, а не список правок: ничего в коде не менялось.

---

## Вердикт

> **Metadata Rejected / нужны действия перед сабмитом.** В самом коде нет фатального нарушения guidelines, но приложение **нельзя отправить как есть** из-за обязательных полей App Store Connect (Privacy Policy URL, App Privacy) и риска краша в основных flow. Код-блокеров уровня «реджект по содержанию» нет.

---

## Tier 1 — Блокирует сам процесс ревью / сабмит (сделать обязательно)

### 1.1 Privacy Policy URL — обязательное поле (нет ни в метаданных, ни в UI)
- **Guideline 5.1.1.** Apple **не примет** билд без Privacy Policy URL в App Store Connect — это hard-gate метаданных, независимо от кода.
- В приложении ссылки тоже **нет**: строки `privacyPolicy` / `termsOfService` есть в локализации (`lib/l10n/app_*.arb`), но **нигде не отрендерены** через `launchUrl` (проверено: 0 реальных ссылок в `lib/screens`, `lib/dashboard`).
- **Действие:** (1) опубликовать Privacy Policy + Terms на сайте и вписать URL в App Store Connect; (2) добавить кликабельную ссылку в `settings_screen.dart` (рядом с GDPR-разделом) и желательно на `login_screen.dart`.

### 1.2 App Privacy («nutrition label») + export compliance
- Apple требует декларацию собираемых данных в App Store Connect. Приложение собирает **precise location** (`geolocator`, Mapbox), device ID, фото профиля. Лейбл должен это отражать и совпадать с privacy-манифестами SDK (Firebase/GoogleMaps/Mapbox манифесты на месте — это PASS).
- **`ITSAppUsesNonExemptEncryption` отсутствует** в `ios/Runner/Info.plist` (проверено: 0 вхождений) → каждый билд будет спрашивать про export compliance. Добавить ключ (для HTTPS-only `false`).
- **Действие:** заполнить App Privacy под реальный сбор данных; добавить `ITSAppUsesNonExemptEncryption=false`.

### 1.3 Demo-доступ для ревьюера (Guideline 2.1)
- Приложение **login-gated, без self-service регистрации** — аккаунты заводит админ/диспетчер. Без рабочих кредов **ревьюер физически не войдёт** → почти гарантированный реджект 2.1.
- **Хорошая новость:** demo-аккаунты уже есть — `lib/modules/auth/widgets/test_credentials_card.dart` (client/driver/secretary/dispatcher/superadmin, пароль `password123`).
- **Действие:** в App Review Notes указать креды + объяснить ролевую модель (это B2B, регистрация invite-only). **Отдельно:** карточка тест-кредов не должна показываться в проде — спрятать за dev-флаг (см. Tier 3), иначе это «test/demo content» по 2.3.

---

## Tier 2 — Вероятный реджект, если ревьюер на это наткнётся

### 2.1 Риск краша в основных flow (force-unwrap'ы)
- Не нарушение само по себе, но Apple реджектит за краш во время теста. Плотность `!.` в критичных экранах высокая: `driver_map_screen.dart` ~56, `client_map_screen.dart` ~38 (всего по `lib/` ~289), включая цепочки `_currentRide!.clientLocation!.latitude!`.
- **Действие (тест, не рефактор):** прогнать вручную и стабилизировать сценарии, которые ревьюер обязательно пройдёт:
  - driver: accept → live-tracking → complete;
  - client: book → виден водитель на карте → cancel;
  - рендер карты при отсутствующих координатах.
  Где падает — закрыть null-guard'ами/`??`. Полный рефактор 289 анврапов не нужен — нужны устойчивые core-пути.

### 2.2 Placeholder / отключённые фичи (Guideline 2.1 — incomplete)
Ревьюер кликает по всему. Видимые «пустышки»:
- `superadmin_dashboard.dart`: вкладки **Users & Roles** и **Audit Log** — заглушки («Requires a /superadmin/... endpoint (not yet available)»).
- `company_settings_screen.dart`: кнопки **Audit Log** и **Blacklist** с `onTap: null` и меткой «TODO».
- `client_payment_screen.dart`: заглушка «Payment processing is not yet implemented» (в навигацию не подключена — ниже риск).
- **Действие:** скрыть/убрать недоделанные пункты для ролей, которые получит ревьюер (особенно SuperAdmin), либо не давать SuperAdmin-аккаунт на ревью. Дашборды driver/client/dispatcher выглядят завершёнными.

---

## Tier 3 — Гигиена (не блокирует, но поправить перед релизом)

- **Location usage string рассинхронизирован с реальным использованием.** В Info.plist есть `NSLocationAlwaysAndWhenInUseUsageDescription` («always»), но фактически только **when-in-use** (нет `UIBackgroundModes`, нет `ACCESS_BACKGROUND_LOCATION`). Строка «always» без background-режима сбивает с толку — привести строку к when-in-use, чтобы не провоцировать вопросы по 5.1.1.
- **iOS deployment target рассинхрон:** Podfile 15.0 vs `project.pbxproj` Runner 14.0. Унифицировать (рекомендуется 15.0) — иначе риск сборки/несоответствия минимальной версии.
- **Firebase API key restriction (НЕ блокер).** Ключ в `GoogleService-Info.plist` / `firebase_options.dart` — это **публичный client-key, он по дизайну едет в бинарнике и не является секретом**; Apple за это не реджектит. Просто ограничить ключ по bundle ID в Firebase Console (хардненинг). *(Один из под-агентов ошибочно пометил это как High/FAIL — это переоценка.)*

---

## Явные PASS (чтобы не приняли за работу)

| Зона | Вывод |
|------|-------|
| **Background location (2.5.4)** | Не используется. Только when-in-use, трекинг останавливается. ✅ |
| **Sign in with Apple (4.8)** | Соц-логинов нет (ни Google, ни Facebook) → требование **не применяется**. ✅ |
| **Account deletion (5.1.1(v))** | Есть: `gdpr_screen.dart` → `_requestDeletion()` (`/gdpr/deletion-request`) + экспорт данных `/gdpr/export`. Достижимо из `settings_screen.dart`, а он смонтирован в driver/client/secretary/dispatcher дашбордах → **demo-аккаунт любой роли удаляет аккаунт**. Request-based удаление допустимо. ✅ |
| **Min functionality / web-wrapper (4.2, 4.3)** | Полноценное нативное Flutter-приложение, ~37 экранов, реальные ролевые сценарии. Нет webview. ✅ |
| **IAP / payments (3.1.1)** | Оплата поездок (cash/card/invoice) — физическая услуга, **IAP не требуется**. Подписок/IAP нет. ✅ |
| **Push (5.1.1)** | Только операционные уведомления (подтверждение/отклонение поездки), не маркетинг; permission запрашивается явно. ✅ |
| **ATT / tracking** | Ни один SDK не включает `NSPrivacyTracking`. ATT-промпт не нужен. ✅ |
| **Privacy manifests** | Есть для Firebase / GoogleMaps / Mapbox / Google* — ✅ |
| **App icons / launch screen** | Полный сет иконок (вкл. 1024×1024), LaunchScreen.storyboard на месте. ✅ |
| **iPad** | Поддержка universal, все ориентации, responsive-лейауты. ✅ |
| **Permission usage strings** | Все нужные строки присутствуют (FaceID, Photo, Camera, Location) с контекстом. ✅ |

---

## Чеклист перед сабмитом

- [ ] Опубликовать Privacy Policy + Terms; вписать **Privacy Policy URL** в App Store Connect (1.1)
- [ ] Добавить ссылку на Privacy Policy/Terms в `settings_screen.dart` (+ login) (1.1)
- [ ] Заполнить **App Privacy** под реальный сбор (precise location, device ID, фото) (1.2)
- [ ] Добавить `ITSAppUsesNonExemptEncryption=false` в Info.plist (1.2)
- [ ] App Review Notes: demo-креды + объяснение invite-only ролевой модели (1.3)
- [ ] Спрятать `test_credentials_card` за dev-флаг для прод-билда (1.3 / 2.3)
- [ ] Прогнать и стабилизировать driver accept→track→complete и client map (2.1)
- [ ] Скрыть SuperAdmin-заглушки и `onTap:null`-кнопки для ревью-ролей (2.2)
- [ ] Привести location usage string к when-in-use (3)
- [ ] Унифицировать iOS target Podfile/pbxproj на 15.0 (3)
- [ ] Ограничить Firebase API key по bundle ID в Console (3, не блокер)

---

## Как проверить (end-to-end)

1. **Сборка ревью-билда:** `flutter build ipa` из `web/` с прод dart-define (API URL, Mapbox token).
2. **Crash-прогон (2.1):** на реальном iPhone под driver-аккаунтом — accept → live tracking → complete; под client — book → карта → cancel. Смотреть на null-краши в map-экранах.
3. **5.1.1(v):** войти demo-driver → Settings → Privacy & Data (GDPR) → Request deletion: должно дойти до `/gdpr/deletion-request` и показать статус.
4. **Permissions:** чистая установка → проверить, что каждый системный промпт (location/photo/camera/FaceID/push) триггерится в контексте и показывает usage-строку.
5. **App Privacy sanity:** сверить декларацию в App Store Connect с тем, что реально собирают geolocator/Mapbox/Firebase (см. их `.xcprivacy`).
