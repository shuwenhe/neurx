cmake_minimum_required(VERSION 3.18)
project(neurx_rocm_runtime LANGUAGES HIP CXX)

find_package(HIP REQUIRED)
find_package(rocblas REQUIRED)
find_package(MIOpen REQUIRED)

find_package(Findrocm-cmake QUIET)
if(NOT rocm-cmake_FOUND)
    set(rocm_HOME "/opt/rocm")
    set(CMAKE_MODULE_PATH "${rocm_HOME}/lib/cmake" ${CMAKE_MODULE_PATH})
endif()

set(ROCM_SOURCES
    rocm_runtime_binding.hip
)

add_library(neurx_rocm_runtime SHARED ${ROCM_SOURCES})

target_include_directories(neurx_rocm_runtime
    PUBLIC
        ${HIP_INCLUDE_DIRS}
        ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(neurx_rocm_runtime
    PUBLIC
        hip::host
        rocblas::rocblas
        MIOpen::MIOpen
)

set_target_properties(neurx_rocm_runtime PROPERTIES
    HIP_STANDARD 17
    HIP_STANDARD_REQUIRED ON
    POSITION_INDEPENDENT_CODE ON
)

install(
    TARGETS neurx_rocm_runtime
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)

install(
    FILES rocm_runtime_binding.h
    DESTINATION include
)

enable_testing()

add_executable(test_rocm_runtime rocm_runtime_test.hip)
target_link_libraries(test_rocm_runtime PRIVATE neurx_rocm_runtime)
add_test(NAME rocm_runtime_test COMMAND test_rocm_runtime)

message(STATUS "ROCm Runtime Build Configuration:")
message(STATUS "  HIP Version: ${HIP_VERSION}")
message(STATUS "  rocBLAS: ${rocblas_FOUND}")
message(STATUS "  MIOpen: ${MIOpen_FOUND}")
