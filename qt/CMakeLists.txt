cmake_minimum_required(VERSION 3.21)
project(neurx_qt_shell LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets)

qt_add_executable(neurx_qt
    app/main.cpp
    bridge/neurx_bridge.h
    bridge/neurx_bridge.cpp
)

target_link_libraries(neurx_qt PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets)

target_include_directories(neurx_qt PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

install(TARGETS neurx_qt)
