#!/bin/bash
# Builds Bikemodo's Google Play bundle (AAB) for arm64 phones and tablets inside WSL, with the
# toolchain from bikemodo_android_setup.sh. Run as root:
#   wsl -d Ubuntu-22.04 -u root -- bash /mnt/d/Creations/Applications/qz/tools/bikemodo_android_release.sh [out.aab]
#
# The release is org.dhawal.bikemodo with its own version (src/android/build.gradle,
# androidComponents), and leaves out QZ's iFit, OCR and floating-window pieces
# (src/android/release/AndroidManifest.xml). It builds in its own folder, so the debug build's
# objects are never mixed in. QZ's supporter-licence check is not built in: it would send the
# rider's e-mail address to QZ's server.
#
# Signing with your upload key (kept off this repository, and never lost: Play needs it for
# every update), from the environment:
#   BIKEMODO_UPLOAD_KEYSTORE=/path/upload.jks BIKEMODO_UPLOAD_ALIAS=upload
#   BIKEMODO_UPLOAD_STORE_PASS=... BIKEMODO_UPLOAD_KEY_PASS=...
# Without them the bundle is left unsigned, which is enough to check it.
# BIKEMODO_SECRET_H may name a secret.h with Bikemodo's own Strava / intervals.icu keys; without it
# the sign-ins to those services do not work in the release.
# BIKEMODO_VERSION_CODE and BIKEMODO_VERSION_NAME set the version (the release workflow asks Play
# for the next code); without them it is 1 / 0.1.0, fine for checking, refused by Play after the
# first upload.
set -euo pipefail

TOOLS=/opt/bikemodo
QT_DIR=$TOOLS/qt/5.15.0/android
SDK=$TOOLS/sdk
NDK=$SDK/ndk-bundle
REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=/root/bikemodo-release
OUT_AAB=${1:-$WORK/bikemodo-release.aab}
JOBS=${JOBS:-6}
APP_ID=org.dhawal.bikemodo

export PATH=$QT_DIR/bin:$PATH
export ANDROID_SDK_ROOT=$SDK ANDROID_HOME=$SDK ANDROID_NDK_ROOT=$NDK ANDROID_NDK=$NDK
export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")
export CCACHE_DIR=$TOOLS/ccache CCACHE_BASEDIR=$WORK
START=$(date +%s)

echo "== copying changed sources"
mkdir -p "$WORK"
rsync -a --delete --exclude='.git/' --exclude='output/' --exclude='build-*/' \
  --exclude='*.o' --exclude='Makefile*' --exclude='src/secret.h' --exclude='.qmake.stash' \
  --filter='P src/qthttpserver/***' --filter='P src/android-*' --filter='P src/**/Makefile*' \
  --filter='P src/**/*.o' --filter='P src/**/moc_*' --filter='P src/**/qrc_*' --filter='P *.so' \
  "$REPO/" "$WORK/"
cd "$WORK"

if [ -n "${BIKEMODO_SECRET_H:-}" ]; then
  cp "$BIKEMODO_SECRET_H" src/secret.h
else
  printf '#define STRAVA_SECRET_KEY\n#define PELOTON_SECRET_KEY\n#define SMTP_USERNAME\n#define SMTP_PASSWORD\n#define SMTP_SERVER\n#define INTERVALSICU_CLIENT_ID\n#define INTERVALSICU_CLIENT_SECRET\n' > src/secret.h
fi
if grep -q "define LICENSE" src/secret.h; then
  echo "secret.h defines LICENSE: the release must not have QZ's licence check" >&2
  exit 1
fi

echo "== qthttpserver (first build only)"
if [ ! -f "$WORK/.qthttpserver-built" ]; then
  cp qHttpServerBin/5.15.2/headers/* src/qthttpserver/src/3rdparty/http-parser/
  (cd src/qthttpserver && qmake && make -j"$JOBS" && make install)
  touch "$WORK/.qthttpserver-built"
fi

echo "== QZ for arm64-v8a, release"
lrelease src/qdomyos-zwift.pri > /dev/null
qmake -spec android-clang 'ANDROID_ABIS=arm64-v8a' "ANDROID_NDK_ROOT=$NDK" 'CONFIG+=release' 'CONFIG+=bikemodo'
make qmake_all > /dev/null
make -j"$JOBS" -C src -f Makefile.qdomyos-zwift arm64-v8a-all
# one ABI at a time: two at once break qdomyos-zwift_metatypes.json (see bikemodo_android_build.sh)
for abi in armeabi-v7a x86 x86_64; do
  make -j"$JOBS" -C src -f Makefile.qdomyos-zwift "$abi-all"
done
make -j"$JOBS"
rm -rf "$WORK/output/android"
make INSTALL_ROOT="$WORK/output/android" install > /dev/null

STRIP=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip
find "$WORK/output/android" -name '*.so' -exec "$STRIP" --strip-debug {} \; 2>/dev/null || true

echo "== bundle"
cd src
mkdir -p "$WORK/output/android"
rsync -a --exclude build --exclude .gradle android/ "$WORK/output/android/"
androiddeployqt --input android-qdomyos-zwift-deployment-settings.json --output "$WORK/output/android/" \
  --android-platform android-37.0 --gradle --aux-mode --release > /dev/null
export GRADLE_USER_HOME=$TOOLS/gradle-home
find "$WORK/output/android" \( -name '*.properties' -o -name '*.gradle' -o -name '*.gradle.kts' \) \
  -exec sed -i '/android\.bundle\.enableUncompressedNativeLibs/d' {} +
printf '\nqt5AndroidDir=%s/src/android/java\n' "$QT_DIR" >> "$WORK/output/android/gradle.properties"
VERSION_ARGS=()
[ -n "${BIKEMODO_VERSION_CODE:-}" ] && VERSION_ARGS+=("-PbikemodoVersionCode=$BIKEMODO_VERSION_CODE")
[ -n "${BIKEMODO_VERSION_NAME:-}" ] && VERSION_ARGS+=("-PbikemodoVersionName=$BIKEMODO_VERSION_NAME")
"$TOOLS/gradle-9.3.1/bin/gradle" -g "$GRADLE_USER_HOME" -q -p "$WORK/output/android" "${VERSION_ARGS[@]}" bundleRelease

echo "== checks"
AAB=$WORK/output/android/build/outputs/bundle/release/android-release.aab
MERGED=$(find "$WORK/output/android/build/intermediates" -path '*merged_manifest*' -path '*release*' -name AndroidManifest.xml | head -n 1)
if [ -z "$MERGED" ]; then
  echo "no merged release manifest found" >&2
  exit 1
fi
FAILED=0
grep -q "package=\"$APP_ID\"" "$MERGED" || { echo "app ID is not $APP_ID"; FAILED=1; }
for piece in ShellService ScreenCaptureService FloatingWindowGFG mlkit.vision.DEPENDENCIES \
  SYSTEM_ALERT_WINDOW PACKAGE_USAGE_STATS GET_TASKS FOREGROUND_SERVICE_MEDIA_PROJECTION; do
  if grep -q "$piece" "$MERGED"; then
    echo "still in the release manifest: $piece"
    FAILED=1
  fi
done
grep -q 'dataExtractionRules' "$MERGED" || { echo "backup rules missing"; FAILED=1; }
if grep -q 'android:debuggable="true"' "$MERGED"; then
  echo "the release is debuggable"
  FAILED=1
fi
python3 "$REPO/tools/bikemodo_check_16kb.py" "$AAB" || FAILED=1
if [ "$FAILED" != 0 ]; then
  echo "release checks failed (manifest: $MERGED)" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT_AAB")"
if [ -n "${BIKEMODO_UPLOAD_KEYSTORE:-}" ]; then
  echo "== signing with the upload key"
  jarsigner -keystore "$BIKEMODO_UPLOAD_KEYSTORE" -storepass:env BIKEMODO_UPLOAD_STORE_PASS \
    -keypass:env BIKEMODO_UPLOAD_KEY_PASS -sigalg SHA256withRSA -digestalg SHA-256 \
    -signedjar "$OUT_AAB" "$AAB" "$BIKEMODO_UPLOAD_ALIAS"
  jarsigner -verify "$OUT_AAB" > /dev/null
  echo "== done in $(( $(date +%s) - START )) s: $OUT_AAB, signed ($(du -h "$OUT_AAB" | cut -f1))"
else
  cp "$AAB" "$OUT_AAB"
  echo "== done in $(( $(date +%s) - START )) s: $OUT_AAB, NOT signed (no BIKEMODO_UPLOAD_KEYSTORE) ($(du -h "$OUT_AAB" | cut -f1))"
fi
