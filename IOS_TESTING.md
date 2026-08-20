# Progression Lab iOS testing

Progression Lab now has an iOS test-build workflow in `.github/workflows/ios-test-build.yml`.

## Artifacts

Each successful run produces:

- `Progression-Lab-<version>-iOS-Simulator.app.zip` — an iOS Simulator app for Apple-silicon Macs.
- `Progression-Lab-<version>-unsigned.ipa` — an unsigned iPhone package intended for re-signing.
- `Progression-Lab-<version>-iOS-Project.zip` — the generated Xcode project.
- `Progression-Lab-<version>-iOS.sha256` — SHA-256 checksums for all three files.

## Simulator testing

1. Install Xcode on an Apple-silicon Mac.
2. Open an iPhone simulator.
3. Extract the simulator ZIP.
4. Install the app with:

```bash
xcrun simctl install booted Runner.app
xcrun simctl launch booted com.h4cks1lv3r.progressionlab
```

## Testing on a physical iPhone

Apple requires every iPhone app to be signed with a valid certificate and provisioning profile. The generated unsigned IPA cannot be installed directly.

To test on a physical device, use one of these paths:

- Open the generated iOS project in Xcode, select an Apple Development team, connect the iPhone, and run the app.
- Re-sign the unsigned IPA with an Apple Development certificate and matching provisioning profile.
- Configure App Store Connect signing and distribute a signed build through TestFlight.

The repository does not contain Apple signing certificates, provisioning profiles, or App Store Connect credentials.

## Current configuration

- Bundle identifier: `com.h4cks1lv3r.progressionlab`
- Display name: `Progression Lab`
- Minimum deployment target: iOS 13.0
- Branded app icon and launch artwork are generated from the Android launcher asset.
- Photo-library usage descriptions are included for workout-story images.
