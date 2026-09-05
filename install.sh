#!/usr/bin/env bash
#
# lidkeeper installer.
#
# Installs the menu bar plugin, its icons, and a tightly scoped sudoers rule
# that lets the plugin flip `pmset disablesleep` without a password prompt.
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PMSET=/usr/bin/pmset
ICON_DIR="$HOME/.config/lidkeeper/icons"
SUDOERS_FILE=/etc/sudoers.d/lidkeeper
SWIFTBAR_ID=com.ameba.SwiftBar
PLUGIN_NAME=lidkeeper.10s.sh

say()  { printf '  %s\n' "$*"; }
step() { printf '\n\033[1m==>\033[0m %s\n' "$*"; }
die()  { printf '\n\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# --- preflight ---------------------------------------------------------------
step "Checking prerequisites"

[ "$(uname -s)" = "Darwin" ] || die "lidkeeper is macOS-only."

# Running the whole script under sudo would leave root-owned files in $HOME.
# We escalate only for the sudoers install, and only when needed.
[ "$(id -u)" -ne 0 ] || die "Do not run this with sudo. It will ask for your password when it needs to."

[ -x "$PMSET" ] || die "$PMSET not found."
say "macOS $(sw_vers -productVersion), user $(id -un)"

if [ ! -d /Applications/SwiftBar.app ]; then
  say "SwiftBar is not installed."
  if command -v brew >/dev/null 2>&1; then
    printf '  Install it with Homebrew now? [y/N] '
    read -r reply
    case "$reply" in
      [yY]*) brew install --cask swiftbar ;;
      *) die "SwiftBar is required. Install it, then re-run this script." ;;
    esac
  else
    die "SwiftBar is required: https://swiftbar.app (or 'brew install --cask swiftbar')"
  fi
fi
say "SwiftBar found"

# --- resolve the plugin directory --------------------------------------------
step "Resolving SwiftBar plugin directory"

PLUGIN_DIR="$(defaults read "$SWIFTBAR_ID" PluginDirectory 2>/dev/null || true)"
if [ -z "$PLUGIN_DIR" ]; then
  PLUGIN_DIR="$HOME/.config/swiftbar-plugins"
  say "Not configured yet — using $PLUGIN_DIR"
  mkdir -p "$PLUGIN_DIR"
  defaults write "$SWIFTBAR_ID" PluginDirectory -string "$PLUGIN_DIR"
else
  say "$PLUGIN_DIR"
  mkdir -p "$PLUGIN_DIR"
fi

# --- icons and plugin --------------------------------------------------------
step "Installing icons"
mkdir -p "$ICON_DIR"
for n in busy sleep warn; do
  [ -f "$REPO/icons/$n.png" ] || die "missing icons/$n.png — repo is incomplete"
  install -m 0644 "$REPO/icons/$n.png" "$ICON_DIR/$n.png"
done
say "$ICON_DIR"

step "Installing plugin"
install -m 0755 "$REPO/plugin/$PLUGIN_NAME" "$PLUGIN_DIR/$PLUGIN_NAME"
say "$PLUGIN_DIR/$PLUGIN_NAME"

# --- sudoers rule ------------------------------------------------------------
step "Installing sudoers rule"

# Scoped to two exact command lines. No other pmset setting is reachable
# through this rule, and no other command is granted at all.
TMP_SUDOERS="$(mktemp -t lidkeeper.sudoers)"
trap 'rm -f "$TMP_SUDOERS"' EXIT
cat > "$TMP_SUDOERS" <<EOF
# lidkeeper: allow toggling only the pmset disablesleep key without a password.
# Installed by lidkeeper's install.sh. Remove with uninstall.sh.
$(id -un) ALL=(root) NOPASSWD: $PMSET -a disablesleep 0
$(id -un) ALL=(root) NOPASSWD: $PMSET -a disablesleep 1
EOF

# Never install an unvalidated sudoers file: a syntax error there can lock
# you out of sudo entirely.
visudo -c -f "$TMP_SUDOERS" >/dev/null || die "generated sudoers rule failed validation; nothing was installed"
say "Syntax validated"

# The target must NOT contain a dot: sudo skips files in sudoers.d whose
# names contain '.' or end in '~' (see `man sudoers`).
say "Requesting privileges to write $SUDOERS_FILE"
sudo install -m 0440 -o root -g wheel "$TMP_SUDOERS" "$SUDOERS_FILE"
say "Installed"

# --- CLI entry point ---------------------------------------------------------
step "Installing CLI"

# A symlink, not a copy: the plugin stays the single source of truth. This is
# the query path that survives SwiftBar crashing, quitting, or being removed.
sudo mkdir -p /usr/local/bin
sudo ln -sf "$PLUGIN_DIR/$PLUGIN_NAME" /usr/local/bin/lidkeeper
say "/usr/local/bin/lidkeeper -> $PLUGIN_DIR/$PLUGIN_NAME"

# --- restart SwiftBar --------------------------------------------------------
step "Restarting SwiftBar"
pkill -x SwiftBar 2>/dev/null || true
sleep 1
open -a SwiftBar
sleep 2

# --- verify ------------------------------------------------------------------
step "Verifying"
if sudo -n -l "$PMSET" -a disablesleep 1 >/dev/null 2>&1; then
  say "Passwordless toggle: OK"
else
  die "sudoers rule is not taking effect. Check $SUDOERS_FILE"
fi
say "Current state: $("$PLUGIN_DIR/$PLUGIN_NAME" status) (0 = normal, 1 = lid stays awake)"

printf '\n\033[32mDone.\033[0m Look for the laptop icon in your menu bar.\n'
printf 'Click it to toggle. Run ./uninstall.sh to remove everything.\n\n'
