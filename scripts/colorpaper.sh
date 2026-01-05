#!/bin/bash
# Usage: colorpaper.sh <hex_color> <video_path>
# Example: colorpaper.sh "#FFCC00" ~/Downloads/video.mp4

COLOR="${1:-#FFCC00}"
VIDEO="${2:-$HOME/Downloads/space-science-hud.1920x1080.mp4}"
VIDEO_BASE_HUE=20  # The space HUD video's base hue (orange ~20°)

# Convert hex to hue
hex_to_hue() {
    local hex="${1#\#}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    
    python3 -c "
from colorsys import rgb_to_hsv
r, g, b = $r/255, $g/255, $b/255
h, s, v = rgb_to_hsv(r, g, b)
print(int(h * 360))
"
}

TARGET_HUE=$(hex_to_hue "$COLOR")
ROTATION=$((TARGET_HUE - VIDEO_BASE_HUE))

echo "Target color: $COLOR (hue: $TARGET_HUE°)"
echo "Rotation: $ROTATION°"

pkill mpvpaper 2>/dev/null
mpvpaper -o "--loop --vf=hflip,hue=h=$ROTATION" '*' "$VIDEO" &
echo "Wallpaper set!"
