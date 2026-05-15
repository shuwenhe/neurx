Neurx prebuilt binaries directory

This folder holds platform-specific prebuilt executables and archives.
Do not commit large binaries to Git; use CI releases or external artifact storage.

Layout:
- neurx/bin/<platform-arch>/ (e.g. linux-x86_64, macos-arm64, windows-x86_64)

Each platform folder should contain a `RELEASES.md` or a versioned archive.
