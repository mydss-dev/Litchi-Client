# Android Core

Android uses a source-built mihomo shared library rather than an AAR. Gradle
invokes `tool/build_mihomo_android.ps1` or `tool/build_mihomo_android.sh`,
then packages the generated libraries from `src/main/jniLibs`.

The Kotlin VPN service creates the TUN interface. A small JNI bridge passes its
file descriptor to mihomo and calls `VpnService.protect()` for every outbound
socket, following the integration model used by FlClash.
