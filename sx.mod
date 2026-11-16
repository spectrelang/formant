version "v0.0.1"
spectre_version "v0.0.17"

build dev {
    info "formant is a library and cannot be built standalone."
}

build example_titlebar {
    entry "./examples/custom_titlebar.sx"
    windows {
        flags ["-alt", "-runtime:hosted", "-dynamic", "-o", "examples/custom_titlebar.exe", "-link-obj:$OUT/webview.o", "-link-obj:$OUT/windecor.o"]
    }
    posix {
        flags ["-alt", "-runtime:hosted", "-dynamic", "-o", "examples/custom_titlebar", "-link-obj:$OUT/webview.o", "-link-obj:$OUT/windecor.o"]
    }
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
