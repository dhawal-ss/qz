# Fitness, Fatigue and Form

The card at the top of the workout history tells a rider how ready they are, from the training
load of their bike rides.

## What it shows

- **Fitness** (CTL): training over the last 6 weeks. **Fatigue** (ATL): the last 7 days.
  **Form** (TSB) = Fitness - Fatigue. Whole numbers; Form is computed from the rounded values so
  the three numbers on screen always add up.
- A plain-language status, the 7-day change in Fitness, a 6-week sparkline of Fitness and Fatigue,
  the current FTP and how many workouts of the last 6 weeks were counted.
- Tapping the card opens an explanation with the rider's own Form zones.
- Hidden while a day is picked in the calendar, and when no ride is counted.

## Calculation (`src/metric.cpp`)

- **TSS of a ride**: `metric::rideTrainingStress`. The FIT records are spread to one power value
  per second (a record holds until the next one; a gap over 30 s is a pause and counts 1 s; of
  several records in a second the last is kept), then Normalized Power (30 s rolling average,
  fourth power, mean, fourth root) and TSS = seconds x NP x IF / (FTP x 3600) x 100.
- **FTP**: the one in the file (session `threshold_power`, which QZ writes for every bike ride,
  else QZ's "FTP" developer field) when it is between 50 and 700 W, else the current FTP. TSS is
  fixed once stored: changing FTP later does not rewrite past rides.
- **Which workouts count**: FIT sport cycling with power. Runs, rows, ellipticals and rides
  without power get TSS 0 and are listed as not counted.
- **Days**: `metric::dailyTrainingStress` adds the rides of each local day (a ride across midnight
  counts on its start day). A ride that starts before the end of the previous one is the same ride
  recorded twice (QZ and a watch): the higher TSS is kept. An end time more than a day after the
  start is ignored (a broken clock).
- **Fitness and Fatigue**: `metric::trainingLoad`, TrainingPeaks' recursion
  F_d = F_(d-1) + (TSS_d - F_(d-1)) / 42 (7 for Fatigue), both 0 before the first ride, one step per
  calendar day up to today (rest days count as 0).
- **Status** (`metric::trainingStatus`), in order:
  1. `break` when the last workout of any kind is 14 days old or more,
  2. `learning` during the first 42 days of history,
  3. else the Form zone: limits are 20%, 5%, -10% and -30% of Fitness (of 20 at least):
     fading (above the first), fresh, balanced, building, tired (below the last).

## Storage (`src/fitdatabaseprocessor.cpp`)

- Column `workouts.tss`: NULL = not worked out yet, 0 = not counted, > 0 = the TSS.
- New and imported rides get it when they are saved.
- Rides saved before the column existed are filled once, after the startup scan, 20 at a time
  through the processor's event loop, on their own SQLite connection (the rows are read and the
  statement closed before any file is parsed, so the UI thread's writes do not wait). A missing or
  unreadable file gets 0. What a stopped fill leaves is done at the next launch.
- While rows are NULL the card says "Working out your fitness from your past rides..." instead of
  showing partial numbers.

## Model and UI

- `WorkoutModel::trainingLoad` (a `QVariantMap`, keys documented above
  `WorkoutModel::refreshTrainingLoad`), refreshed with the streaks after each load, when the fill
  ends, and when the history page opens (the numbers follow the date).
- `src/WorkoutsHistory.qml`: the card is the list header. Its content uses positioners with set
  widths, not layouts: a layout's height read in a binding loops on the wrapped texts.

## Tests

`tst/ToolTests/metrictestsuite.cpp` (TSS resampling, daily totals and duplicates, the recursion,
zones and status) and `tst/ToolTests/qfittestsuite.cpp` (the FTP stored in the file, the TSS rules,
saving and the one-time fill on a real database).

## Not yet

Runs, rows and heart-rate-only rides; recalculating past rides after an FTP change; a training
load number on each workout card; Fitness for a day picked in the calendar.
