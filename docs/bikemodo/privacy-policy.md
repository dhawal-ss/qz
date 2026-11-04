# Bikemodo privacy policy

*Draft, 4 November 2026. Fill in the contact address and review before publishing. It has to be
reachable at a public URL for Google Play and Health Connect.*

Bikemodo is made by dhawal.org. It records your indoor bike rides on your phone. There is no
Bikemodo account, no Bikemodo server, no advertising and no analytics.

## What stays on your phone

- **Your rides.** Every ride is saved as a FIT file in `Documents/Bikemodo` on your phone, with a
  ride library (an index of those files) in the app's private storage.
- **Your settings and profile.** Weight, age, heart-rate and power zones, FTP, goals and the
  other settings stay in the app's private storage.
- **Sign-ins.** When you connect Strava, intervals.icu or Peloton, the sign-in (an access token)
  is kept in the app's private storage. Bikemodo never sees your password for those services.

Bikemodo sends none of this anywhere except as described below.

## What leaves your phone, and when

- **Services you connect.** When you connect a service, rides go to it:
  - **Strava:** each ride is uploaded when it ends.
  - **intervals.icu:** each ride is uploaded when it ends, and the day's planned workout is
    read from your calendar.
  - **Peloton:** class details are read so you can follow a class.

  Each of these services has its own privacy policy. Disconnect any time under You, Connections.
- **Health Connect.** Once you allow it, each saved ride is written to Health Connect:
  - the exercise session
  - distance, calories, heart rate and power
  - speed, cadence, elevation and steps
  - heart-rate variability

  If you turn on readiness on the Today screen, Bikemodo reads three things from Health Connect
  to describe how rested you are: heart-rate variability, resting heart rate and sleep. That
  data is only shown to you and is not stored by Bikemodo or sent anywhere. Change or remove
  access any time in the Health Connect app.

  Bikemodo's use of information received from Health Connect follows the Health Connect
  Permissions policy, including the Limited Use requirements.
- **Sharing and export.** When you share a ride card or export your rides (CSV, backup), the file
  goes where you send it.
- **An emoji font.** On the first start Bikemodo downloads a font file from GitHub
  (raw.githubusercontent.com) so emoji show correctly. GitHub sees your phone's IP address, as
  with any download. Nothing about you is sent.

## Bluetooth and location

Bikemodo uses Bluetooth to find and connect to your bike, heart-rate strap and other sensors. It
does not use Bluetooth to work out where you are.

While a ride runs, Bikemodo also shows up as a Bluetooth bike that other apps nearby can connect
to, such as Zwift on a tablet. Those apps see your live speed, cadence, power and heart rate.
Bikemodo also serves the same live numbers as a web page on your Wi-Fi network, for overlays on
another screen. This stays on your local network and does not go to the internet. On Android 11 and older, Android requires the
location permission to scan for Bluetooth devices. Bikemodo asks for it only there and does not
read your location.

## Backups

Android's backup to your Google account includes your ride library. It leaves out the settings
file and the sign-in pages' cookies, because they hold your sign-ins. A direct transfer to a new
phone brings everything over. Your rides in `Documents/Bikemodo` are not part of Android's
backup, so copy that folder, or use Your data, Back up, to keep them.

## Children

Bikemodo is not directed at children under 13.

## Deleting your data

Everything is on your phone. To delete it:
- **Ride files:** delete `Documents/Bikemodo`.
- **Settings, library and sign-ins:** uninstall Bikemodo, or clear its storage in Android's settings.
- **Health Connect:** delete data written by Bikemodo in the Health Connect app.
- **Connected services:** delete rides uploaded to Strava or intervals.icu there.

## Changes and contact

If this policy changes, the new version will be posted at this address with a new date.
Questions: **[contact e-mail]**.
