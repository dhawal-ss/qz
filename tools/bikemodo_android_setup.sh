#!/bin/bash
# One-time setup of a local Android build for Bikemodo, inside WSL (Ubuntu 22.04), the same
# toolchain as .github/workflows/android.yml: Qt 5.15.0 for Android with QZ's 16K-page overlay,
# NDK 21.1, the Android 37 SDK, Gradle 9.3.1 and ccache. Run as root:
#   wsl -d Ubuntu-22.04 -u root -- bash /mnt/d/Creations/Applications/qz/tools/bikemodo_android_setup.sh
# Everything lands in /opt/bikemodo; running it again skips what is already there.
set -euo pipefail

TOOLS=/opt/bikemodo
QT_DIR=$TOOLS/qt/5.15.0/android
SDK=$TOOLS/sdk
NDK=$SDK/ndk/21.1.6352462
REPO=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$TOOLS"

echo "== packages"
apt-get update -y
apt-get install -y openjdk-17-jdk-headless build-essential ccache python3-pip unzip zip rsync curl git qttools5-dev-tools

echo "== Qt 5.15.0 for Android"
if [ ! -x "$QT_DIR/bin/qmake" ]; then
  pip3 install --quiet aqtinstall
  python3 -m aqt install-qt linux android 5.15.0 android -m qtcharts qtnetworkauth qtpurchasing -O "$TOOLS/qt-aqt"
  mkdir -p "$TOOLS/qt"
  mv "$TOOLS/qt-aqt/5.15.0" "$TOOLS/qt/5.15.0"
  rm -rf "$TOOLS/qt-aqt"
  # the 16K-page-aligned target libraries over the stock install, keeping the Linux host tools
  curl -fsSL -o /tmp/qt-page16.zip https://github.com/cagnulein/qt-5.15.0-android-page16k/releases/download/1.0.1/qt5.15.0-android-page16-1.0.1.zip
  rm -rf /tmp/qt-page16k && unzip -q /tmp/qt-page16.zip -d /tmp/qt-page16k
  rsync -a --exclude='bin/' /tmp/qt-page16k/qt5.15.0-android-page16/usr/local/Qt-5.15.0/ "$QT_DIR/"
  sed -i 's/darwin-x86_64/linux-x86_64/' "$QT_DIR/mkspecs/qdevice.pri"
  rm -rf /tmp/qt-page16.zip /tmp/qt-page16k
  cp "$REPO"/qt-patches/android/5.15.0/jar/*.* "$QT_DIR/jar/"
fi

echo "== Android SDK and NDK"
if [ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
  mkdir -p "$SDK/cmdline-tools"
  curl -fsSL -o /tmp/cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  rm -rf /tmp/cmdline-tools && unzip -q /tmp/cmdline-tools.zip -d /tmp
  mv /tmp/cmdline-tools "$SDK/cmdline-tools/latest"
  rm -f /tmp/cmdline-tools.zip
fi
yes | "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" --licenses > /dev/null || true
"$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" "ndk;21.1.6352462" "platforms;android-37.0" "build-tools;36.0.0" "platform-tools" --channel=3
if [ -d "$SDK/platforms/android-37.0" ] && [ ! -e "$SDK/platforms/android-37" ]; then
  ln -s android-37.0 "$SDK/platforms/android-37"
fi
ln -sfn "$NDK" "$SDK/ndk-bundle"

echo "== ccache around the NDK compilers"
NDK_BIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin
if [ ! -f "$NDK_BIN/clang.real" ]; then
  mv "$NDK_BIN/clang" "$NDK_BIN/clang.real"
  mv "$NDK_BIN/clang++" "$NDK_BIN/clang++.real"
fi
printf '#!/bin/bash\nexec /usr/bin/ccache %s/clang.real "$@"\n' "$NDK_BIN" > "$NDK_BIN/clang"
printf '#!/bin/bash\nexec /usr/bin/ccache %s/clang++.real "$@"\n' "$NDK_BIN" > "$NDK_BIN/clang++"
chmod +x "$NDK_BIN/clang" "$NDK_BIN/clang++"
CCACHE_DIR=$TOOLS/ccache ccache --set-config=max_size=4G
CCACHE_DIR=$TOOLS/ccache ccache --set-config=sloppiness=pch_defines,time_macros,include_file_mtime,file_macro

echo "== Gradle 9.3.1"
if [ ! -x "$TOOLS/gradle-9.3.1/bin/gradle" ]; then
  curl -fsSL -o /tmp/gradle.zip https://services.gradle.org/distributions/gradle-9.3.1-bin.zip
  unzip -q /tmp/gradle.zip -d "$TOOLS"
  rm -f /tmp/gradle.zip
fi

echo "== local debug key (each local build installs over the last one)"
if [ ! -f "$TOOLS/debug.keystore" ]; then
  keytool -genkeypair -keystore "$TOOLS/debug.keystore" -storepass android -keypass android \
    -alias bikemodo -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Bikemodo Local Debug" -noprompt
fi

echo "Setup done. Build with: bash $REPO/tools/bikemodo_android_build.sh"
