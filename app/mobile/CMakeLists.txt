cmake_minimum_required(VERSION 3.21)
project(neurx_mobile LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Network
    Qml
    Quick
    QuickControls2
    Concurrent
    Sql
)

qt_add_executable(neurx_mobile
    main.cpp
    ../bridge/AgentListModel.h
    ../bridge/AgentListModel.cpp
    ../bridge/LogModel.h
    ../bridge/LogModel.cpp
    ../bridge/neurx_bridge.h
    ../bridge/neurx_bridge.cpp
)

qt_add_qml_module(neurx_mobile
    URI neurx.mobile
    VERSION 1.0
    QML_FILES
        qml/MobileMain.qml
        qml/MobileHome.qml
)

target_include_directories(neurx_mobile PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(neurx_mobile PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Concurrent
    Qt6::Sql
)

set_target_properties(neurx_mobile PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
    QT_QMLCACHEGEN_ARGUMENTS "--only-bytecode"
)

if(ANDROID)
    set_target_properties(neurx_mobile PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
    )
endif()

if(IOS)
    set(NEURX_MOBILE_BUNDLE_ID "com.neurx.mobile" CACHE STRING "iOS bundle identifier")
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist.in"
        "${CMAKE_CURRENT_BINARY_DIR}/Info.plist"
        @ONLY
    )
    set_target_properties(neurx_mobile PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/Info.plist"
        MACOSX_BUNDLE_BUNDLE_NAME "NeurX Mobile"
        MACOSX_BUNDLE_GUI_IDENTIFIER "${NEURX_MOBILE_BUNDLE_ID}"
    )
endif()

install(TARGETS neurx_mobile
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
)
