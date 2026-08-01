#!/usr/bin/env bash
# Prepare or reset the CTRL+ESC+HOST Linux workshop kiosk.

if [[ "${CTRL_ESC_HOST_CLEAN_ENV:-}" != "1" ]]; then
  clean_uid="$(/usr/bin/id -u)"
  exec /usr/bin/env -i \
    CTRL_ESC_HOST_CLEAN_ENV=1 \
    HOME="$HOME" \
    USER="$(/usr/bin/id -un)" \
    LOGNAME="$(/usr/bin/id -un)" \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin" \
    LANG="${LANG:-C.UTF-8}" \
    TERM="${TERM:-xterm}" \
    DISPLAY="${DISPLAY:-}" \
    WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
    XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}" \
    XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-GNOME}" \
    XDG_RUNTIME_DIR="/run/user/$clean_uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$clean_uid/bus" \
    /usr/bin/bash "${BASH_SOURCE[0]}" "$@"
fi

set -euo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
export PATH

SUDO_BIN="/usr/bin/sudo"
ID_BIN="/usr/bin/id"
GETENT_BIN="/usr/bin/getent"
SYSTEMCTL_BIN="/usr/bin/systemctl"
PYTHON_BIN="/usr/bin/python3"
DPKG_QUERY_BIN="/usr/bin/dpkg-query"

PROGRAM_NAME="${0##*/}"
SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd -- "$(/usr/bin/dirname -- "$SCRIPT_PATH")" && pwd)"

INSTALL_ROOT="ctrl-esc-host-kiosk"
INSTALL_SCRIPT="/usr/local/libexec/$INSTALL_ROOT/prepare-kiosk.sh"
INSTALL_APP_DIR="/usr/local/share/$INSTALL_ROOT"
INSTALL_HTML=""
INSTALL_COMMAND="/usr/local/bin/kiosk"
INSTALL_COMPLETION="/usr/share/bash-completion/completions/kiosk"

DESKTOP_FILE_NAME="skyline-kiosk.desktop"
DEFAULT_KIOSK_APP="airline_kiosk.html"
SETTINGS_DESKTOP_FILE_NAME="org.gnome.Settings.desktop"
SETTINGS_DESKTOP_MASK_MARKER="X-CTRL-ESC-HOST-Managed=true"
GNOME_CONSOLE_SERVICE="/usr/share/dbus-1/services/org.gnome.Console.service"
RECOVERY_ACCELERATOR="<Control><Alt><Shift>o"
CUSTOM_BINDING_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
CUSTOM_BINDING_BASE="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
RECOVERY_BINDING_PATH="$CUSTOM_BINDING_BASE/kiosk-instructor-terminal/"

ACTION="setup"
LOCKDOWN_LEVEL="2"
BROWSER_NAME="firefox"
KIOSK_USER="$($ID_BIN -un)"
KIOSK_APP="$DEFAULT_KIOSK_APP"
REBOOT_MODE="ask"
REBOOT_OPTION_SEEN="false"
SETUP_OPTION_SEEN="false"
DISABLE_GNOME_CLICKABLE="false"
GNOME_CLICKABLE_OVERRIDE_SEEN="false"
TOUCHSCREEN_MODE="false"
TOUCHSCREEN_OPTION_SEEN="false"

USER_THEME_EXTENSION_UUID="user-theme@gnome-shell-extensions.gcampax.github.com"
USER_THEME_EXTENSION_PACKAGE="gnome-shell-extension-user-theme"
USER_THEME_EXTENSION_DIR="/usr/share/gnome-shell/extensions/$USER_THEME_EXTENSION_UUID"
USER_THEME_NAME="ctrl-esc-host-kiosk"
USER_THEME_DIR_NAME=".themes"
USER_THEME_GNOME_SHELL_SUBDIR="gnome-shell"
USER_THEME_CSS_NAME="gnome-shell.css"
THEME_BASE_SCHEMA="org.gnome.shell.extensions.user-theme"
THEME_BASE_KEY="name"
KIOSK_USER_THEME_DIR=""
KIOSK_USER_THEME_CSS=""

CURRENT_USER="$($ID_BIN -un)"
KIOSK_HOME="$HOME"
STATE_DIR=""
CONFIG_FILE=""
AUTOSTART_BACKUP=""
AUTOSTART_BACKUP_STATUS=""
CUSTOM_BINDINGS_BACKUP=""
AUTOSTART_DIR=""
AUTOSTART_STAGE=""
AUTOSTART_PREVIOUS=""
KIOSK_DIR=""
KIOSK_HTML=""
KIOSK_WRAPPER=""
SETTINGS_DESKTOP_MASK=""
KIOSK_HTML_TEMP=""
KIOSK_WRAPPER_TEMP=""
KIOSK_DESKTOP_TEMP=""
BROWSER_BIN=""
FIREFOX_PROFILE=""
FIREFOX_WAS_RUNNING="false"
TERMINAL_BIN=""
SOURCE_HTML=""
GDM_VARIANT=""

BLOCK_BINDING_IDS=(
  terminal
  close-tab
  close-window
  new-tab
  reopen-tab
  new-window
  incognito-window
  address-bar
  fullscreen
  devtools-f12
  devtools-i
  devtools-j
  devtools-c
)

BLOCK_BINDING_NAMES=(
  "Kiosk Block Standard Terminal"
  "Kiosk Block Close Tab"
  "Kiosk Block Close Window"
  "Kiosk Block New Tab"
  "Kiosk Block Reopen Tab"
  "Kiosk Block New Window"
  "Kiosk Block Incognito Window"
  "Kiosk Block Address Bar"
  "Kiosk Block Fullscreen Toggle"
  "Kiosk Block Developer Tools F12"
  "Kiosk Block Developer Tools I"
  "Kiosk Block Developer Tools J"
  "Kiosk Block Developer Tools C"
)

BLOCK_BINDING_KEYS=(
  "<Primary><Alt>t"
  "<Primary>w"
  "<Primary><Shift>w"
  "<Primary>t"
  "<Primary><Shift>t"
  "<Primary>n"
  "<Primary><Shift>n"
  "<Primary>l"
  "F11"
  "F12"
  "<Primary><Shift>i"
  "<Primary><Shift>j"
  "<Primary><Shift>c"
)

print_usage() {
  cat <<EOF
Usage:
  ./prepare-kiosk.sh [options]
  kiosk reset [--reboot|--no-reboot]
  kiosk remove

First-run options:
  --level 1|2                 Lockdown level (default: 2)
  --browser firefox|chromium|chrome
                              Browser used for the kiosk (default: firefox)
  --app FILE|URL              Local HTML filename beside the script or an
                              http(s) URL (default: airline_kiosk.html)
  --user USER                 GDM autologin user (default: current user)
  --disable-gnome-clickable  Hide the clickable Activities button and the
                              Quick Settings gear (installs/enables the
                              user-theme GNOME Shell extension and a small
                              theme). Off by default while being validated.
  --no-disable-gnome-clickable
                              Restore the Activities button and Settings gear.
                              Accepted on setup or reset to toggle the saved
                              state.
  --touchscreen               Install GNOME Console for Nautilus's touch
                              Open in Console path. Accepted on setup or reset
                              and saved for future resets.
  --reboot                    Reboot automatically after success
  --no-reboot                 Do not reboot after success
  -h, --help                  Show this help

Lockdown levels:
  1  Disable Activities, hot corners, and core GNOME Super navigation.
  2  Level 1 plus common GNOME and browser escape shortcuts.

The instructor recovery shortcut is Ctrl+Alt+Shift+O. It opens a terminal so
the instructor can run: kiosk reset

kiosk remove clears the saved kiosk configuration and the managed autostart
entry so the device can be redeployed with a different app or browser via
first-time setup. GDM autologin and GNOME lockdown remain until the next setup
overwrites them; install the new browser first, then run:

  ./prepare-kiosk.sh --level 2 --browser chrome --user kiosk --reboot

The kiosk account must be authorized to use sudo. Keep its password available
to instructors; do not run this script as root.
EOF
}

log() {
  printf '%s\n' "$*"
}

warn() {
  printf '    [!] %s\n' "$*" >&2
}

die() {
  printf '[!] %s\n' "$*" >&2
  exit 1
}

run_root() {
  "$SUDO_BIN" -- "$@"
}

clear_bash_history() {
  local history_file="${HISTFILE:-$KIOSK_HOME/.bash_history}"

  HISTFILE="$history_file"
  history -c && history -w
}

kiosk_app_is_url() {
  [[ "$KIOSK_APP" == http://* || "$KIOSK_APP" == https://* ]]
}

validate_kiosk_app() {
  local authority

  case "$KIOSK_APP" in
  *$'\n'* | *$'\r'* | *$'\t'* | *" "*)
    die "--app must not contain whitespace."
    ;;
  esac

  if kiosk_app_is_url; then
    authority="${KIOSK_APP#*://}"
    authority="${authority%%[/?#]*}"
    [[ -n "$authority" ]] || die "--app URL must include a host."
  else
    [[ "$KIOSK_APP" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.html$ ]] \
      || die "--app must be an HTML filename beside the script or an http(s) URL."
  fi
}

write_root_file_atomic() {
  local destination="$1"
  local mode="$2"

  run_root /bin/sh -c '
    set -eu
    destination=$1
    mode=$2
    temporary="${destination}.tmp.$$"
    umask 077
    cat >"$temporary"
    chown root:root "$temporary"
    chmod "$mode" "$temporary"
    mv -f "$temporary" "$destination"
  ' sh "$destination" "$mode"
}

set_user_paths() {
  local passwd_entry
  local detected_home
  local kiosk_uid

  passwd_entry="$($GETENT_BIN passwd "$KIOSK_USER" 2>/dev/null || true)"
  [[ -n "$passwd_entry" ]] || die "Unable to find the '$KIOSK_USER' account."
  IFS=: read -r _ _ kiosk_uid _ _ detected_home _ <<<"$passwd_entry"
  [[ "$kiosk_uid" =~ ^[0-9]+$ ]] || die "Invalid numeric UID for '$KIOSK_USER'."
  [[ "$kiosk_uid" == "$($ID_BIN -u "$KIOSK_USER")" ]] || die "Account UID validation failed for '$KIOSK_USER'."
  [[ -n "$detected_home" ]] || die "Unable to determine the home directory for '$KIOSK_USER'."
  [[ "$KIOSK_USER" == "$CURRENT_USER" ]] || die "Run this command while logged in as '$KIOSK_USER'."
  [[ "$detected_home" == "$HOME" ]] || die "HOME is '$HOME', but '$KIOSK_USER' uses '$detected_home'."

  KIOSK_HOME="$detected_home"
  STATE_DIR="/var/lib/$INSTALL_ROOT/users/$kiosk_uid"
  CONFIG_FILE="$STATE_DIR/config"
  AUTOSTART_BACKUP="$STATE_DIR/autostart.original"
  AUTOSTART_BACKUP_STATUS="$STATE_DIR/autostart.status"
  CUSTOM_BINDINGS_BACKUP="$STATE_DIR/custom-keybindings.original"
  AUTOSTART_DIR="$KIOSK_HOME/.config/autostart"
  KIOSK_DIR="$KIOSK_HOME/Public"
  if kiosk_app_is_url; then
    KIOSK_HTML=""
  else
    KIOSK_HTML="$KIOSK_DIR/$KIOSK_APP"
  fi
  KIOSK_WRAPPER="$KIOSK_DIR/start-kiosk.sh"
  SETTINGS_DESKTOP_MASK="$KIOSK_HOME/.local/share/applications/$SETTINGS_DESKTOP_FILE_NAME"
}

parse_arguments() {
  if [[ "${1:-}" == "setup" || "${1:-}" == "reset" || "${1:-}" == "remove" ]]; then
    ACTION="$1"
    shift
  elif [[ "$PROGRAM_NAME" == "kiosk" && "${1:-}" == "" ]]; then
    ACTION="setup"
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --level)
      [[ -n "${2:-}" ]] || die "--level requires 1 or 2."
      LOCKDOWN_LEVEL="$2"
      SETUP_OPTION_SEEN="true"
      shift 2
      ;;
    --browser)
      [[ -n "${2:-}" ]] || die "--browser requires firefox, chromium, or chrome."
      BROWSER_NAME="$2"
      SETUP_OPTION_SEEN="true"
      shift 2
      ;;
    --app)
      [[ -n "${2:-}" ]] || die "--app requires an HTML filename or http(s) URL."
      KIOSK_APP="$2"
      SETUP_OPTION_SEEN="true"
      shift 2
      ;;
    --user)
      [[ -n "${2:-}" ]] || die "--user requires an account name."
      KIOSK_USER="$2"
      SETUP_OPTION_SEEN="true"
      shift 2
      ;;
    --reboot)
      [[ "$REBOOT_OPTION_SEEN" == "false" || "$REBOOT_MODE" == "yes" ]] || die "--reboot conflicts with --no-reboot."
      REBOOT_MODE="yes"
      REBOOT_OPTION_SEEN="true"
      shift
      ;;
    --no-reboot)
      [[ "$REBOOT_OPTION_SEEN" == "false" || "$REBOOT_MODE" == "no" ]] || die "--no-reboot conflicts with --reboot."
      REBOOT_MODE="no"
      REBOOT_OPTION_SEEN="true"
      shift
      ;;
    --disable-gnome-clickable)
      DISABLE_GNOME_CLICKABLE="true"
      GNOME_CLICKABLE_OVERRIDE_SEEN="true"
      shift
      ;;
    --no-disable-gnome-clickable)
      DISABLE_GNOME_CLICKABLE="false"
      GNOME_CLICKABLE_OVERRIDE_SEEN="true"
      shift
      ;;
    --touchscreen)
      TOUCHSCREEN_MODE="true"
      TOUCHSCREEN_OPTION_SEEN="true"
      shift
      ;;
    -h | --help)
      print_usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
    esac
  done

  [[ "$LOCKDOWN_LEVEL" == "1" || "$LOCKDOWN_LEVEL" == "2" ]] || die "--level must be 1 or 2."
  case "$BROWSER_NAME" in
  firefox | chromium | chrome) ;;
  *) die "--browser must be firefox, chromium, or chrome." ;;
  esac
  validate_kiosk_app

  if [[ "$ACTION" == "reset" && "$SETUP_OPTION_SEEN" == "true" ]]; then
    die "kiosk reset reuses the saved app, browser, user, and level. Only reboot options, --touchscreen, and --disable-gnome-clickable / --no-disable-gnome-clickable are accepted."
  fi

  if [[ "$ACTION" == "remove" && ( "$SETUP_OPTION_SEEN" == "true" || "$GNOME_CLICKABLE_OVERRIDE_SEEN" == "true" || "$TOUCHSCREEN_OPTION_SEEN" == "true" ) ]]; then
    die "kiosk remove accepts no setup options. Re-run first-time setup to choose a new app or browser."
  fi

  if [[ "$ACTION" == "remove" && "$REBOOT_MODE" == "yes" ]]; then
    die "kiosk remove does not reboot. Run first-time setup with --reboot after choosing the new app or browser."
  fi
}

locate_source_html() {
  SOURCE_HTML=""
  INSTALL_HTML=""
  if kiosk_app_is_url; then
    return 0
  fi

  INSTALL_HTML="$INSTALL_APP_DIR/$KIOSK_APP"
  if [[ -f "$SCRIPT_DIR/$KIOSK_APP" ]]; then
    SOURCE_HTML="$SCRIPT_DIR/$KIOSK_APP"
  elif [[ -f "$INSTALL_HTML" ]]; then
    SOURCE_HTML="$INSTALL_HTML"
  else
    die "Unable to locate $KIOSK_APP beside the script or at $INSTALL_HTML."
  fi
}

load_saved_configuration() {
  local configuration
  local key
  local value
  local saved_user=""
  local saved_browser=""
  local saved_level=""
  local saved_app="$DEFAULT_KIOSK_APP"
  local saved_disable_gnome_clickable=""
  local saved_touchscreen_mode=""

  run_root test -f "$CONFIG_FILE" || die "No completed kiosk setup was found. Run prepare-kiosk.sh first."
  configuration="$(run_root cat "$CONFIG_FILE")" || die "Unable to read the saved kiosk configuration."
  while IFS='=' read -r key value; do
    case "$key" in
    KIOSK_USER) saved_user="$value" ;;
    BROWSER_NAME) saved_browser="$value" ;;
    LOCKDOWN_LEVEL) saved_level="$value" ;;
    KIOSK_APP) saved_app="$value" ;;
    DISABLE_GNOME_CLICKABLE) saved_disable_gnome_clickable="$value" ;;
    TOUCHSCREEN_MODE) saved_touchscreen_mode="$value" ;;
    *) die "Unexpected key in saved kiosk configuration: $key" ;;
    esac
  done <<<"$configuration"

  [[ "$saved_user" == "$CURRENT_USER" ]] || die "Saved kiosk user '$saved_user' does not match '$CURRENT_USER'."
  case "$saved_browser" in
  firefox | chromium | chrome) ;;
  *) die "Saved browser is invalid." ;;
  esac
  [[ "$saved_level" == "1" || "$saved_level" == "2" ]] || die "Saved lockdown level is invalid."
  KIOSK_APP="$saved_app"
  validate_kiosk_app
  case "${saved_disable_gnome_clickable:-}" in
  "" | true | false) ;;
  *) die "Saved --disable-gnome-clickable value is invalid." ;;
  esac
  case "${saved_touchscreen_mode:-}" in
  "" | true | false) ;;
  *) die "Saved --touchscreen value is invalid." ;;
  esac

  KIOSK_USER="$saved_user"
  BROWSER_NAME="$saved_browser"
  LOCKDOWN_LEVEL="$saved_level"
  if [[ "$GNOME_CLICKABLE_OVERRIDE_SEEN" != "true" ]]; then
    DISABLE_GNOME_CLICKABLE="${saved_disable_gnome_clickable:-false}"
  fi
  if [[ "$TOUCHSCREEN_OPTION_SEEN" != "true" ]]; then
    TOUCHSCREEN_MODE="${saved_touchscreen_mode:-false}"
  fi
}

ensure_state_directory() {
  run_root install -d -o root -g root -m 700 "$STATE_DIR"
}

save_configuration() {
  ensure_state_directory
  {
    printf 'KIOSK_USER=%s\n' "$KIOSK_USER"
    printf 'BROWSER_NAME=%s\n' "$BROWSER_NAME"
    printf 'LOCKDOWN_LEVEL=%s\n' "$LOCKDOWN_LEVEL"
    printf 'KIOSK_APP=%s\n' "$KIOSK_APP"
    printf 'DISABLE_GNOME_CLICKABLE=%s\n' "$DISABLE_GNOME_CLICKABLE"
    printf 'TOUCHSCREEN_MODE=%s\n' "$TOUCHSCREEN_MODE"
  } | write_root_file_atomic "$CONFIG_FILE" 600
}

cleanup_autostart_stage() {
  [[ -z "$KIOSK_HTML_TEMP" || ! -e "$KIOSK_HTML_TEMP" ]] || rm -f -- "$KIOSK_HTML_TEMP"
  [[ -z "$KIOSK_WRAPPER_TEMP" || ! -e "$KIOSK_WRAPPER_TEMP" ]] || rm -f -- "$KIOSK_WRAPPER_TEMP"
  [[ -z "$KIOSK_DESKTOP_TEMP" || ! -e "$KIOSK_DESKTOP_TEMP" ]] || rm -f -- "$KIOSK_DESKTOP_TEMP"
  if [[ -n "$AUTOSTART_STAGE" && -e "$AUTOSTART_STAGE" ]]; then
    rm -rf -- "$AUTOSTART_STAGE" 2>/dev/null || run_root rm -rf -- "$AUTOSTART_STAGE"
  fi
  if [[ -n "$AUTOSTART_PREVIOUS" && ( -e "$AUTOSTART_PREVIOUS" || -L "$AUTOSTART_PREVIOUS" ) && ! -e "$AUTOSTART_DIR" && ! -L "$AUTOSTART_DIR" ]]; then
    mv -- "$AUTOSTART_PREVIOUS" "$AUTOSTART_DIR"
  fi
  restart_stopped_kiosk_firefox || true
}

preflight() {
  [[ "$EUID" -ne 0 ]] || die "Do not run this script with sudo. Run it as the logged-in kiosk user."
  command -v apt-get &>/dev/null || die "This setup currently supports Debian/Ubuntu systems with apt-get."
  [[ -x "$SUDO_BIN" ]] || die "$SUDO_BIN is required for package installation, GDM, and command installation."
  command -v gsettings &>/dev/null || die "gsettings is required for GNOME lockdown."
  [[ -x "$GETENT_BIN" && -x "$ID_BIN" ]] || die "Trusted id/getent utilities are required."

  if ! "$SUDO_BIN" -v; then
    die "'$CURRENT_USER' must be authorized to use sudo. Configure the kiosk account as an Ubuntu administrator before setup or reset."
  fi
}

install_dependencies() {
  local packages=()

  command -v thunderbird &>/dev/null || packages+=(thunderbird)
  command -v curl &>/dev/null || packages+=(curl)
  command -v xdg-mime &>/dev/null || packages+=(xdg-utils)
  command -v gnome-terminal &>/dev/null || packages+=(gnome-terminal)
  if [[ "$TOUCHSCREEN_MODE" == "true" ]] && ! command -v kgx &>/dev/null; then
    packages+=(gnome-console)
  fi

  case "$BROWSER_NAME" in
  firefox)
    if ! command -v firefox &>/dev/null; then
      packages+=(firefox)
    fi
    ;;
  chromium)
    if ! command -v chromium-browser &>/dev/null && ! command -v chromium &>/dev/null; then
      if apt-cache show chromium-browser &>/dev/null; then
        packages+=(chromium-browser)
      elif apt-cache show chromium &>/dev/null; then
        packages+=(chromium)
      else
        die "Neither chromium-browser nor chromium is available from the configured apt repositories."
      fi
    fi
    ;;
  chrome)
    if ! command -v google-chrome &>/dev/null && ! command -v google-chrome-stable &>/dev/null; then
      die "Google Chrome is not installed. Install it first or use --browser firefox|chromium."
    fi
    ;;
  esac

  if [[ ${#packages[@]} -gt 0 ]]; then
    log "Refreshing APT package metadata..."
    run_root apt-get update
    log "Installing required packages: ${packages[*]}"
    run_root apt-get install -y "${packages[@]}"
  fi

  if [[ "$TOUCHSCREEN_MODE" == "true" ]]; then
    command -v kgx &>/dev/null || die "GNOME Console is required for --touchscreen."
    [[ -r "$GNOME_CONSOLE_SERVICE" ]] || die "GNOME Console is installed but its D-Bus service is unavailable at $GNOME_CONSOLE_SERVICE."
  fi
}

ensure_user_theme_extension() {
  [[ "$DISABLE_GNOME_CLICKABLE" == "true" ]] || return 0

  [[ -x "$DPKG_QUERY_BIN" ]] || die "$DPKG_QUERY_BIN is required to verify $USER_THEME_EXTENSION_PACKAGE."

  if ! "$DPKG_QUERY_BIN" --show --showformat='${Status}\n' "$USER_THEME_EXTENSION_PACKAGE" 2>/dev/null \
    | grep -Fxq "install ok installed"; then
    log "Installing the user-theme GNOME Shell extension package for --disable-gnome-clickable..."
    run_root apt-get install -y "$USER_THEME_EXTENSION_PACKAGE"
  fi

  "$DPKG_QUERY_BIN" --show --showformat='${Status}\n' "$USER_THEME_EXTENSION_PACKAGE" 2>/dev/null \
    | grep -Fxq "install ok installed" \
    || die "$USER_THEME_EXTENSION_PACKAGE is not installed after apt-get completed."
  [[ -r "$USER_THEME_EXTENSION_DIR/metadata.json" && -r "$USER_THEME_EXTENSION_DIR/extension.js" ]] \
    || die "$USER_THEME_EXTENSION_PACKAGE is installed but its extension files are unavailable at $USER_THEME_EXTENSION_DIR."
  gsettings_schema_exists "$THEME_BASE_SCHEMA" \
    || die "$USER_THEME_EXTENSION_PACKAGE is installed but the $THEME_BASE_SCHEMA schema is unavailable."
}

resolve_browser() {
  case "$BROWSER_NAME" in
  firefox)
    BROWSER_BIN="$(command -v firefox || true)"
    ;;
  chromium)
    BROWSER_BIN="$(command -v chromium-browser || command -v chromium || true)"
    ;;
  chrome)
    BROWSER_BIN="$(command -v google-chrome || command -v google-chrome-stable || true)"
    ;;
  esac

  [[ -n "$BROWSER_BIN" && -x "$BROWSER_BIN" ]] || die "Unable to resolve the '$BROWSER_NAME' browser executable."
  log "Resolved browser executable: $BROWSER_BIN"
  TERMINAL_BIN="$(command -v gnome-terminal || true)"
  [[ -n "$TERMINAL_BIN" && -x "$TERMINAL_BIN" ]] || die "gnome-terminal is required for the instructor recovery shortcut."
}

resolve_firefox_profile() {
  local profiles_ini
  local profile_selector="install"
  local version

  [[ "$BROWSER_NAME" == "firefox" ]] || return 0
  [[ -x "$PYTHON_BIN" ]] || die "$PYTHON_BIN is required to configure Firefox shortcuts."
  command -v pgrep &>/dev/null && command -v pkill &>/dev/null || die "pgrep and pkill are required to stop Firefox safely."
  version="$(LC_ALL=C "$BROWSER_BIN" --version 2>/dev/null)" || die "Unable to determine the Firefox version."
  [[ "$version" =~ Firefox[^0-9]*([0-9]+) ]] || die "Unable to parse the Firefox version: $version"
  [[ "${BASH_REMATCH[1]}" -ge 147 ]] || die "Firefox 147 or newer is required for profile shortcut overrides (found: $version)."

  if [[ "$BROWSER_BIN" == /snap/* ]] || { [[ "$BROWSER_BIN" == "/usr/bin/firefox" && -r "$BROWSER_BIN" ]] && grep -Eq '/snap/bin/firefox|snap (run )?firefox' "$BROWSER_BIN"; }; then
    profiles_ini="$KIOSK_HOME/snap/firefox/common/.mozilla/firefox/profiles.ini"
    profile_selector="profile"
  else
    profiles_ini="$KIOSK_HOME/.mozilla/firefox/profiles.ini"
  fi
  [[ -f "$profiles_ini" ]] || die "Firefox profile metadata is missing at $profiles_ini. Launch this Firefox installation once, close it, and rerun setup."

  FIREFOX_PROFILE="$($PYTHON_BIN - "$profiles_ini" "$profile_selector" <<'PY'
import configparser
import os
import sys

profiles_ini = os.path.abspath(sys.argv[1])
profile_selector = sys.argv[2]
profile_root = os.path.dirname(profiles_ini)
config = configparser.ConfigParser(interpolation=None)
try:
    with open(profiles_ini, encoding="utf-8") as profiles_file:
        config.read_file(profiles_file)
except (OSError, configparser.Error) as error:
    raise SystemExit(f"Unable to read {profiles_ini}: {error}")

install_defaults = {
    config[section]["Default"].strip()
    for section in config.sections()
    if section.startswith("Install") and config[section].get("Default")
}
profile_defaults = {
    config[section]["Path"].strip()
    for section in config.sections()
    if section.startswith("Profile")
    and config[section].get("Path")
    and config[section].getboolean("Default", fallback=False)
}
defaults = profile_defaults if profile_selector == "profile" else install_defaults
if len(defaults) != 1:
    raise SystemExit(
        f"Unable to identify one unambiguous default Firefox profile from {profiles_ini}"
    )

selected_profile = defaults.pop()
if not os.path.isabs(selected_profile):
    selected_profile = os.path.join(profile_root, selected_profile)
selected_profile = os.path.abspath(selected_profile)
if not os.path.isdir(selected_profile):
    raise SystemExit(f"Firefox default profile does not exist: {selected_profile}")
print(selected_profile)
PY
  )" || die "Unable to resolve the Firefox profile selected by $profiles_ini."
  [[ -n "$FIREFOX_PROFILE" && "$FIREFOX_PROFILE" != *$'\n'* ]] || die "Firefox returned an invalid profile path."
  log "Resolved Firefox kiosk profile: $FIREFOX_PROFILE"
}

stop_running_kiosk_firefox() {
  local attempt
  local kiosk_uid
  local pids

  [[ "$BROWSER_NAME" == "firefox" ]] || return 0
  kiosk_uid="$($ID_BIN -u "$KIOSK_USER")"
  # Skip zombie/defunct processes — they can't be killed and don't hold the profile lock.
  pids="$(pgrep -u "$kiosk_uid" -x firefox 2>/dev/null || true)"
  [[ -n "$pids" ]] || return 0

  # Check if any matching process is NOT a zombie.
  if ! echo "$pids" | xargs ps -o pid=,stat= -p 2>/dev/null | awk '{print $2}' | grep -qv 'Z'; then
    log "Firefox is not running (only defunct processes). Proceeding."
    return 0
  fi

  FIREFOX_WAS_RUNNING="true"
  log "Stopping the running kiosk Firefox before updating its profile..."
  pkill -TERM -u "$kiosk_uid" -x firefox 2>/dev/null || true
  for ((attempt = 0; attempt < 100; attempt++)); do
    pids="$(pgrep -u "$kiosk_uid" -x firefox 2>/dev/null || true)"
    [[ -n "$pids" ]] || return 0
    if ! echo "$pids" | xargs ps -o pid=,stat= -p 2>/dev/null | awk '{print $2}' | grep -qv 'Z'; then
      return 0
    fi
    sleep 0.1
  done
  die "The kiosk Firefox process did not stop cleanly; refusing to update $FIREFOX_PROFILE/customKeys.json."
}

restart_stopped_kiosk_firefox() {
  [[ "$FIREFOX_WAS_RUNNING" == "true" ]] || return 0
  if [[ -x "$KIOSK_WRAPPER" ]]; then
    log "Restarting the kiosk Firefox through $KIOSK_WRAPPER"
    /usr/bin/nohup "$KIOSK_WRAPPER" >/dev/null 2>&1 &
  else
    warn "Firefox was stopped, but $KIOSK_WRAPPER is unavailable for restart."
  fi
  FIREFOX_WAS_RUNNING="false"
}

configure_firefox_shortcuts() {
  local custom_keys
  local kiosk_uid

  [[ "$BROWSER_NAME" == "firefox" ]] || return 0
  [[ -n "$FIREFOX_PROFILE" && -d "$FIREFOX_PROFILE" ]] || die "The Firefox kiosk profile is unavailable."
  kiosk_uid="$($ID_BIN -u "$KIOSK_USER")"
  custom_keys="$FIREFOX_PROFILE/customKeys.json"

  "$PYTHON_BIN" - "$FIREFOX_PROFILE" "$kiosk_uid" <<'PY'
import json
import os
import sys
import tempfile

profile = os.path.abspath(sys.argv[1])
expected_uid = int(sys.argv[2])
custom_keys = os.path.join(profile, "customKeys.json")

if os.getuid() != expected_uid:
    raise SystemExit("customKeys.json must be configured by the kiosk user")

try:
    with open(custom_keys, encoding="utf-8") as source:
        shortcuts = json.load(source)
except FileNotFoundError:
    shortcuts = {}

if not isinstance(shortcuts, dict):
    raise SystemExit(f"{custom_keys} must contain a JSON object")

shortcuts.update(
    {
        "key_close": {},
        "key_closeWindow": {},
        "key_quitApplication": {},
    }
)

temporary_fd, temporary_path = tempfile.mkstemp(prefix=".customKeys.", dir=profile)
try:
    os.fchmod(temporary_fd, 0o600)
    with os.fdopen(temporary_fd, "w", encoding="utf-8") as destination:
        json.dump(shortcuts, destination, ensure_ascii=True, indent=2)
        destination.write("\n")
        destination.flush()
        os.fsync(destination.fileno())
    os.replace(temporary_path, custom_keys)
finally:
    if os.path.exists(temporary_path):
        os.unlink(temporary_path)

installed = os.stat(custom_keys)
if installed.st_uid != expected_uid or installed.st_mode & 0o7777 != 0o600:
    raise SystemExit(f"Incorrect owner or mode on {custom_keys}")
PY

  "$PYTHON_BIN" -m json.tool "$custom_keys" >/dev/null || die "Firefox shortcut JSON validation failed: $custom_keys"
  log "Disabled Firefox close and quit shortcuts in $custom_keys"
}

install_kiosk_command() {
  log "Installing the kiosk command and runtime assets..."
  run_root install -d -m 755 "${INSTALL_SCRIPT%/*}" "$INSTALL_APP_DIR"

  if [[ "$SCRIPT_PATH" != "$INSTALL_SCRIPT" ]]; then
    run_root install -m 755 "$SCRIPT_PATH" "$INSTALL_SCRIPT"
  fi
  if [[ -n "$SOURCE_HTML" && "$SOURCE_HTML" != "$INSTALL_HTML" ]]; then
    run_root install -m 644 "$SOURCE_HTML" "$INSTALL_HTML"
  fi

  write_root_file_atomic "$INSTALL_COMMAND" 755 <<'EOF'
#!/usr/bin/env bash
exec /usr/local/libexec/ctrl-esc-host-kiosk/prepare-kiosk.sh "$@"
EOF
}

configure_bash_alias() {
  local bashrc="$KIOSK_HOME/.bashrc"
  local alias_line="alias kiosk='$INSTALL_COMMAND'"

  if [[ -L "$bashrc" || ( -e "$bashrc" && ! -f "$bashrc" ) ]]; then
    warn "Skipping the optional Bash alias because $bashrc is not a regular file."
    return
  fi
  if [[ -f "$bashrc" ]] && grep -Fxq -- "$alias_line" "$bashrc"; then
    return
  fi
  if ! printf '\n# CTRL+ESC+HOST kiosk recovery command\n%s\n' "$alias_line" >>"$bashrc"; then
    warn "Unable to add the optional kiosk alias to $bashrc. The global $INSTALL_COMMAND command is still available."
    return
  fi
  log "Added the Bash alias for '$INSTALL_COMMAND'. Run 'source ~/.bashrc' in an existing Bash prompt to load it."
}

install_kiosk_completion() {
  log "Installing the kiosk tab completion..."
  run_root install -d -m 755 "${INSTALL_COMPLETION%/*}"
  write_root_file_atomic "$INSTALL_COMPLETION" 644 <<'EOF'
# Bash tab completion for the CTRL+ESC+HOST kiosk command.
# Generated by prepare-kiosk.sh; do not edit by hand.

_kiosk_completions() {
  local cur prev words cword
  _init_completion -n = || return

  local action="" w
  for w in "${words[@]:1:cword}"; do
    case "$w" in
      setup|reset|remove) action="$w"; break ;;
    esac
  done

  if [[ "$cword" -eq 1 && -z "$action" ]]; then
    COMPREPLY=( $(compgen -W "setup reset remove" -- "$cur") )
    return 0
  fi

  case "$prev" in
    --level)   COMPREPLY=( $(compgen -W "1 2" -- "$cur") ); return 0 ;;
    --browser) COMPREPLY=( $(compgen -W "firefox chromium chrome" -- "$cur") ); return 0 ;;
    --app)     COMPREPLY=( $(compgen -f -X '!*.html' -- "$cur") ); return 0 ;;
    --user)    COMPREPLY=( $(compgen -W "$(/usr/bin/getent passwd | cut -d: -f1)" -- "$cur") ); return 0 ;;
  esac

  case "$action" in
    setup)  COMPREPLY=( $(compgen -W "--level --browser --app --user --touchscreen --disable-gnome-clickable --no-disable-gnome-clickable --reboot --no-reboot -h --help" -- "$cur") ) ;;
    reset)  COMPREPLY=( $(compgen -W "--touchscreen --disable-gnome-clickable --no-disable-gnome-clickable --reboot --no-reboot -h --help" -- "$cur") ) ;;
    remove) COMPREPLY=( $(compgen -W "-h --help" -- "$cur") ) ;;
  esac
}
complete -F _kiosk_completions kiosk
EOF
}

remove_kiosk_completion() {
  if run_root test -f "$INSTALL_COMPLETION"; then
    run_root rm -f -- "$INSTALL_COMPLETION"
    log "Removed the kiosk tab completion: $INSTALL_COMPLETION"
  fi
}

backup_autostart_once() {
  local temporary_backup
  local original_status

  ensure_state_directory
  if run_root test -f "$AUTOSTART_BACKUP_STATUS"; then
    run_root test -d "$AUTOSTART_BACKUP" || die "Autostart backup metadata exists, but the backup directory is missing."
    log "Keeping the existing first-run autostart backup."
    return
  fi

  [[ ! -L "$AUTOSTART_DIR" ]] || die "$AUTOSTART_DIR is a symbolic link; refusing to replace it during workshop reset."
  [[ ! -e "$AUTOSTART_DIR" || -d "$AUTOSTART_DIR" ]] || die "$AUTOSTART_DIR exists but is not a directory."
  [[ ! -e "$AUTOSTART_DIR/$DESKTOP_FILE_NAME" && ! -L "$AUTOSTART_DIR/$DESKTOP_FILE_NAME" ]] || die "$AUTOSTART_DIR/$DESKTOP_FILE_NAME is reserved by the kiosk installer."

  if run_root test -e "$AUTOSTART_BACKUP"; then
    warn "Removing an incomplete autostart backup that has no completion marker."
    run_root rm -rf -- "$AUTOSTART_BACKUP"
  fi
  temporary_backup="$AUTOSTART_BACKUP.tmp.$$"
  run_root rm -rf -- "$temporary_backup"
  if [[ -d "$AUTOSTART_DIR" ]]; then
    run_root cp -a -- "$AUTOSTART_DIR" "$temporary_backup"
    original_status="present"
  else
    run_root install -d -o root -g root -m 700 "$temporary_backup"
    original_status="absent"
  fi

  run_root mv "$temporary_backup" "$AUTOSTART_BACKUP"
  printf '%s\n' "$original_status" | write_root_file_atomic "$AUTOSTART_BACKUP_STATUS" 600
  log "Captured the first-run autostart baseline at $AUTOSTART_BACKUP"
}

recover_stranded_autostart() {
  local -a previous_directories

  shopt -s nullglob
  previous_directories=("${AUTOSTART_DIR}.kiosk-previous."*)
  shopt -u nullglob
  [[ ${#previous_directories[@]} -le 1 ]] || die "Multiple interrupted autostart backups require manual review."
  [[ ${#previous_directories[@]} -eq 1 ]] || return 0

  if [[ ! -e "$AUTOSTART_DIR" && ! -L "$AUTOSTART_DIR" ]]; then
    mv -- "${previous_directories[0]}" "$AUTOSTART_DIR"
    log "Recovered the autostart directory from an interrupted reset."
  else
    rm -rf -- "${previous_directories[0]}"
  fi
}

prepare_autostart_stage() {
  local original_status
  local expected_path="$KIOSK_HOME/.config/autostart"

  [[ "$AUTOSTART_DIR" == "$expected_path" ]] || die "Unsafe autostart restore path: $AUTOSTART_DIR"
  recover_stranded_autostart
  run_root test -f "$AUTOSTART_BACKUP_STATUS" || die "The first-run autostart status is missing."
  run_root test -d "$AUTOSTART_BACKUP" || die "The first-run autostart backup is missing."

  original_status="$(run_root cat "$AUTOSTART_BACKUP_STATUS")"
  [[ "$original_status" == "present" || "$original_status" == "absent" ]] || die "Invalid autostart backup status."

  mkdir -p "${AUTOSTART_DIR%/*}"
  AUTOSTART_STAGE="${AUTOSTART_DIR%/*}/.autostart.kiosk-stage.$$"
  rm -rf -- "$AUTOSTART_STAGE"
  if [[ "$original_status" == "present" ]]; then
    run_root cp -a -- "$AUTOSTART_BACKUP" "$AUTOSTART_STAGE"
  else
    mkdir -p "$AUTOSTART_STAGE"
  fi

  [[ -w "$AUTOSTART_STAGE" ]] || die "The staged autostart baseline is not writable by '$KIOSK_USER'."
  log "Staged the original autostart baseline."
}

activate_autostart_stage() {
  [[ -n "$AUTOSTART_STAGE" && -d "$AUTOSTART_STAGE" ]] || die "The complete autostart stage is missing."
  AUTOSTART_PREVIOUS="${AUTOSTART_DIR}.kiosk-previous.$$"
  rm -rf -- "$AUTOSTART_PREVIOUS"
  if [[ -e "$AUTOSTART_DIR" || -L "$AUTOSTART_DIR" ]]; then
    mv -- "$AUTOSTART_DIR" "$AUTOSTART_PREVIOUS"
  fi

  if mv -- "$AUTOSTART_STAGE" "$AUTOSTART_DIR"; then
    AUTOSTART_STAGE=""
    rm -rf -- "$AUTOSTART_PREVIOUS"
    AUTOSTART_PREVIOUS=""
  else
    [[ ! -e "$AUTOSTART_DIR" && -e "$AUTOSTART_PREVIOUS" ]] && mv -- "$AUTOSTART_PREVIOUS" "$AUTOSTART_DIR"
    AUTOSTART_PREVIOUS=""
    die "Unable to activate the restored autostart directory. The previous directory was retained."
  fi

  log "Activated the original autostart baseline and managed kiosk launcher."
}

generate_kiosk_files() {
  local target_autostart="$1"
  local browser_command
  local kiosk_target
  local -a browser_args

  mkdir -p "$KIOSK_DIR" "$target_autostart"
  [[ ! -d "$KIOSK_WRAPPER" ]] || die "$KIOSK_WRAPPER is a directory and cannot be replaced."
  [[ ! -d "$target_autostart/$DESKTOP_FILE_NAME" ]] || die "$target_autostart/$DESKTOP_FILE_NAME is a directory and cannot be replaced."

  if kiosk_app_is_url; then
    kiosk_target="$KIOSK_APP"
  else
    [[ ! -d "$KIOSK_HTML" ]] || die "$KIOSK_HTML is a directory and cannot be replaced."
    KIOSK_HTML_TEMP="$(/usr/bin/mktemp "$KIOSK_DIR/.kiosk-app.XXXXXX")"
    cp -- "$INSTALL_HTML" "$KIOSK_HTML_TEMP"
    chmod 644 "$KIOSK_HTML_TEMP"
    mv -f -- "$KIOSK_HTML_TEMP" "$KIOSK_HTML"
    KIOSK_HTML_TEMP=""
    kiosk_target="$KIOSK_HTML"
  fi

  case "$BROWSER_NAME" in
  firefox)
    [[ -n "$FIREFOX_PROFILE" ]] || die "The Firefox kiosk profile was not resolved."
    browser_args=("$BROWSER_BIN" --profile "$FIREFOX_PROFILE" --kiosk "$kiosk_target")
    ;;
  chromium | chrome)
    browser_args=(
      "$BROWSER_BIN"
      --noerrdialogs
      --disable-infobars
      --no-first-run
      --enable-features=OverlayScrollbar
      --start-maximized
      --kiosk
      "$kiosk_target"
    )
    ;;
  esac

  printf -v browser_command '%q ' "${browser_args[@]}"
  KIOSK_WRAPPER_TEMP="$(/usr/bin/mktemp "$KIOSK_DIR/.start-kiosk.XXXXXX")"
  cat >"$KIOSK_WRAPPER_TEMP" <<EOF
#!/usr/bin/env bash
export LIBGL_ALWAYS_SOFTWARE=1
if [[ "\${XDG_SESSION_TYPE:-}" == "wayland" || -n "\${WAYLAND_DISPLAY:-}" ]]; then
  export MOZ_ENABLE_WAYLAND=1
fi
sleep 5
exec $browser_command
EOF
  chmod 755 "$KIOSK_WRAPPER_TEMP"
  mv -f -- "$KIOSK_WRAPPER_TEMP" "$KIOSK_WRAPPER"
  KIOSK_WRAPPER_TEMP=""

  KIOSK_DESKTOP_TEMP="$(/usr/bin/mktemp "$target_autostart/.skyline-kiosk.XXXXXX")"
  cat >"$KIOSK_DESKTOP_TEMP" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=SkyLine Kiosk
Comment=Launch the CTRL+ESC+HOST workshop kiosk
Exec="$KIOSK_WRAPPER"
Icon=$BROWSER_NAME
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF
  chmod 755 "$KIOSK_DESKTOP_TEMP"
  mv -f -- "$KIOSK_DESKTOP_TEMP" "$target_autostart/$DESKTOP_FILE_NAME"
  KIOSK_DESKTOP_TEMP=""

  log "Created the fullscreen kiosk autostart entry."
}

configure_mail_handler() {
  local current_handler
  local desktop_id=""
  local candidate
  local directory

  for candidate in thunderbird.desktop thunderbird_thunderbird.desktop org.mozilla.Thunderbird.desktop; do
    for directory in \
      "$KIOSK_HOME/.local/share/applications" \
      /usr/local/share/applications \
      /usr/share/applications \
      /var/lib/snapd/desktop/applications; do
      if [[ -f "$directory/$candidate" ]]; then
        desktop_id="$candidate"
        break 2
      fi
    done
  done
  [[ -n "$desktop_id" ]] || die "Unable to locate Thunderbird's desktop entry for the mailto handler."

  current_handler="$(xdg-mime query default x-scheme-handler/mailto 2>/dev/null || true)"
  if [[ "$current_handler" != "$desktop_id" ]]; then
    xdg-mime default "$desktop_id" x-scheme-handler/mailto
    log "Configured Thunderbird as the default mailto handler."
  fi
  current_handler="$(xdg-mime query default x-scheme-handler/mailto 2>/dev/null || true)"
  if [[ "$current_handler" == "$desktop_id" ]]; then
    log "Thunderbird is the default mailto handler."
  else
    log "Note: Unable to verify the requested mailto handler '$desktop_id' (xdg-mime reported '${current_handler:-none}'). Continuing setup; validate the kiosk Email link before the workshop."
  fi
}

verify_active_gdm() {
  local fragment_path
  local fragment_name
  local default_manager
  local default_name

  [[ -x "$SYSTEMCTL_BIN" ]] || die "$SYSTEMCTL_BIN is required to verify GDM."
  run_root "$SYSTEMCTL_BIN" is-active --quiet display-manager.service || die "The system display manager is not active. Refusing to configure GDM autologin."

  fragment_path="$(run_root "$SYSTEMCTL_BIN" show --property=FragmentPath --value display-manager.service)" || die "Unable to identify the active display manager."
  fragment_name="${fragment_path##*/}"
  case "$fragment_name" in
  gdm.service) GDM_VARIANT="gdm" ;;
  gdm3.service) GDM_VARIANT="gdm3" ;;
  *) die "The active display manager is '$fragment_name', not GDM. Refusing to configure autologin." ;;
  esac

  if run_root test -f /etc/X11/default-display-manager; then
    default_manager="$(run_root cat /etc/X11/default-display-manager)" || die "Unable to read /etc/X11/default-display-manager."
    default_name="${default_manager##*/}"
    case "$default_name" in
    gdm | gdm3) GDM_VARIANT="$default_name" ;;
    *) die "Debian's configured display manager is '$default_name', not GDM. Refusing to configure autologin." ;;
    esac
  fi
}

detect_gdm_configuration() {
  if [[ "$GDM_VARIANT" == "gdm3" ]] && run_root test -f /etc/gdm3/custom.conf; then
    printf '%s\n' /etc/gdm3/custom.conf
  elif [[ "$GDM_VARIANT" == "gdm" ]] && run_root test -f /etc/gdm/custom.conf; then
    printf '%s\n' /etc/gdm/custom.conf
  elif run_root test -f /etc/gdm3/custom.conf && ! run_root test -f /etc/gdm/custom.conf; then
    printf '%s\n' /etc/gdm3/custom.conf
  elif run_root test -f /etc/gdm/custom.conf && ! run_root test -f /etc/gdm3/custom.conf; then
    printf '%s\n' /etc/gdm/custom.conf
  else
    return 1
  fi
}

configure_gdm_autologin() {
  local gdm_conf
  local backup_file
  local root_temporary_file

  verify_active_gdm
  gdm_conf="$(detect_gdm_configuration)" || die "Unable to select the active GDM configuration from /etc/gdm3/custom.conf or /etc/gdm/custom.conf."
  backup_file="$gdm_conf.ctrl-esc-host-original"

  if ! run_root test -e "$backup_file"; then
    run_root cp -a "$gdm_conf" "$backup_file"
    log "Saved the original GDM configuration at $backup_file"
  fi

  root_temporary_file="$gdm_conf.ctrl-esc-host.tmp.$$"
  run_root awk -v login_user="$KIOSK_USER" '
  BEGIN { in_daemon=0; daemon_found=0; has_enable=0; has_login=0 }

  /^\[daemon\]/ {
    daemon_found=1
    in_daemon=1
    print
    next
  }

  /^\[/ {
    if (in_daemon) {
      if (!has_enable) print "AutomaticLoginEnable=True"
      if (!has_login) print "AutomaticLogin=" login_user
    }
    in_daemon=0
    print
    next
  }

  {
    if (in_daemon && $0 ~ /^[[:space:]]*AutomaticLoginEnable[[:space:]]*=/) {
      if (!has_enable) {
        print "AutomaticLoginEnable=True"
        has_enable=1
      }
      next
    }

    if (in_daemon && $0 ~ /^[[:space:]]*AutomaticLogin[[:space:]]*=/) {
      if (!has_login) {
        print "AutomaticLogin=" login_user
        has_login=1
      }
      next
    }

    print
  }

  END {
    if (!daemon_found) {
      print ""
      print "[daemon]"
      print "AutomaticLoginEnable=True"
      print "AutomaticLogin=" login_user
    } else if (in_daemon) {
      if (!has_enable) print "AutomaticLoginEnable=True"
      if (!has_login) print "AutomaticLogin=" login_user
    }
  }
  ' "$gdm_conf" | write_root_file_atomic "$root_temporary_file" 600

  run_root grep -Fxq "AutomaticLoginEnable=True" "$root_temporary_file" || die "Generated GDM configuration is missing AutomaticLoginEnable=True."
  run_root grep -Fxq "AutomaticLogin=$KIOSK_USER" "$root_temporary_file" || die "Generated GDM configuration is missing the kiosk account."

  run_root chown --reference="$gdm_conf" "$root_temporary_file"
  run_root chmod --reference="$gdm_conf" "$root_temporary_file"
  run_root mv -f "$root_temporary_file" "$gdm_conf"
  run_root grep -Fxq "AutomaticLoginEnable=True" "$gdm_conf" || die "Installed GDM configuration does not enable automatic login."
  run_root grep -Fxq "AutomaticLogin=$KIOSK_USER" "$gdm_conf" || die "Installed GDM configuration does not select the kiosk account."
  log "Configured GDM automatic login for '$KIOSK_USER'."
}

gsettings_schema_exists() {
  gsettings list-schemas | grep -Fx "$1" &>/dev/null
}

gsettings_key_exists() {
  gsettings range "$1" "$2" &>/dev/null
}

set_gsettings_key() {
  local schema="$1"
  local key="$2"
  local value="$3"
  local writable

  gsettings_key_exists "$schema" "$key" || return 1
  writable="$(gsettings writable "$schema" "$key" 2>/dev/null || true)"
  [[ "$writable" == "true" ]] || return 1
  gsettings set "$schema" "$key" "$value"
  verify_gsettings_value "$schema" "$key" "$value"
}

verify_gsettings_value() {
  local schema="$1"
  local key="$2"
  local expected="$3"
  local actual

  actual="$(gsettings get "$schema" "$key" 2>/dev/null)" || return 1
  if [[ "$expected" == "[]" ]]; then
    [[ "$actual" == "[]" || "$actual" == "@as []" ]]
  else
    [[ "$actual" == "$expected" ]]
  fi
}

set_required_gsettings_key() {
  set_gsettings_key "$1" "$2" "$3" || die "Unable to set required GNOME setting $1::$2."
}

reset_gsettings_key() {
  local schema="$1"
  local key="$2"
  local writable

  gsettings_key_exists "$schema" "$key" || return 1
  writable="$(gsettings writable "$schema" "$key" 2>/dev/null || true)"
  [[ "$writable" == "true" ]] || return 1
  gsettings reset "$schema" "$key"
}

disable_binding_keys() {
  local schema="$1"
  shift
  local key

  for key in "$@"; do
    if gsettings_key_exists "$schema" "$key"; then
      set_gsettings_key "$schema" "$key" "[]" || die "Unable to disable GNOME binding $schema::$key."
    fi
  done
}

disable_required_binding_keys() {
  local schema="$1"
  shift
  local key

  for key in "$@"; do
    set_gsettings_key "$schema" "$key" "[]" || die "Unable to disable required GNOME binding $schema::$key."
  done
}

disable_super_bindings_in_schema() {
  local schema="$1"
  local key
  local current_value
  local failed="false"

  local key_list

  gsettings_schema_exists "$schema" || return 0
  key_list="$(gsettings list-keys "$schema" 2>/dev/null)" || return 1
  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    if ! current_value="$(gsettings get "$schema" "$key" 2>/dev/null)"; then
      warn "Unable to read GNOME binding $schema::$key"
      failed="true"
      continue
    fi
    if [[ "$current_value" == *"<Super>"* || "$current_value" == *"Super_L"* || "$current_value" == *"Super_R"* ]]; then
      if ! set_gsettings_key "$schema" "$key" "[]"; then
        warn "Unable to disable Super-based binding $schema::$key"
        failed="true"
      fi
    fi
  done <<<"$key_list"

  [[ "$failed" == "false" ]]
}

capture_custom_bindings_once() {
  local current_value

  if run_root test -f "$CUSTOM_BINDINGS_BACKUP"; then
    return
  fi
  gsettings_schema_exists "$CUSTOM_BINDING_SCHEMA" || die "GNOME media-key settings are unavailable."
  gsettings_key_exists "$CUSTOM_BINDING_SCHEMA" custom-keybindings || die "GNOME custom keybindings are unavailable."

  current_value="$(gsettings get "$CUSTOM_BINDING_SCHEMA" custom-keybindings)"
  [[ "$current_value" != *"$CUSTOM_BINDING_BASE/kiosk-"* ]] || die "An existing custom shortcut uses the kiosk installer's reserved path prefix."
  validate_original_custom_bindings "$current_value"
  printf '%s\n' "$current_value" | write_root_file_atomic "$CUSTOM_BINDINGS_BACKUP" 600
}

validate_original_custom_bindings() {
  local remaining="$1"
  local path_pattern="'([^']+)'"
  local path
  local schema
  local binding
  local managed_accelerator
  local normalized_binding
  local normalized_managed

  while [[ "$remaining" =~ $path_pattern ]]; do
    path="${BASH_REMATCH[1]}"
    remaining="${remaining#*"${BASH_REMATCH[0]}"}"
    schema="$(managed_binding_schema "$path")"
    binding="$(gsettings get "$schema" binding 2>/dev/null)" || die "Unable to inspect existing custom shortcut: $path"
    normalized_binding="${binding//<Primary>/<Control>}"

    if [[ "$binding" == *"<Super>"* || "$binding" == *"Super_L"* || "$binding" == *"Super_R"* ]]; then
      die "Existing custom shortcut '$path' uses Super and conflicts with kiosk lockdown."
    fi
    [[ "$normalized_binding" != *"$RECOVERY_ACCELERATOR"* ]] || die "Existing custom shortcut '$path' conflicts with instructor recovery."

    if [[ "$LOCKDOWN_LEVEL" == "2" ]]; then
      for managed_accelerator in "${BLOCK_BINDING_KEYS[@]}"; do
        normalized_managed="${managed_accelerator//<Primary>/<Control>}"
        [[ "$normalized_binding" != *"$normalized_managed"* ]] || die "Existing custom shortcut '$path' conflicts with Level 2 binding $managed_accelerator."
      done
    fi
  done
}

append_gvariant_array_value() {
  local current_array="$1"
  local new_value="$2"

  [[ "$current_array" != "@as []" ]] || current_array="[]"
  if [[ "$current_array" == *"'$new_value'"* ]]; then
    REPLY="$current_array"
  elif [[ "$current_array" == "[]" ]]; then
    REPLY="['$new_value']"
  else
    REPLY="${current_array%]}, '$new_value']"
  fi
}

remove_gvariant_array_value() {
  local current_array="$1"
  local old_value="$2"
  local remaining
  local value_pattern="'([^']*)'"
  local value
  local updated_array="[]"

  [[ "$current_array" != "@as []" ]] || current_array="[]"
  remaining="$current_array"
  while [[ "$remaining" =~ $value_pattern ]]; do
    value="${BASH_REMATCH[1]}"
    remaining="${remaining#*"${BASH_REMATCH[0]}"}"
    if [[ "$value" != "$old_value" ]]; then
      append_gvariant_array_value "$updated_array" "$value"
      updated_array="$REPLY"
    fi
  done
  REPLY="$updated_array"
}

managed_binding_schema() {
  printf '%s.custom-keybinding:%s\n' "$CUSTOM_BINDING_SCHEMA" "$1"
}

reset_managed_custom_bindings() {
  local path
  local schema
  local id

  path="$RECOVERY_BINDING_PATH"
  schema="$(managed_binding_schema "$path")"
  reset_gsettings_key "$schema" name || true
  reset_gsettings_key "$schema" command || true
  reset_gsettings_key "$schema" binding || true

  for id in "${BLOCK_BINDING_IDS[@]}"; do
    path="$CUSTOM_BINDING_BASE/kiosk-block-$id/"
    schema="$(managed_binding_schema "$path")"
    reset_gsettings_key "$schema" name || true
    reset_gsettings_key "$schema" command || true
    reset_gsettings_key "$schema" binding || true
  done
}

configure_custom_binding() {
  local path="$1"
  local name="$2"
  local command="$3"
  local binding="$4"
  local schema

  schema="$(managed_binding_schema "$path")"
  set_gsettings_key "$schema" name "'$name'" || return 1
  set_gsettings_key "$schema" command "'$command'" || return 1
  set_gsettings_key "$schema" binding "'$binding'" || return 1
}

apply_managed_custom_bindings() {
  local binding_list
  local path
  local index

  run_root test -f "$CUSTOM_BINDINGS_BACKUP" || die "The original GNOME custom-keybinding list is missing."
  binding_list="$(run_root cat "$CUSTOM_BINDINGS_BACKUP")"
  reset_managed_custom_bindings

  configure_custom_binding \
    "$RECOVERY_BINDING_PATH" \
    "Kiosk Instructor Recovery Terminal" \
    "$TERMINAL_BIN" \
    "$RECOVERY_ACCELERATOR" || die "Unable to register the instructor recovery shortcut."
  append_gvariant_array_value "$binding_list" "$RECOVERY_BINDING_PATH"
  binding_list="$REPLY"

  if [[ "$LOCKDOWN_LEVEL" == "2" ]]; then
    for index in "${!BLOCK_BINDING_IDS[@]}"; do
      path="$CUSTOM_BINDING_BASE/kiosk-block-${BLOCK_BINDING_IDS[$index]}/"
      configure_custom_binding \
        "$path" \
        "${BLOCK_BINDING_NAMES[$index]}" \
        "/usr/bin/true" \
        "${BLOCK_BINDING_KEYS[$index]}" || die "Unable to register ${BLOCK_BINDING_NAMES[$index]}."
      append_gvariant_array_value "$binding_list" "$path"
      binding_list="$REPLY"
    done
  fi

  set_required_gsettings_key "$CUSTOM_BINDING_SCHEMA" custom-keybindings "$binding_list"
}

apply_level_one_lockdown() {
  local schema

  log "Applying lockdown level 1 (Activities and core GNOME Super navigation)..."
  set_required_gsettings_key "org.gnome.mutter" overlay-key "''"
  set_required_gsettings_key "org.gnome.desktop.interface" enable-hot-corners "false"
  set_required_gsettings_key "org.gnome.shell.keybindings" toggle-overview "[]"
  set_required_gsettings_key "org.gnome.shell.keybindings" toggle-application-view "[]"

  disable_binding_keys "org.gnome.shell.keybindings" \
    focus-active-notification \
    toggle-message-tray \
    shift-overview-up \
    shift-overview-down

  for schema in \
    org.gnome.shell.keybindings \
    org.gnome.desktop.wm.keybindings \
    org.gnome.mutter.keybindings \
    org.gnome.mutter.wayland.keybindings \
    org.gnome.settings-daemon.plugins.media-keys; do
    disable_super_bindings_in_schema "$schema" || die "Unable to complete Super-key lockdown for $schema."
  done
}

apply_level_two_lockdown() {
  local workspace

  log "Applying lockdown level 2 (common GNOME and browser escape shortcuts)..."
  disable_required_binding_keys "org.gnome.desktop.wm.keybindings" \
    close \
    cycle-windows \
    cycle-windows-backward \
    panel-run-dialog \
    show-desktop \
    switch-applications \
    switch-applications-backward

  disable_binding_keys "org.gnome.desktop.wm.keybindings" \
    activate-window-menu \
    always-on-top \
    begin-move \
    begin-resize \
    cycle-group \
    cycle-group-backward \
    cycle-panels \
    cycle-panels-backward \
    maximize \
    minimize \
    panel-main-menu \
    switch-group \
    switch-group-backward \
    switch-panels \
    switch-panels-backward \
    switch-to-workspace-down \
    switch-to-workspace-last \
    switch-to-workspace-left \
    switch-to-workspace-right \
    switch-to-workspace-up \
    switch-windows \
    switch-windows-backward \
    toggle-fullscreen \
    toggle-maximized \
    toggle-on-all-workspaces \
    unmaximize

  for workspace in 1 2 3 4 5 6 7 8 9 10 11 12; do
    disable_binding_keys "org.gnome.desktop.wm.keybindings" \
      "switch-to-workspace-$workspace" \
      "move-to-workspace-$workspace"
  done

  disable_binding_keys "org.gnome.settings-daemon.plugins.media-keys" \
    logout \
    screensaver \
    terminal
}

disable_screen_timeout_sleep_and_lock() {
  log "Disabling screen blanking, automatic suspend, and the lock screen..."
  set_required_gsettings_key "org.gnome.desktop.session" idle-delay "uint32 0"
  set_required_gsettings_key "org.gnome.desktop.screensaver" lock-enabled "false"
  set_required_gsettings_key "org.gnome.desktop.lockdown" disable-lock-screen "true"
  set_required_gsettings_key "org.gnome.settings-daemon.plugins.power" idle-dim "false"
  set_required_gsettings_key "org.gnome.settings-daemon.plugins.power" sleep-inactive-ac-type "'nothing'"
  set_required_gsettings_key "org.gnome.settings-daemon.plugins.power" sleep-inactive-battery-type "'nothing'"
}

user_theme_extension_enabled() {
  local enabled_list
  enabled_list="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || true)"
  [[ "$enabled_list" == *"'$USER_THEME_EXTENSION_UUID'"* ]]
}

user_theme_extension_disabled() {
  local disabled_list
  disabled_list="$(gsettings get org.gnome.shell disabled-extensions 2>/dev/null || true)"
  [[ "$disabled_list" == *"'$USER_THEME_EXTENSION_UUID'"* ]]
}

enable_user_theme_extension() {
  local enabled_list
  local disabled_list
  local initial_state
  initial_state="$(gsettings get org.gnome.shell disable-user-extensions 2>/dev/null || true)"
  if [[ "$initial_state" == "true" ]]; then
    set_required_gsettings_key "org.gnome.shell" disable-user-extensions "false"
  fi

  enabled_list="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null)" \
    || die "Unable to read GNOME's enabled extension list."
  disabled_list="$(gsettings get org.gnome.shell disabled-extensions 2>/dev/null)" \
    || die "Unable to read GNOME's disabled extension list."

  append_gvariant_array_value "$enabled_list" "$USER_THEME_EXTENSION_UUID"
  enabled_list="$REPLY"
  set_required_gsettings_key "org.gnome.shell" enabled-extensions "$enabled_list"

  remove_gvariant_array_value "$disabled_list" "$USER_THEME_EXTENSION_UUID"
  disabled_list="$REPLY"
  set_required_gsettings_key "org.gnome.shell" disabled-extensions "$disabled_list"

  user_theme_extension_enabled && ! user_theme_extension_disabled \
    || die "Unable to persist the enabled state for the user-theme GNOME Shell extension."
}

disable_user_theme_extension() {
  local enabled_list
  local disabled_list

  enabled_list="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null)" \
    || die "Unable to read GNOME's enabled extension list."
  disabled_list="$(gsettings get org.gnome.shell disabled-extensions 2>/dev/null)" \
    || die "Unable to read GNOME's disabled extension list."

  remove_gvariant_array_value "$enabled_list" "$USER_THEME_EXTENSION_UUID"
  enabled_list="$REPLY"
  set_required_gsettings_key "org.gnome.shell" enabled-extensions "$enabled_list"

  append_gvariant_array_value "$disabled_list" "$USER_THEME_EXTENSION_UUID"
  disabled_list="$REPLY"
  set_required_gsettings_key "org.gnome.shell" disabled-extensions "$disabled_list"

  ! user_theme_extension_enabled && user_theme_extension_disabled \
    || die "Unable to persist the disabled state for the user-theme GNOME Shell extension."
}

install_user_theme_files() {
  KIOSK_USER_THEME_DIR="$KIOSK_HOME/$USER_THEME_DIR_NAME/$USER_THEME_NAME"
  KIOSK_USER_THEME_CSS="$KIOSK_USER_THEME_DIR/$USER_THEME_GNOME_SHELL_SUBDIR/$USER_THEME_CSS_NAME"

  mkdir -p "$KIOSK_USER_THEME_DIR/$USER_THEME_GNOME_SHELL_SUBDIR"

  cat >"$KIOSK_USER_THEME_CSS" <<'EOF'
/* CTRL+ESC+HOST kiosk theme: hide the clickable Activities button. */
#panel .panel-button#panelActivities,
#panel .panel-button#panelActivities StBoxLayout,
#panel .panel-button#panelActivities .workspace-dot {
  opacity: 0 !important;
  width: 0 !important;
  height: 0 !important;
  padding: 0 !important;
  margin: 0 !important;
  border: 0 !important;
  min-width: 0 !important;
  min-height: 0 !important;
  -st-pointer-events: none !important;
}
EOF
  chmod 644 "$KIOSK_USER_THEME_CSS"
  log "Installed the kiosk GNOME Shell theme at $KIOSK_USER_THEME_DIR"
}

install_settings_desktop_mask() {
  local applications_dir="${SETTINGS_DESKTOP_MASK%/*}"
  local temporary

  [[ -n "$SETTINGS_DESKTOP_MASK" ]] || die "The Settings desktop-mask path was not initialized."
  mkdir -p "$applications_dir"
  if [[ -e "$SETTINGS_DESKTOP_MASK" || -L "$SETTINGS_DESKTOP_MASK" ]]; then
    [[ -f "$SETTINGS_DESKTOP_MASK" && ! -L "$SETTINGS_DESKTOP_MASK" ]] \
      || die "$SETTINGS_DESKTOP_MASK exists but is not a regular file."
    grep -Fxq "$SETTINGS_DESKTOP_MASK_MARKER" "$SETTINGS_DESKTOP_MASK" \
      || die "$SETTINGS_DESKTOP_MASK already exists and is not managed by the kiosk installer."
  fi

  temporary="$(/usr/bin/mktemp "$applications_dir/.gnome-settings-mask.XXXXXX")"
  cat >"$temporary" <<EOF
[Desktop Entry]
Type=Application
Name=Settings
Hidden=true
NoDisplay=true
$SETTINGS_DESKTOP_MASK_MARKER
EOF
  chmod 644 "$temporary"
  mv -f -- "$temporary" "$SETTINGS_DESKTOP_MASK"
  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$applications_dir" || warn "Unable to refresh the user desktop-file cache."
  fi
  log "Masked GNOME Settings from Shell application discovery: $SETTINGS_DESKTOP_MASK"
}

remove_settings_desktop_mask() {
  [[ -n "$SETTINGS_DESKTOP_MASK" ]] || die "The Settings desktop-mask path was not initialized."
  [[ -e "$SETTINGS_DESKTOP_MASK" || -L "$SETTINGS_DESKTOP_MASK" ]] || return 0
  [[ -f "$SETTINGS_DESKTOP_MASK" && ! -L "$SETTINGS_DESKTOP_MASK" ]] \
    || die "$SETTINGS_DESKTOP_MASK exists but is not a regular file."
  grep -Fxq "$SETTINGS_DESKTOP_MASK_MARKER" "$SETTINGS_DESKTOP_MASK" \
    || die "$SETTINGS_DESKTOP_MASK exists and is not managed by the kiosk installer."
  rm -f -- "$SETTINGS_DESKTOP_MASK"
  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "${SETTINGS_DESKTOP_MASK%/*}" || warn "Unable to refresh the user desktop-file cache."
  fi
  log "Removed the managed GNOME Settings desktop mask."
}

remove_user_theme_files() {
  KIOSK_USER_THEME_DIR="$KIOSK_HOME/$USER_THEME_DIR_NAME/$USER_THEME_NAME"
  if [[ -d "$KIOSK_USER_THEME_DIR" ]]; then
    rm -rf -- "$KIOSK_USER_THEME_DIR"
    log "Removed the kiosk GNOME Shell theme at $KIOSK_USER_THEME_DIR"
  fi
  KIOSK_USER_THEME_DIR=""
  KIOSK_USER_THEME_CSS=""
}

configure_gnome_clickable_lockdown() {
  if [[ "$DISABLE_GNOME_CLICKABLE" == "true" ]]; then
    log "Hiding the clickable Activities button (--disable-gnome-clickable)..."
    gsettings_schema_exists "$THEME_BASE_SCHEMA" \
      || die "The $THEME_BASE_SCHEMA schema is unavailable. Install $USER_THEME_EXTENSION_PACKAGE and re-run setup."
    enable_user_theme_extension
    install_user_theme_files
    install_settings_desktop_mask
    set_required_gsettings_key "$THEME_BASE_SCHEMA" "$THEME_BASE_KEY" "'$USER_THEME_NAME'"
    log "Activities button and Quick Settings gear hidden. The change applies on the next GNOME Shell restart or login."
  elif [[ "$GNOME_CLICKABLE_OVERRIDE_SEEN" == "true" ]]; then
    log "Re-enabling the clickable Activities button (--no-disable-gnome-clickable)..."
    if gsettings_schema_exists "$THEME_BASE_SCHEMA"; then
      reset_gsettings_key "$THEME_BASE_SCHEMA" "$THEME_BASE_KEY" || true
    fi
    if user_theme_extension_enabled || user_theme_extension_disabled; then
      disable_user_theme_extension
    fi
    remove_user_theme_files
    remove_settings_desktop_mask
    log "Activities button and Quick Settings gear restored. The change applies on the next GNOME Shell restart or login."
  fi
}

apply_lockdown() {
  capture_custom_bindings_once
  disable_screen_timeout_sleep_and_lock
  apply_level_one_lockdown
  if [[ "$LOCKDOWN_LEVEL" == "2" ]]; then
    apply_level_two_lockdown
  fi
  configure_gnome_clickable_lockdown
  apply_managed_custom_bindings
  log "Instructor recovery terminal: Ctrl+Alt+Shift+O"
}

maybe_reboot() {
  local answer

  case "$REBOOT_MODE" in
  yes)
    answer="yes"
    ;;
  no)
    answer="no"
    ;;
  ask)
    if [[ -t 0 ]]; then
      read -r -p "Reboot now to enter the fullscreen kiosk? [y/N]: " answer || answer="no"
    else
      answer="no"
      warn "No interactive terminal is available; skipping reboot. Use --reboot to automate it."
    fi
    ;;
  esac

  case "$answer" in
  y | Y | yes | YES)
    log "Rebooting into the kiosk..."
    if run_root systemctl reboot; then
      FIREFOX_WAS_RUNNING="false"
    else
      restart_stopped_kiosk_firefox
      die "Unable to reboot into the kiosk."
    fi
    ;;
  *)
    restart_stopped_kiosk_firefox
    log "Reboot skipped. Reboot later to verify GDM autologin and kiosk autostart."
    ;;
  esac
}

run_setup() {
  set_user_paths
  locate_source_html
  preflight
  run_root test ! -f "$CONFIG_FILE" || die "This account is already configured. Use 'kiosk reset' instead."
  ensure_state_directory
  backup_autostart_once
  capture_custom_bindings_once
  install_dependencies
  ensure_user_theme_extension
  resolve_browser
  resolve_firefox_profile
  install_kiosk_command
  configure_bash_alias
  install_kiosk_completion
  prepare_autostart_stage
  stop_running_kiosk_firefox
  configure_firefox_shortcuts
  generate_kiosk_files "$AUTOSTART_STAGE"
  configure_mail_handler
  configure_gdm_autologin
  apply_lockdown
  activate_autostart_stage
  save_configuration
  clear_bash_history

  log ""
  log "Kiosk setup completed successfully."
  log "Lockdown level: $LOCKDOWN_LEVEL"
  log "Browser: $BROWSER_NAME"
  log "App: $KIOSK_APP"
  if [[ "$TOUCHSCREEN_MODE" == "true" ]]; then
    log "Touchscreen Nautilus console path: enabled (--touchscreen)"
  fi
  if [[ "$DISABLE_GNOME_CLICKABLE" == "true" ]]; then
    log "Activities button and Settings gear: hidden (--disable-gnome-clickable)"
  fi
  log "Recovery: Ctrl+Alt+Shift+O, then run 'kiosk reset'"
  maybe_reboot
}

run_reset() {
  set_user_paths
  preflight
  load_saved_configuration
  set_user_paths
  locate_source_html
  install_dependencies
  ensure_user_theme_extension
  resolve_browser
  resolve_firefox_profile
  install_kiosk_command
  configure_bash_alias
  install_kiosk_completion
  prepare_autostart_stage
  stop_running_kiosk_firefox
  configure_firefox_shortcuts
  generate_kiosk_files "$AUTOSTART_STAGE"
  configure_mail_handler
  configure_gdm_autologin
  apply_lockdown
  activate_autostart_stage
  if [[ "$GNOME_CLICKABLE_OVERRIDE_SEEN" == "true" || "$TOUCHSCREEN_OPTION_SEEN" == "true" ]]; then
    save_configuration
    log "Saved updated kiosk options."
  fi
  clear_bash_history

  log ""
  log "Kiosk reset completed successfully."
  log "The original autostart baseline and managed kiosk launcher are restored."
  log "App: $KIOSK_APP"
  if [[ "$TOUCHSCREEN_MODE" == "true" ]]; then
    log "Touchscreen Nautilus console path: enabled (--touchscreen)"
  fi
  if [[ "$DISABLE_GNOME_CLICKABLE" == "true" ]]; then
    log "Activities button and Settings gear: hidden (--disable-gnome-clickable)"
  elif [[ "$GNOME_CLICKABLE_OVERRIDE_SEEN" == "true" ]]; then
    log "Activities button and Settings gear: visible (--no-disable-gnome-clickable)"
  fi
  log "Recovery: Ctrl+Alt+Shift+O, then run 'kiosk reset'"
  maybe_reboot
}

run_remove() {
  set_user_paths
  preflight

  if ! run_root test -f "$CONFIG_FILE"; then
    log "No completed kiosk setup was found. Nothing to remove."
    return 0
  fi

  if [[ -f "$AUTOSTART_DIR/$DESKTOP_FILE_NAME" ]]; then
    rm -f -- "$AUTOSTART_DIR/$DESKTOP_FILE_NAME"
    log "Removed the managed kiosk autostart entry: $AUTOSTART_DIR/$DESKTOP_FILE_NAME"
  fi

  run_root rm -f -- "$CONFIG_FILE"
  log "Cleared the saved kiosk configuration: $CONFIG_FILE"

  remove_kiosk_completion

  log ""
  log "Kiosk removal completed successfully."
  log "Choose the new app or install the new browser, then run first-time setup:"
  log "  ./prepare-kiosk.sh --level 2 --browser chrome --user kiosk --reboot"
  log "GDM autologin and GNOME lockdown remain until the next setup overwrites them."
}

main() {
  parse_arguments "$@"
  [[ "$EUID" -ne 0 ]] || die "Do not run this script with sudo. Run it as the logged-in kiosk user."
  [[ -x "$GETENT_BIN" && -x "$ID_BIN" ]] || die "Trusted id/getent utilities are required."
  trap cleanup_autostart_stage EXIT
  trap 'exit 130' HUP INT TERM

  case "$ACTION" in
  setup) run_setup ;;
  reset) run_reset ;;
  remove) run_remove ;;
  *) die "Unsupported action: $ACTION" ;;
  esac
}

main "$@"
