#!/usr/bin/env bash
#
# lidkeeper uninstaller.
#
# Order matters: the lid-awake state is cleared BEFORE the sudoers rule is
# removed, otherwise a machine left in "lid stays awake" mode would keep that
# setting with no icon left to indicate it and no passwordless way to undo it.
#
set -euo pipefail

PMSET=/usr/bin/pmset
ICON_DIR="$HOME/.config/lidkeeper/icons"
SUDOERS_FILE=/etc/sudoers.d/lidkeeper
SWIFTBAR_ID=com.ameba.SwiftBar
PLUGIN_NAME=lidkeeper.10s.sh

say()  { printf '  %s\n' "$*"; }
step() { printf '\n\033[1m==>\033[0m %s\n' "$*"; }

[ "$(id -u)" -ne 0 ] || { printf 'Do not run this with sudo.\n' >&2; exit 1; }

# --- clear the state first ---------------------------------------------------
step "Restoring default lid behaviour"
state="$("$PMSET" -g | awk '/disablesleep/ {print $2; f=1} END {if (!f) print 0}')"
if [ "$state" = "1" ]; then
  if sudo -n "$PMSET" -a disablesleep 0 >/dev/null 2>&1; then
    say "disablesleep 1 -> 0 (via the sudoers rule, no password needed)"
  else
    say "Need privileges to clear disablesleep:"
    sudo "$PMSET" -a disablesleep 0
    say "disablesleep 1 -> 0"
  fi
else
  say "Already at the default (disablesleep 0)"
fi

# --- remove files ------------------------------------------------------------
step "Removing plugin"
PLUGIN_DIR="$(defaults read "$SWIFTBAR_ID" PluginDirectory 2>/dev/null || echo "$HOME/.config/swiftbar-plugins")"
if [ -f "$PLUGIN_DIR/$PLUGIN_NAME" ]; then
  rm -f "$PLUGIN_DIR/$PLUGIN_NAME"
  say "Removed $PLUGIN_DIR/$PLUGIN_NAME"
else
  say "Not present"
fi

step "Removing icons"
if [ -d "$ICON_DIR" ]; then
  rm -rf "$ICON_DIR"
  rmdir "$HOME/.config/lidkeeper" 2>/dev/null || true
  say "Removed $ICON_DIR"
else
  say "Not present"
fi

step "Removing CLI"
if [ -L /usr/local/bin/lidkeeper ]; then
  sudo rm -f /usr/local/bin/lidkeeper
  say "Removed /usr/local/bin/lidkeeper"
else
  say "Not present"
fi

step "Removing sudoers rule"
if [ -f "$SUDOERS_FILE" ]; then
  sudo rm -f "$SUDOERS_FILE"
  say "Removed $SUDOERS_FILE"
else
  say "Not present"
fi

step "Restarting SwiftBar"
pkill -x SwiftBar 2>/dev/null || true
sleep 1
open -a SwiftBar 2>/dev/null || true

printf '\n\033[32mDone.\033[0m Lid behaviour is back to the system default.\n'
printf 'SwiftBar itself was left installed (brew uninstall --cask swiftbar to remove it).\n\n'
