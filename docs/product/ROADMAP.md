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

Metrics
- NP, IF and TSS: a live tile for bikes, the end-of-workout summary and the post-ride page, one
  calculation shared with the FIT file.
- Peak power (5 s to 20 min) fixed: it counted one sample too many (5 s power read 20% high).
- Estimated FTP at 95% of the best 20 minutes.
- Fitness, Fatigue and Form on the history page (`docs/product/fitness-form.md`).
- Average power with zeros everywhere: tiles (AVG Watts, AVG Watt Lap, W/kg), the summary and
  mail, the chart page after Stop, the web templates, the FIT file and the history.
- FTMS power parsed as signed (a negative sample became 9999 W, +18% TSS); 3000 W or more is
  recorded as 0 (the same rule as the history TSS).
- The recorded power is the raw power, not the 3 s / 5 s display smoothing.
- Calories from work on bikes with power; METs from the ACSM leg ergometry formula.
- HR zones: the tile showed "Z1.5" for a second counted as Z2, and Z5 could not be reached with
  the defaults.

Recording
- A wall-clock change (NTP, manual) no longer deletes or clones minutes of the recording; the
  time a phone sleeps is counted (a clock that includes suspend).
- A Bluetooth dropout no longer records the last power for the whole gap; a separate power
  meter or cadence sensor is still recorded while only the trainer's link is down. Drivers that
  never report their link (RFCOMM) record as before.
- A stall over a minute keeps the FIT timeline aligned (one line per second).
- ERG is released after a workout and in free-ride blocks; What's on Zwift inclines and Power
  Zone Pack fixes; a What's on Zwift workout drives the trainer with the top bar off.
- The workout name (program, GPX, What's on Zwift) names the FIT file and the uploads, and an old
  name no longer sticks to the next ride.

Setup and post-ride
- The setup wizard no longer sets a resistance offset of 18 for everyone; ellipticals get the
  step too.
- A typed FTP or weight is saved when leaving the field with Back.
- Strava upload reports failures; the mail waits for the end of the ride.
- Ending a ride asks for confirmation by default.
- History: rides imported from other devices no longer show 65535 W / 255 bpm when a sensor was
  missing.
- Desktops without Bluetooth start fake, Wi-Fi, USB/serial and ANT equipment.

Dashboard v1
- Step 1: dark tokens (`src/ThemeTokens.qml`), flat tiles, quiet chrome.
- Step 2: legible tile anatomy (caption, value, unit, second line), 44 px touch targets, size
  classes for phones, tablets and TVs.
- Step 3: a ride bar (Lap, Pause, then End and Resume on a bike; Stop stays one tap on a
  treadmill), a status chip (searching, connected, reconnecting, paused), the tiles dimmed while
  paused, and a connection card with Search now and More help instead of the old help text (the
  support address and signature are gone; the disclaimer is in Credits).
- Step 4: Watts, Heart, Cadence and Elapsed large above the tiles on a bike (setting "Big key
  metrics at the top", on by default).
- Step 5: one zone palette (`ThemeTokens.zoneColor`): the Watts, FTP Zone, Heart and HR
  time-in-zone tiles carry a zone band, a "Z" pill and the zone colour on their value; the hero
  cells are tinted by zone; screen readers say "zone 4".
- The hero follows a running workout: Elapsed says when the next interval starts, Watts shows
  the target. Details in `docs/product/dashboard.md`.
- Open Train Program works again on builds without CHARTJS (Linux desktops): the page failed to
  load.

Records
- Power records on the history page: the best 5 s, 1 min, 5 min and 20 min of every bike ride and
  the day of each, saved with each ride and filled once for older ones (without touching their
  TSS). A ride that beats one says so when it is saved ("New power record: 5 min 312 W").

Never lose a ride
- A ride QZ did not save (closed or crashed before Stop) is offered at the next launch from its
  FIT backup: Recover puts it in the workout history, Discard deletes the backup, Not now asks
  again next time. A saved ride's backups are removed, and none are written after Stop. Backups
  of rides already in the history, or of no ride, are cleaned up; ones older than two days are
  left alone (earlier versions never removed the backups of saved rides).

Your numbers
- The setup wizard asks for FTP, max and resting heart rate (220 - age stays the default).
- After a bike ride whose best 20 minutes beats the FTP by 2% and 3 W, QZ offers the new FTP
  (95% of the 20 minutes) when the rider is back from the chart page.

## Next, in order

### Then
1. **One ride, one set of numbers**: a single workout summary used by the FIT file, the history,
   the email and the tiles.
2. **Never lose a ride, part 2**: save or discard after a ride, honest upload status with retry.
3. **First connection that works**: a connection card per sensor role, a filtered device picker,
   pairing without a restart, live data freshness.
4. **Zones, one definition**: one power and HR zone model and one palette for tiles, charts and
   targets.
5. **Ride dashboard v1.1**: the chart palette matches the tiles, a theme picker (OLED black,
   light), the hero for treadmills and rowers.
6. **Trainer control you can trust** and **workout engine correctness** (ZWO elements, ramps,
   segment laps, Peloton timing).
7. **Interval coaching**: current interval, countdown, target in range, next interval.
8. **Post-ride summary** built from the workout summary, scrubbable charts, one chart page.
9. **Progress and records, part 2**: the full power curve, records per period, weekly totals and
   goals.
10. **Share and celebrate**: a share card with the ride's numbers and PRs.
11. **Insights**: aerobic efficiency and decoupling, qualified VO2max, filtered HRV.
12. **Settings that get out of the way**: devices page, equipment filtering, grouped navigation,
   theme picker.

## Deferred

- Splitting `homeform.cpp` and `settings.qml`: large refactors with no gain for riders; done piece
  by piece where features touch them.
- Training load for runs, rows and heart-rate-only rides: needs thresholds QZ does not ask for yet.
- Readiness from overnight HRV: QZ only sees the heart rate during rides.
