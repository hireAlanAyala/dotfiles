# colorpaper.sh - Dynamic Video Wallpaper Color Matching

Changes video wallpaper colors in real-time using mpvpaper's hue rotation filter.

## Usage

```bash
colorpaper.sh <hex_color> [video_path]
```

### Examples

```bash
# Set wallpaper to yellow (default)
colorpaper.sh "#FFCC00"

# Set wallpaper to green
colorpaper.sh "#66DE84"

# Set wallpaper to blue
colorpaper.sh "#4488FF"

# Use a different video
colorpaper.sh "#FFCC00" ~/Videos/my-video.mp4
```

## How It Works

1. **Extract target hue** from the hex color (converts RGB → HSV)
2. **Calculate rotation** needed from video's base hue (20° for space-hud)
3. **Apply filter** via mpvpaper: `--vf=hflip,hue=h=ROTATION`

### Color Reference

| Color   | Hex       | Hue  | Rotation |
|---------|-----------|------|----------|
| Yellow  | `#FFCC00` | 48°  | +28°     |
| Orange  | `#FF8800` | 32°  | +12°     |
| Green   | `#66DE84` | 135° | +115°    |
| Cyan    | `#00CCFF` | 192° | +172°    |
| Blue    | `#4488FF` | 220° | +200°    |
| Magenta | `#FF44AA` | 330° | +310°    |

## Dependencies

- `mpvpaper` - video wallpaper daemon
- `python3` - for hue calculation
- Video file (default: `~/Downloads/space-science-hud.1920x1080.mp4`)

## Customizing for Different Videos

Edit `VIDEO_BASE_HUE` in the script to match your video's dominant color:

```bash
VIDEO_BASE_HUE=20  # Orange-based video (~20°)
```

To find a video's base hue, sample its dominant color and convert to HSV.
