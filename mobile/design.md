# CAMP Mobile App — Design System & UI/UX Documentation

Welcome to the design documentation for the **CAMP Mobile Application**. This document serves as the single source of truth for the app's visual identity, design philosophy, layout metrics, color palette, typography system, component specifications, and user experience paradigms.

---

## 1. Core Design Philosophy: Tactile Clay & Neumorphism / Skeuomorphism

The CAMP mobile app is built around a **tactile claymorphic & skeuomorphic design language**. Rather than flat, minimalist, or generic interfaces, CAMP delivers a rich, tactile, physical cockpit feel reminiscent of outdoor adventure equipment, tactical vehicle instruments, and premium off-grid gear.

### Key Pillars:
1. **Physicality & Extrusions**: UI elements look extruded from or pressed into a physical light-clay surface (`#EDF1F7`).
2. **Dual-Shadow Extrusion**: Raised elements (cards, active action buttons, floating badges) cast a soft white highlight shadow top-left and a soft dark-blue/grey shadow bottom-right.
3. **Recessed Wells**: Inputs, search fields, status bars, and indicator slots use inverted inner-shadow styling to appear recessed into the canvas.
4. **Cockpit Aesthetic**: High-importance widgets (such as the live expedition mode / voice control hub) use dark espresso gradients (`#3E2619` → `#1A0E08`) enclosed in extruded clay bezels for high contrast and tactical readability under bright sunlight or dark night settings.
5. **Tactile & Interactive**: Micro-animations, glowing accent highlights (`#FA7014`), and distinct elevation hierarchies ensure the interface feels alive and instantly responsive.

---

## 2. Color System (`AppColors`)

All color tokens are strictly defined in [`app_colors.dart`](file:///c:/Users/huzai/Desktop/Hassan%20CAMP/Camp-Frontend/mobile/lib/app/theme/app_colors.dart).

### 2.1 Canvas & Background Colors
| Token Name | Hex Code | Purpose / Application |
| :--- | :--- | :--- |
| `background` | `#1E1E1E` | Outer dark backdrop / viewport background |
| `clay` | `#EDF1F7` | Primary canvas & light surface background |
| `clayDark` | `#E3E8F0` | Recessed/inset light surfaces & container bases |
| `clayDeep` | `#D5DCE7` | Deeply pressed wells & sunken card surfaces |

### 2.2 Primary Brand & Tactical Accents
| Token Name | Hex Code | Purpose / Application |
| :--- | :--- | :--- |
| `tacticalOrange` | `#FA7014` | Primary brand accent, active states, key CTAs |
| `tacticalOrangeDark` | `#D95200` | Pressed CTA states, overline text, orange links |
| `tacticalOrangeLight` | `#FF8C3A` | Hover/focus highlights, active pill fills |

### 2.3 Cockpit Cards (Dark Espresso Theme)
| Token Name | Hex Code | Purpose / Application |
| :--- | :--- | :--- |
| `cockpitGradientStart` | `#3E2619` | Dark cockpit card gradient top-left |
| `cockpitGradientMid` | `#29180F` | Dark cockpit card gradient center |
| `cockpitGradientEnd` | `#1A0E08` | Dark cockpit card gradient bottom-right |
| `cockpitBannerBg` | `#1D1009` | Sunken cockpit banner / voice bar background |

### 2.4 Neutral Typography Colors
| Token Name | Hex Code | Purpose / Application |
| :--- | :--- | :--- |
| `darkCharcoal` | `#14171A` | High-contrast primary text and headings |
| `charcoalLight` | `#3D3A35` | Secondary headings, subtitle text |
| `mutedText` | `#6B7280` | Body secondary text, subtitles, captions |
| `mutedLight` | `#9CA3AF` | Placeholder text, disabled icon tints |

### 2.5 Status & System Indicators
| Token Name | Hex Code | Purpose / Application |
| :--- | :--- | :--- |
| `statusGreen` | `#22C55E` | Online, active connection, healthy status |
| `statusYellow` | `#FBBF24` | Warning, low battery, standby state |
| `alertRed` | `#DC2626` | Emergency alert, hazard, error text |
| `alertRedBg` | `#FEE2E2` | Emergency alert banner / badge background |
| `terracotta` | `#8A4C24` | Earthy secondary accent, tactical overlines |

---

## 3. Elevation & Dual-Shadow System

Skeuomorphic depth is achieved using precisely calculated multi-source light dual-shadows.

```dart
// Raised Extrusion (Floating Cards & Major Buttons)
BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-5, -5), blurRadius: 10, spreadRadius: 1),
BoxShadow(color: Color(0x33A3B1C6), offset: Offset(6, 6), blurRadius: 12, spreadRadius: 1),

// Recessed / Inset Wells (Input Fields & Inset Containers)
BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(3, 3), blurRadius: 6, spreadRadius: 0),
BoxShadow(color: Color(0x3CA3B1C6), offset: Offset(-3, -3), blurRadius: 6, spreadRadius: 0),
```

### Elevation Token Summary:
1. **`skeuRaised`**: Large floating cards, primary buttons, hero stat widgets.
2. **`skeuRaisedSmall`**: Action buttons, small filter chips, quick badges.
3. **`skeuRecessed`**: Search boxes, voice visualizer container, recessed stats.
4. **`cockpitBezel`**: Outer highlight ring surrounding the dark espresso cockpit hero module.
5. **`dockShadow`**: Deep dark floating bottom navigation dock shadow (`blur: 24, spread: 2`).
6. **`orangeGlow`**: Soft radiant drop shadow for tactical orange action buttons (`#F56500` @ 40%).

---

## 4. Layout Metrics & Radii Tokens

Standardized spatial metrics guarantee visual symmetry across all screens:

| Metric Token | Value | Applied To |
| :--- | :--- | :--- |
| `radiusCard` | `26.0 px` | Main screen cards, hero modules, sheets |
| `radiusTile` | `18.0 px` | Secondary sub-cards, list tiles, stat blocks |
| `radiusPill` | `999.0 px` | Badges, tags, action pills, floating dock |
| `screenPadding` | `16.0 px` | Horizontal screen margins |
| `cardGap` | `16.0 px` | Vertical spacing between primary stack items |
| `cardPadding` | `18.0 px` | Internal padding inside cards |

---

## 5. Typography System (`AppTheme` & `AppTextStyles`)

CAMP uses **Manrope** (via `google_fonts`) as its core typeface—chosen for its modern geometric clarity, technical precision, and outdoor readability.

### Type Hierarchy:
- **Big Stat Numbers (`displayLarge` / `bigStat`)**: 30–32pt Extrabold (`w800`), `-0.5` letter spacing. Used for speed, telemetry data, and major metrics.
- **Medium Stat Numbers (`statMedium`)**: 21pt Extrabold (`w800`). Used for sub-metrics and secondary sensor readings.
- **Page Titles (`headlineMedium` / `title`)**: 24pt Bold (`w700` / `w800`), `-0.3` letter spacing.
- **Card Titles (`titleMedium` / `cardTitle`)**: 16pt Semibold (`w600`).
- **Item / Sub-card Titles (`titleSmall` / `itemTitle`)**: 14–15pt Semibold/Bold (`w600`–`w700`).
- **Body Text (`bodyLarge` / `body`)**: 13.5–14pt Regular (`w400`), height `1.4`.
- **Secondary Body (`bodySmall` / `bodySecondary`)**: 12–13pt Regular (`w400`), `mutedText` tint.
- **Overlines & Tactical Labels (`labelMedium` / `overline`)**: 10.5pt Semibold (`w600`), **UPPERCASE**, tracking `1.2` spacing. Available in default muted, orange (`overlineOrange`), and terracotta (`overlineTerracotta`).

---

## 6. Layout Architecture & Component Structure

The app's UI is structured into modular feature domains:

```
mobile/lib/
├── app/
│   ├── theme/
│   │   ├── app_colors.dart       # Skeuomorphic color system & shadow tokens
│   │   └── app_theme.dart        # Typography & global ThemeData setup
│   └── router/                   # App navigation configuration
├── core/
│   ├── widgets/                  # Shared tactical buttons, inputs, pills
│   └── services/                 # Hardware, bluetooth, voice & location services
└── features/
    ├── home/                     # Cockpit dashboard & expedition cards
    ├── expedition/               # Live tracking & map telemetry views
    ├── ride_history/             # Past trips & telemetry stats
    └── settings/                 # Vehicle & device setup controls
```

### Core UI Components:
1. **Cockpit Hero Module**: Dark espresso gradient widget displaying live trip status, voice command visualizers, and quick action toggles.
2. **Tactile Clay Cards**: Extruded white/grey cards providing high-contrast stat readouts with subtle borders and dual shadows.
3. **Floating Navigation Dock**: Dark charcoal (`#14171A`) pill dock floating at the bottom with illuminated tactical orange active icon states.
4. **Telemetry Stat Badges**: Compact recessed wells with micro-labels and bold numerical values for elevation, speed, battery, and signal.

---

## 7. Responsive & Accessibility Guidelines

- **Sunlight Contrast**: High-contrast typography (`#14171A` on `#EDF1F7` or `#FFFFFF` on dark cockpit gradient) ensures clarity during outdoor daylight use.
- **Touch Targets**: All interactive buttons enforce a minimum tap target of `48x48 px` with clear visual active/pressed states.
- **Dynamic Font Scaling**: Supports system accessibility font scaling without layout clipping.
