# Android

Android uses sing-box through the generated `libbox.aar`. Kotlin owns the
foreground services and `VpnService`; libbox requests the TUN descriptor and
protects outbound sockets through `AndroidSingBoxPlatform`.

The pinned source version and commit live in `tool/core_versions.env`. Gradle
builds the AAR through `tool/build_libbox_android.ps1` on Windows or
`tool/build_libbox_android.sh` on Unix hosts.

iOS is intentionally outside the current migration scope.
