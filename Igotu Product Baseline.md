# Igotu Product Baseline

**Product and implementation baseline** · **Last updated:** 2026-09-05

`igotu` is an iOS and iPadOS wellness reminder app that uses the user's daily schedule to decide which reminders are relevant. It is designed to feel like a quiet daily rhythm, not a collection of alarms or a health dashboard.

The current product is intentionally small:

- Sleeping, Work, and Idle are the only daily modes.
- Drink Water, Stand Up, and Move Around are the only supported behaviors.
- Reminders are planned from time, mode, rules, and reminder history.
- Completion is user-confirmed; the app does not infer health activity.

## Product Definition

> A schedule-aware wellness assistant that reminds you to take care of yourself at the right time, without making you manage a collection of alarms.

The user configures a sleep schedule, one or more Work periods, and separate reminder rules for Work and Idle. The app plans relevant reminders ahead of time and presents them through local notifications and in-app confirmation flows.

## Daily Modes

The app derives one current mode from the schedule:

1. Sleeping takes priority over every other mode.
2. Work applies during a configured Work period.
3. Idle applies to all remaining time.

The mode is determined by the schedule and the current time. Completion is recorded only when the user confirms a reminder.

### Schedule Model

Schedules are made from explicit time periods. Each period has:

- A start time.
- An end time.
- A set of active weekdays.

The user may configure multiple Work periods across the week. Sleep periods may cross midnight. The schedule validator prevents invalid periods and overlapping Sleep or Work schedules, as well as Sleep/Work conflicts.

When no explicit Sleep or Work period is active, the current mode is Idle.

Example:

```text
Sleep
11:00 PM – 07:00 AM
Every day

Work
09:00 AM – 12:00 PM
Monday – Friday

Work
01:00 PM – 05:00 PM
Monday – Friday

Idle
All other time
```

Sleeping suppresses ordinary behavior reminders. A separate Wind Down notification may be scheduled before the next configured sleep start. Its lead time is configurable in the schedule editor.

## Supported Behaviors

The behavior list is fixed and intentionally small:

| Behavior | Reminder message | Current daily metric |
|---|---|---|
| Drink Water | Take a moment to drink some water. | Confirmed hydration reminders |
| Stand Up | Stand up and stretch for a moment. | Different hours with a confirmed reminder |
| Move Around | Take a short walk or move around. | No daily target currently |

Each behavior can be enabled or disabled independently for Work and Idle. Sleeping has no behavior rules.

## Reminder Settings

Work and Idle have separate settings for every supported behavior.

For an enabled behavior, the user configures:

- **Every:** the base reminder interval.
- **Offset:** a bounded scheduling variation around the base interval.

The scheduler uses the interval and offset to calculate future reminder times. The app records a behavior only after the user confirms the reminder.

The settings surface uses simple interval and offset controls. Technical scheduling details remain internal to the reminder engine and planner.

## Daily Goals

The app tracks lightweight, user-confirmed goals without reading health data:

- **Water:** a configurable number of acknowledged Drink Water events per day.
- **Standing hours:** the number of distinct hours containing an acknowledged Stand Up event.

Skipped, expired, cancelled, and test events do not count toward daily goals. Multiple Stand Up confirmations in the same hour count once.

Daily goals are shown on the Today screen with the current progress for the day.

## Reminder Planning

The reminder engine calculates candidates from:

- The current schedule interval.
- The active mode.
- Enabled Work or Idle rules.
- The base interval and offset range for each rule.
- Recent reminder events and their cooldown anchors.

The planner then builds a desired set of future behavior events. It does not send notifications or write persistence directly.

### Rolling Planning Window

The current planner:

- Plans behavior reminders within a 12-hour rolling window.
- Allows multiple future reminders for the same behavior.
- Supports multiple behaviors being pending at the same time.
- Caps pending behavior notifications at 60.
- Retains valid scheduled events when other settings change.
- Replans only the affected behavior after a completion or skip.
- Avoids duplicate events for the same behavior and planned time.

Background refresh is used to replenish the future window. A background refresh is not required for notifications that are already scheduled.

Sleep / Wind Down is scheduled separately from daily behavior events. It uses one schedule-driven notification for the next applicable sleep start.

## Reminder Event Lifecycle

Every daily behavior reminder has one stable event ID shared by its history record, local notification payload, and in-app confirmation flow.

```text
scheduled ──> delivered ──> acknowledged
     │              │
     │              ├──────> skipped
     │              └──────> expired
     │
     └─────────────────────> cancelled
```

Terminal states are `acknowledged`, `skipped`, `expired`, and `cancelled`.

- `acknowledged` events count toward daily goals.
- `skipped`, `expired`, and `cancelled` events do not count toward daily goals.
- `scheduled` and `delivered` events remain unresolved.
- Repeated actions are idempotent and cannot resolve an already terminal event.
- `resolvedAt` is written only for terminal states.

Cooldown anchors are state-specific:

- `scheduled` and `delivered` use the planned due time.
- `acknowledged` and `skipped` use the action time.
- `expired` uses the planned due time plus the expiration grace period.
- `cancelled` does not block a future reminder.

When a notification is opened, the event is delivered or opened but is not automatically completed. The user must choose Done or Skip in the app.

## Notification and Confirmation Flow

Daily behavior reminders use event-specific local notifications.

### Foreground

When a behavior notification is delivered while the app is active, the app shows an in-app confirmation prompt. The user can:

- Tap Done to acknowledge the event.
- Tap Skip to skip the event.

### Background or Not Running

When the user taps a behavior notification while the app is in the background or not running, the app opens a full-screen confirmation view for that event. Done and Skip resolve the same event record used by the notification.

The system notification opens the app; the behavior action is handled by the in-app confirmation UI.

### Testing

The Testing page can create short-delay behavior test events and independent Wind Down test notifications. Test events reuse the production delivery and confirmation flow but are excluded from normal reminder planning and daily metrics.

## User Experience

### First Setup

The initial setup configures:

1. Sleep periods and the Wind Down lead time.
2. Work periods and active weekdays.
3. Work reminder rules.
4. Idle reminder rules.
5. Daily goals.

The app provides defaults for the supported behaviors so setup can remain brief.

### Today

The Today screen answers:

> What should I do right now?

It shows:

- A time-aware greeting.
- The current mode and its progress through the active schedule interval.
- Daily water and standing progress.
- Today's Sleep and Work rhythm.

The screen should remain calm and scannable. It should show useful progress without becoming a general health dashboard.

### Settings

Settings provides access to:

- Sleep and Work schedule editing.
- Wind Down lead time.
- Work and Idle reminder settings.
- Daily goals.
- Notification testing.

On iPhone, the app uses Today and Settings tabs. On iPad, the same destinations are presented through a sidebar layout.

## Architecture

The implementation keeps schedule decisions testable and platform effects behind iOS adapters:

```text
SwiftUI views
    │
    ├── AppConfigurationStore
    ├── ReminderHistoryStore
    │
    └── Core scheduling and reminder logic
            │
            ├── DailyScheduleTimeline
            ├── DailyModeManager
            ├── ReminderEngine
            ├── ReminderPlanner
            └── Daily metrics calculators
                    │
                    ▼
             ReminderCoordinator
                    │
                    ├── ReminderHistoryStore
                    └── NotificationScheduler
                            │
                            ▼
                    UserNotifications
```

### Core Modules

- `DailyScheduleTimeline` converts schedule periods into non-overlapping Sleep, Work, and Idle intervals and gives Sleep priority.
- `DailyModeManager` exposes the current mode and interval from the timeline.
- `ReminderEngine` calculates next candidates from rules and event history. Random offset generation is injected in tests.
- `ReminderPlanner` builds and reconciles the bounded rolling plan without touching persistence or notification APIs.
- `ReminderHistoryStore` persists reminder events, applies lifecycle transitions, and provides cooldown history.
- `DailyMetricsCalculator` derives daily water and standing progress from acknowledged events.
- `ReminderCoordinator` coordinates planning, persistence, notification scheduling, event actions, expiration, and re-planning.
- `NotificationScheduler` is the local notification adapter.
- `ReminderBackgroundScheduler` requests opportunities to replenish the rolling plan.
- `AppConfigurationStore` persists schedules, rules, goals, and Wind Down configuration in `UserDefaults`.

### Storage

The current prototype stores configuration and reminder history in `UserDefaults`. Reminder events are encoded with stable IDs and retain their status, timestamp, context, test metadata, and resolution time.

## Current Implementation Status

The following describes the current baseline rather than a future checklist:

- SwiftUI iOS/iPadOS app entry point and adaptive navigation.
- Sleep and Work schedule periods with weekday selection.
- Cross-midnight schedule handling and schedule validation.
- Sleeping, Work, and Idle mode resolution.
- Three fixed wellness behaviors.
- Independent Work and Idle reminder rules.
- Configurable reminder intervals and offsets.
- Daily water and standing goals.
- Reminder history and event lifecycle transitions.
- Event-specific local notification planning in a rolling window.
- Foreground in-app reminder prompts.
- Background notification opening into full-screen confirmation.
- Independent behavior notification testing and Wind Down testing.
- Focused unit coverage for schedule, reminder, configuration, history, and metrics logic.

The product direction is deliberately bounded around this implementation. New behavior types or new daily modes should be treated as separate product decisions rather than assumed extensions of the current plan.

## Product Principles

### Simple Configuration

Users choose what to be reminded about and roughly how often. The app owns the event planning, cooldown, notification reconciliation, and lifecycle details.

### Schedule-Aware, Not Alarm-Driven

The app thinks in terms of the user's current daily mode. A reminder is valid only when its behavior is enabled for the mode and its planned time remains inside the corresponding schedule interval.

### Every Notification Has a Reason

The system favors a bounded set of relevant, event-specific reminders. Different behaviors may be pending at the same time when each has an independent enabled rule and valid planned time.

### Minimal Effort

The user should be able to configure the rhythm once, confirm reminders as they happen, and understand today's progress without maintaining a complicated rule system.
