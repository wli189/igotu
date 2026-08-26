# Live Activity Research

## Apple-documented constraints

- Live Activities must support the Lock Screen, expanded Dynamic Island, compact Dynamic Island, and minimal Dynamic Island presentations. The system chooses the presentation for each device and location.
- The Lock Screen presentation should provide glanceable information for the event or task. The system may truncate a Live Activity whose height exceeds 160 points.
- The compact presentation consists of leading and trailing views that form one cohesive piece of information. The minimal presentation is used when multiple Live Activities compete for the Dynamic Island.
- The expanded presentation appears briefly for updates and when a person touches and holds a compact or minimal presentation.
- Buttons and toggles are supported when backed by an App Intent. Live Activity controls do not perform actions in CarPlay.
- `staleDate` marks the point at which displayed content becomes outdated. It changes the activity state to stale; it does not itself remove the Live Activity.
- A Live Activity can be active for up to eight hours. After that, the system removes it from the Dynamic Island, but it can remain on the Lock Screen for up to four additional hours.
- When ending an activity, `.immediate` removes the ended activity from the Lock Screen immediately. The default policy can keep final content visible for up to four hours.

Sources:

- https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- https://developer.apple.com/design/human-interface-guidelines/components/system-experiences/live-activities

## Current project timing

- The Live Activity is eligible from five minutes before `dueAt` through fifteen minutes after `dueAt`.
- The initial content uses `staleDate = dueAt + 15 minutes`.
- Done and Skip end the activity with an immediate dismissal policy.
- The system-level eight-hour limit is not the intended product duration for this reminder. The intended reminder window is about twenty minutes when the activity starts at the five-minute lead time, although the actual start depends on when the app refreshes the scheduler.
