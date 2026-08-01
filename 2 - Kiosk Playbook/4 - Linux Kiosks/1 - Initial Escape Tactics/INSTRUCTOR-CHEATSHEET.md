# Linux Kiosk Instructor Cheatsheet

## Start the Kiosk

Plug in the device and turn it on. No setup is needed.

## What Reboot Should Do

1. GDM automatically logs in as `kiosk`.
2. GNOME autostart runs `~/Public/start-kiosk.sh`.
3. The kiosk app opens full screen after about five seconds.

If the kiosk does not appear, wait briefly, then use the recovery steps below.

For Firefox 147 or newer, manually verify that `Ctrl+W`, `Ctrl+Shift+W`, and `Ctrl+Q` do nothing. Then confirm that available controls or links can still open and use multiple tabs and popup windows, and that the kiosk Email link still launches the configured Thunderbird application. On devices configured with `--touchscreen`, press and hold a folder in Nautilus and confirm that **Open → Open in Console** launches GNOME Console.

## Reset Between Students

If the kiosk is broken, changed, or does not start correctly:

1. Press `Ctrl+Alt+Shift+O`.
2. Run:

```bash
kiosk reset --reboot
```

The reset restores the original kiosk files and autostart configuration, reapplies GDM automatic login and lockdown, and reboots. After reboot, GDM should automatically log in and launch the kiosk app.

Run only one reset at a time on each device. If the recovery shortcut does not work, contact the technical lead rather than changing system files.

## Update the Kiosk Page

To install an updated local kiosk page from GitHub, open the recovery terminal and change to the cloned repository's `2 - Kiosk Playbook/4 - Linux Kiosks/1 - Initial Escape Tactics` directory. Then run:

```bash
git pull
./prepare-kiosk.sh reset --reboot
```

`kiosk reset --reboot` by itself uses the already-installed page. Running the updated repository script installs the saved app's new HTML before rebooting. URL apps always load their remote content directly.

## Choose the Kiosk App

Omit `--app` to use `airline_kiosk.html`, or select the alternate local app during first-time setup:

```bash
./prepare-kiosk.sh --reboot --app airport-coffee-kiosk_touchscreen.html
```

An `http://` or `https://` URL is also accepted, but a local file is preferred when the workshop must remain usable without network access. The selected app is saved per device and reused by `kiosk reset`.

## Enable Touchscreen Console Access

During first-time setup, add `--touchscreen` to install GNOME Console for Nautilus's **Open → Open in Console** touch path. To enable and save it on an existing device, run from the updated repository:

```bash
./prepare-kiosk.sh reset --touchscreen --reboot
```

## Switch App or Browser

`kiosk reset` always reuses the app and browser saved during first-time setup. To redeploy with a different app or browser, remove the saved kiosk configuration and run first-time setup with the new choices. Install the new browser first if it is not already present.

```bash
kiosk remove
./prepare-kiosk.sh --app airport-coffee-kiosk_touchscreen.html --browser chrome --user kiosk --reboot
```

`kiosk remove` clears the saved configuration and the managed autostart entry. GDM autologin and GNOME lockdown remain until the next setup overwrites them.

## Optional: Hide Activities and Settings

The `--disable-gnome-clickable` flag is **optional and not part of the standard workshop kiosk setup.** It is off by default while the approach is validated. The standard lockdown already disables the Activities keyboard shortcut and hot corner; this flag additionally hides the clickable Activities button and the Settings gear in Quick Settings, which only matters if a participant reaches the desktop.

If you choose to enable it on a device, pass it during first-time setup. It installs and enables the `user-theme` GNOME Shell extension, a small user theme, and a managed desktop-entry mask for GNOME Settings. It does not uninstall `gnome-control-center`. The changes take effect on the next login. `kiosk reset` reuses whatever state was saved at setup.

```bash
./prepare-kiosk.sh --level 2 --browser firefox --user kiosk --disable-gnome-clickable --reboot
```

To toggle it on an already-configured device without a full re-setup, pass either flag to `kiosk reset`. The new state is persisted and applied on reboot:

```bash
kiosk reset --disable-gnome-clickable --reboot      # hide Activities and Settings gear
kiosk reset --no-disable-gnome-clickable --reboot   # restore both controls
```

## Workshop Links

- [Linux kiosk playbook](../README.md)
- [Initial protocol-handler escape](Protocol-Handler-Escape/README.md)
- [Next steps: persistence and enumeration](<../2 - Next Steps/README.md>)
- [Internal discovery and recon](<../3 - Internal Discovery and Recon/README.md>)
- [Post-exploitation](<../4 - Post-Exploitation - Moving from Kiosk to Domain and-or Network/README.md>)
- [Defensive recommendations](<../../../5 - Defensive Recommendations/README.md>)
