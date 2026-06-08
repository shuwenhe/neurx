#include <iostream>
#include <string>

/**
 * @file hello.cc
 * @brief A simple Hello World program implemented in C++
 * @author neurx-code agent
 * @date 2026-06-08
 * 
 * This program demonstrates:
 * - Basic C++ I/O with iostream
 * - String usage
 * - Functions and main entry point
 * - Comments and documentation
 */

/**
 * @brief Greet the user with a welcome message
 * @param name The name to greet
 * @return The greeting message
 */
std::string greet(const std::string& name) {
    return "Hello, " + name + "!";
}

/**
 * @brief Main entry point of the program
 * @return Exit code (0 for success)
 */
int main(int argc, char* argv[]) {
    // Print a simple greeting
    std::cout << "========================================" << std::endl;
    std::cout << "  Welcome to neurx-code Hello World!    " << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << std::endl;

    // Print basic hello world
    std::cout << "Hello, World!" << std::endl;
    std::cout << std::endl;

    // Use the greet function
    std::string message = greet("neurx-code");
    std::cout << "Message: " << message << std::endl;
    std::cout << std::endl;

    // Print program info
    std::cout << "Program Information:" << std::endl;
    std::cout << "  - Arguments: " << argc << std::endl;
    if (argc > 1) {
        std::cout << "  - Program name: " << argv[0] << std::endl;
    }
    std::cout << std::endl;

    // Print success
    std::cout << "========================================" << std::endl;
    std::cout << "  Program executed successfully!        " << std::endl;
    std::cout << "========================================" << std::endl;

    return 0;  // Successful exit
}
