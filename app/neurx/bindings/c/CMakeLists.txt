add_library(neurx_bridge STATIC neurx_bridge.c)
# Add include dirs and link to external runtime/kernels as needed
target_include_directories(neurx_bridge PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
