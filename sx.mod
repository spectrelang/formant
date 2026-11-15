version "v0.0.1"
spectre_version "v0.0.17"

build release {
    entry "./src/main.sx"
    flags ["-release", "-alt", "-runtime:hosted", "-dynamic", "-o", "formant", "-link-obj:$OUT/webview.o", "-link-obj:$OUT/windecor.o"]
}

build dev {
    entry "./src/main.sx"
    windows {
        flags ["-alt", "-runtime:hosted", "-dynamic", "-o", "formant-dev.exe", "-link-obj:$OUT/webview.o", "-link-obj:$OUT/windecor.o"]
    }
    posix {
        flags ["-alt", "-runtime:hosted", "-dynamic", "-o", "formant-dev", "-link-obj:$OUT/webview.o", "-link-obj:$OUT/windecor.o"]
    }
}

build example {
    entry "./examples/contact_form.sx"
    flags ["-alt", "-runtime:hosted", "-dynamic", "-o", "examples/contact_form", "-link-obj:$OUT/webview.o", "-link-obj:$OUT/windecor.o"]
}

build example_ft {
    entry "./examples/profile_form.sx"
    flags ["-alt", "-runtime:hosted", "-dynamic", "-o", "examples/profile_form", "-link-obj:$OUT/webview.o", "-link-obj:$OUT/windecor.o"]
}

build example_all {
    entry "./examples/component_gallery.sx"
    flags ["-alt", "-runtime:hosted", "-dynamic", "-o", "examples/component_gallery", "-link-obj:$OUT/webview.o", "-link-obj:$OUT/windecor.o"]
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
