cmake_minimum_required(VERSION 3.16)
project(neurx LANGUAGES C)

# Top-level targets for building bridges and examples
add_subdirectory(bindings/c)
add_subdirectory(examples)
add_subdirectory(tests)
