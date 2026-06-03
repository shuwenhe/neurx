cmake_minimum_required(VERSION 3.21.1)

option(LINK_INSIGHT "Link Qt Insight Tracker library" ON)
option(BUILD_QDS_COMPONENTS "Build design studio components" ON)

project(neurx-codeApp LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Qml Quick Network Concurrent)
find_package(Qt6 OPTIONAL_COMPONENTS WebSockets)

find_path(SQLITE3_INCLUDE_DIR
    NAMES sqlite3.h
    HINTS
        "C:/Users/Public/qt/Tools/mingw1310_64/opt/include"
        "C:/Program Files/msys64/mingw64/include"
)

find_library(SQLITE3_LIBRARY
    NAMES sqlite3 libsqlite3
    HINTS
        "C:/Users/Public/qt/Tools/mingw1310_64/opt/lib"
        "C:/Program Files/msys64/mingw64/lib"
)

if(NOT SQLITE3_INCLUDE_DIR OR NOT SQLITE3_LIBRARY)
    message(FATAL_ERROR
        "[neurx] SQLite3 development files were not found. "
        "Expected sqlite3.h and a sqlite3 library in a configured toolchain path.")
endif()

add_library(sqlite3 UNKNOWN IMPORTED)
set_target_properties(sqlite3 PROPERTIES
    IMPORTED_LOCATION "${SQLITE3_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${SQLITE3_INCLUDE_DIR}"
)

if (Qt6_VERSION VERSION_GREATER_EQUAL 6.3)
    qt_standard_project_setup()
endif()

# Use GLOB_RECURSE to find all sources, then filter out problematic files
file(GLOB_RECURSE NEURX_CORE_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp"
)
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "/src/main\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "/src/bridge/")
# Temporarily exclude files with known compilation issues
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DefaultToolRegistry\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DefaultExecutionEngine\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DefaultIntegrationOrchestrator\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DefaultGoalManager\\.cpp$")
list(FILTER NEURX_CORE_SOURCES EXCLUDE REGEX "DefaultLLMExtensions\\.cpp$")

add_library(neurx_core STATIC
    ${NEURX_CORE_SOURCES}
)

target_include_directories(neurx_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(neurx_core PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6::Concurrent
    sqlite3
)

set_target_properties(neurx_core PROPERTIES
    POSITION_INDEPENDENT_CODE ON
)

add_library(neurx_ui STATIC
    src/bridge/AgentController.cpp
    src/bridge/SyntaxHighlighter.cpp
)

target_include_directories(neurx_ui PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(neurx_ui PUBLIC
    neurx_core
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
)

set_target_properties(neurx_ui PROPERTIES
    POSITION_INDEPENDENT_CODE ON
)

qt_add_executable(neurx-codeApp
    src/main.cpp
)

target_link_libraries(neurx-codeApp PRIVATE
    neurx_ui
    neurx_core
)

qt_add_resources(neurx-codeApp "configuration"
    PREFIX "/"
    FILES
        qtquickcontrols2.conf
)

target_link_libraries(neurx-codeApp PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Network
    Qt6::Concurrent
)

# Optional WebSockets support
if(Qt6WebSockets_FOUND)
    target_link_libraries(neurx-codeApp PRIVATE Qt6::WebSockets)
    target_compile_definitions(neurx-codeApp PRIVATE NEURX_HAS_WEBSOCKETS)
endif()

# ── Platform-specific packaging ───────────────────────────────────────────────
if(APPLE)
    set_target_properties(neurx-codeApp PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "NeurX Code"
        MACOSX_BUNDLE_BUNDLE_VERSION "1.0.0"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0"
        MACOSX_BUNDLE_GUI_IDENTIFIER "ai.neurx.code"
        MACOSX_BUNDLE_ICON_FILE "AppIcon"
    )
    # Embed Qt plugins into the .app bundle
    qt_generate_deploy_app_script(
        TARGET neurx-codeApp
        OUTPUT_SCRIPT deploy_script
        NO_UNSUPPORTED_PLATFORM_ERROR
    )
    install(SCRIPT ${deploy_script})
elseif(WIN32)
    set_target_properties(neurx-codeApp PROPERTIES
        WIN32_EXECUTABLE TRUE
    )
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/app.rc")
        target_sources(neurx-codeApp PRIVATE assets/app.rc)
    endif()
    # Windows deploy via windeployqt (called from build-windows.bat)
endif()

# ── Codex CLI (Rust) ──────────────────────────────────────────────────────────
# Builds the bundled Codex CLI Rust workspace and copies the resulting binary
# into the app output directory so CodexTool can invoke it at runtime.
#
# Disable with:  cmake ... -DBUILD_CODEX_CLI=OFF
# ─────────────────────────────────────────────────────────────────────────────
option(BUILD_CODEX_CLI "Build the Codex CLI from the bundled Rust workspace" ON)

set(CODEX_RS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/codex/codex-rs")

if(BUILD_CODEX_CLI)
    find_program(CARGO_EXECUTABLE cargo
        HINTS
            "$ENV{HOME}/.cargo/bin"
            "/opt/homebrew/bin"
            "/usr/local/bin"
            "$ENV{CARGO_HOME}/bin"
        DOC "Rust Cargo build tool (https://rustup.rs)")

    if(NOT CARGO_EXECUTABLE)
        message(WARNING
            "[neurx] BUILD_CODEX_CLI=ON but 'cargo' was not found. "
            "Install Rust via https://rustup.rs, or pass -DBUILD_CODEX_CLI=OFF to skip. "
            "Disabling Codex CLI build for this configuration.")
        set(BUILD_CODEX_CLI OFF CACHE BOOL "" FORCE)
    endif()
endif()

if(BUILD_CODEX_CLI)
    # Map CMake build type → Cargo profile.
    set(_codex_cargo_args "build" "-p" "codex-cli")
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(CODEX_CARGO_PROFILE "debug")
    else()
        set(CODEX_CARGO_PROFILE "release")
        list(APPEND _codex_cargo_args "--release")
    endif()

    set(CODEX_CLI_BINARY
        "${CODEX_RS_DIR}/target/${CODEX_CARGO_PROFILE}/codex${CMAKE_EXECUTABLE_SUFFIX}")

    # Cargo is incremental; always invoke it — it will only recompile changed crates.
    # Force RUSTUP_TOOLCHAIN=stable so rustup does not attempt to sync/install
    # the pinned 1.95.0 toolchain from rust-toolchain.toml on every build.
    # stable (1.96.0) satisfies the 1.95.0 minimum requirement.
    add_custom_target(codex_cli ALL
        COMMAND ${CMAKE_COMMAND} -E env RUSTUP_TOOLCHAIN=stable
            "${CARGO_EXECUTABLE}" ${_codex_cargo_args}
        BYPRODUCTS "${CODEX_CLI_BINARY}"
        WORKING_DIRECTORY "${CODEX_RS_DIR}"
        COMMENT "[neurx] Building Codex CLI (Rust, profile=${CODEX_CARGO_PROFILE})…"
        USES_TERMINAL
        VERBATIM
    )

    # neurx_core must wait for codex_cli and receives the binary path as a macro.
    add_dependencies(neurx_core codex_cli)
    target_compile_definitions(neurx_core PRIVATE
        CODEX_CLI_BINARY_PATH="${CODEX_CLI_BINARY}"
    )

    # ── Copy the binary into the runtime output tree ──────────────────────────
    if(APPLE)
        # macOS: place inside the .app bundle's Contents/MacOS/
        add_custom_command(TARGET neurx-codeApp POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CODEX_CLI_BINARY}"
                "$<TARGET_BUNDLE_DIR:neurx-codeApp>/Contents/MacOS/codex"
            COMMENT "[neurx] Copying Codex CLI into .app bundle…"
            VERBATIM
        )
        install(PROGRAMS "${CODEX_CLI_BINARY}"
                DESTINATION "neurx-codeApp.app/Contents/MacOS"
                COMPONENT Runtime)
    elseif(WIN32)
        add_custom_command(TARGET neurx-codeApp POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CODEX_CLI_BINARY}"
                "$<TARGET_FILE_DIR:neurx-codeApp>/codex.exe"
            COMMENT "[neurx] Copying Codex CLI next to executable…"
            VERBATIM
        )
        install(PROGRAMS "${CODEX_CLI_BINARY}"
                DESTINATION "."
                COMPONENT Runtime)
    else()
        # Linux: place in the same directory as the app binary.
        add_custom_command(TARGET neurx-codeApp POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CODEX_CLI_BINARY}"
                "$<TARGET_FILE_DIR:neurx-codeApp>/codex"
            COMMENT "[neurx] Copying Codex CLI next to executable…"
            VERBATIM
        )
        install(PROGRAMS "${CODEX_CLI_BINARY}"
                DESTINATION "bin"
                COMPONENT Runtime)
    endif()

    message(STATUS "[neurx] Codex CLI: cargo=${CARGO_EXECUTABLE}, profile=${CODEX_CARGO_PROFILE}")
    message(STATUS "[neurx] Codex CLI binary: ${CODEX_CLI_BINARY}")
endif()

set(QT_QML_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml)
set(QML_IMPORT_PATH ${QT_QML_OUTPUT_DIRECTORY}
    CACHE STRING "Import paths for Qt Creator's code model"
    FORCE
)

if (BUILD_QDS_COMPONENTS)
    include(${CMAKE_CURRENT_SOURCE_DIR}/qmlcomponents)
endif()

include(${CMAKE_CURRENT_SOURCE_DIR}/qmlmodules)

if (LINK_INSIGHT)
    include(${CMAKE_CURRENT_SOURCE_DIR}/insight)
endif ()

include(GNUInstallDirs)
install(TARGETS neurx-codeApp
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# make IDEs aware of the QML import path
set(QML_IMPORT_PATH ${PROJECT_BINARY_DIR}/qml CACHE PATH
    "Path to the custom QML components defined by the project")
