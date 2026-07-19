# NeurX Code — Logo & Icon Configuration Guide

## Directory Structure

English textrecommendeddirectoryEnglish text:

```
neurx-code/
├── assets/                           ← English text
│   ├── README.md                    (English textfile)
│   ├── app.icns                     (macOS English text - English text)
│   ├── app.ico                      (Windows English text - English text)
│   └── icons/
│       ├── logo-light.svg           (Light mainEnglish text logo)
│       ├── logo-dark.svg            (Dark mainEnglish text logo)
│       └── splash-logo.svg          (startEnglish text logo)
│
└── content/
    └── assets/                      ← QML UI English text
        ├── splash-logo.svg
        └── loading-spinner.svg
```

## fileEnglish text

### 1. **English textstart Icon (macOS/Windows)**
- **English text**: `assets/app.icns` (macOS) English text `assets/app.ico` (Windows)
- **English text**:
  - Dock English text
  - Finder English text
  - systemEnglish text
- **English text**:
  - `.icns` fileEnglish text macOS
  - `.ico` fileEnglish text Windows

### 2. **startEnglish text Logo**
- **English text**: `content/assets/splash-logo.svg`
- **English text**: English text QML startEnglish text
- **English text**: SVG English text PNG (English text SVG English textsupportEnglish text)

### 3. **UI Logo (Light/Dark)**
- **English text**: `assets/icons/logo-light.svg` English text `assets/icons/logo-dark.svg`
- **English text**: English text logo(English text, English text)
- **English text**: SVG (supportmainEnglish text)

## English textstepEnglish text

### Step 1: English textfile

#### macOS app.icns generate
```bash
# English text 1024×1024 English text PNG file neurx-logo.png

# English text iconset fileEnglish text
mkdir neurx-code.iconset

# use sips generateEnglish text
sips -z 16 16     neurx-logo.png --out neurx-code.iconset/icon_16x16.png
sips -z 32 32     neurx-logo.png --out neurx-code.iconset/icon_32x32.png
sips -z 64 64     neurx-logo.png --out neurx-code.iconset/icon_64x64.png
sips -z 128 128   neurx-logo.png --out neurx-code.iconset/icon_128x128.png
sips -z 256 256   neurx-logo.png --out neurx-code.iconset/icon_256x256.png
sips -z 512 512   neurx-logo.png --out neurx-code.iconset/icon_512x512.png
sips -z 1024 1024 neurx-logo.png --out neurx-code.iconset/icon_1024x1024.png

# English text .icns
iconutil -c icns neurx-code.iconset -o assets/app.icns

# English text
rm -rf neurx-code.iconset
```

#### Windows app.ico generate
- useEnglish texttool (English text icoconvert.com) English text ImageMagick: `convert logo.png -define icon:auto-resize=256,128,96,64,48,32,16 app.ico`

### Step 2: English textfile

1. English text `app.icns` English text `assets/` directory
2. English text SVG logo English text `assets/icons/` directory
3. English textstartEnglish text logo English text `content/assets/` directory

### Step 3: English text

CMakeLists.txt English textconfigurationEnglish textfile:
```bash
cd neurx-code
make mac
```

## CMakeLists.txt configurationexplanation

English text CMakeLists.txt English text:

```cmake
# macOS icon
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/app.icns")
    set_source_files_properties(
        "${CMAKE_CURRENT_SOURCE_DIR}/assets/app.icns"
        PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources
    )
    target_sources(neurx-codeApp PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/assets/app.icns")
endif()

# Windows icon (through app.rc resource file)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/app.rc")
    target_sources(neurx-codeApp PRIVATE assets/app.rc)
endif()
```

## QML English textuse Logo

### startEnglish text
```qml
import QtQuick
import QtQuick.Controls

Item {
    Image {
        source: "assets/splash-logo.svg"
        width: 200
        height: 200
        anchors.centerIn: parent
    }
}
```

### mainEnglish text
```qml
import QtQuick
import QtQuick.Controls

Button {
    icon.source: Theme.isDarkTheme
               ? "assets/icons/logo-dark.svg"
               : "assets/icons/logo-light.svg"
}
```

## English text

- [ ] English text `assets/` directory ✓ (English text)
- [ ] English text `assets/icons/` directory ✓ (English text)
- [ ] English text `content/assets/` directory ✓ (English text)
- [ ] generate `app.icns` file
- [ ] generate `app.ico` file (English text)
- [ ] English text SVG logo file
- [ ] English text CMakeLists.txt (✓ English text)
- [ ] English textcompileEnglish text
- [ ] testEnglish text Dock English text
- [ ] teststartEnglish text logo English text

## English textfile

- CMakeLists.txt: English textconfiguration
- content/App.qml: mainEnglish text
- assets/README.md: English textexplanation
