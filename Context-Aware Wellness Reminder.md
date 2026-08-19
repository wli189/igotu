# Context-Aware Wellness Reminder

A personal wellness assistant for iOS that provides intelligent reminders based on **what the user is doing and which context they are currently in**.

Instead of creating dozens of fixed alarms, users define a few time-based contexts—such as **Work** or **Sleep**—and simply choose which wellness behaviors they want to be reminded about.

The app handles the reminder logic automatically.

---

## Core Idea

Most reminder apps are time-based:

> "Remind me to drink water every hour."

This project takes a different approach:

> **"During work, remind me to drink water regularly and remind me to stand if I've been sitting too long."**

The user does not need to configure complicated rules.

They simply:

1. Define a context.
2. Set the context's active time.
3. Enable or disable available behaviors.
4. Choose how frequently each behavior should be reminded.

The app handles the underlying scheduling and activity detection.

---

# Product Concept

## Contexts

A **Context** represents a period of the user's day with a particular set of reminder behaviors.

Examples:

- Work
- Sleep
- Study
- Gaming
- Morning
- Evening
- Custom

Example:

```text
Work
09:00 AM – 05:00 PM

Sleep
11:00 PM – 07:00 AM
```

Each context can have its own reminder configuration.

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

## Work Context

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

# Context-Based Behavior

The same behavior can behave differently depending on the current context.

For example:

| Behavior | Work | Study | Home | Sleep |
|---|---|---|---|---|
| Drink Water | Regular | Regular | Occasional | Off |
| Stand Up | Frequent | Frequent | Occasional | Off |
| Move Around | Regular | Regular | Optional | Off |
| Rest Eyes | Regular | Frequent | Optional | Off |
| Wind Down | Off | Off | Regular | Frequent |

This allows the app to adapt to different parts of the user's day without requiring complex configuration.

---

# Reminder Philosophy

The app should **not** behave like a collection of alarms.

Instead, reminders should be:

### Context-aware

Only active when the relevant context is active.

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

When should we remind you?

┌─────────────────────────┐
│ 🧑‍💻 Work               │
│ 9:00 AM – 5:00 PM       │
└─────────────────────────┘

┌─────────────────────────┐
│ 😴 Sleep                │
│ 11:00 PM – 7:00 AM      │
└─────────────────────────┘

        Continue
```

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

---

# Home Screen

The home screen should answer one question:

> **"What should I do right now?"**

Example:

```text
Good afternoon

Work
09:00 AM – 05:00 PM

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
      Context       Behavior     Activity
      Manager       Rules        Monitor
          │            │            │
          └────────────┼────────────┘
                       ▼
             Notification Scheduler
```

---

# Core Components

## ContextManager

Responsible for determining which context is currently active.

```swift
struct ReminderContext {
    let id: UUID
    let name: String
    let startTime: DateComponents
    let endTime: DateComponents
    let enabledBehaviors: Set<Behavior>
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

Defines how a behavior should behave within a context.

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
Current Context
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

Current context:
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

- Current context
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
Context
├── id
├── name
├── startTime
├── endTime
└── behaviors

ContextBehavior
├── contextID
├── behavior
├── enabled
└── frequency

ReminderEvent
├── behavior
├── timestamp
├── context
└── status
```

This also allows the app to build a lightweight history later.

---

# MVP

The first version should stay intentionally small.

### Phase 1 — Foundation

- [ ] SwiftUI app
- [ ] Context creation
- [ ] Work/Sleep contexts
- [ ] Start/end time
- [ ] Predefined behaviors
- [ ] Enable/disable behaviors
- [ ] Reminder frequency
- [ ] Local notifications

### Phase 2 — Smart Reminders

- [ ] Reminder engine
- [ ] Minimum intervals
- [ ] Context switching
- [ ] Reminder history
- [ ] Activity-aware reminders
- [ ] Avoid duplicate reminders

### Phase 3 — Health Integration

- [ ] HealthKit integration
- [ ] Step data
- [ ] Walking/activity detection
- [ ] More intelligent inactivity detection

### Phase 4 — Polish

- [ ] Apple-style UI
- [ ] Animations
- [ ] Notification actions
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

## 2. Context Over Time

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

The user defines their day:

```text
Work
Study
Exercise
Home
Sleep
```

And selects what matters in each context:

```text
Work
├── Water
├── Stand
├── Move
└── Eye Rest

Study
├── Water
├── Eye Rest
└── Break

Exercise
└── Water

Sleep
└── Wind Down
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

> **A context-aware iOS wellness assistant that reminds you to take care of yourself at the right time, without making you manage a collection of alarms.**