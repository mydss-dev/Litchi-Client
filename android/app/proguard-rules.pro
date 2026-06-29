# ── Flutter (handled by the engine's own rules, but be explicit) ──────────
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# ── mihomo native bridge ──────────────────────────────────────────────────
# `external fun native*` are bound by name (Java_com_litchi_client_AndroidMihomoEngine_*),
# and the native lib calls back into LitchiVpnService.protect(int) via JNI. Keep
# these classes and members so R8 never renames or strips the bridge.
-keep class com.litchi.client.AndroidMihomoEngine { *; }
-keep class com.litchi.client.LitchiVpnService { *; }
-keep class com.litchi.client.LitchiCoreService { *; }
-keepclasseswithmembernames class * { native <methods>; }

# ── Kotlin ────────────────────────────────────────────────────────────────
-keepattributes *Annotation*
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# ── OkHttp / network (used by Flutter's HTTP stack) ──────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
