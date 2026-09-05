#!/bin/bash
#
# lidkeeper — toggle macOS lid-close sleep from the menu bar.
#
# Touches exactly one pmset key: `disablesleep`. The user's other power
# settings are never read-modified-written, so turning this off leaves the
# machine on stock behaviour.
#
# <bitbar.title>lidkeeper</bitbar.title>
# <bitbar.version>1.0.0</bitbar.version>
# <bitbar.author>lidkeeper</bitbar.author>
# <bitbar.desc>Toggle lid-close sleep from the menu bar (works on battery too)</bitbar.desc>
# <bitbar.dependencies>bash</bitbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>

export PATH=/usr/bin:/bin:/usr/sbin:/sbin
PMSET=/usr/bin/pmset
ICONS="${LIDKEEPER_ICONS:-$HOME/.config/lidkeeper/icons}"
SELF="${BASH_SOURCE[0]}"

# `disablesleep` is undocumented: pmset accepts it but never echoes it back
# through `pmset -g`, `-g custom` or `-g live`. The live value is exposed by
# IOKit instead, as IOPMrootDomain's SleepDisabled property.
read_state() {
  if ioreg -n IOPMrootDomain -r -d 1 2>/dev/null | grep -q '"SleepDisabled" = Yes'; then
    echo 1
  else
    echo 0
  fi
}

# -n keeps this non-interactive: without the sudoers rule it fails fast
# instead of hanging the menu bar on a password prompt.
can_sudo() { sudo -n -l "$PMSET" -a disablesleep 1 >/dev/null 2>&1; }
icon()     { base64 -i "$ICONS/$1.png" 2>/dev/null | tr -d '\n'; }

case "$1" in
  on)     sudo -n "$PMSET" -a disablesleep 1 >/dev/null 2>&1; exit $? ;;
  off)    sudo -n "$PMSET" -a disablesleep 0 >/dev/null 2>&1; exit $? ;;
  status) read_state; exit 0 ;;
  doctor)
    st=$(read_state)
    printf 'lid stays awake : %s\n' "$([ "$st" = 1 ] && echo 'ON  (closing the lid will NOT sleep)' || echo 'OFF (system default)')"
    printf 'IOKit truth     : %s\n' "$(ioreg -n IOPMrootDomain -r -d 1 2>/dev/null | awk -F'= ' '/SleepDisabled/{print $2}')"
    printf 'menu bar app    : %s\n' "$(pgrep -qx SwiftBar && echo 'running' || echo 'NOT running  -> open -a SwiftBar')"
    printf 'sudo rule       : %s\n' "$(can_sudo && echo 'ok' || echo 'MISSING -> re-run install.sh')"
    printf 'icons           : %s\n' "$([ -f "$ICONS/busy.png" ] && echo "ok ($ICONS)" || echo "MISSING -> re-run install.sh")"
    real="$SELF"; [ -L "$real" ] && real="$(readlink "$real")"
    printf 'plugin          : %s\n' "$real"
    exit 0 ;;
  toggle) [ "$(read_state)" = "1" ] && exec "$SELF" off || exec "$SELF" on ;;
esac

if ! can_sudo; then
  echo " | templateImage=$(icon warn)"
  echo "---"
  echo "Not authorised — run install.sh | color=#b42318"
  exit 0
fi

if [ "$(read_state)" = "1" ]; then
  echo " | templateImage=$(icon busy)"
  echo "---"
  echo "Awake | checked=true bash=\"$SELF\" param1=off terminal=false refresh=true"
else
  echo " | templateImage=$(icon sleep)"
  echo "---"
  echo "Awake | bash=\"$SELF\" param1=on terminal=false refresh=true"
fi
