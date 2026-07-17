cmake_minimum_required(VERSION 3.16)
project(neurx_cann LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(neurx_cann_runtime STATIC
  runtime/acl_runtime.cpp
  cache/paged_kv_cache.cpp
  cache/prefix_cache.cpp
  model/nxtrfmv2_loader.cpp
  operators/operator_library.cpp
  operators/transformer_engine.cpp
  operators/transformer_plan.cpp
  inference/ascend_adapter.cpp
  inference/ascend_executor.cpp
  inference/ascend_worker.cpp
  inference/logits_sampler.cpp
)
set_target_properties(neurx_cann_runtime PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(neurx_cann_runtime PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/.."
)
target_compile_options(neurx_cann_runtime PRIVATE -Wall -Wextra -Werror)
target_link_libraries(neurx_cann_runtime PUBLIC ${CMAKE_DL_LIBS})

add_executable(neurx_ascend_worker
  inference/ascend_worker_main.cpp
  ../serving/native/serving_socket.c
)
target_link_libraries(neurx_ascend_worker PRIVATE neurx_cann_runtime)
target_compile_options(neurx_ascend_worker PRIVATE -Wall -Wextra -Werror)

include(CTest)
if(BUILD_TESTING)
  add_executable(cann_logits_sampler_test
    ../tests/cann_logits_sampler_test.cpp
    inference/logits_sampler.cpp
  )
  target_include_directories(cann_logits_sampler_test PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/.."
  )
  target_compile_options(cann_logits_sampler_test PRIVATE
    -Wall -Wextra -Werror)
  add_test(NAME cann_logits_sampler COMMAND cann_logits_sampler_test)

  add_executable(cann_prefix_cache_test
    ../tests/cann_prefix_cache_test.cpp
  )
  target_link_libraries(cann_prefix_cache_test PRIVATE neurx_cann_runtime)
  target_compile_options(cann_prefix_cache_test PRIVATE
    -Wall -Wextra -Werror)
  add_test(NAME cann_prefix_cache COMMAND cann_prefix_cache_test)
endif()

# These sources are supplied on an Ascend build host because they require the
# matching CANN toolkit and target-SoC compiler.
option(NEURX_ENABLE_ATB_310P
       "Build the production Ascend310P ATB operator plugin" OFF)
set(NEURX_CANN_OPERATOR_SOURCES "" CACHE STRING
    "Semicolon-separated Ascend C/ACLNN operator plugin sources")
if(NEURX_ENABLE_ATB_310P)
  add_library(neurx_cann_operators SHARED operators/atb_310p_plugin.cpp)
  target_include_directories(neurx_cann_operators PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/.."
    "$ENV{ASCEND_HOME_PATH}/include"
    "$ENV{ATB_HOME_PATH}/include"
  )
  target_link_directories(neurx_cann_operators PRIVATE
    "$ENV{ASCEND_HOME_PATH}/lib64"
    "$ENV{ATB_HOME_PATH}/lib"
  )
  target_link_libraries(neurx_cann_operators PRIVATE
    neurx_cann_runtime atb ascendcl)
  set_target_properties(neurx_cann_operators PROPERTIES
    OUTPUT_NAME neurx_cann_operators)
  install(TARGETS neurx_cann_operators LIBRARY DESTINATION lib)
elseif(NEURX_CANN_OPERATOR_SOURCES)
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
install(TARGETS neurx_ascend_worker RUNTIME DESTINATION bin)
install(DIRECTORY runtime cache model operators inference
        DESTINATION include/neurx/cann
        FILES_MATCHING PATTERN "*.h")
