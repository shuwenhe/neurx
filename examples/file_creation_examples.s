package main
use std.io.println

func main() {
    println("S-native file creation examples")
    println("  NEURX_CREATE_FILE_PATH=src/main.s NEURX_CREATE_FILE_TEXT='package main' NEURX_CREATE_FILE_OVERWRITE=1 create_file")
    println("  NEURX_CREATE_FILE_PATH=configs/neurx/runtime.json NEURX_CREATE_FILE_TEXT='{}' create_file")
    println("The command creates parent directories and refuses accidental overwrite.")
    0
}
