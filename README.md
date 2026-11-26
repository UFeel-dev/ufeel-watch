# UFeel Watch

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](./LICENSE)

Watch apps that stream your heart rate over Wi-Fi (UDP) to the [UFeel library](https://github.com/UFeel-dev/ufeel):

- [Wear OS](#wear-os): tested on Samsung Galaxy Watch 7.
- [Apple Watch](#apple-watch), with its iPhone app, in [apple/](apple).

Both send the BPM as plain text (e.g. `72`) to UDP port `9999`. The receiving side is documented in [UFeel heart rate](https://github.com/UFeel-dev/ufeel/blob/main/docs/heart-rate.md).

## Wear OS

### Install

1. On the watch: Settings -> About watch -> Software -> tap **Software version** 7 times.
2. Settings -> Developer options -> enable **ADB debugging** and **Wireless debugging**.
3. Open this project in Android Studio.
4. Device Manager -> Physical -> **Pair using Wi-Fi** -> **Pair using pairing code**.
5. Select the watch and click ▶.

### Use

1. Connect the watch to the same Wi-Fi as your computer.
2. Tap **Start**, accept the permissions, and keep the watch enabled and on your wrist.
3. Tap **Stop** when done.

Only one workout can run at a time, so this conflicts with other workout apps.

### Configuration

Constants at the top of `HeartRateService.kt`:

| Constant | Default | Description |
| --- | --- | --- |
| `TARGET` | `255.255.255.255` | LAN broadcast. Use your computer's IP if your router blocks broadcast. |
| `PORT` | `9999` | UDP port. Must match UFeel. |

## Apple Watch

watchOS only lets apps send UDP packets while they stream audio, so the watch app sends each reading to its iPhone app, which sends it to UFeel. The iPhone sends it to your computer's IP address: broadcast needs an Apple entitlement on iOS.

Requirements: Apple Watch with watchOS 10 or later, paired with an iPhone with iOS 17 or later, and Xcode 16 or later.

### Install

1. Open `apple/UFeelHeartRate.xcodeproj` in Xcode.
2. In **Signing & Capabilities**, select your team for the `UFeelHeartRate` and `UFeelHeartRateWatch` targets. If the bundle identifiers are taken, change both: the watch one must start with the iPhone one, and `WKCompanionAppBundleIdentifier` in `apple/Watch/Info.plist` must match the iPhone one.
3. Enable **Developer Mode** on the iPhone: Settings -> Privacy & Security -> **Developer Mode**.
4. Pair the watch with Xcode, so that Xcode registers it for development. With Xcode 27 and watchOS 27: in Xcode, Window -> **Device Hub** -> **+** -> **Pair Nearby Device** -> **Apple Watch**. Then on the watch, Settings -> Privacy & Security -> **Developer Mode**, turn it on, tap **Pair with** your Mac, and enter the code Xcode shows. With earlier versions, the watch appears in Window -> **Devices and Simulators** through its iPhone. Keep the watch unlocked while Xcode prepares it.
5. Select the `UFeelHeartRate` scheme and your iPhone, and click ▶. Then select the `UFeelHeartRateWatch` scheme and your watch, and click ▶.

If the watch says "This app cannot be installed because its integrity could not be verified", Xcode has not registered the watch yet: pair it (step 4) and run both schemes again.

### Use

1. Find your computer's IP address (macOS: System Settings -> Wi-Fi -> **Details**; Linux: `hostname -I`).
2. Open **UFeel** on the iPhone, enter the IP address (port `9999`), and allow local network access.
3. Open **UFeel** on the watch, tap **Start**, and allow access to heart rate and workouts. The first reading usually takes a few seconds.
4. Tap **Stop** when done. The workout is not saved in Health.

Keep the iPhone near the watch and on the same Wi-Fi as your computer. Only one workout can run at a time, so this conflicts with other workout apps.

### Tests

```bash
xcodebuild test -project apple/UFeelHeartRate.xcodeproj -scheme UFeelHeartRate \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Any iPhone simulator works: change `name` to one listed by `xcrun simctl list devices`.

## License

Apache 2.0 License - see [LICENSE](LICENSE).
