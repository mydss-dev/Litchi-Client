# Android Core Libraries

Android cannot run the desktop `sing-box.exe` directly. It needs the same
sing-box core packaged as an Android library (`libbox.aar`).

## Official Source Build

Android builds use a libbox built from the official sing-box source. Before
`preBuild`, Gradle checks this folder for:

- `libbox.aar` for Android 6.0+ / API 23+
- `libbox-legacy.aar` if you later add a legacy API 21 flavor

If `libbox.aar` is missing, Gradle runs one of these scripts:

```powershell
tool\build_libbox_android.ps1
```

```bash
tool/build_libbox_android.sh
```

That script clones the official upstream repository:

```text
https://github.com/SagerNet/sing-box
```

and runs:

```bash
make lib_install
make lib_android
```

The upstream Makefile runs:

```bash
go run ./cmd/internal/build_libbox -target android
```

The generated `libbox.aar` is copied back into this folder. The current Gradle
config loads any `*.aar` in this folder.

## Expected API

The Kotlin adapter supports the gomobile command-server API:

- `Libbox.setup(options)`
- `Libbox.newCommandServer(handler, platformInterface)`
- `CommandServer.start()`
- `CommandServer.startOrReloadService(configContent, overrideOptions)`
- `CommandServer.closeService()`
- `CommandServer.close()`
- `Libbox.Version()`
