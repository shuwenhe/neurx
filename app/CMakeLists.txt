cmake_minimum_required(VERSION 3.21)
project(neurx_app_shell LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

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
    QML_FILES
        qml/Main.qml
        qml/AppShell.qml
)

target_link_libraries(neurx_app PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2)

target_include_directories(neurx_app PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

install(TARGETS neurx_app)
