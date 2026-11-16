version "v0.0.1"
spectre_version "v0.0.17"

var {
    EXAMPLE_OUT="custom_titlebar"
    windows {
        EXAMPLE_OUT="custom_titlebar.exe"
    }
}

build dev {
    note "formant is a library and cannot be built standalone."
}

build example_titlebar {
    entry "./examples/custom_titlebar.sx"
    flags ["-alt", "-runtime:hosted", "-dynamic", "-o", "examples/$EXAMPLE_OUT", "-link-obj:$OUT/webview.o", "-link-obj:$OUT/windecor.o"]
}

dep "https://github.com/webview/webview.git" {
    windows {
        build_actions {
            "cmd /c ..\..\scripts\build_webview.bat $OUT"
        }
    }
    posix {
        build_actions {
            "sh ../../scripts/build_webview.sh $OUT"
        }
    }
}
