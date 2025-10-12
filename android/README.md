# Android Epson ePOS2 SDK Integration

The Flutter build expects the Epson ePOS2 runtime libraries to be checked into the
Android module so the native method channel can compile and link. Because the SDK
is distributed under Epson's license, the actual binaries are **not** stored in
this repository. Download the "Epson ePOS SDK for Android" package from Epson's
developer portal and copy the following files into the indicated locations
(relative to the repository root):

```
android/app/libs/ePOS2.jar
android/app/src/main/jniLibs/arm64-v8a/libepos2.so
android/app/src/main/jniLibs/armeabi-v7a/libepos2.so
android/app/src/main/jniLibs/x86_64/libepos2.so
```

After placing the files, the Gradle module will pick up the dependency declared
in `android/app/build.gradle`:

```
dependencies {
    implementation files('libs/ePOS2.jar')
}
```

If you need to use a different Kotlin toolchain version than the default, add a
`kotlin.version` entry to `android/local.properties`. The build script falls
back to `1.8.22` when the property is missing.

To verify the binaries are in place you can run the helper script:

```
./tool/verify_epson_sdk.sh
```

which checks the expected files and prints guidance if any are missing.

## Building for 64-bit only devices

Modern Pixel hardware (including the Pixel 8 Pro) ships as 64-bit only and
refuses to install APKs that do not bundle `arm64-v8a` native libraries. The
`android/app/build.gradle` configuration limits builds to `armeabi-v7a` and
`arm64-v8a`, and the CI workflow pins `flutter build apk` to the matching target
platforms. If you invoke `flutter build apk` manually, make sure to pass the same
flag:

```
flutter build apk --target-platform android-arm,android-arm64
```

Without the flag Flutter may default to a 32-bit only build, which would prevent
installation on 64-bit only devices.
