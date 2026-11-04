#!/bin/bash
# Bikemodo's tests: the ride library (C++, desktop Qt 5) and the logic of the screens (JS, Node).
#   bash tools/bikemodo_tests.sh
# Needs qmake for desktop Qt 5 (qtbase5-dev, qtpositioning5-dev, qtconnectivity5-dev) and node.
# The C++ test builds in a temporary folder, so the source tree stays clean.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${BIKEMODO_TEST_BUILD:-/tmp/bikemodo-tests}
QMAKE=${QMAKE:-qmake}

echo "== JS logic"
if ! command -v node >/dev/null; then
  echo "node is needed for the JS tests (BIKEMODO_SKIP_JS=1 skips them)" >&2
  [ "${BIKEMODO_SKIP_JS:-0}" = "1" ] || exit 1
else
  node "$REPO/tests/ui2/run.js"
fi

echo "== ride library"
mkdir -p "$BUILD"
cd "$BUILD"
"$QMAKE" "$REPO/tests/ridelibrary/ridelibrary_test.pro" >/dev/null
make -j"$(nproc)" >/dev/null
QT_QPA_PLATFORM=offscreen ./ridelibrary_test
