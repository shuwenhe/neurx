# NeurX Code Assets

This directory contains application assets including icons, logos, and images.

## Directory Structure

```
assets/
├── app.icns              - macOS application icon (required for .app bundle)
├── app.ico               - Windows application icon (optional)
├── icons/
│   ├── logo-light.svg    - Light theme logo for UI
│   ├── logo-dark.svg     - Dark theme logo for UI
│   └── splash-logo.svg   - Splash screen logo
└── images/
    └── (other images)
```

## Icon Specifications

### app.icns (macOS)
- Format: ICNS (Apple Icon Image Format)
- Sizes: Multiple (16×16, 32×32, 64×64, 128×128, 256×256, 512×512, 1024×1024)
- Generated from: A 1024×1024 PNG using `iconutil` command
- Usage: Application icon in Finder, Dock, and system menus

### app.ico (Windows)
- Format: ICO
- Sizes: 256×256, 128×128, 64×64, 32×32, 16×16
- Usage: Taskbar and File Explorer

### SVG Logos
- logo-light.svg: Use for light/default themes
- logo-dark.svg: Use for dark themes
- splash-logo.svg: Display on application startup

## Creating app.icns from PNG

```bash
# 1. Create a 1024×1024 PNG (logo.png)
# 2. Create iconset folder
mkdir neurx-code.iconset

# 3. Generate different sizes
sips -z 16 16     logo.png --out neurx-code.iconset/icon_16x16.png
sips -z 32 32     logo.png --out neurx-code.iconset/icon_32x32.png
sips -z 64 64     logo.png --out neurx-code.iconset/icon_64x64.png
sips -z 128 128   logo.png --out neurx-code.iconset/icon_128x128.png
sips -z 256 256   logo.png --out neurx-code.iconset/icon_256x256.png
sips -z 512 512   logo.png --out neurx-code.iconset/icon_512x512.png
sips -z 1024 1024 logo.png --out neurx-code.iconset/icon_1024x1024.png

# 4. Convert to .icns
iconutil -c icns neurx-code.iconset -o app.icns

# 5. Clean up
rm -rf neurx-code.iconset
```

## CMakeLists.txt Integration

The app.icns file is referenced in CMakeLists.txt:
```cmake
MACOSX_BUNDLE_ICON_FILE "AppIcon"
```

The executable needs to be linked with the icon resource during the build process.
