# NeurX Mobile

`app/mobile` is a dedicated Qt Quick mobile client for Android and iOS.

## Included

- `CMakeLists.txt`: standalone mobile build target
- `main.cpp`: mobile entrypoint that reuses the existing bridge and models
- `qml/`: phone-oriented UI for agent chat and logs
- `android/`: Android manifest and resources
- `ios/`: iOS bundle metadata template
- `scripts/`: helper build scripts for Android and iOS

## Build

Android:

```bash
bash scripts/build_android.sh
```

iOS:

```bash
bash scripts/build_ios.sh
```

## Notes

- The mobile app reuses `app/bridge/*.cpp` and the existing backend/agent runtime.
- The current UI is intentionally smaller and touch-first rather than a direct copy of the desktop shell.
- Platform signing, store packaging, push notifications, and native camera/file integrations are not included yet.
