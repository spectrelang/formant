#!/bin/sh
# Compile the webview C++ core into $OUT/webview.o.
#
# Invoked by sx.mod from inside lib/webview, with the project output directory
# as the first argument. Override the compiler with CXX=clang++ if needed.

set -eu

OUT="${1:-}"
if [ -z "$OUT" ]; then
    echo "build_webview.sh: missing output directory" >&2
    exit 1
fi

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(dirname -- "$HERE")
SRC="$ROOT/lib/webview/core/src/webview.cc"
INC="$ROOT/lib/webview/core/include"
WINDECOR="$ROOT/src/formant"

if [ ! -f "$SRC" ]; then
    echo "build_webview.sh: webview sources not found at $SRC" >&2
    echo "run 'spectre restore' to fetch dependencies" >&2
    exit 1
fi

if [ -n "${CXX:-}" ]; then
    CXX_BIN="$CXX"
elif command -v g++ >/dev/null 2>&1; then
    CXX_BIN=g++
elif command -v clang++ >/dev/null 2>&1; then
    CXX_BIN=clang++
else
    echo "build_webview.sh: no C++ compiler found (set CXX)" >&2
    exit 1
fi

mkdir -p "$OUT"

OS=$(uname -s 2>/dev/null || echo unknown)
case "$OS" in
    Darwin)
        "$CXX_BIN" -std=c++11 -O2 -fPIC -DWEBVIEW_STATIC \
            -I"$INC" -c "$SRC" -o "$OUT/webview.o"

        if command -v clang >/dev/null 2>&1; then
            OBJC_BIN=clang
        else
            OBJC_BIN=cc
        fi
        "$OBJC_BIN" -fobjc-arc -O2 -fPIC \
            -c "$WINDECOR/windecor_mac.m" -o "$OUT/windecor.o"
        ;;
    *)
        if ! command -v pkg-config >/dev/null 2>&1; then
            echo "build_webview.sh: pkg-config is required" >&2
            exit 1
        fi
        if pkg-config --exists webkit2gtk-4.1; then
            MODULES="gtk+-3.0 webkit2gtk-4.1"
        elif pkg-config --exists webkitgtk-6.0; then
            MODULES="gtk4 webkitgtk-6.0"
        else
            echo "build_webview.sh: install webkit2gtk-4.1 (or webkitgtk-6.0) development files" >&2
            exit 1
        fi
        CFLAGS=$(pkg-config --cflags $MODULES)
        # shellcheck disable=SC2086
        "$CXX_BIN" -std=c++11 -O2 -fPIC -DWEBVIEW_STATIC \
            -I"$INC" $CFLAGS -c "$SRC" -o "$OUT/webview.o"

        # shellcheck disable=SC2086
        "$CXX_BIN" -std=c++11 -O2 -fPIC $CFLAGS \
            -c "$WINDECOR/windecor_gtk.cc" -o "$OUT/windecor.o"
        ;;
esac

echo "built $OUT/webview.o"
echo "built $OUT/windecor.o"
