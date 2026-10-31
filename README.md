# UFeel Watch

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](./LICENSE)

Wear OS app that streams your heart rate over Wi-Fi (UDP) to the [UFeel library](https://github.com/UFeel-dev/ufeel). Tested on Samsung Galaxy Watch 7.

The receiving side is documented in [UFeel heart rate](https://github.com/UFeel-dev/ufeel/blob/main/docs/heart-rate.md).

## Install

1. On the watch: Settings -> About watch -> Software -> tap **Software version** 7 times.
2. Settings -> Developer options -> enable **ADB debugging** and **Wireless debugging**.
3. Open this project in Android Studio.
4. Device Manager -> Physical -> **Pair using Wi-Fi** -> **Pair using pairing code**.
5. Select the watch and click ▶.

## Use

1. Connect the watch to the same Wi-Fi as your computer.
2. Tap **Start**, accept the permissions, and keep the watch enabled and on your wrist.
3. Tap **Stop** when done.

Only one workout can run at a time, so this conflicts with other workout apps.

## Configuration

Constants at the top of `HeartRateService.kt`:

| Constant | Default | Description |
| --- | --- | --- |
| `TARGET` | `255.255.255.255` | LAN broadcast. Use your computer's IP if your router blocks broadcast. |
| `PORT` | `9999` | UDP port. Must match UFeel. |

## License

Apache 2.0 License - see [LICENSE](LICENSE).
