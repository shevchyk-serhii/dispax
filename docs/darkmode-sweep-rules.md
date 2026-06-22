# Dark-mode color sweep — правила классификации (внутренний бриф)

Цель: устранить хардкод цветов, который ломает **dark-тему**, НЕ ломая light. Тема — единственный
источник истины: `web/lib/theme/app_theme.dart`. Токены — `web/lib/constants/app_colors.dart`.

## Ключевой принцип
Не каждый `Colors.white` / `AppColors.primary` — баг. Многие НАМЕРЕННЫ. Классифицируй КАЖДОЕ
вхождение по контексту фона, на котором оно лежит.

## ОСТАВИТЬ КАК ЕСТЬ (намеренный хардкод)
1. **Белое на графите.** Текст/иконка `Colors.white` (или `AppColors.textOnPrimary`) поверх
   `AppColors.primary` / `primaryGradient` / `*Gradient` фона (графитовая шапка, sidebar,
   active-ride graphite-карточка). Графитовый хедер — фиксированная композиция в ОБЕИХ темах.
2. **Белое на accent.** `foregroundColor: Colors.white` на кнопке с `backgroundColor: AppColors.accent`
   (cyan) — белое на cyan читается всегда.
3. **Login/Splash content-панель** — намеренно всегда светлая (см. graphite-header+light-content).
4. **withValues(alpha:) поверх графита** — полупрозрачное белое (бордеры/тинты) на тёмном фоне.
5. **Map-оверлеи** поверх тайлов карты (фон не из темы).

## ЧИНИТЬ (баг dark-темы)
1. **Белый фон карточки/контейнера**, который должен темнеть: `color: Colors.white` /
   `AppColors.surface` как `Container.color`/`Card.color` на странице →
   `Theme.of(context).colorScheme.surface` (тема уже даёт surfaceDark в dark).
2. **Тёмный текст на surface**: `color: AppColors.primary`/`textPrimary` как цвет ТЕКСТА на
   surface-фоне → `colorScheme.onSurface`. В dark это станет светлым; в light останется графитом.
3. **Акцент = primary на surface** (подчёркивания табов, бейджи, активный текст), который в dark
   сливается (`surfaceDark==primary==#18181B`) → `AppColors.accent` ИЛИ `colorScheme.primary`
   через тему (она уже инвертирует primary в dark на светлый графит).
4. **Status-бейджи** с хардкодом light-цвета → использовать `*BgDark`/`*TextDark` варианты через
   `isDark ? ...Dark : ...`, либо существующий хелпер `web/lib/utils/ride_status_styles.dart`.

## Паттерн правки
- Получить тему один раз: `final cs = Theme.of(context).colorScheme;`
  или `final isDark = Theme.of(context).brightness == Brightness.dark;`
- Сомнительные места (не ясно, графит это фон или surface) — НЕ трогать, выписать в отчёт.

## Гейт после правок (в worktree)
- `cd web && flutter analyze` — 0 issues (CI падает на любых).
- `flutter test` — зелёный.
- `make fmtAll` (dart format).
- Не плодить новые `Color(0xFF...)` — только токены/тему.
