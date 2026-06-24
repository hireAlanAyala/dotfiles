#!/usr/bin/env bash
# Launch Moonlight with a bitrate chosen by which WiFi network you're on.
#
# Why SSID and not raw "WiFi speed": the radio link rate is never the
# bottleneck on a decent network, and the real bottleneck (the Tailscale path
# to the host) can't be measured locally. Which network you're on is the
# signal that actually predicts whether you should dial back.
#
# Safe by design:
#   - edits ONLY the `bitrate=` line (anchored sed) -> cannot touch the TLS
#     key/cert blocks stored in the same conf file
#   - edits only while Moonlight is closed -> Moonlight can't clobber it on exit
#   - ALWAYS launches Moonlight, even if detection fails (no set -e)

CONF="$HOME/.config/Moonlight Game Streaming Project/Moonlight.conf"
MOONLIGHT="/usr/bin/moonlight"

# --- bitrate table (kbps) ------------------------------------------------
# One entry per known network. Anything not listed uses DEFAULT.
# Tune these to taste; raise home once you've confirmed the link to homebase
# can sustain it.
declare -A BITRATE=(
  ["I'm tired of this grandpa"]=20000   # home
)
DEFAULT=5000   # unknown / public / hotspot — stay conservative
# -------------------------------------------------------------------------

iface=$(iw dev 2>/dev/null | awk '/Interface/{print $2; exit}')
ssid=$(iw dev "$iface" link 2>/dev/null | sed -n 's/^[[:space:]]*SSID: //p')

if [[ -n "$ssid" ]]; then
  rate="${BITRATE[$ssid]:-$DEFAULT}"
  if [[ -f "$CONF" ]] && grep -q '^bitrate=' "$CONF" && ! pgrep -x moonlight >/dev/null; then
    sed -i "s/^bitrate=.*/bitrate=$rate/" "$CONF"
    echo "moonlight: SSID '$ssid' -> bitrate ${rate} kbps" >&2
  fi
fi

exec "$MOONLIGHT" "$@"
