#!/bin/bash
# Builds the Bikemodo APK from this working copy (uncommitted changes included) for arm64 phones
# and tablets, inside WSL, with the toolchain from bikemodo_android_setup.sh. Run as root:
#   wsl -d Ubuntu-22.04 -u root -- bash /mnt/d/Creations/Applications/qz/tools/bikemodo_android_build.sh [out.apk]
# The sources are copied to /root/bikemodo-build so the build runs on the Linux disk; only
# files that changed are copied again, so ccache and make redo only what changed.
set -euo pipefail

TOOLS=/opt/bikemodo
QT_DIR=$TOOLS/qt/5.15.0/android
SDK=$TOOLS/sdk
NDK=$SDK/ndk-bundle
REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=/root/bikemodo-build
OUT_APK=${1:-$WORK/bikemodo-debug.apk}
JOBS=${JOBS:-6}

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

# the same placeholders CI writes when it has no secrets
if [ ! -f src/secret.h ]; then
  printf '#define STRAVA_SECRET_KEY\n#define PELOTON_SECRET_KEY\n#define SMTP_USERNAME\n#define SMTP_PASSWORD\n#define SMTP_SERVER\n#define INTERVALSICU_CLIENT_ID\n#define INTERVALSICU_CLIENT_SECRET\n' > src/secret.h
fi
# never QZ's supporter-licence check: it sends the rider's e-mail address to QZ's server
sed -i '/define LICENSE/d' src/secret.h

echo "== qthttpserver (first build only)"
if [ ! -f "$WORK/.qthttpserver-built" ]; then
  cp qHttpServerBin/5.15.2/headers/* src/qthttpserver/src/3rdparty/http-parser/
  (cd src/qthttpserver && qmake && make -j"$JOBS" && make install)
  touch "$WORK/.qthttpserver-built"
fi

echo "== QZ for arm64-v8a"
lrelease src/qdomyos-zwift.pri > /dev/null
qmake -spec android-clang 'ANDROID_ABIS=arm64-v8a' "ANDROID_NDK_ROOT=$NDK" 'CONFIG+=debug' 'CONFIG+=bikemodo'
make qmake_all > /dev/null
make -j"$JOBS" -C src -f Makefile.qdomyos-zwift arm64-v8a-all
make -j"$JOBS"
rm -rf "$WORK/output/android"
make INSTALL_ROOT="$WORK/output/android" install > /dev/null

# debug symbols make the libraries several times larger; a stripped APK installs much faste
STRIP=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip
find "$WORK/output/android" -name '*.so' -exec "$STRIP" --strip-debug {} \; 2>/dev/null || true

echo "== APK"
cd src
mkdir -p "$WORK/output/android"
rsync -a --exclude build --exclude .gradle android/ "$WORK/output/android/"
androiddeployqt --input android-qdomyos-zwift-deployment-settings.json --output "$WORK/output/android/" \
  --android-platform android-37.0 --gradle --aux-mode > /dev/null
export GRADLE_USER_HOME=$TOOLS/gradle-home
find "$WORK/output/android" \( -name '*.properties' -o -name '*.gradle' -o -name '*.gradle.kts' \) \
  -exec sed -i '/android\.bundle\.enableUncompressedNativeLibs/d' {} +
printf '\nqt5AndroidDir=%s/src/android/java\n' "$QT_DIR" >> "$WORK/output/android/gradle.properties"
"$TOOLS/gradle-9.3.1/bin/gradle" -g "$GRADLE_USER_HOME" -q -p "$WORK/output/android" assembleDebug

APK=$WORK/output/android/build/outputs/apk/debug/android-debug.apk
APKSIGNER=$(find "$SDK/build-tools" -name apksigner | sort | tail -n 1)
"$APKSIGNER" sign --ks "$TOOLS/debug.keystore" --ks-key-alias bikemodo --ks-pass pass:android \
  --key-pass pass:android --v4-signing-enabled false --out "$APK.signed" "$APK"
mkdir -p "$(dirname "$OUT_APK")"
mv "$APK.signed" "$OUT_APK"
echo "== done in $(( $(date +%s) - START )) s: $OUT_APK ($(du -h "$OUT_APK" | cut -f1))"
CCACHE_DIR=$TOOLS/ccache ccache --show-stats | grep -i "hit\|miss" | head -n 3 || true
