# Ride dashboard

The home page riders look at during a ride: the ride bar, the hero strip and the tiles.

## Colours (`src/ThemeTokens.qml`)

- Dark tokens: `bg`, `surface`, `surfaceRaised`, `stroke`, text colours (every text colour is at
  least 4.5:1 on `surface`), and the state colours `go`, `caution`, `danger`, `info` with their
  tonal fills.
- `pick(stored, legacy, token)`: a colour setting still at its old stock value takes the token,
  so riders who chose their own colours keep them.
- `zoneColor(zone, count)`: one palette for power zones 1-7 and heart rate zones 1-5 (red is the
  top zone on both scales).

## Ride bar (`src/HomeForm.ui.qml`, `src/RideButton.qml`)

- `homeform::rideState`: 0 not recording, 1 recording, 2 paused (stopped is checked first:
  `pause_on_start` leaves both flags set). `endNeedsPause`: a device exists and it is not a
  treadmill.
- Buttons, left to right, the primary one at the edge:

  | State | Bike, rower, elliptical | Treadmill |
  |---|---|---|
  | not recording | Start | Start |
  | recording | Lap, Pause | Lap, Stop, Pause |
  | paused | End, Resume | Stop, Resume |

  End and Stop open the confirmation (`confirm_stop_workout`, on by default). External stops (web,
  keyboard shortcut, the end of a program, Peloton) are unchanged.
- Status chip: searching (the first line of the search status), Reconnecting (a device whose link
  is down), Paused, Connected. A tap searches now, or looks for the heart rate sensor again. A
  device whose `connected()` was never true (the RFCOMM drivers) counts as connected while it
  exists, as the recording does.
- The line under the bar names the workout or the equipment.
- Paused: the tiles dim to 50%.

## Connection card

Shown while no equipment is connected (`labelHelp`), above the dimmed tiles, also with the top bar
off: what QZ is doing, three tips (when there is room), Search now and More help (the old
checklist). Linux desktop builds call `deviceConnected()` at start, so they never show it.

## Hero strip (`src/HeroStrip.qml`)

- Bikes with `tile_hero_enabled` (on by default): Watts, Heart, Cadence and Elapsed leave the grid
  (`homeform::heroTiles`, so the grid indices of `appModel` and `moveTile` stay aligned) and are
  shown large in the grid's header, which scrolls with the tiles.
- Columns: the tile count up to 3, else 2 on phones and 4 from 600 px. Cell height
  `clamp(max(18% of the page, half the cell width), 112, 240)`.
- No heart rate reads `--`; an elapsed time under an hour drops its hours.
- While a workout runs, Elapsed says when the next interval starts ("Next in 1:00 · 3/12") and
  Watts shows the target the trainer is asked for.

## Zones

- `DataObject::zone` and `zoneCount` (0: no zone). Set in `homeform::update` on FTP Zone, Watts
  (with `tile_watt_color_enabled`) and Heart; the HR time-in-zone tiles carry their own zone.
- A tile with a zone: a band on its top edge, a "Z4" pill (not on FTP Zone, which reads "Z4.2"),
  the zone colour on its value (zone 1 stays white). A hero cell is tinted by its zone.
- Screen readers add "zone 4" to the name.

## Tests

`tst/qml/tst_herostrip.qml` (layout, display rules, zone tint, screen reader name);
`metric::ftpSuggestion` in `tst/ToolTests/metrictestsuite.cpp`.
