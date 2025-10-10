# LeSon POS

This project contains a Flutter-based POS application. The printing pipeline now
supports Epson ePOS2 direct printing for TM-m30II-NT devices while keeping the
existing Android system print dialog as a fallback.

## Epson ePOS2 Direct Printing Setup

1. **Drop Epson SDK AARs**
   - Place the required Epson ePOS2 AAR files inside `android/app/libs/`.
   - Example: `android/app/libs/ePOS2-9.2.0.0.aar`.

2. **Gradle configuration**
   - `android/app/build.gradle` already looks for any `.aar` or `.jar` dropped in
     `android/app/libs/` via:
     ```gradle
     dependencies {
         implementation fileTree(include: ['*.jar', '*.aar'], dir: 'libs')
     }
     ```
   - Simply copy the Epson ePOS2 AAR (for example `ePOS2-9.2.0.0.aar`) into that
     folder. Without the SDK present, the Android build still succeeds by using
     lightweight stubs, but direct printing will effectively be disabled until
     the real library is provided.

3. **Android Manifest**
   - Add the Epson networking permission to `android/app/src/main/AndroidManifest.xml`:
     ```xml
     <uses-permission android:name="android.permission.INTERNET" />
     ```

4. **Printer configuration**
   - Update `assets/config/printer.json` with the correct target IP/hostname and
     printer series/language:
     ```json
     {
       "target": "TCP:192.168.1.50",
       "timeout": 10000,
       "model": "TM_M30",
       "lang": "MODEL_ANK"
     }
     ```

5. **Enable direct printing**
   - Pass the feature flag when running on Android:
     ```bash
     flutter run --dart-define=DIRECT_EPOS=true
     ```
   - Without the flag (or on non-Android platforms) the app continues to use the
     existing Android print dialog.

## Troubleshooting

- **Printer offline/timeout** – Verify the IP address in `printer.json` and that
  the device is reachable on the network.
- **Cover open** – Close the printer cover and retry.
- **Paper end / near end** – Refill paper before retrying.
- **Recovery error** – Power cycle the printer and ensure it is online before
  reattempting the print.

Use the debug-only "Test Direct Print (EPOS)" button on the start order screen
to send a minimal receipt to the configured printer and validate connectivity.
