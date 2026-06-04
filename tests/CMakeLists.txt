cmake_minimum_required(VERSION 3.21)

# Find Qt6 Test module
find_package(Qt6 COMPONENTS Test Core Gui Qml Quick REQUIRED)

# Enable automatic MOC for test files
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Get all test files
file(GLOB TEST_SOURCES "tst_*.cpp")

# Create executable for each test
foreach(TEST_FILE ${TEST_SOURCES})
    get_filename_component(TEST_NAME ${TEST_FILE} NAME_WE)
    
    add_executable(${TEST_NAME} ${TEST_FILE})
    
    target_link_libraries(${TEST_NAME}
        Qt6::Test
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        neurx_core
        neurx_ui
    )
    
    target_include_directories(${TEST_NAME} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/../src
    )
    
    # Register the test with CTest
    add_test(NAME ${TEST_NAME} COMMAND ${TEST_NAME})
endforeach()

# Summary
message(STATUS "Tests configured: ${CMAKE_CURRENT_SOURCE_DIR}")
