# Design System & UI/UX Guidelines: Ambient Calm (Soft Minimal iOS)

A comprehensive design specification for the **Context-Aware Wellness Reminder** iOS application.

---

## 1. Design Philosophy

The core goal of the interface is to be **quiet, effortless, and ambient**. 

- **Calm by Default**: Wellness apps should not induce stress or feel like rigid task managers.
- **Ambient Awareness**: Information is communicated through subtle depth, soft lighting, and minimal typography rather than loud alarms or heavy data grids.
- **Native Elegance**: Built to feel like an organic extension of iOS, adhering to Human Interface Guidelines (HIG) with contemporary soft-minimal aesthetics.

---

## 2. Visual Style & Aesthetics

### 2.1 Aesthetic Overview
- **Design Archetype**: Soft Minimal iOS / Ambient Calm UI.
- **Visual Weight**: Lightweight, breathable, and floating.
- **Metaphor**: Gentle environmental light, frosted glass surfaces, and tactile soft-touch physical elements.

---

## 3. Color Palette & Dynamic Theming

The color system adapts dynamically according to the active **Context**, using low-saturation, organic tones.

### 3.1 Base Semantic Colors (Light & Dark Mode)
| Token | Light Mode Value | Dark Mode Value | Usage |
|---|---|---|---|
| `bgPrimary` | `#F6F8F6` | `#0E1210` | Canvas base layer |
| `cardBackground` | `rgba(255, 255, 255, 0.72)` | `rgba(28, 32, 30, 0.65)` | Frosted glass cards |
| `textPrimary` | `#1D231F` | `#F0F4F1` | Primary titles & active labels |
| `textSecondary` | `#637067` | `#8E9E94` | Timestamps, subtitles, context details |
| `cardBorder` | `rgba(255, 255, 255, 0.8)` | `rgba(255, 255, 255, 0.08)` | Subtle 1px glass border |
| `shadowSoft` | `rgba(24, 40, 30, 0.06)` | `rgba(0, 0, 0, 0.35)` | Multi-layer diffused blur |

### 3.2 Context-Driven Ambient Palettes
| Context | Mood / Tone | Primary Accent | Gradient Lighting |
|---|---|---|---|
| **Work** | Focus & Balance | Sage Slate (`#5E8570`) | Soft Sage $\rightarrow$ Pale Mist |
| **Study** | Clarity & Calm | Soft Indigo / Iris (`#6B7CB5`) | Muted Iris $\rightarrow$ Pearl Gray |
| **Home / Relax** | Warmth & Comfort | Sand / Warm Ochre (`#C29B62`) | Warm Linen $\rightarrow$ Cream |
| **Sleep / Wind Down** | Rest & Stillness | Deep Indigo / Charcoal (`#3A405A`) | Night Indigo $\rightarrow$ Dark Slate |

---

## 4. Typography Hierarchy

Using standard Apple System Fonts (**SF Pro / SF Pro Rounded** for numerals and icons) with tight tracking and balanced weights.

- **Greeting / Primary Title**: `SF Pro Display`, Bold / Heavy, `28pt` – `32pt`
- **Context Header**: `SF Pro Text`, Semibold, `16pt` – `17pt`
- **Section & Category Headers**: `SF Pro Text`, Medium, `11pt` – `12pt`, Uppercase, `+0.8` tracking
- **Active Nudge Title**: `SF Pro Display`, Semibold, `20pt` – `22pt`
- **Time Remaining / Status**: `SF Pro Text`, Regular, `14pt` – `15pt`
- **Metric Cards (Value & Subtitle)**: `SF Pro Rounded`, Semibold, `15pt` (Label: `12pt` Regular)

---

## 5. UI Components & Layout Specs

### 5.1 Dynamic Ambient Background
- Background is composed of a smooth radial/mesh gradient located behind frosted containers.
- Transitions between contexts smoothly morph color over a 1.2s ease-in-out curve.

### 5.2 The Hero Context Card
- **Corner Radius**: `28pt` (continuous squircle / `.continuous`).
- **Material**: `UltraThinMaterial` or `ThinMaterial` with background blur (`blur: 24pt`).
- **Border**: `1pt` solid stroke with subtle gradient highlight (`top: rgba(255,255,255,0.9)`, `bottom: rgba(255,255,255,0.2)`).
- **Shadow**: `Y: 12, Blur: 28, Color: shadowSoft`.

### 5.3 Soft-Skeuomorphic Focus Dial (Center Action Element)
- **Geometry**: Concentric circular container (`100pt x 100pt`).
- **Progress Track**: Low-opacity track with a smooth indicator arc showing time elapsed towards the next reminder.
- **Center Emblem**: Circular badge with subtle inner shadows (`inset 0 2px 4px rgba(0,0,0,0.06)`) and light surface embossing.
- **Icon**: SF Symbol or custom vector centered with primary context tint.

### 5.4 Activity Quick-Cards
- Row of compact horizontal summary cards (`Corner Radius: 18pt`).
- Highlights daily totals (e.g., Hydration reminders logged, Movement occurrences) with minimalist SF Symbols.

### 5.5 Navigation & Tab Bar
- Floating translucent bottom bar (`UltraThinMaterial`, `Corner Radius: 32pt`).
- Minimal monochrome SF Symbols that subtly tint to the context accent when active.

---

## 6. Micro-Interactions & Haptics

- **Breathing Indicator**: The focus dial slightly expands and contracts (`scaleEffect(1.02)`) over a 4-second cycle when a reminder is approaching.
- **Haptic Feedback**:
  - `UIImpactFeedbackGenerator(style: .soft)` on completing or acknowledging a reminder.
  - `UISelectionFeedbackGenerator()` when switching context cards or toggling behaviors.
- **Dismiss / Action Gestures**: Swipe down or tap to smoothly mark behavior done without popping up modal alerts.

---

## 7. SwiftUI Architecture Implementation Notes

```swift
// Example Hero Card View Styling Modifier
struct AmbientCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.2 : 0.8),
                                Color.white.opacity(colorScheme == .dark ? 0.02 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 20, x: 0, y: 10)
    }
}
```
