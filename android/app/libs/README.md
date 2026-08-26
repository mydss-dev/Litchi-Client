# Android sing-box core

Gradle invokes `tool/build_libbox_android.ps1` or
`tool/build_libbox_android.sh` and places the reproducibly pinned
`libbox.aar` in this directory. The AAR contains the gomobile API and native
`libbox.so` libraries; it is intentionally not committed.
