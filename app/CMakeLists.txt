cmake_minimum_required(VERSION 3.21)
project(neurx_app_shell LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

set(NEURX_APP_TARGET_PLATFORM "${NEURX_APP_TARGET_PLATFORM}" CACHE STRING "NeurX app target platform")
if(NOT NEURX_APP_TARGET_PLATFORM)
    if(WIN32)
        set(NEURX_APP_TARGET_PLATFORM "windows")
    elseif(APPLE)
        set(NEURX_APP_TARGET_PLATFORM "macos")
    else()
        set(NEURX_APP_TARGET_PLATFORM "linux")
    endif()
endif()

string(TOLOWER "${NEURX_APP_TARGET_PLATFORM}" NEURX_APP_TARGET_PLATFORM)

if(NEURX_APP_TARGET_PLATFORM STREQUAL "ios" OR NEURX_APP_TARGET_PLATFORM STREQUAL "android")
    find_package(Qt6 REQUIRED COMPONENTS Core Gui Network Qml Quick QuickControls2 Concurrent Sql)
    add_subdirectory(mobile)
    return()
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Concurrent Sql)

if(NEURX_APP_TARGET_PLATFORM STREQUAL "windows")
    set(NEURX_APP_OUTPUT_SUBDIR "windows-x86_64")
elseif(NEURX_APP_TARGET_PLATFORM STREQUAL "linux")
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
        set(NEURX_APP_OUTPUT_SUBDIR "linux-arm64")
    else()
        set(NEURX_APP_OUTPUT_SUBDIR "linux-x86_64")
    endif()
elseif(NEURX_APP_TARGET_PLATFORM STREQUAL "macos")
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
        set(NEURX_APP_OUTPUT_SUBDIR "macos-arm64")
    else()
        set(NEURX_APP_OUTPUT_SUBDIR "macos-x86_64")
    endif()
elseif(NEURX_APP_TARGET_PLATFORM STREQUAL "harmony")
    message(FATAL_ERROR "NeurX app Harmony target is not implemented yet.")
else()
    message(FATAL_ERROR "Unsupported NEURX_APP_TARGET_PLATFORM=${NEURX_APP_TARGET_PLATFORM}")
endif()

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../bin/${NEURX_APP_OUTPUT_SUBDIR}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")

qt_add_executable(neurx_app
    app/main.cpp
    bridge/AgentListModel.h
    bridge/AgentListModel.cpp
    bridge/LogModel.h
    bridge/LogModel.cpp
    bridge/neurx_bridge.h
    bridge/neurx_bridge.cpp
)

qt_add_qml_module(neurx_app
    URI neurx.app
    VERSION 1.0
    RESOURCES
        icons/copy.svg
        icons/check.svg
        icons/folder.svg
        icons/file.svg
        icons/chevron-right.svg
        icons/chevron-down.svg
        icons/refresh.svg
        icons/disks.svg
        icons/up.svg
    QML_FILES
        qml/Main.qml
        qml/AppShell.qml
)

set_target_properties(neurx_app PROPERTIES
    QT_QMLCACHEGEN_ARGUMENTS "--only-bytecode"
)

target_link_libraries(neurx_app PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Concurrent Qt6::Sql)

target_include_directories(neurx_app PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

install(TARGETS neurx_app
    RUNTIME DESTINATION bin/${NEURX_APP_OUTPUT_SUBDIR}
)
