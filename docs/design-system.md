# Dispax Design System

## Brand Identity

**Dispax** is an intelligent transport management platform. Visual style: **tech-premium** — clean, precise, confident. Not "corporate blue", not "cheerful multicolored cards". It is a business tool that looks like a Linear / Vercel / Stripe-grade product.

### Design principles

1. **Clarity over decoration** — information first, decoration minimal
2. **Consistent depth** — a unified shadow and elevation system creates a clean hierarchy
3. **Controlled color** — color is used deliberately: for navigation, statuses and accents — not for "looks"
4. **Dark anchors, light canvas** — dark gradient headers as anchors, light content as the workspace

---

## Color System

### Brand Core

A single brand palette is built around **deep navy** as the base and **electric accents** for roles.

| Token | Hex | Usage |
|-------|-----|---------------|
| `brand-900` | `#0A0E1A` | Darkest backgrounds, overlays |
| `brand-800` | `#111827` | Dark headers base |
| `brand-700` | `#1E293B` | Secondary dark surfaces |
| `brand-600` | `#334155` | Tertiary, borders on dark |
| `brand-100` | `#F1F5F9` | Page background (scaffold) |
| `brand-50` | `#F8FAFC` | Card backgrounds |
| `brand-0` | `#FFFFFF` | Pure white surfaces |

### Role Accent Colors

Each role has one **accent color** from a single chromatic system. All accents are bright, saturated, high-tech.

| Role | Accent | Hex | Light BG | Gradient (from → to) |
|------|--------|-----|----------|---------------------|
| **Dispatcher** | Amber | `#F59E0B` | `#FFFBEB` | `#FBBF24` → `#D97706` |
| **Driver** | Cyan | `#06B6D4` | `#ECFEFF` | `#22D3EE` → `#0891B2` |
| **Secretary** | Violet | `#8B5CF6` | `#F5F3FF` | `#A78BFA` → `#7C3AED` |
| **Client** | Emerald | `#10B981` | `#ECFDF5` | `#34D399` → `#059669` |

**Why these colors:**
- They are bright and distinguishable from one another (hue distance > 60°)
- All from the same "energy band" — medium-high saturation, medium-high lightness
- Work well on both dark (gradient headers) and light (badges, accents)
- Do not evoke the "cheap" Material default (not `Colors.blue`, not `Colors.orange`)

### Status Colors

Ride statuses are functional, not brand. They do not change between roles.

| Status | Color | Hex | Background | Border | Text |
|--------|-------|-----|------------|--------|------|
| Requested | Amber | `#F59E0B` | `#FFFBEB` | `#FCD34D` | `#92400E` |
| Assigned | Blue | `#3B82F6` | `#EFF6FF` | `#93C5FD` | `#1E40AF` |
| In Progress | Teal | `#14B8A6` | `#F0FDFA` | `#5EEAD4` | `#115E59` |
| Completed | Green | `#22C55E` | `#F0FDF4` | `#86EFAC` | `#166534` |
| Cancelled | Red | `#EF4444` | `#FEF2F2` | `#FCA5A5` | `#991B1B` |

### Semantic Colors

| Token | Hex | Usage |
|-------|-----|---------------|
| `success` | `#22C55E` | Positive actions, confirmations |
| `warning` | `#F59E0B` | Warnings, attention needed |
| `error` | `#EF4444` | Errors, destructive actions |
| `info` | `#3B82F6` | Informational, neutral highlights |

### Text Colors

| Token | Hex | Usage |
|-------|-----|---------------|
| `text-primary` | `#0F172A` | Headlines, primary content |
| `text-secondary` | `#64748B` | Descriptions, labels |
| `text-tertiary` | `#94A3B8` | Hints, placeholders, disabled |
| `text-on-dark` | `#FFFFFF` | Text on dark/gradient backgrounds |
| `text-on-dark-secondary` | `rgba(255,255,255,0.7)` | Secondary text on dark |

### Surface & Border Colors

| Token | Hex | Usage |
|-------|-----|---------------|
| `surface-primary` | `#FFFFFF` | Cards, modals |
| `surface-secondary` | `#F8FAFC` | Page background |
| `surface-tertiary` | `#F1F5F9` | Input backgrounds, subtle sections |
| `border-primary` | `#E2E8F0` | Card borders, dividers |
| `border-secondary` | `#CBD5E1` | Input borders |
| `border-focus` | Role accent | Focused input borders |

---

## Gradient System

### Header Gradients (Role-specific)

Each header uses a gradient built from a single formula: **dark navy base + role accent glow**.

```
Formula: brand-800 (base) → brand-700 (mid) with a role accent overlay at 15-20% opacity
```

| Role | Gradient Definition | Angle |
|------|---------------------|-------|
| Dispatcher | `#1E293B` → `#D97706` (via `#78350F`) | 135° |
| Driver | `#1E293B` → `#0891B2` (via `#164E63`) | 135° |
| Secretary | `#1E293B` → `#7C3AED` (via `#3B0764`) | 135° |
| Client | `#1E293B` → `#059669` (via `#064E3B`) | 135° |

**Alternative approach (vivid gradients):**

For a brighter, tech-forward look — a gradient entirely from the accent color range:

| Role | Vivid Gradient | Usage |
|------|---------------|-------|
| Dispatcher | `#FBBF24` → `#D97706` → `#92400E` | Mobile headers |
| Driver | `#22D3EE` → `#06B6D4` → `#155E75` | Mobile headers |
| Secretary | `#A78BFA` → `#8B5CF6` → `#5B21B6` | Mobile headers |
| Client | `#34D399` → `#10B981` → `#065F46` | Mobile headers |

### Glass Effect (for overlay cards on gradient headers)

```
background: rgba(255, 255, 255, 0.12)
border: 1px solid rgba(255, 255, 255, 0.18)
backdrop-filter: blur(16px)
border-radius: 12px
```

---

## Typography

**Font Family**: Inter (primary), System fallback

| Scale | Size | Weight | Line Height | Letter Spacing | Usage |
|-------|------|--------|-------------|----------------|-------|
| Display | 36px | 700 | 1.1 | -0.02em | Hero numbers, big stats |
| H1 | 28px | 700 | 1.2 | -0.01em | Page titles |
| H2 | 22px | 600 | 1.3 | 0 | Section headers |
| H3 | 18px | 600 | 1.4 | 0 | Card titles |
| Body L | 16px | 400 | 1.5 | 0 | Primary content |
| Body M | 14px | 400 | 1.5 | 0 | Secondary content, descriptions |
| Body S | 12px | 400 | 1.5 | 0.01em | Captions, timestamps |
| Label L | 14px | 500 | 1.3 | 0.01em | Button text, nav items |
| Label M | 12px | 500 | 1.3 | 0.02em | Tags, badges |
| Label S | 10px | 500 | 1.3 | 0.03em | Bottom nav labels, micro text |

---

## Spacing & Layout

### Spacing Scale (4px base)

| Token | Value | Usage |
|-------|-------|-------|
| `space-1` | 4px | Tight gaps (icon-to-text) |
| `space-2` | 8px | Small gaps, inline spacing |
| `space-3` | 12px | List item gaps |
| `space-4` | 16px | Standard padding, section gaps |
| `space-5` | 20px | Card internal padding |
| `space-6` | 24px | Section spacing |
| `space-8` | 32px | Large section gaps |
| `space-10` | 40px | Page-level spacing |
| `space-12` | 48px | Major section breaks |

### Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| `radius-sm` | 6px | Small elements (tags, chips) |
| `radius-md` | 8px | Inputs, small cards |
| `radius-lg` | 12px | Cards, modals |
| `radius-xl` | 16px | Large cards, containers |
| `radius-2xl` | 20px | Hero cards, action cards |
| `radius-full` | 9999px | Pills, avatars, circles |

### Shadow System

| Level | Definition | Usage |
|-------|-----------|-------|
| `shadow-xs` | `0 1px 2px rgba(0,0,0,0.05)` | Subtle lift (inputs, mini cards) |
| `shadow-sm` | `0 2px 4px rgba(0,0,0,0.06)` | Default cards |
| `shadow-md` | `0 4px 12px rgba(0,0,0,0.08)` | Elevated cards, dropdowns |
| `shadow-lg` | `0 8px 24px rgba(0,0,0,0.12)` | Modals, floating elements |
| `shadow-xl` | `0 16px 48px rgba(0,0,0,0.16)` | Overlay panels |

---

## Component Patterns

### Screen Structure (Mobile)

```
┌──────────────────────┐
│  Status Bar (62px)    │  transparent over gradient
├──────────────────────┤
│  Gradient Header      │  role gradient, 120-160px
│  ┌─ Title + Icons ─┐ │  white text, lucide icons
│  └─ Stats / Chips ─┘ │  glass cards or pills
├──────────────────────┤
│                       │
│  Content Area         │  surface-secondary bg (#F8FAFC)
│  ┌─────────────────┐ │
│  │  Cards          │ │  white cards, shadow-sm, radius-lg
│  └─────────────────┘ │
│                       │
├──────────────────────┤
│  Bottom Nav (60px)    │  white bg, border-top, role accent active
└──────────────────────┘
```

### Card Anatomy

```
┌─────────────────────────────────┐  radius: 12px
│  padding: 16px                  │  bg: white
│                                 │  shadow: shadow-sm
│  [Icon/Avatar]  Title    [Badge]│  border: none (or 1px border-primary for subtle)
│                 Subtitle        │
│                                 │
│  Content area                   │
│                                 │
│  [Action Button]   [Secondary]  │
└─────────────────────────────────┘
```

### Bottom Navigation

- Height: 60px + safe area (24px bottom)
- Background: white
- Border top: 1px `border-primary` (#E2E8F0)
- Icons: 22px, Lucide family
- Active: role accent color, font-weight 600
- Inactive: `text-tertiary` (#94A3B8)
- Labels: 10px Label S

### Status Badges

```
┌──────────────┐
│  ● Status    │  padding: 4px 10px
└──────────────┘  radius: radius-full (pill)
                  bg: status light bg
                  text: status text color
                  font: Label M (12px, 500)
                  optional dot: 6px circle, status color
```

### Header Stats (Glass Cards)

```
┌─────────────┐  on gradient header
│  28         │  radius: 10px
│  Completed  │  bg: rgba(255,255,255,0.15)
└─────────────┘  text: white (number: 22px 700, label: 11px 400)
                  padding: 8px 12px
```

### Input Fields

```
┌──────────────────────┐  height: 48px
│  🔍 Placeholder...   │  radius: radius-md (8px) or radius-full for search
└──────────────────────┘  bg: surface-tertiary (#F1F5F9)
                          border: 1px border-secondary
                          focus border: 2px role accent
                          text: Body M (14px)
                          placeholder: text-tertiary
```

---

## Icon System

- **Library**: Lucide (lucide.dev)
- **Style**: Outline only, stroke-width 1.5-2
- **Sizes**: 16px (inline), 20px (action), 22px (nav), 24px (header), 32px (feature)
- **Color**: Inherits from context (text-secondary for content, white for headers, role accent for active nav)

---

## Interaction Patterns

### Tap States
- Cards: scale(0.98) + shadow reduction
- Buttons: darken 10%
- Nav items: instant color change

### Transitions
- Fast: 150ms (hover states, color changes)
- Medium: 300ms (layout changes, reveals)
- Slow: 500ms (page transitions)
- Easing: cubic-bezier(0.4, 0, 0.2, 1) — Material standard

---

## Mapping: Old → New Colors

For migrating the current code:

| Old (app_colors.dart) | New Token | New Hex |
|----------------------|-----------|---------|
| `primary` (#1976D2) | `brand-accent` / `info` | `#3B82F6` |
| `driverColor` (blue) | `role-driver` | `#06B6D4` |
| `clientColor` (green) | `role-client` | `#10B981` |
| `secretaryColor` (purple) | `role-secretary` | `#8B5CF6` |
| `dispatcherColor` (orange) | `role-dispatcher` | `#F59E0B` |
| `textPrimary` (#212121) | `text-primary` | `#0F172A` |
| `textSecondary` (#757575) | `text-secondary` | `#64748B` |
| `textLight` (#BDBDBD) | `text-tertiary` | `#94A3B8` |
| `background` (#FAFAFA) | `surface-secondary` | `#F8FAFC` |
| `surface` (white) | `surface-primary` | `#FFFFFF` |
| `surfaceVariant` (#F5F5F5) | `surface-tertiary` | `#F1F5F9` |

---

## Design Principles Summary

1. **A single dark base** — all gradient headers are built from `brand-800` (#1E293B), creating a cohesive look
2. **Accent = role** — one bright color per role, used sparingly (header glow, active nav, badges)
3. **Neutral content** — white cards, slate background, slate text — no color noise
4. **Functional color** — status colors are separated from role colors; they are semantic and do not change
5. **Depth through shadows** — shadows, not borders, create the hierarchy (shadow-xs → shadow-xl)
6. **Modern, not playful** — Inter font, tight spacing, subtle animations, no rounded-everything
