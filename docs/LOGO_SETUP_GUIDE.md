# NeurX Code — Logo & Icon Configuration Guide

## Directory Structure

已创建的推荐目录结构：

```
neurx-code/
├── assets/                           ← 应用图标和资源
│   ├── README.md                    (此文件)
│   ├── app.icns                     (macOS 应用图标 - 需添加)
│   ├── app.ico                      (Windows 图标 - 需添加)
│   └── icons/
│       ├── logo-light.svg           (Light 主题 logo)
│       ├── logo-dark.svg            (Dark 主题 logo)
│       └── splash-logo.svg          (启动屏幕 logo)
│
└── content/
    └── assets/                      ← QML UI 资源
        ├── splash-logo.svg
        └── loading-spinner.svg
```

## 文件放置建议

### 1. **应用启动 Icon (macOS/Windows)**
- **位置**: `assets/app.icns` (macOS) 或 `assets/app.ico` (Windows)
- **用途**: 
  - Dock 中的应用图标
  - Finder 中显示的应用图标
  - 系统菜单和快捷方式中的图标
- **格式**: 
  - `.icns` 文件用于 macOS
  - `.ico` 文件用于 Windows

### 2. **启动屏幕 Logo**
- **位置**: `content/assets/splash-logo.svg`
- **用途**: 在 QML 启动屏幕中显示
- **格式**: SVG 或 PNG (建议 SVG 以支持所有分辨率)

### 3. **UI Logo (Light/Dark)**
- **位置**: `assets/icons/logo-light.svg` 和 `assets/icons/logo-dark.svg`
- **用途**: 在应用界面中显示品牌 logo（菜单栏、对话框等）
- **格式**: SVG (支持主题切换)

## 集成步骤

### Step 1: 准备图标文件

#### macOS app.icns 生成
```bash
# 假设你有一个 1024×1024 的 PNG 文件 neurx-logo.png

# 创建 iconset 文件夹
mkdir neurx-code.iconset

# 使用 sips 生成多个尺寸
sips -z 16 16     neurx-logo.png --out neurx-code.iconset/icon_16x16.png
sips -z 32 32     neurx-logo.png --out neurx-code.iconset/icon_32x32.png
sips -z 64 64     neurx-logo.png --out neurx-code.iconset/icon_64x64.png
sips -z 128 128   neurx-logo.png --out neurx-code.iconset/icon_128x128.png
sips -z 256 256   neurx-logo.png --out neurx-code.iconset/icon_256x256.png
sips -z 512 512   neurx-logo.png --out neurx-code.iconset/icon_512x512.png
sips -z 1024 1024 neurx-logo.png --out neurx-code.iconset/icon_1024x1024.png

# 转换为 .icns
iconutil -c icns neurx-code.iconset -o assets/app.icns

# 清理
rm -rf neurx-code.iconset
```

#### Windows app.ico 生成
- 使用在线工具 (如 icoconvert.com) 或 ImageMagick: `convert logo.png -define icon:auto-resize=256,128,96,64,48,32,16 app.ico`

### Step 2: 放置文件

1. 将 `app.icns` 放在 `assets/` 目录
2. 将 SVG logo 放在 `assets/icons/` 目录
3. 将启动屏幕 logo 放在 `content/assets/` 目录

### Step 3: 构建

CMakeLists.txt 已配置为自动查找这些文件：
```bash
cd neurx-code
make mac
```

## CMakeLists.txt 配置说明

修改后的 CMakeLists.txt 包含：

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

## QML 中使用 Logo

### 启动屏幕
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

### 主应用
```qml
import QtQuick
import QtQuick.Controls

Button {
    icon.source: Theme.isDarkTheme 
               ? "assets/icons/logo-dark.svg"
               : "assets/icons/logo-light.svg"
}
```

## 检查清单

- [ ] 创建 `assets/` 目录 ✓ (已完成)
- [ ] 创建 `assets/icons/` 目录 ✓ (已完成)
- [ ] 创建 `content/assets/` 目录 ✓ (已完成)
- [ ] 生成 `app.icns` 文件
- [ ] 生成 `app.ico` 文件 (可选)
- [ ] 添加 SVG logo 文件
- [ ] 更新 CMakeLists.txt (✓ 已完成)
- [ ] 重新编译应用
- [ ] 测试应用图标在 Dock 中正确显示
- [ ] 测试启动屏幕 logo 显示

## 相关文件

- CMakeLists.txt: 应用构建配置
- content/App.qml: 主应用界面
- assets/README.md: 资源详细说明
