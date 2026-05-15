# Qt Setup Scripts

## Linux and macOS

Run:

```bash
cd /app/neurx/qt
bash scripts/setup_qt_env.sh
source .env.qt
cmake -S . -B build
cmake --build build
```

## Windows PowerShell

Run:

```powershell
cd C:\\app\\neurx\\qt
powershell -ExecutionPolicy Bypass -File .\\scripts\\setup_qt_env.ps1
cmake -S . -B build
cmake --build build
```

If Qt6 is installed in a custom location, pass the Qt6 config directory:

```powershell
powershell -ExecutionPolicy Bypass -File .\\scripts\\setup_qt_env.ps1 -Qt6Dir "C:\\Qt\\6.7.2\\msvc2022_64\\lib\\cmake\\Qt6"
```
