#!/bin/bash
# Toggle shader based on active workspace
# Workspace 1 = shader on, others = shader off

SHADER="$HOME/.config/hypr/shaders/neon.glsl"

apply_shader() {
    local workspace="$1"
    if [[ "$workspace" == "1" ]]; then
        hyprctl keyword decoration:screen_shader "$SHADER" >/dev/null
    else
        hyprctl keyword decoration:screen_shader "" >/dev/null
    fi
}

# Apply for current workspace on start
current=$(hyprctl activeworkspace -j | jq -r '.id')
apply_shader "$current"

# Listen for workspace changes (only match workspace>>N, not workspacev2 etc)
socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
    if [[ "$line" =~ ^workspace\>\>([0-9]+)$ ]]; then
        apply_shader "${BASH_REMATCH[1]}"
    fi
done
