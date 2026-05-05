# StillLight iPhone Runbook

This project is ready for a real iPhone workflow. The remaining machine-specific step is Apple code signing, which must be tied to the developer account on the Mac that installs the app.

## 1. Check Local Readiness

From the repo root:

```sh
scripts/check_ios_device.sh
```

The script prints:

- installed Xcode version
- physical iPhone/iPad detection
- `devicectl` device visibility
- available Apple Development signing identities
- unsigned iPhone SDK compile result

If it says no physical device was detected, connect the iPhone by USB, unlock it, and tap **Trust This Computer** on the phone.

## 2. Enable Signing in Xcode

1. Open `StillLight.xcodeproj`.
2. Go to **Xcode > Settings > Accounts** and add your Apple ID.
3. Select the **StillLight** target.
4. Open **Signing & Capabilities**.
5. Enable **Automatically manage signing**.
6. Select your personal or paid Apple Developer Team.
7. Keep the bundle identifier as `com.trevorcui.StillLight`, or change it if Xcode reports that the identifier is already taken.

For a free Apple ID, the app can still be installed on your own device, but the provisioning profile may expire sooner.

## 3. Run on iPhone from Xcode

1. Select your connected iPhone in the Xcode device menu.
2. Press **Run**.
3. On first install, iOS may ask you to trust the developer profile:
   **Settings > General > VPN & Device Management**.
4. Grant Camera and Photos permissions when StillLight opens.

## 4. Run from CLI

After signing is configured and the device is trusted:

```sh
scripts/run_on_iphone.sh
```

If multiple devices are connected, pass the device id shown by `scripts/check_ios_device.sh`:

```sh
scripts/run_on_iphone.sh YOUR_DEVICE_ID
```

If the install step says **Developer Mode is disabled**, enable it on the iPhone:

1. Open **Settings > Privacy & Security**.
2. Tap **Developer Mode**.
3. Turn it on and restart when iOS asks.
4. After the phone restarts, unlock it and confirm Developer Mode.
5. Run `scripts/run_on_iphone.sh` again.

The run script builds into `/tmp/StillLightBuild` so code signing avoids Desktop/iCloud extended attributes that can make `codesign` reject the app bundle.

If the install step reports `kAMDMobileImageMounterDeviceLocked` or says the
developer disk image could not be mounted, the build and signing usually
succeeded but iOS refused device services because the phone was locked. Keep the
iPhone unlocked on the Home Screen, then rerun the same command. The script
retries transient CoreDevice connection resets automatically.

## 5. Current MVP Smoke Test

On the phone:

1. Open StillLight.
2. Choose a film roll.
3. Take a photo.
4. Confirm the lower-left recent-frame thumbnail updates without an automatic
   result sheet.
5. Open Gallery and confirm the local photo record appears.
6. Swipe between Gallery detail pages and long-press briefly to compare the
   original if one was saved.
7. Switch to video mode, record a short clip, and confirm the saved status clears
   after a moment.
8. Open Import Lab, import multiple photos, develop all, and save/share the
   selected result.

## Known Local Blockers

The repo can compile without signing using:

```sh
scripts/build_unsigned.sh
```

Actual device installation requires:

- a connected and trusted iPhone
- an unlocked iPhone while Xcode mounts developer disk image services
- Developer Mode enabled on the iPhone
- an Apple Development signing identity from Xcode Accounts

The repo includes a prepared 1024px app icon in the asset catalog. It is kept non-critical for the current MVP build because this Mac's Xcode install reports no available iOS simulator runtime while compiling asset catalogs. Install an iOS runtime from **Xcode > Settings > Components** before enabling the asset catalog in the target Resources phase.
