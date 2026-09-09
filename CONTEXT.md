# Domain Vocabulary

## Mode

A `DailyMode` is a named state of the daily rhythm. A schedulable mode owns
zero or more explicit time periods. `idle` is the fallback state produced when
no explicit period is active; it is not currently an editable schedule mode.

## Schedule Period

A schedule period belongs to one mode, has a start and end time, and applies on
one or more weekdays. The schedule stores periods by mode so adding a mode does
not require adding another top-level schedule field.

## Reminder Frequency

A reminder frequency is an interval plus an allowed timing offset. Preset
frequencies and editor interval choices are catalog entries, while custom
values retain the same interval-and-offset shape.

## Reminder Policy

Each mode defines which reminder behaviors make sense in that context and
which of those behaviors are enabled by default. A behavior outside a mode's
policy is not part of that mode's reminder configuration and is not scheduled
there. Reminder configurations belong to their mode, so changing one mode's
frequency or membership does not change another mode.

The current policy is:

- Sleeping: no reminders
- Work: hydration, standing, and movement
- Study: hydration and standing
- Idle: hydration and movement
