# SETUP — Full Deployment Test Instructions

> **Temporary section.** Operational verification of the Linux kiosk deployment after the last rounds of commits (`0a9c522`, `1d71186`, `1f8ad70`). There is no automated test suite in this repo; verification runs on a target Ubuntu/GNOME device.

## What changed recently

- `0a9c522` — rewrote `prepare-kiosk.sh` (setup + reset), restructured README
- `1d71186` — added `INSTRUCTOR-CHEATSHEET.md`
- `1f8ad70` — **hardening**: active GDM service verification, sudo-preflight, post-install GDM assertions
- Firefox shortcut overrides — resolves Firefox profile, atomically merges `customKeys.json` (`key_close`, `key_closeWindow`, `key_quitApplication`), launches kiosk with `--profile`, restarts Firefox on non-reboot paths
- `kiosk remove` — clears saved config + autostart entry for browser redeployment

## Test environment

A fresh Ubuntu Desktop (GNOME + GDM) VM or one of the 12 workshop devices. Do not test on a production machine — `prepare-kiosk.sh` reconfigures GDM, autostart, and gsettings.

This guide was validated on a VM snapshot with: user `kiosk`, GDM3 active, `/etc/gdm3/custom.conf` present, no prior kiosk config (fresh), sudo requiring the `kiosk` password.

## Stage 1 — Pre-flight (on a clean device, as `kiosk`)

Confirm the prerequisites the new hardening checks for. If any fail, the script will now `die` instead of silently misconfiguring:

```bash
id -un                       # -> kiosk
sudo -v                      # accepts instructor password (NEW: preflight now dies with a clear message)
sudo snap refresh firefox    # use the current Ubuntu Firefox Snap
command -v firefox           # normally /snap/bin/firefox on Ubuntu
firefox --version            # must be Firefox 147 or newer
systemctl is-active display-manager.service                       # -> active
systemctl show --property=FragmentPath --value display-manager.service  # -> *gdm*.service
cat /etc/X11/default-display-manager 2>/dev/null                  # -> gdm or gdm3
ls -l /etc/gdm3/custom.conf /etc/gdm/custom.conf 2>/dev/null      # one must exist
```

Launch Firefox once and close it before setup so its selected default profile and `profiles.ini` exist. The installer refuses to invent or guess a profile path.

Remove any stale reserved file:

```bash
rm -f ~/.config/autostart/skyline-kiosk.desktop
```

## Stage 2 — First-time setup (interactive, to validate the reboot prompt)

```bash
cd "2 - Kiosk Playbook/4 - Linux Kiosks/1 - Initial Escape Tactics"
chmod +x prepare-kiosk.sh
./prepare-kiosk.sh --user kiosk
```

Enter the `kiosk` password at the sudo prompt. Watch for `Configured GDM automatic login for 'kiosk'.` (the new `grep -Fxq` assertions die if the write failed). Answer `y` to reboot (this branch only runs when stdin is a TTY — worth confirming).

## Stage 3 — Booted-kiosk validation checklist

After reboot, fill in the cheatsheet table per device:

| Check | Expected |
|---|---|
| GDM auto-logs in as `kiosk` | yes |
| Kiosk opens full screen ~5s after login | yes |
| Screen remains on and unlocked while idle | yes |
| Super → Activities | blocked |
| `Alt+F2`, `Alt+F4`, `Alt+Tab` | blocked |
| `Ctrl+W`, `Ctrl+Shift+W`, `Ctrl+Q` in Firefox | no effect |
| `Ctrl+T/N/L`, `F11` at lockdown level 2 | blocked |
| Multiple tabs and popup windows opened through available controls or links | work normally |
| `Ctrl+Alt+Shift+O` | opens `gnome-terminal` |
| `/usr/local/bin/kiosk` | executable; `type -a kiosk` also shows the optional alias |
| generated `start-kiosk.sh` | uses the system Firefox and its resolved kiosk profile |
| Email link | opens the configured Thunderbird application |

Diagnostics from the cheatsheet:

```bash
type -a kiosk
test -x /usr/local/bin/kiosk
command -v firefox
grep '^exec ' ~/Public/start-kiosk.sh
ls -l ~/.config/autostart/skyline-kiosk.desktop
sudo cat "/var/lib/ctrl-esc-host-kiosk/users/$(id -u)/config"
sudo grep -E '^(AutomaticLoginEnable|AutomaticLogin)=' /etc/gdm3/custom.conf
gsettings get org.gnome.mutter overlay-key   # -> ''
gsettings get org.gnome.desktop.session idle-delay                            # -> uint32 0
gsettings get org.gnome.desktop.screensaver lock-enabled                       # -> false
gsettings get org.gnome.desktop.lockdown disable-lock-screen                   # -> true
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type   # -> 'nothing'
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type # -> 'nothing'

# Use the profile path printed by prepare-kiosk.sh.
FIREFOX_PROFILE='/path/to/the/resolved/profile'
python3 -m json.tool "$FIREFOX_PROFILE/customKeys.json"
stat -c '%U %a %n' "$FIREFOX_PROFILE/customKeys.json"  # -> kiosk 600 ...
```

Confirm the JSON retains any preexisting shortcut customizations and also contains empty objects for `key_close`, `key_closeWindow`, and `key_quitApplication`.

## Stage 4 — mailto escape (the actual workshop exercise)

Follow `Protocol-Handler-Escape/README.md`: 6-digit ID → Assistance → Digital Support → Contact Support → Email link. Confirm Thunderbird launches (Firefox must delegate `mailto:` to the OS handler the script requested; its post-set `xdg-mime` check is best-effort). Then:

Thunderbird → Troubleshooting → Open Directory → Nautilus → right-click → Open in Terminal.

This validates the exercise still works end-to-end.

## Stage 5 — Reset round-trip (most important to re-test)

From the shell you just spawned, and then again via the recovery shortcut (`Ctrl+Alt+Shift+O`):

```bash
# Needed only for a Bash prompt that was already open when setup added the alias.
source ~/.bashrc

# via recovery shortcut Ctrl+Alt+Shift+O
kiosk reset            # interactive, asks about reboot
```

Re-verify Stage 3 after reset. Then test the explicit reboot modes the cheatsheet documents. Test the rebooting case last:

```bash
kiosk reset --no-reboot
kiosk reset --reboot
```

Use `kiosk reset --reboot` after the updated repository script has already been installed. When testing a newly pulled script, use the repository update path in Stage 6 so the installed command and HTML are refreshed before reboot.

Confirm reset refuses setup options:

```bash
kiosk reset --level 1   # should die: "kiosk reset reuses the saved browser, user, and level."
```

## Stage 5.5 — Browser switch via kiosk remove (Firefox to Chrome)

If Google Chrome is installed, test the browser-switch path:

```bash
# Install Chrome first if not present:
# sudo dpkg -i google-chrome-stable_current_amd64.deb

kiosk remove                              # clears saved config + autostart entry
kiosk remove                              # idempotent: "Nothing to remove."

# Confirm the saved config is gone:
sudo test -f /var/lib/ctrl-esc-host-kiosk/users/$(id -u)/config && echo FAIL || echo PASS

# Redeploy with Chrome:
./prepare-kiosk.sh --level 2 --browser chrome --user kiosk --reboot
```

After reboot, re-verify Stage 3 (Chrome should open full screen; the Firefox-specific `Ctrl+W`/`Ctrl+Q` checks are N/A). Then switch back to Firefox if needed:

```bash
kiosk remove
./prepare-kiosk.sh --level 2 --browser firefox --user kiosk --reboot
```

Confirm remove rejects options:

```bash
kiosk remove --browser chrome   # should die: "kiosk remove accepts no setup options."
kiosk remove --reboot           # should die: "kiosk remove does not reboot."
```

## Stage 6 — Update path (simulates pulling these commits onto a deployed device)

On an already-configured device, pull and run from the repo:

```bash
./prepare-kiosk.sh reset --reboot
```

Confirm it preserves `/var/lib/ctrl-esc-host-kiosk/users/<uid>/autostart.original` and the saved config while refreshing `/usr/local/libexec/...` and the HTML.

## Stage 7 — Negative paths worth hitting once

```bash
sudo ./prepare-kiosk.sh                  # dies: "Do not run this script with sudo."
./prepare-kiosk.sh                       # again, on configured account -> "already configured"
kiosk reset --level 1                    # dies: reset reuses saved options
kiosk remove --browser chrome            # dies: remove accepts no setup options
kiosk remove --reboot                    # dies: remove does not reboot
```

Point at a non-GDM display manager (e.g. lightdm) → `verify_active_gdm` dies: "The active display manager is '...', not GDM."

## Regression focus for `1f8ad70`

The highest-risk changes are the new GDM-variant detection (`verify_active_gdm` + `detect_gdm_configuration` ordering) and the two post-install `grep -Fxq` assertions. If you only have time for one device, run Stages 1, 2, 5, and 7 — they exercise the commit's hardening directly.

## Revert

Roll back to the VM snapshot when done.
