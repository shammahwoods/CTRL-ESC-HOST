This directory contains the Linux kiosk setup and the initial escape workshop resources.

## Resources

- `prepare-kiosk.sh`: GNOME kiosk installer, workshop reset utility, and app/browser-switch helper.
- `airline_kiosk.html`: SkyLine Premium full-screen kiosk demo.
- `airport-coffee-kiosk_touchscreen.html`: Alternate full-screen kiosk demo.
- `INSTRUCTOR-CHEATSHEET.md`: Deployment, validation, recovery, and between-student reset commands.
- `Protocol-Handler-Escape/`: Protocol-handler breakout walkthrough.

## First-Time Setup

Run the installer as the desktop user that will become the kiosk account. The account must be an Ubuntu administrator authorized to use `sudo`; keep its password available to instructors and do not disclose it to participants. Do not make the account UID 0 or run the entire script with `sudo`. The script requests elevated access only for packages, GDM, `/usr/local` installation, and the root-protected reset state under `/var/lib`. Run repository-based setup or update only from an administrator-reviewed checkout because approval installs that script and HTML into root-owned locations.

On a fresh Ubuntu installation, the simplest arrangement is to create `kiosk` as the initial administrator account. To authorize an existing account, run the following from another administrator account, then sign out and back in:

```bash
sudo usermod -aG sudo kiosk
sudo passwd kiosk
```

Confirm authorization before setup:

```bash
sudo -v
```

Firefox deployments require Firefox 147 or newer. Launch the selected system Firefox once and close it before setup so Firefox creates its default profile metadata; the installer will not create or guess a profile.

```bash
chmod +x prepare-kiosk.sh
./prepare-kiosk.sh --level 2
```

Defaults:

- Browser: Firefox
- App: `airline_kiosk.html`
- Lockdown: Level 2
- Autologin account: Current user
- Reboot: Ask after successful setup when stdin is an interactive terminal; otherwise skip reboot
- Touchscreen Nautilus console path: Disabled (see `--touchscreen`)
- Activities button and Quick Settings gear: Not hidden (see `--disable-gnome-clickable`)
- Screen blanking, automatic suspend, and lock screen: Disabled

For unattended deployment to the three workshop devices:

```bash
./prepare-kiosk.sh --level 2 --browser firefox --user kiosk --reboot
```

Use `--no-reboot` to finish configuration without rebooting. Google Chrome must already be installed if selected; Firefox and Chromium are installed through `apt-get` when missing.

### Select the Kiosk App

Use `--app` to give different devices different kiosk experiences while keeping every other default:

```bash
./prepare-kiosk.sh --reboot --app airport-coffee-kiosk_touchscreen.html
```

A local app must be a `.html` filename beside `prepare-kiosk.sh`. The installer copies it into the root-owned runtime assets and `~/Public`, then saves the selection for future `kiosk reset` runs. The default remains `airline_kiosk.html` when `--app` is omitted.

An HTTP or HTTPS URL is also accepted and is launched directly:

```bash
./prepare-kiosk.sh --reboot --app https://kiosk.example.test/app
```

Prefer a local file for workshop devices when offline reliability and fixed content matter. A URL makes startup dependent on the network, DNS, TLS, and the continued availability of the remote content. Quote URLs that contain shell metacharacters such as `&`.

### Enable the Touchscreen Terminal Path

Use `--touchscreen` to install GNOME Console and enable Nautilus 50's touch-accessible terminal path:

```bash
./prepare-kiosk.sh --app airport-coffee-kiosk_touchscreen.html --touchscreen --reboot
```

The option is off by default and saved per device. To enable it on an already configured device, run the updated repository script:

```bash
./prepare-kiosk.sh reset --touchscreen --reboot
```

Future `kiosk reset` commands reuse the saved touchscreen mode.

To also hide the clickable Activities button and the GNOME Settings gear in Quick Settings (useful if a participant reaches the desktop), pass `--disable-gnome-clickable`:

```bash
./prepare-kiosk.sh --level 2 --browser firefox --user kiosk --disable-gnome-clickable --reboot
```

The flag is optional and off by default while the approach is validated across the workshop images. When set, the installer installs and enables the `user-theme` GNOME Shell extension (`gnome-shell-extension-user-theme`) and drops a small user theme under `~/.themes/ctrl-esc-host-kiosk/gnome-shell/gnome-shell.css` that hides the `#panelActivities` button. It also creates a managed user-level `org.gnome.Settings.desktop` override with `Hidden=true`; GNOME Shell then omits the Settings gear and Settings application-search entry. This does not uninstall or prevent direct execution of `gnome-control-center`. A running GNOME Shell may not discover a newly installed system extension immediately, so the installer records its enabled state for the next session instead of requiring live discovery. The changes take effect on the next GNOME Shell restart or login.

`kiosk reset` reuses the saved `--disable-gnome-clickable` state. To toggle it on an already-configured device without a full re-setup, pass either flag to `kiosk reset`; the new state is persisted and applied:

```bash
kiosk reset --disable-gnome-clickable --reboot      # hide Activities and Settings gear
kiosk reset --no-disable-gnome-clickable --reboot  # restore both controls
```

Firefox is resolved from the system `PATH`. On current Ubuntu Desktop installations this normally selects `/snap/bin/firefox`; the installer no longer silently prefers a separate Firefox under `~/.local/opt`. It resolves Firefox's declared default profile, atomically merges only the close-tab, close-window, and quit overrides into that profile's `customKeys.json`, and launches the kiosk with that same profile. Refresh the Firefox Snap before workshop deployment and validate the shortcut and email-link workflows on each image.

## Lockdown Levels

### Level 1

```bash
./prepare-kiosk.sh --level 1
```

Level 1 disables the ordinary Activities and Super-key paths provided by core GNOME schemas:

- Standalone Super key
- GNOME Activities Overview and application view shortcuts
- GNOME hot corners
- Super-based application, window, workspace, and media-key bindings in core GNOME schemas

GNOME Shell extensions can define shortcuts in their own schemas. The script does not disable extension-specific bindings such as Ubuntu Dock or third-party tiling-extension shortcuts; verify or configure those separately on the workshop image.

### Level 2

```bash
./prepare-kiosk.sh --level 2
```

Level 2 includes Level 1 and blocks common kiosk escape navigation:

- `Alt+F2`, `Alt+F4`, `Alt+Tab`, reverse window switching, and window cycling
- Standard terminal, logout, show-desktop, window movement, and workspace shortcuts
- `Ctrl+W`, `Ctrl+Shift+W`, `Ctrl+T`, `Ctrl+Shift+T`, `Ctrl+N`, and `Ctrl+Shift+N`
- `Ctrl+L`, `F11`, `F12`, and common Chromium developer-tools shortcuts

By default the script uses normal GNOME `gsettings` and custom media-key bindings and does not install a GNOME Shell extension or modify the top bar; the browser's full-screen kiosk mode covers the desktop UI. The optional `--disable-gnome-clickable` flag is the one exception: it enables the `user-theme` extension, installs a minimal user theme to hide the clickable Activities button, and masks the Settings desktop entry so GNOME Shell omits its Quick Settings gear.

The Firefox profile shortcut overrides apply at either lockdown level when Firefox is selected. Existing unrelated `customKeys.json` entries are preserved.

The installer refreshes APT metadata when dependencies are missing and installs Thunderbird, `curl`, and GNOME Terminal when absent. With `--touchscreen`, it also installs GNOME Console. It selects an installed Thunderbird desktop entry as the OS `mailto:` handler and checks that association with `xdg-mime`. A post-set query mismatch produces a note instead of aborting kiosk deployment. The selected browser still decides whether to delegate a `mailto:` link to the OS, so verify the email-link workflow in the deployed browser profile.

Ubuntu Resolute does not provide the retired `mousetweaks` package. Nautilus 50 handles touch context menus natively on file and folder items. On a device configured with `--touchscreen`, press and hold a folder, select **Open**, then select **Open in Console**. Nautilus requires the `gnome-console` package for that action, so touchscreen mode ensures it is present. Blank whitespace does not provide the same native long-press gesture.

## Instructor Recovery

Both levels reserve this instructor shortcut:

```text
Ctrl+Alt+Shift+O
```

It opens `gnome-terminal`. From that terminal, restore the workshop kiosk with:

```bash
kiosk reset
```

The installer also adds `alias kiosk='/usr/local/bin/kiosk'` to `~/.bashrc`. New Bash terminals load it automatically. In a terminal that was already open during setup, run `source ~/.bashrc`; the global `/usr/local/bin/kiosk` command remains available even without the alias. A bash-completion file installed at `/usr/share/bash-completion/completions/kiosk` provides tab completion for the `setup`, `reset`, and `remove` actions and their options; it loads automatically in new Bash terminals on systems with bash-completion installed.

The shortcut is an operational recovery path, not a security boundary. A participant who obtains a shell can inspect GNOME settings or the setup source.

## Autostart Backup and Reset

The first setup captures `~/.config/autostart` before adding the kiosk launcher. The authoritative workshop baseline and saved setup configuration are protected by a root-owned mode `0700` state directory so a participant shell cannot replace them:

```text
/var/lib/ctrl-esc-host-kiosk/users/<uid>/autostart.original
```

`kiosk reset` performs the following actions:

1. Removes the current participant-modified `~/.config/autostart` directory.
2. Restores the exact first-run baseline.
3. Adds the managed `skyline-kiosk.desktop` entry back on top of the baseline.
4. Refreshes the installed local app, when selected, and the browser wrapper.
5. Reapplies GDM autologin, disables idle blanking/suspend/locking, and restores the saved lockdown level and instructor shortcut.
6. Asks whether to reboot when run from an interactive terminal. Without an interactive terminal it skips reboot unless `--reboot` is supplied.

Use either reboot mode when scripting a reset:

```bash
kiosk reset --reboot
kiosk reset --no-reboot
```

`kiosk reset` validates sudo authorization before making changes. Unless a sudo credential is already cached, the instructor enters the `kiosk` account password and then chooses whether to reboot. Run only one reset at a time on each device; separate devices can be reset simultaneously.

Use `kiosk reset` when the instructor should be asked before rebooting. Use `kiosk reset --reboot` only when an immediate reboot after a successful reset is intended.

Reset first builds a complete replacement in a sibling staging directory. It only swaps that directory into place after the baseline and managed launcher have been prepared successfully. The baseline is never replaced by reset. Therefore the resulting autostart directory is the original pre-kiosk content plus the managed `skyline-kiosk.desktop` required to start the kiosk after login.

## Switching Apps or Browsers

`kiosk reset` always reuses the app and browser saved during first-time setup. To redeploy with a different app or browser, use `kiosk remove` to clear the saved configuration and the managed autostart entry, then run first-time setup with the new selection:

```bash
kiosk remove
./prepare-kiosk.sh --app airport-coffee-kiosk_touchscreen.html --browser chrome --user kiosk --reboot
```

`kiosk remove` accepts no options and does not reboot. It removes only the saved configuration at `/var/lib/ctrl-esc-host-kiosk/users/<uid>/config`, the managed `skyline-kiosk.desktop` autostart entry, and the bash-completion file at `/usr/share/bash-completion/completions/kiosk`. GDM autologin and GNOME lockdown remain in place until the next setup overwrites them. Install the new browser first if it is not already present; the installer installs Firefox and Chromium through `apt-get` but requires Google Chrome to be pre-installed. Previously copied local app files are not launched after a different app is selected.

## Installed Files

First-time setup installs:

```text
/usr/local/bin/kiosk
/usr/local/libexec/ctrl-esc-host-kiosk/prepare-kiosk.sh
/usr/local/share/ctrl-esc-host-kiosk/<selected-local-app>.html
/usr/share/bash-completion/completions/kiosk
~/Public/<selected-local-app>.html
~/Public/start-kiosk.sh
~/.config/autostart/skyline-kiosk.desktop
```

The two HTML paths are present for local app selections; URL selections are written directly into `~/Public/start-kiosk.sh`. The installed `kiosk` command does not depend on the repository remaining on the device.

## Automatic Login

The installer supports both common GDM configuration paths:

```text
/etc/gdm3/custom.conf
/etc/gdm/custom.conf
```

It first verifies that the active systemd display-manager service and Debian display-manager selection, when present, identify GDM. It then creates a one-time sibling backup ending in `.ctrl-esc-host-original`, preserves unrelated configuration, configures the selected user under `[daemon]`, and verifies the installed values.

## Scope

The lockdown targets common core GNOME and browser navigation used to escape a full-screen workshop kiosk. It does not manage GNOME Shell extension shortcuts or disable Linux virtual-terminal switching such as `Ctrl+Alt+F3`, firmware keys, or physical access recovery. The optional `--disable-gnome-clickable` flag hides the top-bar Activities button and Quick Settings gear; it does not remove other top-bar indicators, block the overview from other entry points, or prevent direct execution of `gnome-control-center` after shell access.
