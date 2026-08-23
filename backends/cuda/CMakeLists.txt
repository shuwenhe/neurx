cmake_minimum_required(VERSION 3.18)
project(neurx_cuda_runtime LANGUAGES CUDA CXX)

find_package(CUDA REQUIRED)
find_package(CUDAToolkit REQUIRED)

set(CUDA_SOURCES
    cuda_runtime_binding.cu
)

add_library(neurx_cuda_runtime SHARED ${CUDA_SOURCES})

target_link_libraries(neurx_cuda_runtime
    PUBLIC
        CUDA::cudart
        CUDA::cublas
)

target_include_directories(neurx_cuda_runtime
    PUBLIC
        ${CUDA_INCLUDE_DIRS}
        ${CMAKE_CURRENT_SOURCE_DIR}
)

set_target_properties(neurx_cuda_runtime PROPERTIES
    CUDA_STANDARD 14
    CUDA_STANDARD_REQUIRED ON
    POSITION_INDEPENDENT_CODE ON
)

install(
    TARGETS neurx_cuda_runtime
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)

install(
    FILES cuda_runtime_binding.h
    DESTINATION include
)

enable_testing()

add_executable(test_cuda_runtime cuda_runtime_test.cu)
target_link_libraries(test_cuda_runtime PRIVATE neurx_cuda_runtime)
add_test(NAME cuda_runtime_test COMMAND test_cuda_runtime)
