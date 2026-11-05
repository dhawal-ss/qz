# QZ product roadmap

QZ is turning from an equipment bridge into an indoor cycling platform: accurate numbers first, then
the screens riders look at every day (the ride dashboard, the post-ride summary, the history), then
progress and insights. This file is the shared plan; it is updated as work lands.

It comes from a verified audit of the app (eight areas, every finding checked against the code by
a second reviewer before it was kept): about 70 findings after merging duplicates.

## Product decisions

Taken by the product lead; each can be reverted on its own.

1. **Average power counts zero samples** (coasting), as TrainingPeaks, WKO and Garmin do by default.
   Cadence averages still leave zeros out.
2. **Calories on bikes with power come from the work done** (kJ at 24% gross efficiency, about
   kJ x 1), not from a MET formula that grows with body weight.
3. **Estimated FTP is 95% of the best 20 minutes** (Coggan). Done.
4. **Training load is TSS from Normalized Power and the FTP of the day of the ride**; Fitness,
   Fatigue and Form follow TrainingPeaks' 42/7-day recursion, Form measured after the day's rides
   (the intervals.icu convention). Form zones are a percentage of Fitness. Bike rides only for now.
5. **Ending a ride asks for confirmation** by default.
6. Treadmill, rower and elliptical support stays; cycling is the focus of new work.

## Shipped

- NP, IF and TSS: a live tile for bikes, the end-of-workout summary and the post-ride page, one
  calculation shared with the FIT file.
- Peak power (5 s to 20 min) fixed: it counted one sample too many (5 s power read 20% high).
- Estimated FTP at 95% of the best 20 minutes.
- Fitness, Fatigue and Form on the history page (`docs/product/fitness-form.md`).
- History: rides imported from other devices no longer show 65535 W / 255 bpm when a sensor was
  missing.
- Desktops without Bluetooth start fake, Wi-Fi, USB/serial and ANT equipment.

## Next, in order

### Fix now: wrong numbers and lost rides
- Average power with zeros everywhere (tile, summary, FIT, history).
- FTMS power parsed as signed (a negative sample became 9999 W, +18% TSS); spikes ignored in
  the history TSS.
- The recorded power is the raw power, not the 3 s / 5 s display smoothing.
- Calories from work on bikes with power; METs from the ACSM leg ergometry formula.
- HR zones: the tile showed "Z1.5" for a second counted as Z2, and Z5 could not be reached with
  the defaults.
- A wall-clock change (NTP, manual) deleted or cloned minutes of the recording.
- A Bluetooth dropout recorded the last power for the whole gap.
- ERG left on after a workout or in free-ride blocks.
- The setup wizard set a resistance offset of 18 for everyone who tapped Next.
- A typed FTP or weight was lost when leaving the field with Back.
- Strava upload reported success when it failed.

### Then
1. **One ride, one set of numbers**: a single workout summary used by the FIT file, the history,
   the email and the tiles.
2. **Your numbers from day one**: FTP, max and resting HR in the setup wizard, and an
   "Update FTP to N W?" prompt after a ride whose best 20 minutes says so.
3. **Never lose a ride**: recover the crash backups at the next launch, save or discard after a
   ride, honest upload status with retry.
4. **First connection that works**: a connection card per sensor role, a filtered device picker,
   pairing without a restart, live data freshness.
5. **Zones, one definition**: one power and HR zone model and one palette for tiles, charts and
   targets.
6. **Ride dashboard v1**: hero metrics, legible tiles, zone colours, safe pause/end controls, a
   theme system.
7. **Trainer control you can trust** and **workout engine correctness** (ZWO elements, ramps,
   segment laps, Peloton timing).
8. **Interval coaching**: current interval, countdown, target in range, next interval.
9. **Post-ride summary** built from the workout summary, scrubbable charts, one chart page.
10. **Progress and records**: power curve and PRs, weekly totals and goals.
11. **Share and celebrate**: a share card with the ride's numbers and PRs.
12. **Insights**: aerobic efficiency and decoupling, qualified VO2max, filtered HRV.
13. **Settings that get out of the way**: devices page, equipment filtering, grouped navigation,
   theme picker.

## Deferred

- Splitting `homeform.cpp` and `settings.qml`: large refactors with no gain for riders; done piece
  by piece where features touch them.
- Training load for runs, rows and heart-rate-only rides: needs thresholds QZ does not ask for yet.
- Readiness from overnight HRV: QZ only sees the heart rate during rides.
