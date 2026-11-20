cmake_minimum_required(VERSION 3.16)
project(neurx_mlu_device_abi LANGUAGES C)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
  message(FATAL_ERROR "The MLU Device ABI plugin requires Linux")
endif()

set(S_REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../s" CACHE PATH
    "Path to the S source checkout")
set(S_SEED_COMPILER "${S_REPO_ROOT}/bin/s_seed" CACHE FILEPATH
    "Path to a prebuilt S seed compiler")
if(NOT EXISTS "${S_SEED_COMPILER}")
  message(FATAL_ERROR "MLU Device ABI requires a prebuilt S seed compiler")
endif()

set(mlu_source "${CMAKE_CURRENT_SOURCE_DIR}/device_abi_mlu.s")
set(mlu_ir "${CMAKE_CURRENT_BINARY_DIR}/device_abi_mlu.ir")
set(mlu_s_library "${CMAKE_CURRENT_BINARY_DIR}/libneurx_mlu_s.so")

add_custom_command(
  OUTPUT "${mlu_ir}"
  COMMAND "${S_SEED_COMPILER}" "${mlu_source}" "${mlu_ir}"
  DEPENDS "${mlu_source}" "${S_SEED_COMPILER}"
  VERBATIM)
add_custom_command(
  OUTPUT "${mlu_s_library}"
  COMMAND "${CMAKE_COMMAND}" -E env "S_SOURCE_ROOT=${S_REPO_ROOT}"
          "${S_SEED_COMPILER}" --emit-shared "${mlu_ir}" "${mlu_s_library}"
  DEPENDS "${mlu_ir}"
  VERBATIM)

add_custom_target(neurx_mlu_s_build DEPENDS "${mlu_s_library}")
add_library(neurx_mlu_s SHARED IMPORTED)
set_target_properties(neurx_mlu_s PROPERTIES
  IMPORTED_LOCATION "${mlu_s_library}"
  IMPORTED_NO_SONAME TRUE)

find_package(Threads REQUIRED)

add_library(neurx_backend_mlu SHARED device_abi_mlu.c)
add_dependencies(neurx_backend_mlu neurx_mlu_s_build)
target_compile_features(neurx_backend_mlu PRIVATE c_std_11)
target_compile_options(neurx_backend_mlu PRIVATE -Wall -Wextra -Werror)
set(NEURX_MLU_CNRT_INCLUDE "" CACHE PATH "CNRT headers for the optional diagnostics")
if(NEURX_MLU_CNRT_INCLUDE)
  target_include_directories(neurx_backend_mlu PRIVATE "${NEURX_MLU_CNRT_INCLUDE}")
  target_compile_definitions(neurx_backend_mlu PRIVATE NEURX_ENABLE_CNRT_DIAGNOSTIC)
endif()
target_link_options(neurx_backend_mlu PRIVATE LINKER:-z,defs)
target_link_libraries(neurx_backend_mlu PRIVATE neurx_mlu_s Threads::Threads ${CMAKE_DL_LIBS})
set_target_properties(neurx_backend_mlu PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/$<0:unused>"
  BUILD_WITH_INSTALL_RPATH TRUE
  INSTALL_RPATH "$ORIGIN")

install(TARGETS neurx_backend_mlu LIBRARY DESTINATION lib)
install(FILES "${mlu_s_library}" DESTINATION lib)
