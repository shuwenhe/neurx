cmake_minimum_required(VERSION 3.16)
project(neurx_cann LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(neurx_cann_runtime STATIC
  runtime/acl_runtime.cpp
  cache/paged_kv_cache.cpp
  model/nxtrfmv2_loader.cpp
  operators/operator_library.cpp
  inference/ascend_adapter.cpp
  inference/ascend_executor.cpp
)
target_include_directories(neurx_cann_runtime PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/.."
)
target_compile_options(neurx_cann_runtime PRIVATE -Wall -Wextra -Werror)
target_link_libraries(neurx_cann_runtime PUBLIC ${CMAKE_DL_LIBS})

# These sources are supplied on an Ascend build host because they require the
# matching CANN toolkit and target-SoC compiler.
set(NEURX_CANN_OPERATOR_SOURCES "" CACHE STRING
    "Semicolon-separated Ascend C/ACLNN operator plugin sources")
if(NEURX_CANN_OPERATOR_SOURCES)
  add_library(neurx_cann_operators SHARED ${NEURX_CANN_OPERATOR_SOURCES})
  target_include_directories(neurx_cann_operators PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/.."
    "$ENV{ASCEND_HOME_PATH}/include"
  )
  target_link_directories(neurx_cann_operators PRIVATE
    "$ENV{ASCEND_HOME_PATH}/lib64"
  )
  target_link_libraries(neurx_cann_operators PRIVATE ascendcl)
  set_target_properties(neurx_cann_operators PROPERTIES
    OUTPUT_NAME neurx_cann_operators
  )
endif()

install(TARGETS neurx_cann_runtime ARCHIVE DESTINATION lib)
install(DIRECTORY runtime cache model operators inference
        DESTINATION include/neurx/cann
        FILES_MATCHING PATTERN "*.h")
