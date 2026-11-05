# Bikemodo on Google Play

How the release is built, and the answers Play Console asks for. *Draft, 4 November 2026.*

## The build

```bash
wsl -d Ubuntu-22.04 -u root -- bash /mnt/d/Creations/Applications/qz/tools/bikemodo_android_release.sh /mnt/c/Users/dhawa/bikemodo/bikemodo-release.aab
```

- **App ID:** `org.dhawal.bikemodo`, set for the release build only (`src/android/build.gradle`,
  `androidComponents`). It can never change after the first upload. The debug build stays
  `app.bikemodo`, so test installs and the CI checks are untouched.
- **Version:** the release workflow passes the version code and name to gradle
  (`-PbikemodoVersionCode`, `-PbikemodoVersionName`, or `BIKEMODO_VERSION_CODE` and
  `BIKEMODO_VERSION_NAME` for the script). Without them a build is `1` / `0.1.0`, which is
  right for the first upload by hand only.
- **Stripped from the release** (`src/android/release/AndroidManifest.xml`):
  - QZ's ADB shell service for iFit consoles
  - OCR with screen capture. The ML Kit library is still bundled, and its own start-up provider
    and component service stay in the manifest; only QZ's OCR service and meta-data are removed.
  - the floating window
  - the `SYSTEM_ALERT_WINDOW`, `PACKAGE_USAGE_STATS` and `GET_TASKS` permissions

  The script fails if any of these are still in the merged manifest.
- **QZ's supporter licence check is not built in.** It would send the rider's e-mail address to
  QZ's server over plain HTTP.
- **16 KB pages:** the script and CI run `tools/bikemodo_check_16kb.py` over every 64-bit library.
- **Only arm64-v8a.** Phones that run 32-bit Android only cannot install it.
- **Signing:** create an upload key once and keep it safe, off this repository:

  ```bash
  keytool -genkeypair -keystore upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000
  ```

  Then pass `BIKEMODO_UPLOAD_KEYSTORE`, `BIKEMODO_UPLOAD_ALIAS`, `BIKEMODO_UPLOAD_STORE_PASS` and
  `BIKEMODO_UPLOAD_KEY_PASS` to the script. Use Play App Signing, so Google holds the app
  signing key.

## Releases and updates

After the first upload, every release goes through `.github/workflows/bikemodo-release.yml`.

1. **Release:** push a tag such as `bikemodo-v0.2.0`, or run the workflow by hand.
   - The workflow builds the bundle with `tools/bikemodo_android_release.sh` and signs it with
     the upload key.
   - It asks Play for the next version code and uploads the bundle.
   - A tag goes to the track in the repository variable `BIKEMODO_RELEASE_TRACK`. When the
     variable is unset, that's `internal`. Set it to `production` once releases should reach
     every rider.
2. **Riders get it:** through Play's own auto-update, or inside the app.
   - **Inside the app** (`BikemodoUpdate.kt`, Play's in-app update, flexible kind): when the
     app comes to the front with no ride open, it asks Play for a newer version.
   - **The offer:** Today's banner offers it. Play's dialog asks once, and the download runs in
     the background.
   - **Restart:** the banner then offers **Restart**. If the rider picks **Later**, the update
     goes in by itself a minute after the app leaves the front, but never while a ride is open.
   - **Not now:** the banner doesn't offer that version again.
   - **Test installs:** a build not installed from Play, such as a test APK, never sees an
     update. Test the flow through internal app sharing or the internal track.

Play allows no other way: a Play app "may not modify, replace, or update itself using any method
other than Google Play's update mechanism" (Device and Network Abuse policy).

**Repository secrets the workflow needs:**

| Secret | What it holds |
|---|---|
| `BIKEMODO_UPLOAD_KEYSTORE_B64` | base64 of `upload.jks` |
| `BIKEMODO_UPLOAD_ALIAS` | the upload key's alias |
| `BIKEMODO_UPLOAD_STORE_PASS` | the keystore password |
| `BIKEMODO_UPLOAD_KEY_PASS` | the key password |
| `BIKEMODO_PLAY_SERVICE_ACCOUNT_JSON` | a Play service account with release rights on `org.dhawal.bikemodo` |
| `BIKEMODO_SECRET_H` (optional) | the text of `secret.h` |

Play's API can't make the first upload. Upload the first bundle in Play Console by hand: build
it with the script, which gives version code 1.

## Still to do (needs your accounts)

- **Strava and intervals.icu sign-ins.** Register Bikemodo's own apps with both services, put
  their keys in a `secret.h` and pass it as `BIKEMODO_SECRET_H`. Without it those sign-ins do
  not work in the release.
- **Peloton sign-in.** It returns through QZ's web address (`www.qzfitness.com/peloton/callback`),
  which can't be verified for Bikemodo's app ID. Peloton needs its own registration and an
  address you own, or it should be hidden in the release.
- **Crash reports.** None are built in. Adding them means choosing a service (for example
  Sentry or Firebase Crashlytics) and declaring it below.
- **Privacy policy.** Publish `docs/bikemodo/privacy-policy.md` at a public URL with a contact
  address.

## Play Console: App content

- **Foreground service type `connectedDevice`.** Keeps the ride recording from the bike's
  Bluetooth connection while the screen is off. Video of a ride with the screen off, if asked.
- **Health Connect.** The app writes:
  - exercise sessions
  - distance, total calories, heart rate and power
  - speed, cycling cadence, elevation gained and steps
  - steps cadence and heart-rate variability

  It reads heart-rate variability, resting heart rate and sleep, for the readiness on Today.
  Declare each with its reason in the Health apps form.
- **Ads:** none. **Target audience:** 13 and older.

## Play Console: Data safety

*Review this against Play's own definitions of "collected" and "shared" before submitting.
Health Connect is an on-device API, so it may not count as shared at all, and a Strava upload
may count as collected. The table below is a first guess, not a checked answer.*

| Data type | Collected? | Shared? | Why |
|---|---|---|---|
| Health and fitness: fitness info | No¹ | Yes, when the rider connects Strava, intervals.icu or allows Health Connect | App functionality |
| Health and fitness: health info (HRV, resting HR, sleep) | No, read on the phone only | No | App functionality |
| Location | No | No | |
| Personal info, contacts, messages, photos | No | No | |
| App activity, diagnostics | No² | No | |
| Device or other IDs | No | No | |

- ¹ "Collected" means sent off the phone to the developer. Bikemodo has no server, so nothing is
  collected. Uploads to Strava and intervals.icu are transfers the rider starts by connecting the
  service; declare them as shared, with user consent.
- ² ML Kit is bundled but cannot start in the release. Check Google's ML Kit data disclosure
  before submitting, in case Play's scanner flags the library.
- **Encrypted in transit:** yes. Strava, intervals.icu, Peloton and Health Connect all use HTTPS
  or on-device APIs.
- **Can users ask for data to be deleted:** yes. It is all on the phone (see the privacy policy).
