# Аудит соответствия нового дизайна (Dispax Design)

Дата: 2026-06-21. Эталон: `docs/design/Dispax Design.dc.html` (синк сегодня, коммит `e3243db`) + `docs/design/HANDOFF.md`.

## TL;DR

**Новый дизайн реализован практически полностью.** Все 7 фаз роллаута (0 backend + 6 ролевых)
смержены в master: ~27-30 экранов по 5 ролям + auth + desktop + dark. Дизайн-токены (Inter,
графит #18181B + sky #0EA5E9, badge-цвета статусов light/dark), навигация (NavigationRail ≥800px /
BottomNav <800px), новый функционал (Saved Places, vehicle class + /estimate, scheduled/now,
predictive ETA, templates, chat, DATEV) — на месте.

Сегодняшний синк эталона (`1b1137e`→`e3243db`) **чисто косметический**: добавлен `white-space:nowrap`
в badge-чипы статусов. Новых экранов/функций дизайн не вводит → реализация по-прежнему актуальна.

> Прим.: план `~/.claude/plans/flutter-sorted-bee.md` — снимок ДО реализации и помечает backend
> Фазы 0 как «не сделано». Это устарело: миграция `V9__Add_ride_vehicle_class.sql`,
> `RideEstimateService.scala`, `VehicleClass` в `RideDomain.scala`, `driverRating` в
> `RideApiModels.scala` — всё реально в master.

## Остаточные расхождения

### 1. Хардкод цветов в обход темы (риск dark-mode) — основное
- `Colors.white` — **300** вхождений в `web/lib`
- `AppColors.primary` — **94** хардкода (в light совпадает с темой, в dark `surfaceDark==primary==#18181B` → акценты сливаются с фоном)
- Концентрация: `dashboard/driver/`, `dashboard/dispatcher/widgets/`
- Это системный долг из [[web-color-system-hardcoded-primary]]; точечно чинилось в прошлых фазах,
  но полного прохода `grep AppColors.primary` → только `app_theme.dart` ещё нет.
- **Действие:** sweep по dashboard-виджетам, замена `Colors.white`→`colorScheme.onSurface/onPrimary`,
  `AppColors.primary`→`colorScheme.primary`; визуальная сверка экранов в dark.

### 2. Экраны-заглушки, ждущие backend (дизайн рисует, бэка нет)
| Экран | Файл | Чего не хватает на бэке |
|---|---|---|
| SuperAdmin → Users & Roles | `dashboard/superadmin/superadmin_dashboard.dart:90` | `GET /superadmin/users` |
| SuperAdmin → Audit Log | `dashboard/superadmin/superadmin_dashboard.dart:184` | `GET /superadmin/audit` |
| SuperAdmin → Analytics «Avg slack» | `screens/superadmin_analytics_screen.dart:369` | поле в `PlatformRideStats` |
| SuperAdmin → Companies «Drivers»/«Rides/mo» | `screens/superadmin_companies_screen.dart:552,561` | поля в `CompanyResponse` |

Деградируют gracefully (показывают `—`/placeholder), но дизайн предполагает реальные данные.

### 3. Незавершённый client-функционал из HANDOFF
| Что | Файл | Статус |
|---|---|---|
| Payment screen | `screens/client_payment_screen.dart:3,356` | UI-заглушка, не подключена в flow; add-method не реализован |
| Call driver (tel:) | `screens/client_map_screen.dart` | TODO, кнопка без действия |
| Chat с driver | `screens/client_map_screen.dart` | TODO, переход на chat не реализован |
| Geofence toggle | `screens/geofence_screen.dart:132` | мок POST вместо реального PATCH |

## Что подтверждено как соответствующее дизайну
- Inter (4 TTF в pubspec) + lucide_icons 0.257 — ✅
- Badge-цвета статусов поездок light + dark (Requested/Assigned/InProgress/Completed/Cancelled) — ✅ в `app_colors.dart`
- ResponsiveScaffold (NavigationRail/BottomNav, breakpoint 800) у всех 5 ролей — ✅
- Saved Places, vehicle class + `/estimate`, scheduled/now, ETA-alert card, templates, billing/DATEV — ✅

## Рекомендованный приоритет
1. **dark-mode color sweep** (#1) — единственное системное расхождение, влияет на все экраны.
2. SuperAdmin backend-эндпоинты (#2) — снять заглушки.
3. Client payment/call/chat (#3) — если входят в текущий scope MVP.
