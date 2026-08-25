# Context-Aware Wellness Reminder

A personal wellness assistant for iOS that provides intelligent reminders based on **whether the user is sleeping and, when awake, what mode they are in**.

Instead of creating dozens of fixed alarms, users define their sleep schedule and awake modes—initially **Work** and **Idle**—then choose which wellness behaviors they want to be reminded about in each mode.

The app handles the reminder logic automatically.

---

## Core Idea

Most reminder apps are time-based:

> "Remind me to drink water every hour."

This project takes a different approach:

> **"While I am working, remind me to drink water regularly and remind me to stand if I've been sitting too long. When I am idle, use a gentler reminder schedule. Do not send ordinary wellness reminders while I am sleeping."**

The user does not need to configure complicated rules.

They simply:

1. Set the sleep schedule.
2. Set the Work schedule within the awake period.
3. Enable or disable available behaviors for Work and Idle.
4. Choose how frequently each behavior should be reminded in each mode.

The app handles the underlying scheduling and activity detection.

---

# Product Concept

## Daily Modes

A **Daily Mode** represents the user's current sleep or awake state and determines which reminder configuration is active.

The initial product uses a two-level daily state model rather than a flat list of contexts:

Sleeping has priority over every awake mode. When the user is awake, the app selects Work during the configured Work hours and Idle at all other times.

Initial modes:

- Sleeping: the configured sleep interval. Ordinary wellness reminders are off.
- Work: a configured interval during the awake day.
- Idle: any awake time outside the Work interval.

Example:

```text
Sleeping
11:00 PM – 07:00 AM

Work
09:00 AM – 05:00 PM

Idle
05:00 PM – 11:00 PM and 07:00 AM – 09:00 AM
```

Work and Idle each have their own reminder configuration. Sleeping suppresses ordinary reminders.

---

## Behaviors

The app provides a predefined set of wellness behaviors.

Users can simply turn them on or off.

### Example behaviors

- 💧 Drink Water
- 🧍 Stand Up
- 🚶 Move Around
- 👀 Rest Your Eyes
- 🧘 Take a Break
- 😴 Wind Down
- 🌤 Get Some Light
- 🚶 Take a Short Walk

The initial version should intentionally keep this list small.

The goal is not to build a giant health tracker.

---

# Example

## Work Mode

```text
Work
09:00 AM – 05:00 PM

Reminders

☑ Drink Water
  Regular

☑ Stand Up
  Frequent

☑ Move Around
  Regular

☐ Rest Your Eyes

☐ Take a Break
```

The user does not need to understand how the underlying rules work.

Internally, the app might translate these settings into:

```text
Drink Water
→ minimum reminder interval: 60 minutes

Stand Up
→ remind after prolonged inactivity

Move Around
→ minimum reminder interval: 120 minutes
```

---

# Mode-Based Behavior

The same behavior can behave differently depending on the current mode.

For example:

| Behavior | Work | Idle | Sleeping |
|---|---|---|---|---|
| Drink Water | Regular | Occasional | Off |
| Stand Up | Frequent | Occasional | Off |
| Move Around | Regular | Optional | Off |
| Rest Eyes | Regular | Optional | Off |
| Take a Break | Regular | Optional | Off |
| Wind Down | Off | Optional | Off |

This allows the app to adapt to the user's daily rhythm without requiring a flat list of overlapping contexts or complex configuration.

---

# Reminder Philosophy

The app should **not** behave like a collection of alarms.

Instead, reminders should be:

### Mode-aware

Only active when the relevant daily mode is active.

### Behavior-aware

Different behaviors have different reminder logic.

### Activity-aware

When possible, the app should consider actual user activity before sending a reminder.

For example:

```text
09:00
User starts working

09:30
User is still inactive

09:45
Still inactive
        ↓
🧍 Stand Up reminder

09:48
User starts moving
        ↓
Reset inactivity timer
```

The system should avoid reminding the user unnecessarily when the desired behavior has already occurred.

---

# User Experience

## 1. Initial Setup

The first launch should be extremely simple.

```text
Stay Well

When are you sleeping?

┌─────────────────────────┐
│ 😴 Sleep               │
│ 11:00 PM – 7:00 AM      │
└─────────────────────────┘

┌─────────────────────────┐
│ 🧑‍💻 Work               │
│ 9:00 AM – 5:00 PM       │
└─────────────────────────┘

        Continue
```

The app derives the current mode from these times:

```text
During Sleep hours → Sleeping
During Work hours  → Work
All other awake time → Idle
```

Sleeping takes priority if schedules overlap. The first version determines the mode from time only; activity-aware detection is introduced later.

---

## 2. Choose Behaviors

```text
Work Reminders

☑ Drink Water
☑ Stand Up
☑ Move Around
☐ Rest Your Eyes
☐ Take a Break

        Continue
```

After configuring Work, the user configures Idle with the same behavior list and an independent frequency for each behavior.

The app can provide sensible defaults so users can finish setup in under a minute.

---

## 3. Configure Frequency

Instead of exposing technical settings such as thresholds, cooldowns, and timers, the app should use simple language.

```text
Drink Water

How often should we remind you?

○ Occasional
● Regular
○ Frequent
```

Internally:

```text
Occasional → 2 hours
Regular    → 1 hour
Frequent   → 30 minutes
```

These values can be adjusted later as the product evolves.

## 4. Daily Goals Without HealthKit

The first version can track user-confirmed reminders without reading health data:

- Drink Water: a configurable number of confirmations per day.
- Stand Up: a configurable number of different hours completed per day. Multiple confirmations in the same hour count once.

Step totals and automatic activity detection require HealthKit and are deferred.

---

# Home Screen

The home screen should answer one question:

> **"What should I do right now?"**

Example:

```text
Good afternoon

Work
09:00 AM – 05:00 PM

Sleep schedule
11:00 PM – 07:00 AM

────────────────────

Next Reminder

💧 Drink Water

in 24 minutes

────────────────────

Today's Activity

💧 Water
4 reminders

🧍 Movement
3 reminders

🚶 Walking
Good
```

The interface should remain calm and minimal.

The user should not feel like they are operating a health dashboard.

---

# Architecture

A possible architecture:

```text
                    SwiftUI
                       │
                       ▼
                ┌─────────────┐
                │   Views      │
                └──────┬──────┘
                       │
                       ▼
                ┌─────────────┐
                │ ViewModels   │
                └──────┬──────┘
                       │
                       ▼
              ┌─────────────────┐
              │ Reminder Engine │
              └────────┬────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
      Daily Mode    Behavior     Activity
      Manager       Rules        Monitor
          │            │            │
          └────────────┼────────────┘
                       ▼
             Notification Scheduler
```

---

# Core Components

## DailyModeManager

Responsible for determining the current mode from the sleep schedule, Work schedule, and current time.

Resolution order:

```text
1. If current time is inside Sleep → Sleeping
2. Else if current time is inside Work → Work
3. Otherwise → Idle
```

```swift
enum DailyMode {
    case sleeping
    case work
    case idle
}

struct DailySchedule {
    let id: UUID
    let sleepStart: DateComponents
    let sleepEnd: DateComponents
    let workStart: DateComponents
    let workEnd: DateComponents
}
```

---

## Behavior

A predefined set of supported behaviors.

```swift
enum Behavior {
    case hydration
    case standUp
    case movement
    case eyeRest
    case break
    case windDown
}
```

The app controls the behavior definitions instead of allowing users to create arbitrary rules.

---

## ReminderRule

Defines how a behavior should behave within a daily mode.

```swift
struct ReminderRule {
    let behavior: Behavior
    let frequency: ReminderFrequency
    let threshold: TimeInterval?
}
```

---

## ReminderEngine

The core of the application.

Its responsibility is to answer:

> **Should I remind the user right now?**

Conceptually:

```text
Current Time
      +
Current Daily Mode
      +
Enabled Behaviors
      +
Recent Reminders
      +
Activity State
      ↓
ReminderEngine
      ↓
Should Remind?
      ↓
Notification
```

---

# Activity Awareness

The app can gradually become more intelligent.

Instead of relying only on timers, it can use available iOS system data to determine whether a reminder is still relevant.

Potential data sources include:

- HealthKit
- Step count
- Walking activity
- Standing/activity information
- Device activity signals
- User interactions

For example:

```text
Last movement:
12 minutes ago

Last water reminder:
47 minutes ago

Current mode:
Work

Enabled:
Water
Stand Up
Move

             ↓

ReminderEngine
             ↓

No reminder yet
```

Later:

```text
Continuous inactivity:
52 minutes

Stand-up threshold:
45 minutes

             ↓

🧍 Stand Up
```

---

# Notification Strategy

Notifications should be scheduled intelligently rather than generating a large number of fixed notifications.

The system should consider:

- Current daily mode
- Enabled behaviors
- Minimum interval
- Previous reminder
- Recent activity
- Whether the user already performed the behavior
- Whether another reminder is already pending

The goal is:

> **Fewer, more relevant notifications.**

---

# Data Model

A simple initial model could be:

```text
DailySchedule
├── id
├── sleepStart
├── sleepEnd
├── workStart
└── workEnd

ModeBehavior
├── mode
├── behavior
├── enabled
└── frequency

ReminderEvent
├── behavior
├── timestamp
├── mode
└── status
```

This also allows the app to build a lightweight history later.

---

# MVP

The first version should stay intentionally small.

### Phase 1 — Foundation

- [ ] SwiftUI app
- [ ] Sleep schedule
- [ ] Work schedule
- [ ] Automatic Sleeping/Work/Idle mode resolution
- [ ] Predefined behaviors
- [ ] Enable/disable behaviors
- [ ] Independent reminder frequency for Work and Idle
- [ ] Local notifications

### Phase 2 — Smart Reminders

- [ ] Reminder engine
- [ ] Minimum intervals
- [ ] Mode switching at sleep/work boundaries
- [x] Reminder history
- [ ] Activity-aware reminders
- [x] Avoid duplicate reminders

### Phase 3 — Health Integration

- [ ] HealthKit integration
- [ ] Step data
- [ ] Walking/activity detection
- [ ] More intelligent inactivity detection

### Phase 4 — Polish

- [ ] Apple-style UI
- [ ] Animations
- [x] Notification actions
- [ ] Widgets
- [ ] Apple Watch support
- [ ] Focus Mode integration

---

# Design Principles

## 1. Simple Configuration

Users should configure **what they want**, not **how the system works**.

Bad:

```text
Cooldown:
Minimum interval:
Threshold:
Trigger:
Grace period:
```

Good:

```text
Drink Water
Regular

Stand Up
Frequent
```

---

## 2. Mode Over Time

The app should think in terms of:

```text
"What is the user doing right now?"
```

rather than:

```text
"What time is it?"
```

---

## 3. Notifications Are Valuable

Every notification should have a reason.

The system should prefer:

> One useful reminder

over:

> Five technically correct reminders.

---

## 4. Don't Become a Health Dashboard

The product should not try to compete with full health and fitness applications.

Its purpose is much narrower:

> **Help users maintain healthy habits throughout their day with minimal effort.**

---

# Potential Product Direction

The long-term vision is a personal **behavior-aware reminder engine**.

The initial product defines the user's day through Sleeping, Work, and Idle:

```text
Sleeping
Work
Idle
```

In a later version, the awake portion can be expanded with additional modes such as Study, Exercise, or Home. The initial product only needs Work and Idle. The user selects what matters in each awake mode:

```text
Work
├── Water
├── Stand
├── Move
└── Eye Rest

Idle
├── Water
├── Move
└── Break
```

The app then quietly manages the reminders in the background.

The ultimate goal is:

> **Configure once. Let the app take care of the rest.**

---

# Possible App Names

Some possible directions:

- **Igotu**
- **Nudge**
- **Tempo**
- **Pace**
- **Habitual**
- **Flow**
- **Prompt**
- **Cue**
- **Well**
- **Nudge**
- **Rhythm**

A name like **Igotu** could work particularly well if the product personality is meant to feel friendly rather than medical.

---

# One-Sentence Product Definition

> **A mode-aware iOS wellness assistant that reminds you to take care of yourself at the right time, without making you manage a collection of alarms.**
