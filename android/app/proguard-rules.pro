# ── Flutter (handled by the engine's own rules, but be explicit) ──────────
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# ── mihomo native bridge ──────────────────────────────────────────────────
# JNI methods called from Go via cgo must not be renamed or stripped.
-keep class com.litchi.client.MihomoBridge { *; }
-keep class com.litchi.client.LitchiCoreService { *; }

# ── Kotlin ────────────────────────────────────────────────────────────────
-keepattributes *Annotation*
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# ── OkHttp / network (used by Flutter's HTTP stack) ──────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
